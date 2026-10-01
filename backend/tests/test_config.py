from pathlib import Path

import pytest

from backend.app.config import BackendConfig, get_config

_ENV_VARS = (
    "BANANA_MODEL_PATH",
    "BANANA_LABELS_PATH",
    "BANANA_CONFIDENCE_THRESHOLD",
    "BANANA_CORS_ORIGINS",
)


@pytest.fixture(autouse=True)
def _clear_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """Ensure BANANA_* env vars never leak between tests."""
    for name in _ENV_VARS:
        monkeypatch.delenv(name, raising=False)


# ---------------------------------------------------------------------------
# Defaults & validation
# ---------------------------------------------------------------------------


class TestBackendConfig:
    def test_sensible_defaults(self) -> None:
        config = BackendConfig()
        assert config.confidence_threshold == 0.5
        assert config.cors_allow_origins  # non-empty
        assert config.model_path.name == "banana_classifier.tflite"
        assert config.labels_path.name == "labels.txt"

    @pytest.mark.parametrize("threshold", [-0.1, 1.1])
    def test_rejects_out_of_range_threshold(self, threshold: float) -> None:
        with pytest.raises(ValueError, match="confidence_threshold"):
            BackendConfig(confidence_threshold=threshold)

    def test_rejects_empty_cors_origins(self) -> None:
        with pytest.raises(ValueError, match="cors_allow_origins"):
            BackendConfig(cors_allow_origins=())


# ---------------------------------------------------------------------------
# load_labels
# ---------------------------------------------------------------------------


class TestLoadLabels:
    def test_reads_labels_in_order(self, tmp_path: Path) -> None:
        labels_file = tmp_path / "labels.txt"
        labels_file.write_text("Saba_Ripe\nLakatan_Unripe\n", encoding="utf-8")
        config = BackendConfig(labels_path=labels_file)

        assert config.load_labels() == ["Saba_Ripe", "Lakatan_Unripe"]

    def test_skips_blank_lines(self, tmp_path: Path) -> None:
        labels_file = tmp_path / "labels.txt"
        labels_file.write_text("A_B\n\n  \nC_D\n", encoding="utf-8")
        config = BackendConfig(labels_path=labels_file)

        assert config.load_labels() == ["A_B", "C_D"]

    def test_missing_file_returns_empty(self, tmp_path: Path) -> None:
        config = BackendConfig(labels_path=tmp_path / "nope.txt")
        assert config.load_labels() == []


# ---------------------------------------------------------------------------
# get_config — environment overrides
# ---------------------------------------------------------------------------


class TestGetConfig:
    def test_defaults_without_env(self) -> None:
        config = get_config()
        assert config.confidence_threshold == 0.5

    def test_env_overrides_all_fields(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("BANANA_MODEL_PATH", "/models/m.tflite")
        monkeypatch.setenv("BANANA_LABELS_PATH", "/models/labels.txt")
        monkeypatch.setenv("BANANA_CONFIDENCE_THRESHOLD", "0.7")
        monkeypatch.setenv(
            "BANANA_CORS_ORIGINS",
            "http://localhost:3000, http://example.test",
        )

        config = get_config()

        assert config.model_path == Path("/models/m.tflite")
        assert config.labels_path == Path("/models/labels.txt")
        assert config.confidence_threshold == 0.7
        assert config.cors_allow_origins == (
            "http://localhost:3000",
            "http://example.test",
        )
