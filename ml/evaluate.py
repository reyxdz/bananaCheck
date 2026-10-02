"""Model evaluation — accuracy, confusion matrix, and per-class metrics (B9).

Evaluates a trained Keras model against the held-out **test** split produced
by ``ml.split.split_dataset_to_dirs`` and generates the artefacts needed for
the thesis paper (B17) and hyperparameter tuning decisions (B10).

The expected input directory layout is::

    data_dir/
      test/
        Cavendish_Unripe/
        Cavendish_Ripe/
        ...

Generated artefacts (saved to ``output_dir``):

- ``evaluation_metrics.json`` — overall accuracy, per-class precision /
  recall / F1, and the raw confusion matrix as a nested list.
- ``confusion_matrix.png`` — annotated heatmap rendered with seaborn.

Usage
-----
CLI::

    python -m ml.evaluate \\
        --model-path ml/output/banana_classifier.keras \\
        --data-dir ml/data_split \\
        --output-dir ml/output

Programmatic::

    from ml.evaluate import EvaluationConfig, evaluate

    config = EvaluationConfig(
        model_path=Path("ml/output/banana_classifier.keras"),
        data_dir=Path("ml/data_split"),
    )
    metrics = evaluate(config)
"""

from __future__ import annotations

import argparse
import json
from collections.abc import Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
import tensorflow as tf
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
)

from ml.classes import ALL_CLASSES
from ml.config import MLConfig
from ml.preprocess import require_directory

# Use non-interactive backend so the script works in headless / CI
# environments without an X server.
matplotlib.use("Agg")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

_DEFAULT_ML = MLConfig()


@dataclass(frozen=True)
class EvaluationConfig:
    """Immutable configuration for the evaluation pipeline.

    Parameters
    ----------
    model_path:
        Path to the saved Keras model (``.keras`` format).
    data_dir:
        Root of the split dataset (must contain a ``test/`` subdirectory
        with folder-per-class layout).
    output_dir:
        Directory where evaluation artefacts are saved.
    image_width, image_height:
        Input image dimensions.  Must match the preprocessing pipeline
        and MobileNetV2 expectations (224 × 224).
    batch_size:
        Mini-batch size for prediction.
    """

    model_path: Path = field(
        default_factory=lambda: _DEFAULT_ML.output_dir / "banana_classifier.keras",
    )
    data_dir: Path = field(default_factory=lambda: _DEFAULT_ML.data_dir)
    output_dir: Path = field(default_factory=lambda: _DEFAULT_ML.output_dir)
    image_width: int = _DEFAULT_ML.image_width
    image_height: int = _DEFAULT_ML.image_height
    batch_size: int = _DEFAULT_ML.batch_size

    def __post_init__(self) -> None:
        if self.image_width <= 0 or self.image_height <= 0:
            raise ValueError("Image dimensions must be positive integers.")
        if self.batch_size <= 0:
            raise ValueError("Batch size must be a positive integer.")

    @property
    def image_size(self) -> tuple[int, int]:
        """Return ``(height, width)`` for ``image_dataset_from_directory``."""
        return (self.image_height, self.image_width)


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------


def load_test_dataset(
    config: EvaluationConfig,
) -> tuple[tf.data.Dataset, list[str]]:
    """Load the test dataset from the split directory.

    Uses ``tf.keras.utils.image_dataset_from_directory`` which expects
    the folder-per-class layout produced by ``ml.split.split_dataset_to_dirs``.

    Images are rescaled to ``[0, 1]`` via a ``Rescaling`` layer, matching
    the training preprocessing contract.

    Parameters
    ----------
    config:
        Evaluation configuration.

    Returns
    -------
    (tf.data.Dataset, list[str])
        A tuple of the dataset yielding ``(images, labels)`` batches with
        ``shuffle=False`` to preserve sample ordering for metric computation,
        and the ordered list of class names matching label indices.
    """
    test_dir = config.data_dir / "test"
    require_directory(test_dir)

    test_ds = tf.keras.utils.image_dataset_from_directory(
        test_dir,
        image_size=config.image_size,
        batch_size=config.batch_size,
        label_mode="int",
        # Pin index order to ALL_CLASSES (== labels.txt), never folder luck.
        class_names=[cls.folder_name for cls in ALL_CLASSES],
        shuffle=False,
    )

    # Capture class_names before .map()/.prefetch() strip the attribute.
    class_names: list[str] = test_ds.class_names

    rescale = tf.keras.layers.Rescaling(1.0 / 255.0)
    test_ds = test_ds.map(lambda x, y: (rescale(x), y))
    test_ds = test_ds.prefetch(tf.data.AUTOTUNE)

    return test_ds, class_names


# ---------------------------------------------------------------------------
# Metric computation
# ---------------------------------------------------------------------------


def compute_predictions(
    model: tf.keras.Model,
    dataset: tf.data.Dataset,
) -> tuple[np.ndarray, np.ndarray]:
    """Run inference on every sample in *dataset* and collect true/predicted labels.

    Parameters
    ----------
    model:
        Compiled Keras model.
    dataset:
        Test dataset yielding ``(images, labels)`` batches.

    Returns
    -------
    (y_true, y_pred)
        Integer label arrays of shape ``(n_samples,)``.
    """
    y_true_parts: list[np.ndarray] = []
    y_pred_parts: list[np.ndarray] = []

    for images, labels in dataset:
        predictions = model.predict(images, verbose=0)
        y_pred_parts.append(np.argmax(predictions, axis=1))
        y_true_parts.append(labels.numpy())

    y_true = np.concatenate(y_true_parts)
    y_pred = np.concatenate(y_pred_parts)

    return y_true, y_pred


def compute_metrics(
    y_true: np.ndarray,
    y_pred: np.ndarray,
    class_names: list[str],
) -> dict[str, Any]:
    """Compute evaluation metrics from true and predicted labels.

    Parameters
    ----------
    y_true:
        Ground-truth integer labels.
    y_pred:
        Predicted integer labels.
    class_names:
        Ordered list of human-readable class names matching model output
        indices (e.g. ``["Cavendish_Unripe", "Cavendish_Ripe", ...]``).

    Returns
    -------
    dict
        JSON-serialisable dictionary containing:

        - ``overall_accuracy`` — float in ``[0, 1]``.
        - ``num_samples`` — total number of test images evaluated.
        - ``per_class`` — list of dicts with ``class``, ``precision``,
          ``recall``, ``f1_score``, and ``support`` for each class.
        - ``confusion_matrix`` — nested list ``(num_classes × num_classes)``
          where ``cm[true][pred]`` is the count.
    """
    cm = confusion_matrix(y_true, y_pred, labels=list(range(len(class_names))))

    report = classification_report(
        y_true,
        y_pred,
        labels=list(range(len(class_names))),
        target_names=class_names,
        output_dict=True,
        zero_division=0,
    )

    per_class: list[dict[str, Any]] = []
    for name in class_names:
        entry = report[name]
        per_class.append({
            "class": name,
            "precision": round(float(entry["precision"]), 4),
            "recall": round(float(entry["recall"]), 4),
            "f1_score": round(float(entry["f1-score"]), 4),
            "support": int(entry["support"]),
        })

    overall_accuracy = float(np.sum(y_true == y_pred)) / len(y_true) if len(y_true) > 0 else 0.0

    return {
        "overall_accuracy": round(overall_accuracy, 4),
        "num_samples": int(len(y_true)),
        "per_class": per_class,
        "confusion_matrix": cm.tolist(),
    }


# ---------------------------------------------------------------------------
# Visualisation
# ---------------------------------------------------------------------------


def plot_confusion_matrix(
    cm: list[list[int]],
    class_names: list[str],
    output_path: Path,
    *,
    figsize: tuple[int, int] = (14, 12),
) -> Path:
    """Render an annotated confusion-matrix heatmap and save to *output_path*.

    Parameters
    ----------
    cm:
        Confusion matrix as a nested list ``(num_classes × num_classes)``.
    class_names:
        Ordered class labels for axis tick marks.
    output_path:
        Destination file path (e.g. ``output/confusion_matrix.png``).
    figsize:
        Figure dimensions in inches.

    Returns
    -------
    Path
        Resolved *output_path* for convenience.
    """
    output_path = output_path.resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    cm_array = np.array(cm)

    fig, ax = plt.subplots(figsize=figsize)
    sns.heatmap(
        cm_array,
        annot=True,
        fmt="d",
        cmap="Blues",
        xticklabels=class_names,
        yticklabels=class_names,
        ax=ax,
    )
    ax.set_xlabel("Predicted label")
    ax.set_ylabel("True label")
    ax.set_title("Confusion Matrix — Banana Classifier")

    plt.tight_layout()
    fig.savefig(output_path, dpi=150)
    plt.close(fig)

    return output_path


# ---------------------------------------------------------------------------
# Evaluation orchestration
# ---------------------------------------------------------------------------


def evaluate(config: EvaluationConfig) -> dict[str, Any]:
    """Run the full evaluation pipeline.

    1. Load the trained model from ``config.model_path``.
    2. Load the test dataset from ``config.data_dir / "test"``.
    3. Compute predictions and evaluation metrics.
    4. Save ``evaluation_metrics.json`` and ``confusion_matrix.png``.

    Parameters
    ----------
    config:
        Evaluation configuration.

    Returns
    -------
    dict
        The computed metrics dictionary (same content as the saved JSON).

    Raises
    ------
    FileNotFoundError
        If the model file or test directory does not exist.
    """
    model_path = Path(config.model_path).resolve()
    if not model_path.exists():
        raise FileNotFoundError(f"Model file not found: {model_path}")

    output_dir = Path(config.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    # ---- Load model and data ----
    model = tf.keras.models.load_model(model_path)
    test_ds, class_names = load_test_dataset(config)

    # ---- Predict and compute metrics ----
    y_true, y_pred = compute_predictions(model, test_ds)
    metrics = compute_metrics(y_true, y_pred, class_names)

    # ---- Save artefacts ----
    metrics_path = output_dir / "evaluation_metrics.json"
    metrics_path.write_text(
        json.dumps(metrics, indent=2) + "\n",
        encoding="utf-8",
    )

    cm_image_path = output_dir / "confusion_matrix.png"
    plot_confusion_matrix(
        metrics["confusion_matrix"],
        class_names,
        cm_image_path,
    )

    print(f"Evaluation metrics saved to {metrics_path}")
    print(f"Confusion matrix saved to {cm_image_path}")
    print(f"\nOverall accuracy: {metrics['overall_accuracy']:.4f}")
    print(f"Samples evaluated: {metrics['num_samples']}")

    return metrics


# ---------------------------------------------------------------------------
# CLI entry-point
# ---------------------------------------------------------------------------


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entry-point for ``python -m ml.evaluate``."""
    parser = argparse.ArgumentParser(
        description="Evaluate the banana classifier on the test set (B9).",
    )
    parser.add_argument(
        "--model-path",
        required=True,
        type=Path,
        help="Path to the saved Keras model (.keras file).",
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
        help="Directory to save evaluation artefacts.",
    )
    parser.add_argument(
        "--batch-size",
        default=32,
        type=int,
        help="Mini-batch size for prediction (default: 32).",
    )

    args = parser.parse_args(argv)

    config = EvaluationConfig(
        model_path=args.model_path,
        data_dir=args.data_dir,
        output_dir=args.output_dir,
        batch_size=args.batch_size,
    )

    evaluate(config)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
