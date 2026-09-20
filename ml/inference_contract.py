"""Model inference contract — shared specification between the ML pipeline
and the Flutter application.

This module defines the model's input and output shapes, and provides a
``decode_output`` function that converts a raw probability vector into an
``InferenceResult`` mirroring the Dart ``ClassificationResult`` type.

Both sides (Python training pipeline and Dart on-device inference) must
agree on these specifications for the TFLite model to work correctly in
the shipped app.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from typing import NamedTuple

from ml.classes import ALL_CLASSES, NUM_CLASSES, index_to_class
from ml.config import MLConfig

# ---------------------------------------------------------------------------
# Model input specification
# ---------------------------------------------------------------------------

# Default config used to derive image dimensions.
_DEFAULT_CONFIG = MLConfig()


@dataclass(frozen=True)
class ModelInputSpec:
    """Specification for the model's expected input tensor.

    Parameters
    ----------
    width, height:
        Spatial dimensions in pixels.  MobileNetV2 expects 224 × 224.
    channels:
        Number of colour channels (3 for RGB).
    normalize:
        Whether pixel values are scaled to ``[0, 1]`` before inference.
    """

    width: int = _DEFAULT_CONFIG.image_width
    height: int = _DEFAULT_CONFIG.image_height
    channels: int = 3
    normalize: bool = True

    @property
    def input_shape(self) -> tuple[int, int, int, int]:
        """Batch-of-one input tensor shape: ``(1, height, width, channels)``.

        This matches the TFLite model's expected input signature for
        single-image on-device inference.
        """
        return (1, self.height, self.width, self.channels)


# ---------------------------------------------------------------------------
# Model output specification
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class ModelOutputSpec:
    """Specification for the model's output tensor.

    The model produces a probability distribution over ``num_classes``
    classes.  Each index in the output vector corresponds to a
    ``BananaClass`` entry in ``ALL_CLASSES``.
    """

    num_classes: int = NUM_CLASSES

    @property
    def output_shape(self) -> tuple[int, int]:
        """Batch-of-one output tensor shape: ``(1, num_classes)``."""
        return (1, self.num_classes)

    @property
    def class_labels(self) -> list[str]:
        """Ordered list of human-readable class labels (e.g. ``"Lakatan_Ripe"``)."""
        return [cls.folder_name for cls in ALL_CLASSES]


# ---------------------------------------------------------------------------
# Inference result (mirrors Dart ClassificationResult)
# ---------------------------------------------------------------------------


class InferenceResult(NamedTuple):
    """Decoded prediction from the model — mirrors the Dart
    ``ClassificationResult`` class field-for-field.

    Fields
    ------
    variety:
        Predicted banana variety, e.g. ``"Lakatan"``.
    ripeness:
        Predicted ripeness stage, e.g. ``"Ripe"``.
    confidence:
        Maximum probability from the softmax output (0.0–1.0).
    """

    variety: str
    ripeness: str
    confidence: float


# ---------------------------------------------------------------------------
# Output decoder
# ---------------------------------------------------------------------------


def decode_output(probabilities: Sequence[float]) -> InferenceResult:
    """Decode a raw model probability vector into an ``InferenceResult``.

    Parameters
    ----------
    probabilities:
        A flat sequence of ``NUM_CLASSES`` probability values (one per
        class, in the order defined by ``ALL_CLASSES``).  Typically the
        softmax output of the TFLite model.

    Returns
    -------
    InferenceResult
        The decoded variety, ripeness, and confidence.

    Raises
    ------
    ValueError
        If *probabilities* does not contain exactly ``NUM_CLASSES`` elements.
    """
    probs = list(probabilities)
    if len(probs) != NUM_CLASSES:
        raise ValueError(
            f"Expected {NUM_CLASSES} probabilities, got {len(probs)}"
        )

    max_index = max(range(len(probs)), key=lambda i: probs[i])
    confidence = probs[max_index]
    predicted_class = index_to_class(max_index)

    return InferenceResult(
        variety=str(predicted_class.variety),
        ripeness=str(predicted_class.ripeness),
        confidence=confidence,
    )
