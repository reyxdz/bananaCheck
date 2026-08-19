from pathlib import Path

import pytest

from ml.preprocess import PreprocessConfig, require_directory


def test_preprocess_config_rejects_non_positive_dimensions() -> None:
    with pytest.raises(ValueError, match="positive"):
        PreprocessConfig(width=0, height=224)


def test_require_directory_accepts_existing_directory(tmp_path: Path) -> None:
    assert require_directory(tmp_path) == tmp_path.resolve()


def test_require_directory_rejects_missing_path(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="Dataset directory not found"):
        require_directory(tmp_path / "missing")
