"""Convert the final Keras model to TFLite for on-device inference (B11).

Takes the trained/tuned Keras model (``banana_classifier.keras`` produced by
:mod:`ml.train` / :mod:`ml.tune`) and converts it to a ``.tflite`` file that is
bundled as a Flutter asset and run on-device via ``tflite_flutter`` (B13).

Alongside the ``.tflite`` file this writes a ``labels.txt`` in the same
directory, derived from :mod:`ml.classes` so the on-device label ordering can
never drift from the training-time class ordering.  Both files ship together at
``app/assets/model/`` per the repository layout.

Float32 conversion is the default so on-device predictions match the original
model exactly (validated in B12).  Optional dynamic-range quantization
(``--quantize``) shrinks the model for slower/older phones at a small accuracy
cost — verify with B12 before shipping a quantized build.

Usage
-----
CLI::

    python -m ml.convert_to_tflite \\
        --model ml/output/banana_classifier.keras \\
        --output app/assets/model/banana_classifier.tflite

Programmatic::

    from ml.convert_to_tflite import ConversionConfig, convert_model

    config = ConversionConfig(
        model_path=Path("ml/output/banana_classifier.keras"),
        output_path=Path("app/assets/model/banana_classifier.tflite"),
    )
    tflite_path = convert_model(config)
"""

from __future__ import annotations

import argparse
from collections.abc import Sequence
from dataclasses import dataclass, field
from pathlib import Path

import tensorflow as tf

from ml.classes import generate_labels_file
from ml.config import MLConfig

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

_DEFAULT_ML = MLConfig()


def require_model_file(path: Path) -> Path:
    """Return the resolved *path*, raising if it is not an existing file."""
    resolved = path.resolve()
    if not resolved.is_file():
        raise FileNotFoundError(f"Model file not found: {resolved}")
    return resolved


def require_tflite_output(path: Path) -> Path:
    """Return the resolved *path*, raising if it does not end with ``.tflite``."""
    resolved = path.resolve()
    if resolved.suffix.lower() != ".tflite":
        raise ValueError("TFLite output path must end with .tflite")
    return resolved


@dataclass(frozen=True)
class ConversionConfig:
    """Immutable configuration for the TFLite conversion.

    Parameters
    ----------
    model_path:
        Path to the saved Keras model (``.keras`` format).
    output_path:
        Destination ``.tflite`` file.
    quantize:
        When ``True``, apply dynamic-range quantization (smaller model, slight
        accuracy trade-off).  Default ``False`` for exact float32 parity.
    write_labels:
        When ``True`` (default), also write ``labels.txt`` next to the
        ``.tflite`` file, derived from :mod:`ml.classes`.
    """

    model_path: Path = field(
        default_factory=lambda: _DEFAULT_ML.output_dir / "banana_classifier.keras",
    )
    output_path: Path = field(
        default_factory=lambda: _DEFAULT_ML.output_dir / "banana_classifier.tflite",
    )
    quantize: bool = False
    write_labels: bool = True

    def __post_init__(self) -> None:
        # Fail fast on an obviously wrong output extension, mirroring the
        # standalone ``require_tflite_output`` guard used by the CLI.
        if Path(self.output_path).suffix.lower() != ".tflite":
            raise ValueError("TFLite output path must end with .tflite")


# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------


def convert_model(config: ConversionConfig) -> Path:
    """Convert the Keras model at ``config.model_path`` to TFLite.

    1. Load the saved Keras model.
    2. Convert it to a TFLite flatbuffer (optionally quantized).
    3. Write the ``.tflite`` file and, unless disabled, a sibling ``labels.txt``.

    Parameters
    ----------
    config:
        Conversion configuration.

    Returns
    -------
    Path
        The resolved path of the written ``.tflite`` file.

    Raises
    ------
    FileNotFoundError
        If the model file does not exist.
    ValueError
        If the output path does not end with ``.tflite``.
    """
    model_path = require_model_file(Path(config.model_path))
    output_path = require_tflite_output(Path(config.output_path))
    output_path.parent.mkdir(parents=True, exist_ok=True)

    model = tf.keras.models.load_model(model_path)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    if config.quantize:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]

    tflite_bytes = converter.convert()
    output_path.write_bytes(tflite_bytes)

    print(f"TFLite model saved to {output_path} ({len(tflite_bytes)} bytes)")

    if config.write_labels:
        labels_path = generate_labels_file(output_path.parent / "labels.txt")
        print(f"Labels file saved to {labels_path}")

    return output_path


# ---------------------------------------------------------------------------
# CLI entry-point
# ---------------------------------------------------------------------------


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entry-point for ``python -m ml.convert_to_tflite``."""
    parser = argparse.ArgumentParser(description="Convert a Keras model to TFLite (B11).")
    parser.add_argument(
        "--model",
        required=True,
        type=Path,
        help="Path to the saved Keras model (.keras file).",
    )
    parser.add_argument(
        "--output",
        required=True,
        type=Path,
        help="Destination .tflite file.",
    )
    parser.add_argument(
        "--quantize",
        action="store_true",
        help="Apply dynamic-range quantization (smaller model, verify with B12).",
    )
    parser.add_argument(
        "--no-labels",
        dest="write_labels",
        action="store_false",
        help="Do not write a sibling labels.txt file.",
    )
    args = parser.parse_args(argv)

    config = ConversionConfig(
        model_path=args.model,
        output_path=args.output,
        quantize=args.quantize,
        write_labels=args.write_labels,
    )

    convert_model(config)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
