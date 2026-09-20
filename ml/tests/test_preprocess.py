from pathlib import Path

import pytest

from ml.classes import ALL_CLASSES
from ml.preprocess import PreprocessConfig, require_directory, validate_dataset_structure


def test_preprocess_config_rejects_non_positive_dimensions() -> None:
    with pytest.raises(ValueError, match="positive"):
        PreprocessConfig(width=0, height=224)


def test_require_directory_accepts_existing_directory(tmp_path: Path) -> None:
    assert require_directory(tmp_path) == tmp_path.resolve()


def test_require_directory_rejects_missing_path(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="Dataset directory not found"):
        require_directory(tmp_path / "missing")


def test_validate_dataset_structure_passes_when_all_class_folders_exist(
    tmp_path: Path,
) -> None:
    """No exception when every one of the 18 class directories is present."""
    for banana_class in ALL_CLASSES:
        (tmp_path / banana_class.folder_name).mkdir()

    # Must not raise
    validate_dataset_structure(tmp_path)


def test_validate_dataset_structure_raises_listing_all_missing_classes(
    tmp_path: Path,
) -> None:
    """All missing directory names appear in the error message at once."""
    # Create only the first 3 class folders — leave the other 15 missing
    for banana_class in ALL_CLASSES[:3]:
        (tmp_path / banana_class.folder_name).mkdir()

    with pytest.raises(FileNotFoundError) as exc_info:
        validate_dataset_structure(tmp_path)

    error_message = str(exc_info.value)
    # All 15 missing class names must be mentioned
    for banana_class in ALL_CLASSES[3:]:
        assert banana_class.folder_name in error_message, (
            f"Expected missing class '{banana_class.folder_name}' to appear in "
            f"error message"
        )

