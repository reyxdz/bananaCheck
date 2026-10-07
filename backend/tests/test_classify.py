import importlib
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
    def test_returns_503_when_model_cannot_be_loaded(self, tmp_path: Path) -> None:
        """The dependency converts a load failure into a clean 503."""
        bogus = BackendConfig(
            labels_path=tmp_path / "absent.txt",
            model_path=tmp_path / "absent.tflite",
        )
        _cached_inference_service.cache_clear()
        try:
            with pytest.raises(HTTPException) as excinfo:
                get_inference_service(bogus)
            assert excinfo.value.status_code == 503
        finally:
            _cached_inference_service.cache_clear()

    def test_app_config_drives_model_loading(self, tmp_path: Path) -> None:
        """Regression: create_app(config) must not silently use the default model.

        The inference service used to be cached from the environment-derived
        config, so an app built with a custom ``model_path`` loaded the shipped
        model anyway — a model-testing tool quietly testing the wrong model.
        """
        bogus = BackendConfig(
            model_path=tmp_path / "absent.tflite",
            labels_path=tmp_path / "absent.txt",
        )
        _cached_inference_service.cache_clear()
        try:
            client = TestClient(create_app(bogus))
            response = client.post(
                "/classify",
                files={"image": ("b.jpg", _jpeg_bytes(), "image/jpeg")},
            )
            assert response.status_code == 503
        finally:
            _cached_inference_service.cache_clear()


class TestUploadValidation:
    def test_rejects_oversized_upload_with_413(self) -> None:
        """A payload above max_upload_bytes is refused before decoding."""
        app = create_app(BackendConfig(max_upload_bytes=512))
        app.dependency_overrides[get_inference_service] = lambda: _stub_service(
            [1.0, 0.0, 0.0]
        )
        client = TestClient(app)

        big = _jpeg_bytes(size=256)  # comfortably over 512 bytes
        assert len(big) > 512

        response = client.post(
            "/classify", files={"image": ("big.jpg", big, "image/jpeg")}
        )

        assert response.status_code == 413

    def test_accepts_upload_within_the_limit(self) -> None:
        app = create_app(BackendConfig(max_upload_bytes=10 * 1024 * 1024))
        app.dependency_overrides[get_inference_service] = lambda: _stub_service(
            [0.0, 1.0, 0.0]
        )
        client = TestClient(app)

        response = client.post(
            "/classify", files={"image": ("ok.jpg", _jpeg_bytes(), "image/jpeg")}
        )

        assert response.status_code == 200

    def test_rejects_unsupported_format_with_415(self) -> None:
        """A decodable but disallowed format (BMP) gets 415, not 400."""
        buf = io.BytesIO()
        Image.new("RGB", (32, 32), (10, 20, 30)).save(buf, format="BMP")

        client = _client(_stub_service([1.0, 0.0, 0.0]))
        response = client.post(
            "/classify", files={"image": ("sneaky.jpg", buf.getvalue(), "image/jpeg")}
        )

        assert response.status_code == 415

    def test_png_upload_is_accepted(self) -> None:
        buf = io.BytesIO()
        Image.new("RGB", (32, 32), (90, 140, 40)).save(buf, format="PNG")

        client = _client(_stub_service([0.0, 0.0, 1.0]))
        response = client.post(
            "/classify", files={"image": ("ok.png", buf.getvalue(), "image/png")}
        )

        assert response.status_code == 200


# ---------------------------------------------------------------------------
# API edge cases (B24)
# ---------------------------------------------------------------------------


class TestClassifyEdgeCases:
    def test_rejects_get_with_405(self) -> None:
        """Only POST is defined for /classify."""
        assert _client(_stub_service([1.0, 0.0, 0.0])).get("/classify").status_code == 405

    def test_rejects_non_multipart_body_with_422(self) -> None:
        """A JSON body is not a file upload."""
        client = _client(_stub_service([1.0, 0.0, 0.0]))
        response = client.post("/classify", json={"image": "not-a-file"})
        assert response.status_code == 422

    def test_rejects_wrong_field_name_with_422(self) -> None:
        client = _client(_stub_service([1.0, 0.0, 0.0]))
        response = client.post(
            "/classify", files={"file": ("banana.jpg", _jpeg_bytes(), "image/jpeg")}
        )
        assert response.status_code == 422

    @pytest.mark.parametrize("mode,colour", [("L", 128), ("RGBA", (10, 20, 30, 200))])
    def test_accepts_non_rgb_images(self, mode: str, colour: object) -> None:
        """Grayscale and RGBA decode fine — preprocessing converts to RGB."""
        buf = io.BytesIO()
        Image.new(mode, (48, 48), colour).save(buf, format="PNG")

        client = _client(_stub_service([0.0, 1.0, 0.0]))
        response = client.post(
            "/classify", files={"image": ("x.png", buf.getvalue(), "image/png")}
        )

        assert response.status_code == 200
        assert response.json()["variety"] == "Lakatan"

    def test_accepts_single_pixel_image(self) -> None:
        """A 1x1 image is degenerate but valid; it upscales to the model input."""
        buf = io.BytesIO()
        Image.new("RGB", (1, 1), (255, 0, 0)).save(buf, format="PNG")

        client = _client(_stub_service([0.0, 0.0, 1.0]))
        response = client.post(
            "/classify", files={"image": ("tiny.png", buf.getvalue(), "image/png")}
        )

        assert response.status_code == 200

    def test_accepts_large_dimension_image(self) -> None:
        """A high-resolution photo is downscaled rather than rejected."""
        buf = io.BytesIO()
        Image.new("RGB", (2000, 1500), (180, 160, 40)).save(buf, format="JPEG")

        client = _client(_stub_service([1.0, 0.0, 0.0]))
        response = client.post(
            "/classify", files={"image": ("big.jpg", buf.getvalue(), "image/jpeg")}
        )

        assert response.status_code == 200

    def test_rejects_truncated_image_with_400(self) -> None:
        """Valid JPEG magic bytes but a truncated body is still undecodable."""
        truncated = _jpeg_bytes(size=128)[:80]

        client = _client(_stub_service([1.0, 0.0, 0.0]))
        response = client.post(
            "/classify", files={"image": ("cut.jpg", truncated, "image/jpeg")}
        )

        assert response.status_code == 400

    def test_response_matches_the_schema_contract(self) -> None:
        """Response carries exactly the Dart ClassificationResult fields (B21)."""
        client = _client(_stub_service([0.1, 0.75, 0.15]))
        body = client.post(
            "/classify", files={"image": ("b.jpg", _jpeg_bytes(), "image/jpeg")}
        ).json()

        assert set(body) == {"variety", "ripeness", "confidence"}
        assert isinstance(body["variety"], str)
        assert isinstance(body["ripeness"], str)
        assert 0.0 <= body["confidence"] <= 1.0

    def test_classify_is_documented_in_openapi(self) -> None:
        spec = create_app(BackendConfig()).openapi()
        assert "post" in spec["paths"]["/classify"]
        schema = spec["paths"]["/classify"]["post"]["responses"]["200"]["content"][
            "application/json"
        ]["schema"]
        assert schema["$ref"].endswith("ClassificationResponse")


# ---------------------------------------------------------------------------
# Real-model integration (B24)
# ---------------------------------------------------------------------------
#
# Every test above stubs the predictor, so the actual TFLite loading path is
# never exercised. These run against the *shipped* model and skip cleanly when
# the model asset or a TFLite runtime is unavailable (e.g. a lean CI image).


def _tflite_runtime_available() -> bool:
    for module in ("ai_edge_litert", "tensorflow"):
        try:
            importlib.import_module(module)
            return True
        except ImportError:
            continue
    return False


_SHIPPED = BackendConfig()
_REAL_MODEL_READY = (
    _SHIPPED.model_path.is_file()
    and _SHIPPED.labels_path.is_file()
    and _tflite_runtime_available()
)


@pytest.mark.skipif(
    not _REAL_MODEL_READY,
    reason="bundled .tflite or a TFLite runtime is unavailable",
)
class TestRealModelIntegration:
    def test_predictor_loads_and_returns_a_distribution(self) -> None:
        """Covers load_tflite_predictor against the real shipped model."""
        predict = load_tflite_predictor(_SHIPPED.model_path)
        probabilities = list(predict(preprocess_image(_jpeg_bytes(size=224))))

        labels = _SHIPPED.load_labels()
        assert len(probabilities) == len(labels)
        assert all(0.0 <= p <= 1.0 for p in probabilities)
        assert sum(probabilities) == pytest.approx(1.0, abs=1e-3)

    def test_endpoint_classifies_with_the_bundled_model(self) -> None:
        """End-to-end: no stubbing — real model, real labels, real HTTP."""
        _cached_inference_service.cache_clear()
        try:
            client = TestClient(create_app(BackendConfig()))
            response = client.post(
                "/classify",
                files={"image": ("banana.jpg", _jpeg_bytes(size=224), "image/jpeg")},
            )

            assert response.status_code == 200
            body = response.json()
            assert set(body) == {"variety", "ripeness", "confidence"}
            # The predicted label must be one the shipped labels.txt defines.
            # NotBanana is the one class with no ripeness, so it rejoins as the
            # bare variety rather than "Variety_Ripeness" — a synthetic image
            # like this one is exactly what it is trained to catch.
            ripeness = body["ripeness"]
            predicted = f"{body['variety']}_{ripeness}" if ripeness else body["variety"]
            assert predicted in _SHIPPED.load_labels()
            assert 0.0 <= body["confidence"] <= 1.0
        finally:
            _cached_inference_service.cache_clear()
