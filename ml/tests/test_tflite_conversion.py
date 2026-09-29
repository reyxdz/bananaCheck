"""Tests for ml.convert_to_tflite — final model → TFLite conversion (B11).

Strategy
--------
- **Unit tests** for the path-validation helpers and ``ConversionConfig``
  validation (mirrors ``test_train.py`` / ``test_evaluate.py``).
- **Integration tests** for ``convert_model`` — converts a tiny standalone
  Keras model (no MobileNetV2/ImageNet download needed) and checks the
  ``.tflite`` output is a loadable flatbuffer, plus the sibling ``labels.txt``.
- **CLI tests** for ``main``.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pytest
import tensorflow as tf

from ml.classes import NUM_CLASSES
from ml.convert_to_tflite import (
    ConversionConfig,
    convert_model,
    main,
    require_model_file,
    require_tflite_output,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_tiny_keras_model(tmp_path: Path) -> Path:
    """Build and save a minimal Keras classifier — fast, no external weights."""
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(8, 8, 3)),
        tf.keras.layers.GlobalAveragePooling2D(),
        tf.keras.layers.Dense(NUM_CLASSES, activation="softmax"),
    ])
    model_path = tmp_path / "model.keras"
    model.save(model_path)
    return model_path


# ---------------------------------------------------------------------------
# Path-validation helpers
# ---------------------------------------------------------------------------


def test_require_model_file_rejects_missing_model(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="Model file not found"):
        require_model_file(tmp_path / "model.keras")


def test_require_tflite_output_rejects_wrong_extension(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match=r"\.tflite"):
        require_tflite_output(tmp_path / "model.bin")


# ---------------------------------------------------------------------------
# ConversionConfig
# ---------------------------------------------------------------------------


class TestConversionConfig:
    """Test the conversion configuration dataclass."""

    def test_defaults(self) -> None:
        config = ConversionConfig()
        assert config.quantize is False
        assert config.write_labels is True
        assert config.output_path.suffix == ".tflite"

    def test_rejects_wrong_output_extension(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match=r"\.tflite"):
            ConversionConfig(output_path=tmp_path / "model.bin")


# ---------------------------------------------------------------------------
# convert_model
# ---------------------------------------------------------------------------


class TestConvertModel:
    """End-to-end conversion of a real (tiny) Keras model."""

    def test_produces_loadable_tflite(self, tmp_path: Path) -> None:
        model_path = _make_tiny_keras_model(tmp_path)
        output_path = tmp_path / "model.tflite"

        result = convert_model(
            ConversionConfig(model_path=model_path, output_path=output_path)
        )

        assert result == output_path.resolve()
        assert output_path.exists()
        assert output_path.stat().st_size > 0

        # The flatbuffer loads and exposes the expected output shape.
        interpreter = tf.lite.Interpreter(model_path=str(output_path))
        interpreter.allocate_tensors()
        output_details = interpreter.get_output_details()
        assert output_details[0]["shape"][-1] == NUM_CLASSES

    def test_writes_labels_by_default(self, tmp_path: Path) -> None:
        model_path = _make_tiny_keras_model(tmp_path)
        output_path = tmp_path / "out" / "model.tflite"

        convert_model(
            ConversionConfig(model_path=model_path, output_path=output_path)
        )

        labels_path = output_path.parent / "labels.txt"
        assert labels_path.exists()
        lines = labels_path.read_text().strip().splitlines()
        assert len(lines) == NUM_CLASSES

    def test_no_labels_when_disabled(self, tmp_path: Path) -> None:
        model_path = _make_tiny_keras_model(tmp_path)
        output_path = tmp_path / "model.tflite"

        convert_model(
            ConversionConfig(
                model_path=model_path,
                output_path=output_path,
                write_labels=False,
            )
        )

        assert not (output_path.parent / "labels.txt").exists()

    def test_quantized_conversion_is_loadable(self, tmp_path: Path) -> None:
        model_path = _make_tiny_keras_model(tmp_path)
        output_path = tmp_path / "model.tflite"

        convert_model(
            ConversionConfig(
                model_path=model_path,
                output_path=output_path,
                quantize=True,
                write_labels=False,
            )
        )

        interpreter = tf.lite.Interpreter(model_path=str(output_path))
        interpreter.allocate_tensors()
        # Runs a forward pass without error.
        input_details = interpreter.get_input_details()
        dummy = np.zeros(input_details[0]["shape"], dtype=np.float32)
        interpreter.set_tensor(input_details[0]["index"], dummy)
        interpreter.invoke()

    def test_raises_on_missing_model(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError, match="Model file not found"):
            convert_model(
                ConversionConfig(
                    model_path=tmp_path / "nope.keras",
                    output_path=tmp_path / "model.tflite",
                )
            )


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


class TestCLI:
    """Test the ``main`` CLI entry-point."""

    def test_missing_required_args(self) -> None:
        with pytest.raises(SystemExit):
            main([])

    def test_full_conversion_via_cli(self, tmp_path: Path) -> None:
        model_path = _make_tiny_keras_model(tmp_path)
        output_path = tmp_path / "model.tflite"

        exit_code = main([
            "--model", str(model_path),
            "--output", str(output_path),
        ])

        assert exit_code == 0
        assert output_path.exists()
        assert (output_path.parent / "labels.txt").exists()

    def test_cli_no_labels_flag(self, tmp_path: Path) -> None:
        model_path = _make_tiny_keras_model(tmp_path)
        output_path = tmp_path / "model.tflite"

        main([
            "--model", str(model_path),
            "--output", str(output_path),
            "--no-labels",
        ])

        assert output_path.exists()
        assert not (output_path.parent / "labels.txt").exists()
