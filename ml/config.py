"""Central configuration for the banana-classifier ML pipeline.

Every configurable value (image size, batch size, learning rate, directory
paths) lives here so the rest of the codebase imports from one place instead
of scattering magic numbers across modules.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Directory layout defaults (relative to the repository root)
# ---------------------------------------------------------------------------

_ML_ROOT = Path(__file__).resolve().parent
_DEFAULT_DATA_DIR = _ML_ROOT / "data"
_DEFAULT_OUTPUT_DIR = _ML_ROOT / "output"


# ---------------------------------------------------------------------------
# Pipeline configuration
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class MLConfig:
    """Immutable configuration for the training / preprocessing pipeline.

    Parameters
    ----------
    image_width, image_height:
        Target dimensions in pixels for model input.  MobileNetV2 expects
        224 × 224.
    batch_size:
        Mini-batch size used during training and validation.
    learning_rate:
        Initial learning rate for the optimizer.
    epochs:
        Maximum number of training epochs.
    data_dir:
        Root directory containing one subfolder per class
        (e.g. ``data/Saba_Unripe/``).
    output_dir:
        Directory where trained model artefacts are saved.
    """

    image_width: int = 224
    image_height: int = 224
    batch_size: int = 32
    learning_rate: float = 1e-3
    epochs: int = 10
    data_dir: Path = field(default_factory=lambda: _DEFAULT_DATA_DIR)
    output_dir: Path = field(default_factory=lambda: _DEFAULT_OUTPUT_DIR)

    def __post_init__(self) -> None:
        if self.image_width <= 0 or self.image_height <= 0:
            raise ValueError("Image dimensions must be positive integers.")
        if self.batch_size <= 0:
            raise ValueError("Batch size must be a positive integer.")
        if self.learning_rate <= 0:
            raise ValueError("Learning rate must be a positive number.")
        if self.epochs <= 0:
            raise ValueError("Number of epochs must be a positive integer.")

    @property
    def image_size(self) -> tuple[int, int]:
        """Return ``(width, height)`` as a convenience tuple."""
        return (self.image_width, self.image_height)
