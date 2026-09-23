"""Tests for ml/inference_contract.py — the model I/O contract module."""

from __future__ import annotations

import pytest

from ml.classes import ALL_CLASSES, NUM_CLASSES, BananaVariety, RipenessStage
from ml.config import MLConfig
from ml.inference_contract import (
    InferenceResult,
    ModelInputSpec,
    ModelOutputSpec,
    decode_output,
)

# ---------------------------------------------------------------------------
# ModelInputSpec
# ---------------------------------------------------------------------------


def test_default_input_spec_matches_ml_config_defaults() -> None:
    config = MLConfig()
    spec = ModelInputSpec()
    assert spec.width == config.image_width
    assert spec.height == config.image_height


def test_default_input_spec_uses_three_rgb_channels() -> None:
    spec = ModelInputSpec()
    assert spec.channels == 3


def test_default_input_spec_normalizes_by_default() -> None:
    spec = ModelInputSpec()
    assert spec.normalize is True


def test_input_shape_is_batch_of_one() -> None:
    spec = ModelInputSpec()
    assert spec.input_shape == (1, 224, 224, 3)


def test_input_shape_reflects_custom_dimensions() -> None:
    spec = ModelInputSpec(width=128, height=128, channels=1)
    assert spec.input_shape == (1, 128, 128, 1)


# ---------------------------------------------------------------------------
# ModelOutputSpec
# ---------------------------------------------------------------------------


def test_default_output_spec_num_classes_matches_num_classes_constant() -> None:
    spec = ModelOutputSpec()
    assert spec.num_classes == NUM_CLASSES


def test_output_shape_is_batch_of_one_by_num_classes() -> None:
    spec = ModelOutputSpec()
    assert spec.output_shape == (1, NUM_CLASSES)


def test_class_labels_length_matches_num_classes() -> None:
    spec = ModelOutputSpec()
    assert len(spec.class_labels) == NUM_CLASSES


def test_class_labels_match_all_classes_folder_names() -> None:
    spec = ModelOutputSpec()
    expected = [cls.folder_name for cls in ALL_CLASSES]
    assert spec.class_labels == expected


# ---------------------------------------------------------------------------
# InferenceResult
# ---------------------------------------------------------------------------


def test_inference_result_has_correct_field_names() -> None:
    """Field names must match Dart ClassificationResult exactly."""
    assert InferenceResult._fields == ("variety", "ripeness", "confidence")


def test_inference_result_is_constructible() -> None:
    result = InferenceResult(variety="Lakatan", ripeness="Ripe", confidence=0.95)
    assert result.variety == "Lakatan"
    assert result.ripeness == "Ripe"
    assert result.confidence == 0.95


# ---------------------------------------------------------------------------
# decode_output — correct decoding
# ---------------------------------------------------------------------------


def test_decode_output_with_one_hot_returns_correct_class() -> None:
    """A perfect one-hot vector should decode to the corresponding class."""
    for target_index, banana_class in enumerate(ALL_CLASSES):
        probs = [0.0] * NUM_CLASSES
        probs[target_index] = 1.0

        result = decode_output(probs)

        assert result.variety == str(banana_class.variety)
        assert result.ripeness == str(banana_class.ripeness)
        assert result.confidence == 1.0


def test_decode_output_returns_max_probability_as_confidence() -> None:
    """Confidence should equal the maximum value in the probability vector."""
    probs = [0.02] * NUM_CLASSES
    # Make index 5 the winner with 0.7
    probs[5] = 0.7

    result = decode_output(probs)
    assert result.confidence == pytest.approx(0.7)


def test_decode_output_picks_correct_variety_and_ripeness() -> None:
    """Spot-check: the first class (index 0) should be Cavendish Unripe."""
    probs = [0.0] * NUM_CLASSES
    probs[0] = 0.85

    result = decode_output(probs)
    assert result.variety == str(BananaVariety.CAVENDISH)
    assert result.ripeness == str(RipenessStage.UNRIPE)


def test_decode_output_picks_last_class_correctly() -> None:
    """Spot-check: the last class should be Saba Overripe."""
    probs = [0.0] * NUM_CLASSES
    probs[NUM_CLASSES - 1] = 0.99

    result = decode_output(probs)
    assert result.variety == str(BananaVariety.SABA)
    assert result.ripeness == str(RipenessStage.OVERRIPE)


# ---------------------------------------------------------------------------
# decode_output — validation
# ---------------------------------------------------------------------------


def test_decode_output_rejects_too_few_probabilities() -> None:
    with pytest.raises(ValueError, match=f"Expected {NUM_CLASSES}"):
        decode_output([0.5, 0.5])


def test_decode_output_rejects_too_many_probabilities() -> None:
    with pytest.raises(ValueError, match=f"Expected {NUM_CLASSES}"):
        decode_output([0.0] * (NUM_CLASSES + 1))


def test_decode_output_rejects_empty_list() -> None:
    with pytest.raises(ValueError, match=f"Expected {NUM_CLASSES}"):
        decode_output([])


# ---------------------------------------------------------------------------
# Cross-check: input/output specs are consistent
# ---------------------------------------------------------------------------


def test_output_spec_num_classes_equals_18() -> None:
    """Sanity check: 6 varieties × 3 ripeness = 18."""
    assert ModelOutputSpec().num_classes == 18


def test_input_and_output_specs_are_frozen() -> None:
    """Both specs should be immutable."""
    input_spec = ModelInputSpec()
    output_spec = ModelOutputSpec()

    with pytest.raises(AttributeError):
        input_spec.width = 512  # type: ignore[misc]

    with pytest.raises(AttributeError):
        output_spec.num_classes = 99  # type: ignore[misc]
