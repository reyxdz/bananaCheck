"""Validate TFLite accuracy vs. the original Keras model (B12).

After :mod:`ml.convert_to_tflite` (B11) produces a ``.tflite`` file, this module
confirms the converted model behaves like the Keras model it came from — the
conversion (and any quantization) must not silently degrade predictions before
the model ships on-device (B13).

Both models are run over the **same** held-out test split (the folder-per-class
``test/`` directory produced by :mod:`ml.split`) using the same rescaled
``[0, 1]`` inputs, then compared on:

- **agreement** — fraction of samples where both models pick the same class.
  This is the primary gate: a faithful conversion agrees on nearly every sample.
- **keras / tflite accuracy** vs. ground truth, and their delta.
- **probability drift** — max / mean absolute difference between the two models'
  output probability vectors.

The run **passes** when agreement meets ``agreement_threshold``.

Generated artefacts (saved to ``output_dir``):

- ``tflite_validation.json`` — all metrics plus the pass/fail verdict.

Usage
-----
CLI::

    python -m ml.validate_tflite \\
        --keras-model ml/output/banana_classifier.keras \\
        --tflite-model ml/output/banana_classifier.tflite \\
        --data-dir ml/data_split \\
        --output-dir ml/output

Exit code is ``0`` when validation passes and ``1`` when it fails, so the check
can gate a build.

Programmatic::

    from ml.validate_tflite import ValidationConfig, validate

    config = ValidationConfig(
        keras_model_path=Path("ml/output/banana_classifier.keras"),
        tflite_model_path=Path("ml/output/banana_classifier.tflite"),
        data_dir=Path("ml/data_split"),
    )
    report = validate(config)
"""

from __future__ import annotations

import argparse
import json
from collections.abc import Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import numpy as np
import tensorflow as tf

from ml.config import MLConfig
from ml.evaluate import EvaluationConfig, load_test_dataset

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

_DEFAULT_ML = MLConfig()

#: Default minimum class-agreement fraction for a conversion to pass.
_DEFAULT_AGREEMENT_THRESHOLD = 0.99


@dataclass(frozen=True)
class ValidationConfig:
    """Immutable configuration for TFLite-vs-Keras validation.

    Parameters
    ----------
    keras_model_path:
        Path to the original saved Keras model (``.keras``).
    tflite_model_path:
        Path to the converted ``.tflite`` model.
    data_dir:
        Root of the split dataset (must contain a ``test/`` subdirectory).
    output_dir:
        Directory where the validation report is saved.
    image_width, image_height:
        Input image dimensions (must match training / conversion).
    batch_size:
        Mini-batch size for prediction.
    agreement_threshold:
        Minimum fraction of samples on which the two models must agree for the
        validation to pass (default: 0.99).
    """

    keras_model_path: Path = field(
        default_factory=lambda: _DEFAULT_ML.output_dir / "banana_classifier.keras",
    )
    tflite_model_path: Path = field(
        default_factory=lambda: _DEFAULT_ML.output_dir / "banana_classifier.tflite",
    )
    data_dir: Path = field(default_factory=lambda: _DEFAULT_ML.data_dir)
    output_dir: Path = field(default_factory=lambda: _DEFAULT_ML.output_dir)
    image_width: int = _DEFAULT_ML.image_width
    image_height: int = _DEFAULT_ML.image_height
    batch_size: int = _DEFAULT_ML.batch_size
    agreement_threshold: float = _DEFAULT_AGREEMENT_THRESHOLD

    def __post_init__(self) -> None:
        if self.image_width <= 0 or self.image_height <= 0:
            raise ValueError("Image dimensions must be positive integers.")
        if self.batch_size <= 0:
            raise ValueError("Batch size must be a positive integer.")
        if not 0.0 <= self.agreement_threshold <= 1.0:
            raise ValueError("Agreement threshold must be in [0, 1].")

    def as_evaluation_config(self) -> EvaluationConfig:
        """Return an :class:`ml.evaluate.EvaluationConfig` for the data loader."""
        return EvaluationConfig(
            model_path=self.keras_model_path,
            data_dir=self.data_dir,
            output_dir=self.output_dir,
            image_width=self.image_width,
            image_height=self.image_height,
            batch_size=self.batch_size,
        )


# ---------------------------------------------------------------------------
# Probability collection
# ---------------------------------------------------------------------------


def keras_predict_probs(
    model: tf.keras.Model,
    dataset: tf.data.Dataset,
) -> tuple[np.ndarray, np.ndarray]:
    """Collect ground-truth labels and Keras output probabilities.

    Returns
    -------
    (y_true, probs)
        ``y_true`` has shape ``(n_samples,)``; ``probs`` has shape
        ``(n_samples, num_classes)``.
    """
    y_true_parts: list[np.ndarray] = []
    prob_parts: list[np.ndarray] = []

    for images, labels in dataset:
        prob_parts.append(model.predict(images, verbose=0))
        y_true_parts.append(labels.numpy())

    return np.concatenate(y_true_parts), np.concatenate(prob_parts)


def tflite_predict_probs(
    interpreter: tf.lite.Interpreter,
    dataset: tf.data.Dataset,
) -> np.ndarray:
    """Collect TFLite output probabilities over *dataset*.

    The interpreter's input tensor is resized to each batch's shape so batches
    of any size (including a smaller final batch) are handled.

    Returns
    -------
    np.ndarray
        Probabilities of shape ``(n_samples, num_classes)``, ordered to match
        :func:`keras_predict_probs` (both iterate the same unshuffled dataset).
    """
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    in_index = input_details[0]["index"]
    out_index = output_details[0]["index"]

    prob_parts: list[np.ndarray] = []
    for images, _labels in dataset:
        batch = images.numpy().astype(np.float32)
        interpreter.resize_tensor_input(in_index, batch.shape)
        interpreter.allocate_tensors()
        interpreter.set_tensor(in_index, batch)
        interpreter.invoke()
        prob_parts.append(np.array(interpreter.get_tensor(out_index)))

    return np.concatenate(prob_parts)


# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------


def compare_predictions(
    y_true: np.ndarray,
    keras_probs: np.ndarray,
    tflite_probs: np.ndarray,
    *,
    agreement_threshold: float,
) -> dict[str, Any]:
    """Compare Keras and TFLite predictions and build a report dict.

    Parameters
    ----------
    y_true:
        Ground-truth integer labels, shape ``(n_samples,)``.
    keras_probs, tflite_probs:
        Output probability arrays, shape ``(n_samples, num_classes)``.
    agreement_threshold:
        Minimum class-agreement fraction required to pass.

    Returns
    -------
    dict
        JSON-serialisable metrics with a ``passed`` boolean verdict.
    """
    keras_pred = np.argmax(keras_probs, axis=1)
    tflite_pred = np.argmax(tflite_probs, axis=1)
    num_samples = int(len(y_true))

    agreement = float(np.mean(keras_pred == tflite_pred)) if num_samples else 0.0
    keras_accuracy = float(np.mean(keras_pred == y_true)) if num_samples else 0.0
    tflite_accuracy = float(np.mean(tflite_pred == y_true)) if num_samples else 0.0

    prob_diff = np.abs(keras_probs - tflite_probs)
    max_prob_diff = float(np.max(prob_diff)) if prob_diff.size else 0.0
    mean_prob_diff = float(np.mean(prob_diff)) if prob_diff.size else 0.0

    return {
        "num_samples": num_samples,
        "agreement": round(agreement, 4),
        "agreement_threshold": agreement_threshold,
        "keras_accuracy": round(keras_accuracy, 4),
        "tflite_accuracy": round(tflite_accuracy, 4),
        "accuracy_delta": round(tflite_accuracy - keras_accuracy, 4),
        "max_prob_diff": round(max_prob_diff, 6),
        "mean_prob_diff": round(mean_prob_diff, 6),
        "passed": bool(agreement >= agreement_threshold),
    }


# ---------------------------------------------------------------------------
# Validation orchestration
# ---------------------------------------------------------------------------


def validate(config: ValidationConfig) -> dict[str, Any]:
    """Run the full TFLite-vs-Keras validation and save a report.

    Parameters
    ----------
    config:
        Validation configuration.

    Returns
    -------
    dict
        The comparison report (same content as the saved JSON).

    Raises
    ------
    FileNotFoundError
        If either model file or the test directory does not exist.
    """
    keras_path = Path(config.keras_model_path).resolve()
    if not keras_path.exists():
        raise FileNotFoundError(f"Keras model not found: {keras_path}")

    tflite_path = Path(config.tflite_model_path).resolve()
    if not tflite_path.exists():
        raise FileNotFoundError(f"TFLite model not found: {tflite_path}")

    output_dir = Path(config.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    # ---- Load models and data ----
    test_ds, _class_names = load_test_dataset(config.as_evaluation_config())
    keras_model = tf.keras.models.load_model(keras_path)
    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))

    # ---- Collect predictions (same dataset order for both) ----
    y_true, keras_probs = keras_predict_probs(keras_model, test_ds)
    tflite_probs = tflite_predict_probs(interpreter, test_ds)

    report = compare_predictions(
        y_true,
        keras_probs,
        tflite_probs,
        agreement_threshold=config.agreement_threshold,
    )

    # ---- Save artefact ----
    report_path = output_dir / "tflite_validation.json"
    report_path.write_text(
        json.dumps(report, indent=2) + "\n",
        encoding="utf-8",
    )

    verdict = "PASS" if report["passed"] else "FAIL"
    print(f"TFLite validation report saved to {report_path}")
    print(f"\nAgreement: {report['agreement']:.4f} "
          f"(threshold {report['agreement_threshold']}) — {verdict}")
    print(f"Keras accuracy:  {report['keras_accuracy']:.4f}")
    print(f"TFLite accuracy: {report['tflite_accuracy']:.4f}")
    print(f"Max probability drift: {report['max_prob_diff']}")

    return report


# ---------------------------------------------------------------------------
# CLI entry-point
# ---------------------------------------------------------------------------


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entry-point for ``python -m ml.validate_tflite``.

    Returns ``0`` when validation passes and ``1`` when it fails.
    """
    parser = argparse.ArgumentParser(
        description="Validate TFLite accuracy vs. the original Keras model (B12).",
    )
    parser.add_argument(
        "--keras-model",
        required=True,
        type=Path,
        help="Path to the original saved Keras model (.keras file).",
    )
    parser.add_argument(
        "--tflite-model",
        required=True,
        type=Path,
        help="Path to the converted .tflite model.",
    )
    parser.add_argument(
        "--data-dir",
        required=True,
        type=Path,
        help="Root of the split dataset (must contain a test/ subdirectory).",
    )
    parser.add_argument(
        "--output-dir",
        required=True,
        type=Path,
        help="Directory to save the validation report.",
    )
    parser.add_argument(
        "--batch-size",
        default=32,
        type=int,
        help="Mini-batch size for prediction (default: 32).",
    )
    parser.add_argument(
        "--agreement-threshold",
        default=_DEFAULT_AGREEMENT_THRESHOLD,
        type=float,
        help="Minimum class-agreement fraction to pass (default: 0.99).",
    )

    args = parser.parse_args(argv)

    config = ValidationConfig(
        keras_model_path=args.keras_model,
        tflite_model_path=args.tflite_model,
        data_dir=args.data_dir,
        output_dir=args.output_dir,
        batch_size=args.batch_size,
        agreement_threshold=args.agreement_threshold,
    )

    report = validate(config)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
