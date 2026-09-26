"""Preprocessing pipeline — resize, augment, and normalise images for
training and inference.

This module is the single place that transforms raw dataset images into the
tensor representation consumed by the model.  It deliberately keeps the
**inference path** (resize + normalise) separate from **training-only
augmentation** so that augmentation never leaks into on-device preprocessing.

The output contract matches ``ml.inference_contract``:

- Shape: ``(height, width, 3)`` — 224 × 224 × 3 by default
- Dtype: ``float32``
- Range: ``[0, 1]``
- Channel order: RGB
"""

from __future__ import annotations

import random
from dataclasses import dataclass
from pathlib import Path
from typing import NamedTuple

import numpy as np
from numpy.typing import NDArray
from PIL import Image, ImageEnhance, ImageOps

from ml.classes import ALL_CLASSES
from ml.config import MLConfig

# ---------------------------------------------------------------------------
# Supported image extensions (mirrors dataset_scaffold)
# ---------------------------------------------------------------------------

VALID_IMAGE_EXTENSIONS: frozenset[str] = frozenset({".jpg", ".jpeg", ".png"})

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

_DEFAULT_CONFIG = MLConfig()


@dataclass(frozen=True)
class PreprocessConfig:
    """Configuration for the preprocessing pipeline.

    Parameters
    ----------
    width, height:
        Target spatial dimensions.  Must match the model input spec
        (default 224 × 224 for MobileNetV2).
    normalize:
        Scale pixel values to ``[0, 1]``.
    """

    width: int = _DEFAULT_CONFIG.image_width
    height: int = _DEFAULT_CONFIG.image_height
    normalize: bool = True

    def __post_init__(self) -> None:
        if self.width <= 0 or self.height <= 0:
            raise ValueError("Image dimensions must be positive integers.")


@dataclass(frozen=True)
class AugmentConfig:
    """Training-only augmentation parameters.

    Every field toggles or tunes one augmentation strategy.  Disabled by
    default so the caller must opt in explicitly.

    Parameters
    ----------
    horizontal_flip:
        Randomly flip the image left-right with 50 % probability.
    max_rotation_degrees:
        Maximum random rotation in degrees (applied symmetrically).
        Set to 0 to disable.
    brightness_range:
        ``(min_factor, max_factor)`` for random brightness adjustment.
        A factor of 1.0 means no change.  ``None`` disables.
    contrast_range:
        ``(min_factor, max_factor)`` for random contrast adjustment.
        ``None`` disables.
    random_crop_fraction:
        If set, randomly crop this fraction of the image (e.g. 0.8 keeps
        80 %) and resize back to ``(width, height)``.  ``None`` disables.
    """

    horizontal_flip: bool = False
    max_rotation_degrees: float = 0.0
    brightness_range: tuple[float, float] | None = None
    contrast_range: tuple[float, float] | None = None
    random_crop_fraction: float | None = None

    def __post_init__(self) -> None:
        if self.max_rotation_degrees < 0:
            raise ValueError("max_rotation_degrees must be non-negative.")
        if self.brightness_range is not None:
            lo, hi = self.brightness_range
            if lo <= 0 or hi <= 0 or lo > hi:
                raise ValueError(
                    "brightness_range must be (lo, hi) with 0 < lo <= hi."
                )
        if self.contrast_range is not None:
            lo, hi = self.contrast_range
            if lo <= 0 or hi <= 0 or lo > hi:
                raise ValueError(
                    "contrast_range must be (lo, hi) with 0 < lo <= hi."
                )
        if self.random_crop_fraction is not None and not (
            0.0 < self.random_crop_fraction <= 1.0
        ):
            raise ValueError(
                "random_crop_fraction must be in (0, 1]."
            )

    @property
    def is_enabled(self) -> bool:
        """Return ``True`` if any augmentation is active."""
        return (
            self.horizontal_flip
            or self.max_rotation_degrees > 0
            or self.brightness_range is not None
            or self.contrast_range is not None
            or self.random_crop_fraction is not None
        )


# Default augmentation preset for training.
DEFAULT_AUGMENT = AugmentConfig(
    horizontal_flip=True,
    max_rotation_degrees=15.0,
    brightness_range=(0.8, 1.2),
    contrast_range=(0.8, 1.2),
    random_crop_fraction=0.85,
)

# ---------------------------------------------------------------------------
# Directory helpers (preserved from the original skeleton)
# ---------------------------------------------------------------------------


def require_directory(path: Path) -> Path:
    """Return *path* resolved, raising if it is not an existing directory."""
    resolved = path.resolve()
    if not resolved.is_dir():
        raise FileNotFoundError(f"Dataset directory not found: {resolved}")
    return resolved


def validate_dataset_structure(root: Path) -> None:
    """Check that *root* contains a subdirectory for every one of the 18 classes.

    Expected layout::

        root/
          Cavendish_Unripe/
          Cavendish_Ripe/
          Cavendish_Overripe/
          ...
          Saba_Overripe/

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


# ---------------------------------------------------------------------------
# Core image operations
# ---------------------------------------------------------------------------


def load_image(path: Path) -> Image.Image:
    """Load an image from *path* and convert to RGB.

    Raises
    ------
    FileNotFoundError
        If *path* does not exist.
    ValueError
        If the file cannot be opened as an image.
    """
    resolved = path.resolve()
    if not resolved.is_file():
        raise FileNotFoundError(f"Image file not found: {resolved}")
    try:
        img = Image.open(resolved)
        img = img.convert("RGB")
        img.load()  # force read so errors surface now
        return img
    except Exception as exc:
        raise ValueError(f"Cannot open image {resolved}: {exc}") from exc


def resize_image(
    img: Image.Image, config: PreprocessConfig | None = None
) -> Image.Image:
    """Resize *img* to the target dimensions using high-quality resampling.

    Uses ``LANCZOS`` resampling for best quality when downscaling.
    """
    cfg = config or PreprocessConfig()
    return img.resize((cfg.width, cfg.height), Image.LANCZOS)


def normalize_image(
    img: Image.Image,
) -> NDArray[np.float32]:
    """Convert a PIL image to a float32 numpy array in ``[0, 1]``.

    Returns
    -------
    NDArray[np.float32]
        Shape ``(height, width, 3)``, dtype ``float32``, range ``[0, 1]``.
    """
    arr = np.asarray(img, dtype=np.float32)
    return arr / 255.0


# ---------------------------------------------------------------------------
# Augmentation (training-only)
# ---------------------------------------------------------------------------


def augment_image(
    img: Image.Image,
    config: AugmentConfig | None = None,
) -> Image.Image:
    """Apply random training augmentations to *img*.

    This function is **non-deterministic** by design — each call produces a
    different transformation.  It must only be used during training, never
    during inference or validation.

    Parameters
    ----------
    img:
        A PIL RGB image.
    config:
        Augmentation parameters.  ``None`` uses ``DEFAULT_AUGMENT``.
    """
    cfg = config or DEFAULT_AUGMENT

    if not cfg.is_enabled:
        return img

    result = img.copy()

    # Random horizontal flip
    if cfg.horizontal_flip and random.random() < 0.5:
        result = ImageOps.mirror(result)

    # Random rotation
    if cfg.max_rotation_degrees > 0:
        angle = random.uniform(
            -cfg.max_rotation_degrees, cfg.max_rotation_degrees
        )
        result = result.rotate(angle, resample=Image.BICUBIC, expand=False)

    # Random brightness
    if cfg.brightness_range is not None:
        factor = random.uniform(*cfg.brightness_range)
        result = ImageEnhance.Brightness(result).enhance(factor)

    # Random contrast
    if cfg.contrast_range is not None:
        factor = random.uniform(*cfg.contrast_range)
        result = ImageEnhance.Contrast(result).enhance(factor)

    # Random crop
    if cfg.random_crop_fraction is not None:
        w, h = result.size
        crop_w = int(w * cfg.random_crop_fraction)
        crop_h = int(h * cfg.random_crop_fraction)
        left = random.randint(0, w - crop_w)
        top = random.randint(0, h - crop_h)
        result = result.crop((left, top, left + crop_w, top + crop_h))
        result = result.resize((w, h), Image.LANCZOS)

    return result


# ---------------------------------------------------------------------------
# End-to-end preprocessing
# ---------------------------------------------------------------------------


class PreprocessedImage(NamedTuple):
    """A preprocessed image ready for model input."""

    array: NDArray[np.float32]
    """Shape ``(height, width, 3)``, dtype ``float32``, range ``[0, 1]``."""
    source_path: Path
    """Original file path for traceability."""


def preprocess_image(
    path: Path,
    *,
    config: PreprocessConfig | None = None,
    augment: AugmentConfig | None = None,
) -> PreprocessedImage:
    """Load, optionally augment, resize, and normalise a single image.

    Parameters
    ----------
    path:
        Path to the source image file.
    config:
        Preprocessing configuration (dimensions, normalisation).
    augment:
        If provided and ``is_enabled``, apply training augmentation.
        Pass ``None`` (the default) for inference/validation to skip
        augmentation entirely.

    Returns
    -------
    PreprocessedImage
        The preprocessed array and its source path.
    """
    cfg = config or PreprocessConfig()
    img = load_image(path)

    # Training augmentation (before resize so crops work on full resolution)
    if augment is not None and augment.is_enabled:
        img = augment_image(img, augment)

    img = resize_image(img, cfg)

    arr = normalize_image(img) if cfg.normalize else np.asarray(img, dtype=np.float32)

    return PreprocessedImage(array=arr, source_path=path.resolve())


def preprocess_directory(
    data_dir: Path,
    *,
    config: PreprocessConfig | None = None,
    augment: AugmentConfig | None = None,
) -> list[tuple[PreprocessedImage, int]]:
    """Preprocess every image in a folder-per-class dataset directory.

    Parameters
    ----------
    data_dir:
        Root dataset directory containing one subfolder per class.
    config:
        Preprocessing configuration.
    augment:
        Training augmentation config, or ``None`` to skip augmentation.

    Returns
    -------
    list[tuple[PreprocessedImage, int]]
        Each entry is a ``(preprocessed_image, class_index)`` pair.  The
        class index matches the ordering in ``ALL_CLASSES``.
    """
    resolved = require_directory(data_dir)
    validate_dataset_structure(resolved)

    results: list[tuple[PreprocessedImage, int]] = []
    for class_index, banana_class in enumerate(ALL_CLASSES):
        class_dir = resolved / banana_class.folder_name
        for img_path in sorted(class_dir.iterdir()):
            if (
                img_path.is_file()
                and img_path.suffix.lower() in VALID_IMAGE_EXTENSIONS
            ):
                preprocessed = preprocess_image(
                    img_path, config=config, augment=augment
                )
                results.append((preprocessed, class_index))

    return results

