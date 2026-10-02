"""TFLite inference for the development-only backend (B19).

Loads the **same** ``.tflite`` model and ``labels.txt`` the Flutter app bundles
(see PROJECT_PLAN §10) and turns an uploaded image into a
:class:`~backend.app.models.schemas.ClassificationResponse`.

Design notes
------------
- The TFLite runtime is imported **lazily** inside :func:`load_tflite_predictor`
  so importing this module (and unit-testing the surrounding logic) does not
  require a multi-hundred-megabyte dependency.
- :class:`InferenceService` takes an injectable ``predict`` callable, so the
  decode/preprocess path is testable with a stub predictor.
- Preprocessing mirrors the training contract: RGB, resize to the model's square
  input, scale to ``[0, 1]``.  Bilinear resampling is used to match the
  ``tf.image.resize`` default used during training.  (Formalising this into a
  shared, parity-tested module is task B20.)
"""

from __future__ import annotations

import io
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, UnidentifiedImageError

from ..models.schemas import ClassificationResponse

#: A predictor maps a ``(1, size, size, 3)`` float32 batch to class probabilities.
Predictor = Callable[[np.ndarray], Sequence[float]]

#: Square input dimension expected by the MobileNetV2-based model.
DEFAULT_INPUT_SIZE = 224


class ModelUnavailableError(RuntimeError):
    """Raised when the model or labels file cannot be loaded."""


class InvalidImageError(ValueError):
    """Raised when the uploaded bytes cannot be decoded as an image."""


# ---------------------------------------------------------------------------
# Preprocessing
# ---------------------------------------------------------------------------


def preprocess_image(image_bytes: bytes, size: int = DEFAULT_INPUT_SIZE) -> np.ndarray:
    """Decode *image_bytes* into a normalised ``(1, size, size, 3)`` float32 batch.

    Raises
    ------
    InvalidImageError
        If the bytes are not a decodable image.
    """
    try:
        with Image.open(io.BytesIO(image_bytes)) as img:
            rgb = img.convert("RGB").resize((size, size), Image.BILINEAR)
            array = np.asarray(rgb, dtype=np.float32) / 255.0
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise InvalidImageError(f"Could not decode image: {exc}") from exc

    return array[np.newaxis, ...]


# ---------------------------------------------------------------------------
# Label decoding
# ---------------------------------------------------------------------------


def decode_label(label: str) -> tuple[str, str]:
    """Split a ``Variety_Ripeness`` label into ``(variety, ripeness)``.

    Also accepts the pipe-delimited ``Variety|Ripeness`` form, matching the
    tolerance of the Dart ``TFLiteInferenceService``.
    """
    separator = "|" if "|" in label else "_"
    variety, _, ripeness = label.partition(separator)
    return variety, ripeness


# ---------------------------------------------------------------------------
# Inference service
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class InferenceService:
    """Runs preprocessing + prediction + label decoding for one image.

    Parameters
    ----------
    labels:
        Ordered class labels; index *i* must correspond to output index *i*.
    predict:
        Callable mapping a preprocessed batch to class probabilities.
    input_size:
        Square input dimension fed to the model.
    """

    labels: Sequence[str]
    predict: Predictor
    input_size: int = DEFAULT_INPUT_SIZE

    def __post_init__(self) -> None:
        if not self.labels:
            raise ModelUnavailableError("No class labels available.")

    def classify(self, image_bytes: bytes) -> ClassificationResponse:
        """Classify *image_bytes* and return the decoded prediction."""
        batch = preprocess_image(image_bytes, self.input_size)
        probabilities = list(self.predict(batch))

        if len(probabilities) != len(self.labels):
            raise ModelUnavailableError(
                f"Model returned {len(probabilities)} probabilities but "
                f"{len(self.labels)} labels are configured — the model and "
                "labels.txt are out of sync."
            )

        best = max(range(len(probabilities)), key=probabilities.__getitem__)
        variety, ripeness = decode_label(self.labels[best])

        return ClassificationResponse(
            variety=variety,
            ripeness=ripeness,
            confidence=min(max(float(probabilities[best]), 0.0), 1.0),
        )


# ---------------------------------------------------------------------------
# Model loading
# ---------------------------------------------------------------------------


def load_tflite_predictor(model_path: Path) -> Predictor:
    """Return a :data:`Predictor` backed by the ``.tflite`` model at *model_path*.

    The TFLite runtime is imported here rather than at module import time.
    Prefers the standalone LiteRT runtime and falls back to ``tf.lite``.

    Raises
    ------
    ModelUnavailableError
        If the model file is missing or no TFLite runtime is installed.
    """
    resolved = Path(model_path).resolve()
    if not resolved.is_file():
        raise ModelUnavailableError(f"Model file not found: {resolved}")

    try:
        from ai_edge_litert.interpreter import (  # type: ignore[import-not-found]
            Interpreter,
        )
    except ImportError:
        try:
            # NB: ``Interpreter`` is only reachable as an attribute of
            # ``tf.lite`` — ``from tensorflow.lite import Interpreter`` fails.
            import tensorflow as tf  # type: ignore[import-not-found]

            Interpreter = tf.lite.Interpreter
        except (ImportError, AttributeError) as exc:  # pragma: no cover
            raise ModelUnavailableError(
                "No TFLite runtime available. Install 'ai-edge-litert' "
                "(see backend/requirements.txt)."
            ) from exc

    interpreter = Interpreter(model_path=str(resolved))
    interpreter.allocate_tensors()
    input_index = interpreter.get_input_details()[0]["index"]
    output_index = interpreter.get_output_details()[0]["index"]

    def predict(batch: np.ndarray) -> Sequence[float]:
        interpreter.set_tensor(input_index, batch.astype(np.float32))
        interpreter.invoke()
        return [float(p) for p in interpreter.get_tensor(output_index)[0]]

    return predict
