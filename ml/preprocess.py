from dataclasses import dataclass
from pathlib import Path

from ml.classes import ALL_CLASSES


@dataclass(frozen=True)
class PreprocessConfig:
    width: int = 224
    height: int = 224

    def __post_init__(self) -> None:
        if self.width <= 0 or self.height <= 0:
            raise ValueError("Image dimensions must be positive integers.")


def require_directory(path: Path) -> Path:
    resolved = path.resolve()
    if not resolved.is_dir():
        raise FileNotFoundError(f"Dataset directory not found: {resolved}")
    return resolved


def validate_dataset_structure(root: Path) -> None:
    """Check that *root* contains a subdirectory for every one of the 21 classes.

    Expected layout::

        root/
          Saba_Unripe/
          Saba_Ripe/
          Saba_Overripe/
          ...
          Bungulan_Overripe/

    Raises
    ------
    FileNotFoundError
        If one or more expected class directories are missing.  All missing
        directories are listed in the error message so the caller can fix them
        all at once instead of discovering them one by one.
    """
    resolved = require_directory(root)
    missing = [
        banana_class.folder_name
        for banana_class in ALL_CLASSES
        if not (resolved / banana_class.folder_name).is_dir()
    ]
    if missing:
        missing_list = "\n  ".join(missing)
        raise FileNotFoundError(
            f"Dataset at '{resolved}' is missing {len(missing)} class "
            f"director{'y' if len(missing) == 1 else 'ies'}:\n  {missing_list}"
        )

