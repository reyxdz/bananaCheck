"""Shared image preprocessing for the dev backend (B20).

Single place that turns raw image bytes into the tensor the model expects, so
the backend, ``ml/preprocess.py`` and the Dart ``TFLiteInferenceService`` cannot
silently drift apart (PROJECT_PLAN §10).

Output contract — identical to ``ml.preprocess``:

- Shape ``(height, width, 3)`` (``(1, h, w, 3)`` for the batched helper)
- Dtype ``float32``
- Range ``[0, 1]`` (plain ``/ 255``)
- Channel order RGB

Resampling filter
-----------------
The only thing that legitimately varies between implementations is the resize
filter, and it measurably changes accuracy, so it is an explicit parameter
rather than a buried default:

- :data:`TRAINING_RESAMPLE` (bilinear) — what the model was actually trained
  with: ``tf.keras.utils.image_dataset_from_directory`` resizes bilinearly, and
  the Dart app uses ``package:image``'s ``Interpolation.linear``.  This is the
  default because it is what the shipped model sees.
- :data:`ML_PREPROCESS_RESAMPLE` (LANCZOS) — what ``ml.preprocess.resize_image``
  uses.  Selecting it makes this module's output **pixel-identical** to
  ``ml.preprocess`` (asserted in ``tests/test_preprocessing.py``).
"""

from __future__ import annotations

import io

import numpy as np
from PIL import Image, UnidentifiedImageError

#: Square input dimension expected by the MobileNetV2-based model.
DEFAULT_INPUT_SIZE = 224

#: Bilinear — matches the training pipeline and the Dart app.
TRAINING_RESAMPLE = Image.BILINEAR

#: LANCZOS — matches ``ml.preprocess.resize_image``.
ML_PREPROCESS_RESAMPLE = Image.LANCZOS

#: Formats accepted on upload — same set the app accepts (§7.8).
ALLOWED_IMAGE_FORMATS: frozenset[str] = frozenset({"JPEG", "PNG"})


class InvalidImageError(ValueError):
    """Raised when bytes cannot be decoded as an image."""


class UnsupportedImageFormatError(InvalidImageError):
    """Raised when an image decodes but is not an accepted format (B23).

    A subclass of :class:`InvalidImageError` so existing callers that catch the
    base class keep working, while the router can map it to HTTP 415.
    """


def preprocess_pil(
    img: Image.Image,
    size: int = DEFAULT_INPUT_SIZE,
    resample: int = TRAINING_RESAMPLE,
) -> np.ndarray:
    """Convert a PIL image to a normalised ``(size, size, 3)`` float32 array.

    Mirrors ``ml.preprocess``: convert to RGB, resize to ``(size, size)``, then
    scale to ``[0, 1]``.
    """
    rgb = img.convert("RGB").resize((size, size), resample)
    return np.asarray(rgb, dtype=np.float32) / 255.0


def preprocess_bytes(
    image_bytes: bytes,
    size: int = DEFAULT_INPUT_SIZE,
    resample: int = TRAINING_RESAMPLE,
    allowed_formats: frozenset[str] | None = ALLOWED_IMAGE_FORMATS,
) -> np.ndarray:
    """Decode *image_bytes* into a batched ``(1, size, size, 3)`` float32 array.

    The format is validated against the **decoded** image rather than the
    client-supplied MIME type, which can be wrong or spoofed. Pass
    ``allowed_formats=None`` to skip the check.

    Raises
    ------
    UnsupportedImageFormatError
        If the image decodes but its format is not in *allowed_formats*.
    InvalidImageError
        If the bytes are not a decodable image.
    """
    try:
        with Image.open(io.BytesIO(image_bytes)) as img:
            image_format = img.format
            if allowed_formats is not None and image_format not in allowed_formats:
                raise UnsupportedImageFormatError(
                    f"Unsupported image format {image_format!r}; "
                    f"expected one of {sorted(allowed_formats)}."
                )
            array = preprocess_pil(img, size=size, resample=resample)
    except UnsupportedImageFormatError:
        raise
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise InvalidImageError(f"Could not decode image: {exc}") from exc

    return array[np.newaxis, ...]
