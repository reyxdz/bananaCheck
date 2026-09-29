"""Tests for ml.validate_tflite — TFLite vs. Keras validation (B12).

Strategy
--------
- **Unit tests** for ``ValidationConfig`` validation.
- **Unit tests** for ``compare_predictions`` — the pure comparison logic with
  crafted probability arrays, no model or dataset required.
- **Integration test** for ``validate`` — builds a tiny standalone Keras model,
  converts it to TFLite, and checks the two agree (a faithful float32
  conversion agrees on essentially every sample).
- **CLI tests** for ``main`` — including the pass→0 / fail→1 exit contract.

Uses tiny 32×32 images and a standalone model (no MobileNetV2/ImageNet
download) to stay fast.
"""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import patch

import numpy as np
import pytest
import tensorflow as tf
from PIL import Image

from ml.classes import ALL_CLASSES, NUM_CLASSES
from ml.convert_to_tflite import ConversionConfig, convert_model
from ml.validate_tflite import (
    ValidationConfig,
    compare_predictions,
    main,
    validate,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_TEST_IMG_SIZE = 32


def _create_test_dataset(root: Path) -> Path:
    """Create a minimal folder-per-class ``test/`` split under *root*."""
    for cls in ALL_CLASSES:
        class_dir = root / "test" / cls.folder_name
        class_dir.mkdir(parents=True, exist_ok=True)
        for i in range(2):
            img = Image.fromarray(
                np.random.randint(
                    0, 255, (_TEST_IMG_SIZE, _TEST_IMG_SIZE, 3), dtype=np.uint8
                )
            )
            img.save(class_dir / f"img_{i:03d}.jpg")
    return root


def _make_and_convert_model(tmp_path: Path) -> tuple[Path, Path]:
    """Build a tiny Keras model, save it, and convert to TFLite.

    Returns ``(keras_path, tflite_path)``.
    """
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(_TEST_IMG_SIZE, _TEST_IMG_SIZE, 3)),
        tf.keras.layers.GlobalAveragePooling2D(),
        tf.keras.layers.Dense(NUM_CLASSES, activation="softmax"),
    ])
    keras_path = tmp_path / "model.keras"
    model.save(keras_path)

    tflite_path = tmp_path / "model.tflite"
    convert_model(
        ConversionConfig(
            model_path=keras_path,
            output_path=tflite_path,
            write_labels=False,
        )
    )
    return keras_path, tflite_path


# ---------------------------------------------------------------------------
# ValidationConfig
# ---------------------------------------------------------------------------


class TestValidationConfig:
    """Test the validation configuration dataclass."""

    def test_defaults(self) -> None:
        config = ValidationConfig()
        assert config.agreement_threshold == 0.99
        assert config.batch_size == 32

    def test_as_evaluation_config_forwards_fields(self, tmp_path: Path) -> None:
        config = ValidationConfig(
            keras_model_path=tmp_path / "m.keras",
            data_dir=tmp_path / "data",
            output_dir=tmp_path / "out",
            image_width=64,
            image_height=64,
            batch_size=8,
        )
        eval_config = config.as_evaluation_config()
        assert eval_config.model_path == tmp_path / "m.keras"
        assert eval_config.data_dir == tmp_path / "data"
        assert eval_config.image_size == (64, 64)
        assert eval_config.batch_size == 8

    @pytest.mark.parametrize(
        "kwargs,match",
        [
            ({"batch_size": 0}, "Batch size"),
            ({"image_width": -1}, "Image dimensions"),
            ({"agreement_threshold": 1.5}, "Agreement threshold"),
            ({"agreement_threshold": -0.1}, "Agreement threshold"),
        ],
    )
    def test_rejects_invalid_values(self, kwargs: dict, match: str) -> None:
        with pytest.raises(ValueError, match=match):
            ValidationConfig(**kwargs)


# ---------------------------------------------------------------------------
# compare_predictions (pure unit tests)
# ---------------------------------------------------------------------------


class TestComparePredictions:
    """Test the comparison logic with crafted probability arrays."""

    def test_identical_probs_agree_perfectly(self) -> None:
        y_true = np.array([0, 1, 2])
        probs = np.array([
            [0.9, 0.05, 0.05],
            [0.1, 0.8, 0.1],
            [0.2, 0.2, 0.6],
        ])

        report = compare_predictions(
            y_true, probs, probs.copy(), agreement_threshold=0.99
        )

        assert report["agreement"] == 1.0
        assert report["max_prob_diff"] == 0.0
        assert report["mean_prob_diff"] == 0.0
        assert report["accuracy_delta"] == 0.0
        assert report["passed"] is True
        assert report["num_samples"] == 3

    def test_disagreement_below_threshold_fails(self) -> None:
        y_true = np.array([0, 1])
        keras_probs = np.array([[0.9, 0.1], [0.1, 0.9]])
        # Second sample flips its argmax.
        tflite_probs = np.array([[0.9, 0.1], [0.9, 0.1]])

        report = compare_predictions(
            y_true, keras_probs, tflite_probs, agreement_threshold=0.99
        )

        assert report["agreement"] == 0.5
        assert report["passed"] is False

    def test_accuracy_delta_captures_degradation(self) -> None:
        y_true = np.array([0, 1])
        keras_probs = np.array([[0.9, 0.1], [0.1, 0.9]])   # both correct
        tflite_probs = np.array([[0.1, 0.9], [0.1, 0.9]])  # first now wrong

        report = compare_predictions(
            y_true, keras_probs, tflite_probs, agreement_threshold=0.99
        )

        assert report["keras_accuracy"] == 1.0
        assert report["tflite_accuracy"] == 0.5
        assert report["accuracy_delta"] == -0.5

    def test_probability_drift_is_measured(self) -> None:
        y_true = np.array([0])
        keras_probs = np.array([[0.7, 0.3]])
        tflite_probs = np.array([[0.6, 0.4]])

        report = compare_predictions(
            y_true, keras_probs, tflite_probs, agreement_threshold=0.99
        )

        # argmax unchanged → still agrees, but drift is recorded.
        assert report["agreement"] == 1.0
        assert report["max_prob_diff"] == pytest.approx(0.1, abs=1e-6)

    def test_threshold_boundary_passes(self) -> None:
        y_true = np.array([0, 0, 0, 0])
        keras_probs = np.tile([0.9, 0.1], (4, 1))
        tflite_probs = np.array([[0.9, 0.1], [0.9, 0.1], [0.9, 0.1], [0.1, 0.9]])

        # 3/4 agree = 0.75 exactly.
        report = compare_predictions(
            y_true, keras_probs, tflite_probs, agreement_threshold=0.75
        )
        assert report["agreement"] == 0.75
        assert report["passed"] is True


# ---------------------------------------------------------------------------
# validate (end-to-end integration)
# ---------------------------------------------------------------------------


class TestValidate:
    """End-to-end validation with a real tiny model + its conversion."""

    def test_conversion_agrees_with_keras(self, tmp_path: Path) -> None:
        data_dir = tmp_path / "data"
        output_dir = tmp_path / "output"
        _create_test_dataset(data_dir)
        keras_path, tflite_path = _make_and_convert_model(tmp_path)

        config = ValidationConfig(
            keras_model_path=keras_path,
            tflite_model_path=tflite_path,
            data_dir=data_dir,
            output_dir=output_dir,
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
            batch_size=4,
        )

        report = validate(config)

        # A faithful float32 conversion agrees on every sample.
        assert report["agreement"] == 1.0
        assert report["passed"] is True
        assert report["num_samples"] == NUM_CLASSES * 2
        assert report["max_prob_diff"] < 1e-2

        # Report persisted and matches the returned dict.
        saved = json.loads((output_dir / "tflite_validation.json").read_text())
        assert saved == report

    def test_raises_on_missing_keras_model(self, tmp_path: Path) -> None:
        _create_test_dataset(tmp_path / "data")
        _, tflite_path = _make_and_convert_model(tmp_path)

        config = ValidationConfig(
            keras_model_path=tmp_path / "missing.keras",
            tflite_model_path=tflite_path,
            data_dir=tmp_path / "data",
            output_dir=tmp_path / "output",
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
        )
        with pytest.raises(FileNotFoundError, match="Keras model not found"):
            validate(config)

    def test_raises_on_missing_tflite_model(self, tmp_path: Path) -> None:
        _create_test_dataset(tmp_path / "data")
        keras_path, _ = _make_and_convert_model(tmp_path)

        config = ValidationConfig(
            keras_model_path=keras_path,
            tflite_model_path=tmp_path / "missing.tflite",
            data_dir=tmp_path / "data",
            output_dir=tmp_path / "output",
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
        )
        with pytest.raises(FileNotFoundError, match="TFLite model not found"):
            validate(config)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


class TestCLI:
    """Test the ``main`` CLI entry-point."""

    def test_missing_required_args(self) -> None:
        with pytest.raises(SystemExit):
            main([])

    def test_returns_zero_when_passed(self, tmp_path: Path) -> None:
        with patch("ml.validate_tflite.validate", return_value={"passed": True}):
            exit_code = main([
                "--keras-model", str(tmp_path / "m.keras"),
                "--tflite-model", str(tmp_path / "m.tflite"),
                "--data-dir", str(tmp_path / "data"),
                "--output-dir", str(tmp_path / "out"),
            ])
        assert exit_code == 0

    def test_returns_one_when_failed(self, tmp_path: Path) -> None:
        with patch("ml.validate_tflite.validate", return_value={"passed": False}):
            exit_code = main([
                "--keras-model", str(tmp_path / "m.keras"),
                "--tflite-model", str(tmp_path / "m.tflite"),
                "--data-dir", str(tmp_path / "data"),
                "--output-dir", str(tmp_path / "out"),
            ])
        assert exit_code == 1

    def test_cli_forwards_args_to_config(self, tmp_path: Path) -> None:
        captured: list[ValidationConfig] = []

        def fake_validate(config: ValidationConfig) -> dict:
            captured.append(config)
            return {"passed": True}

        with patch("ml.validate_tflite.validate", side_effect=fake_validate):
            main([
                "--keras-model", str(tmp_path / "m.keras"),
                "--tflite-model", str(tmp_path / "m.tflite"),
                "--data-dir", str(tmp_path / "data"),
                "--output-dir", str(tmp_path / "out"),
                "--batch-size", "8",
                "--agreement-threshold", "0.95",
            ])

        assert len(captured) == 1
        cfg = captured[0]
        assert cfg.batch_size == 8
        assert cfg.agreement_threshold == 0.95
        assert cfg.keras_model_path == tmp_path / "m.keras"
        assert cfg.tflite_model_path == tmp_path / "m.tflite"
