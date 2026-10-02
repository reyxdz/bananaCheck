import io
from pathlib import Path

import numpy as np
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from PIL import Image

from backend.app.config import BackendConfig
from backend.app.main import create_app
from backend.app.models.schemas import ClassificationResponse
from backend.app.routers.classify import (
    _cached_inference_service,
    build_inference_service,
    get_inference_service,
)
from backend.app.services.inference import (
    DEFAULT_INPUT_SIZE,
    InferenceService,
    InvalidImageError,
    ModelUnavailableError,
    decode_label,
    load_tflite_predictor,
    preprocess_image,
)

_LABELS = ["Cavendish_Overripe", "Lakatan_Ripe", "Saba_Unripe"]


def _jpeg_bytes(size: int = 32, color: tuple[int, int, int] = (200, 180, 40)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (size, size), color).save(buf, format="JPEG")
    return buf.getvalue()


def _stub_service(probabilities: list[float]) -> InferenceService:
    return InferenceService(
        labels=_LABELS,
        predict=lambda _batch: probabilities,
        input_size=8,
    )


def _client(service: InferenceService | None = None) -> TestClient:
    app = create_app(BackendConfig())
    if service is not None:
        app.dependency_overrides[get_inference_service] = lambda: service
    return TestClient(app)


# ---------------------------------------------------------------------------
# preprocess_image
# ---------------------------------------------------------------------------


class TestPreprocessImage:
    def test_shape_and_normalisation(self) -> None:
        batch = preprocess_image(_jpeg_bytes(), size=DEFAULT_INPUT_SIZE)
        assert batch.shape == (1, DEFAULT_INPUT_SIZE, DEFAULT_INPUT_SIZE, 3)
        assert batch.dtype == np.float32
        assert batch.min() >= 0.0
        assert batch.max() <= 1.0

    def test_resizes_to_requested_size(self) -> None:
        assert preprocess_image(_jpeg_bytes(size=100), size=16).shape == (1, 16, 16, 3)

    def test_rejects_undecodable_bytes(self) -> None:
        with pytest.raises(InvalidImageError):
            preprocess_image(b"definitely not an image")


# ---------------------------------------------------------------------------
# decode_label
# ---------------------------------------------------------------------------


class TestDecodeLabel:
    def test_underscore_format(self) -> None:
        assert decode_label("Lakatan_Ripe") == ("Lakatan", "Ripe")

    def test_pipe_format(self) -> None:
        assert decode_label("Lakatan|Ripe") == ("Lakatan", "Ripe")


# ---------------------------------------------------------------------------
# InferenceService
# ---------------------------------------------------------------------------


class TestInferenceService:
    def test_picks_argmax_label(self) -> None:
        result = _stub_service([0.1, 0.8, 0.1]).classify(_jpeg_bytes())
        assert isinstance(result, ClassificationResponse)
        assert result.variety == "Lakatan"
        assert result.ripeness == "Ripe"
        assert result.confidence == pytest.approx(0.8)

    def test_rejects_empty_labels(self) -> None:
        with pytest.raises(ModelUnavailableError):
            InferenceService(labels=[], predict=lambda _b: [1.0])

    def test_detects_label_model_length_mismatch(self) -> None:
        service = InferenceService(
            labels=_LABELS, predict=lambda _b: [0.5, 0.5], input_size=8
        )
        with pytest.raises(ModelUnavailableError, match="out of sync"):
            service.classify(_jpeg_bytes())

    def test_clamps_confidence(self) -> None:
        result = _stub_service([1.4, 0.0, 0.0]).classify(_jpeg_bytes())
        assert result.confidence <= 1.0


# ---------------------------------------------------------------------------
# load_tflite_predictor
# ---------------------------------------------------------------------------


class TestLoadTflitePredictor:
    def test_raises_on_missing_model(self, tmp_path: Path) -> None:
        with pytest.raises(ModelUnavailableError, match="Model file not found"):
            load_tflite_predictor(tmp_path / "nope.tflite")


# ---------------------------------------------------------------------------
# build_inference_service
# ---------------------------------------------------------------------------


class TestBuildInferenceService:
    def test_raises_when_labels_missing(self, tmp_path: Path) -> None:
        config = BackendConfig(
            labels_path=tmp_path / "absent.txt",
            model_path=tmp_path / "absent.tflite",
        )
        with pytest.raises(ModelUnavailableError, match="No labels found"):
            build_inference_service(config)


# ---------------------------------------------------------------------------
# POST /classify
# ---------------------------------------------------------------------------


class TestClassifyEndpoint:
    def test_returns_prediction(self) -> None:
        client = _client(_stub_service([0.05, 0.9, 0.05]))

        response = client.post(
            "/classify",
            files={"image": ("banana.jpg", _jpeg_bytes(), "image/jpeg")},
        )

        assert response.status_code == 200
        assert response.json() == {
            "variety": "Lakatan",
            "ripeness": "Ripe",
            "confidence": pytest.approx(0.9),
        }

    def test_rejects_undecodable_image_with_400(self) -> None:
        client = _client(_stub_service([1.0, 0.0, 0.0]))

        response = client.post(
            "/classify",
            files={"image": ("bad.jpg", b"not an image", "image/jpeg")},
        )

        assert response.status_code == 400

    def test_rejects_empty_upload_with_400(self) -> None:
        client = _client(_stub_service([1.0, 0.0, 0.0]))

        response = client.post(
            "/classify",
            files={"image": ("empty.jpg", b"", "image/jpeg")},
        )

        assert response.status_code == 400

    def test_requires_the_image_field(self) -> None:
        client = _client(_stub_service([1.0, 0.0, 0.0]))
        assert client.post("/classify").status_code == 422

    def test_returns_503_when_inference_fails(self) -> None:
        """A model/labels mismatch at request time must surface as 503."""

        def _broken(_batch: object) -> list[float]:
            raise ModelUnavailableError("backend broke")

        client = _client(
            InferenceService(labels=_LABELS, predict=_broken, input_size=8)
        )

        response = client.post(
            "/classify",
            files={"image": ("banana.jpg", _jpeg_bytes(), "image/jpeg")},
        )

        assert response.status_code == 503


class TestGetInferenceServiceDependency:
    def test_returns_503_when_model_cannot_be_loaded(
        self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        """The dependency converts a load failure into a clean 503."""
        monkeypatch.setenv("BANANA_LABELS_PATH", str(tmp_path / "absent.txt"))
        monkeypatch.setenv("BANANA_MODEL_PATH", str(tmp_path / "absent.tflite"))
        _cached_inference_service.cache_clear()

        with pytest.raises(HTTPException) as excinfo:
            get_inference_service()
        assert excinfo.value.status_code == 503

        _cached_inference_service.cache_clear()
