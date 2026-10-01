"""Model output sanity checks (B15).

Verifies that a model from :func:`ml.train.build_model` (B8) produces outputs
that satisfy the contract the rest of the pipeline relies on — a valid softmax
probability distribution over the 18 classes, decodable by
:func:`ml.inference_contract.decode_output`, independent per sample, and free of
NaN/Inf. These checks hold for an **untrained** model (they are about output
*structure/behaviour*, not accuracy), so no dataset or training is needed.

Complements ``test_train.py`` (which checks architecture/layer-freezing) by
focusing on the numerical properties of the model's predictions.

The model is built once per module (building MobileNetV2 is the slow part) and
exercised with tiny synthetic inputs.
"""

from __future__ import annotations

import numpy as np
import pytest
import tensorflow as tf

from ml.classes import NUM_CLASSES, BananaVariety, RipenessStage
from ml.inference_contract import ModelOutputSpec, decode_output
from ml.train import build_model

# Tiny input size keeps the model fast to build and run.
_TEST_IMG_SIZE = 32

_VARIETY_VALUES = {v.value for v in BananaVariety}
_RIPENESS_VALUES = {s.value for s in RipenessStage}


@pytest.fixture(scope="module")
def model() -> tf.keras.Model:
    """Build the classifier once and share it across the module's tests."""
    return build_model(
        image_width=_TEST_IMG_SIZE,
        image_height=_TEST_IMG_SIZE,
    )


def _random_batch(n: int) -> np.ndarray:
    """Return *n* random RGB images normalised to ``[0, 1]`` (float32)."""
    rng = np.random.default_rng(42)
    return rng.random((n, _TEST_IMG_SIZE, _TEST_IMG_SIZE, 3), dtype=np.float32)


def _predict(model: tf.keras.Model, batch: np.ndarray) -> np.ndarray:
    return model.predict(batch, verbose=0)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------


class TestOutputShape:
    def test_batch_output_shape(self, model: tf.keras.Model) -> None:
        preds = _predict(model, _random_batch(4))
        assert preds.shape == (4, NUM_CLASSES)

    def test_single_image_output_shape(self, model: tf.keras.Model) -> None:
        preds = _predict(model, _random_batch(1))
        assert preds.shape == (1, NUM_CLASSES)

    def test_width_matches_inference_contract(self, model: tf.keras.Model) -> None:
        # The model's class count must equal the shared output contract.
        assert model.output_shape[-1] == ModelOutputSpec().num_classes


# ---------------------------------------------------------------------------
# Softmax validity
# ---------------------------------------------------------------------------


class TestSoftmaxProperties:
    def test_rows_sum_to_one(self, model: tf.keras.Model) -> None:
        preds = _predict(model, _random_batch(4))
        np.testing.assert_allclose(preds.sum(axis=1), 1.0, rtol=1e-5, atol=1e-5)

    def test_values_are_probabilities(self, model: tf.keras.Model) -> None:
        preds = _predict(model, _random_batch(4))
        assert preds.min() >= 0.0
        assert preds.max() <= 1.0

    def test_outputs_are_finite(self, model: tf.keras.Model) -> None:
        preds = _predict(model, _random_batch(4))
        assert np.all(np.isfinite(preds))

    def test_argmax_within_class_range(self, model: tf.keras.Model) -> None:
        preds = _predict(model, _random_batch(4))
        argmax = preds.argmax(axis=1)
        assert argmax.min() >= 0
        assert argmax.max() < NUM_CLASSES


# ---------------------------------------------------------------------------
# Determinism & per-sample independence
# ---------------------------------------------------------------------------


class TestPredictionStability:
    def test_same_input_is_deterministic(self, model: tf.keras.Model) -> None:
        batch = _random_batch(2)
        first = _predict(model, batch)
        second = _predict(model, batch)
        np.testing.assert_array_equal(first, second)

    def test_batch_matches_single_predictions(
        self, model: tf.keras.Model
    ) -> None:
        # Inference mode (BatchNorm uses moving stats) → each sample's output
        # must not depend on the others it was batched with.
        batch = _random_batch(3)
        batched = _predict(model, batch)
        for i in range(batch.shape[0]):
            single = _predict(model, batch[i : i + 1])
            np.testing.assert_allclose(batched[i], single[0], rtol=1e-4, atol=1e-5)


# ---------------------------------------------------------------------------
# Integration with the inference contract
# ---------------------------------------------------------------------------


class TestDecodesWithContract:
    def test_output_row_decodes_to_valid_result(
        self, model: tf.keras.Model
    ) -> None:
        preds = _predict(model, _random_batch(1))
        result = decode_output(preds[0].tolist())

        assert result.variety in _VARIETY_VALUES
        assert result.ripeness in _RIPENESS_VALUES
        assert 0.0 <= result.confidence <= 1.0

    def test_confidence_equals_max_probability(
        self, model: tf.keras.Model
    ) -> None:
        preds = _predict(model, _random_batch(1))
        result = decode_output(preds[0].tolist())
        assert result.confidence == pytest.approx(float(preds[0].max()))
