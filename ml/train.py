"""Baseline model training — MobileNetV2 transfer learning (B8).

Builds a classification head on top of a frozen MobileNetV2 base pre-trained
on ImageNet, then trains on the split banana-classifier dataset produced by
``ml.split.split_dataset_to_dirs``.

The expected input directory layout is::

    data_dir/
      train/
        Cavendish_Unripe/
        Cavendish_Ripe/
        ...
      val/
        Cavendish_Unripe/
        ...

This matches the output of ``python -m ml.split``.

Two training phases are supported:

1. **Feature extraction** — only the classification head is trained while the
   MobileNetV2 convolutional layers remain frozen.  This is fast and works
   well with small datasets.
2. **Fine-tuning** (optional) — after the head converges, the top layers of
   MobileNetV2 are unfrozen and trained at a lower learning rate for further
   accuracy gains.

Usage
-----
CLI::

    python -m ml.train \\
        --data-dir ml/data_split \\
        --output-dir ml/output \\
        --epochs 10 \\
        --fine-tune-epochs 5

Programmatic::

    from ml.train import TrainingConfig, build_model, train

    config = TrainingConfig(data_dir=Path("ml/data_split"))
    model = build_model(num_classes=18)
    history = train(model, config)
"""

from __future__ import annotations

import argparse
import json
from collections.abc import Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import tensorflow as tf

from ml.classes import ALL_CLASSES, NUM_CLASSES
from ml.config import MLConfig
from ml.preprocess import require_directory

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

_DEFAULT_ML = MLConfig()


@dataclass(frozen=True)
class TrainingConfig:
    """Immutable configuration for the training pipeline.

    Parameters
    ----------
    data_dir:
        Root of the split dataset (must contain ``train/`` and ``val/``
        subdirectories with folder-per-class layout).
    output_dir:
        Directory where trained model artefacts are saved.
    image_width, image_height:
        Input image dimensions.  Must match the preprocessing pipeline
        and MobileNetV2 expectations (224 × 224).
    batch_size:
        Mini-batch size for training and validation.
    epochs:
        Number of feature-extraction epochs (frozen base).
    fine_tune_epochs:
        Number of additional fine-tuning epochs (unfrozen top layers).
        Set to 0 to skip fine-tuning entirely.
    fine_tune_layers:
        Number of MobileNetV2 layers to unfreeze from the top during
        fine-tuning.  Only used when ``fine_tune_epochs > 0``.
    learning_rate:
        Initial learning rate for the feature-extraction phase.
    fine_tune_learning_rate:
        Learning rate for the fine-tuning phase (typically 10× lower).
    dropout_rate:
        Dropout rate applied before the final dense layer.
    """

    data_dir: Path = field(default_factory=lambda: _DEFAULT_ML.data_dir)
    output_dir: Path = field(default_factory=lambda: _DEFAULT_ML.output_dir)
    image_width: int = _DEFAULT_ML.image_width
    image_height: int = _DEFAULT_ML.image_height
    batch_size: int = _DEFAULT_ML.batch_size
    epochs: int = _DEFAULT_ML.epochs
    fine_tune_epochs: int = 0
    fine_tune_layers: int = 20
    learning_rate: float = _DEFAULT_ML.learning_rate
    fine_tune_learning_rate: float = 1e-4
    dropout_rate: float = 0.2

    def __post_init__(self) -> None:
        if self.image_width <= 0 or self.image_height <= 0:
            raise ValueError("Image dimensions must be positive integers.")
        if self.batch_size <= 0:
            raise ValueError("Batch size must be a positive integer.")
        if self.epochs <= 0:
            raise ValueError("Training epochs must be positive.")
        if self.fine_tune_epochs < 0:
            raise ValueError("Fine-tune epochs must be non-negative.")
        if self.fine_tune_layers <= 0:
            raise ValueError("Fine-tune layers must be a positive integer.")
        if self.learning_rate <= 0:
            raise ValueError("Learning rate must be positive.")
        if self.fine_tune_learning_rate <= 0:
            raise ValueError("Fine-tune learning rate must be positive.")
        if not 0.0 <= self.dropout_rate < 1.0:
            raise ValueError("Dropout rate must be in [0, 1).")

    @property
    def image_size(self) -> tuple[int, int]:
        """Return ``(height, width)`` for ``image_dataset_from_directory``."""
        return (self.image_height, self.image_width)


# ---------------------------------------------------------------------------
# Model construction
# ---------------------------------------------------------------------------


def build_model(
    num_classes: int = NUM_CLASSES,
    *,
    image_width: int = _DEFAULT_ML.image_width,
    image_height: int = _DEFAULT_ML.image_height,
    dropout_rate: float = 0.2,
) -> tf.keras.Model:
    """Build a MobileNetV2 transfer-learning model.

    Architecture::

        Input (image_height, image_width, 3)
        → MobileNetV2 base (frozen, no top)
        → GlobalAveragePooling2D
        → Dropout
        → Dense(num_classes, softmax)

    Parameters
    ----------
    num_classes:
        Number of output classes (default: 18 from ``ml.classes``).
    image_width, image_height:
        Spatial input dimensions.
    dropout_rate:
        Dropout probability before the classification head.

    Returns
    -------
    tf.keras.Model
        Compiled model is **not** returned — callers should compile with
        their own optimizer/loss after calling this function.
    """
    if num_classes < 2:
        raise ValueError("num_classes must be at least 2.")

    input_shape = (image_height, image_width, 3)

    base_model = tf.keras.applications.MobileNetV2(
        input_shape=input_shape,
        include_top=False,
        weights="imagenet",
    )
    base_model.trainable = False

    inputs = tf.keras.Input(shape=input_shape)
    x = base_model(inputs, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(dropout_rate)(x)
    outputs = tf.keras.layers.Dense(num_classes, activation="softmax")(x)

    return tf.keras.Model(inputs, outputs)


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------


def load_datasets(
    config: TrainingConfig,
) -> tuple[tf.data.Dataset, tf.data.Dataset]:
    """Load training and validation datasets from the split directory.

    Uses ``tf.keras.utils.image_dataset_from_directory`` which expects
    the folder-per-class layout produced by ``ml.split.split_dataset_to_dirs``.

    Images are rescaled to ``[0, 1]`` via a ``Rescaling`` layer applied
    inline, matching the preprocessing contract.

    Returns
    -------
    (train_ds, val_ds)
        TensorFlow datasets yielding ``(images, labels)`` batches.
    """
    train_dir = config.data_dir / "train"
    val_dir = config.data_dir / "val"

    require_directory(train_dir)
    require_directory(val_dir)

    # Pin the class → index mapping to ALL_CLASSES instead of relying on the
    # implicit alphabetical sort, so the model's output indices always match
    # the shipped labels.txt.
    class_names = [banana_class.folder_name for banana_class in ALL_CLASSES]

    train_ds = tf.keras.utils.image_dataset_from_directory(
        train_dir,
        image_size=config.image_size,
        batch_size=config.batch_size,
        label_mode="int",
        class_names=class_names,
        shuffle=True,
        seed=42,
    )
    val_ds = tf.keras.utils.image_dataset_from_directory(
        val_dir,
        image_size=config.image_size,
        batch_size=config.batch_size,
        label_mode="int",
        class_names=class_names,
        shuffle=False,
    )

    # Rescale pixel values to [0, 1] to match the preprocessing contract.
    rescale = tf.keras.layers.Rescaling(1.0 / 255.0)
    train_ds = train_ds.map(lambda x, y: (rescale(x), y))
    val_ds = val_ds.map(lambda x, y: (rescale(x), y))

    # Performance optimisation: prefetch while training on the current batch.
    train_ds = train_ds.prefetch(tf.data.AUTOTUNE)
    val_ds = val_ds.prefetch(tf.data.AUTOTUNE)

    return train_ds, val_ds


# ---------------------------------------------------------------------------
# Training orchestration
# ---------------------------------------------------------------------------


def _serialize_history(history: tf.keras.callbacks.History) -> dict[str, Any]:
    """Convert a Keras ``History`` object to a JSON-serialisable dict."""
    return {
        key: [float(v) for v in values]
        for key, values in history.history.items()
    }


def train(
    model: tf.keras.Model,
    config: TrainingConfig,
) -> dict[str, Any]:
    """Run the full training pipeline (feature extraction + optional fine-tuning).

    Parameters
    ----------
    model:
        An *uncompiled* model returned by :func:`build_model`.
    config:
        Training configuration.

    Returns
    -------
    dict
        Combined training history (feature extraction + fine-tuning) as a
        JSON-serialisable dictionary.
    """
    train_ds, val_ds = load_datasets(config)

    output_dir = Path(config.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    # ---- Phase 1: Feature extraction (frozen base) ----
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=config.learning_rate),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    history_fe = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=config.epochs,
    )

    combined_history = _serialize_history(history_fe)

    # ---- Phase 2: Fine-tuning (optional) ----
    if config.fine_tune_epochs > 0:
        base_model = model.layers[1]  # MobileNetV2 functional layer
        base_model.trainable = True

        # Freeze all layers except the top `fine_tune_layers`.
        for layer in base_model.layers[: -config.fine_tune_layers]:
            layer.trainable = False

        model.compile(
            optimizer=tf.keras.optimizers.Adam(
                learning_rate=config.fine_tune_learning_rate,
            ),
            loss="sparse_categorical_crossentropy",
            metrics=["accuracy"],
        )

        total_epochs = config.epochs + config.fine_tune_epochs
        history_ft = model.fit(
            train_ds,
            validation_data=val_ds,
            initial_epoch=config.epochs,
            epochs=total_epochs,
        )

        ft_history = _serialize_history(history_ft)
        for key, values in ft_history.items():
            combined_history.setdefault(key, []).extend(values)

    # ---- Save artefacts ----
    model_path = output_dir / "banana_classifier.keras"
    model.save(model_path)

    history_path = output_dir / "training_history.json"
    history_path.write_text(
        json.dumps(combined_history, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Model saved to {model_path}")
    print(f"Training history saved to {history_path}")

    return combined_history


# ---------------------------------------------------------------------------
# CLI entry-point
# ---------------------------------------------------------------------------


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entry-point for ``python -m ml.train``."""
    parser = argparse.ArgumentParser(
        description="Train the banana classifier (MobileNetV2 transfer learning).",
    )
    parser.add_argument(
        "--data-dir",
        required=True,
        type=Path,
        help="Root of the split dataset (must contain train/ and val/).",
    )
    parser.add_argument(
        "--output-dir",
        required=True,
        type=Path,
        help="Directory to save trained model artefacts.",
    )
    parser.add_argument(
        "--epochs",
        default=10,
        type=int,
        help="Feature-extraction training epochs (default: 10).",
    )
    parser.add_argument(
        "--fine-tune-epochs",
        default=0,
        type=int,
        help="Fine-tuning epochs after feature extraction (default: 0).",
    )
    parser.add_argument(
        "--fine-tune-layers",
        default=20,
        type=int,
        help="Number of base-model layers to unfreeze for fine-tuning (default: 20).",
    )
    parser.add_argument(
        "--batch-size",
        default=32,
        type=int,
        help="Mini-batch size (default: 32).",
    )
    parser.add_argument(
        "--learning-rate",
        default=1e-3,
        type=float,
        help="Learning rate for feature extraction (default: 1e-3).",
    )
    parser.add_argument(
        "--fine-tune-lr",
        default=1e-4,
        type=float,
        help="Learning rate for fine-tuning (default: 1e-4).",
    )
    parser.add_argument(
        "--dropout",
        default=0.2,
        type=float,
        help="Dropout rate before the classification head (default: 0.2).",
    )

    args = parser.parse_args(argv)

    config = TrainingConfig(
        data_dir=args.data_dir,
        output_dir=args.output_dir,
        epochs=args.epochs,
        fine_tune_epochs=args.fine_tune_epochs,
        fine_tune_layers=args.fine_tune_layers,
        batch_size=args.batch_size,
        learning_rate=args.learning_rate,
        fine_tune_learning_rate=args.fine_tune_lr,
        dropout_rate=args.dropout,
    )

    model = build_model(
        image_width=config.image_width,
        image_height=config.image_height,
        dropout_rate=config.dropout_rate,
    )

    history = train(model, config)

    total_epochs = len(history.get("accuracy", []))
    final_val_acc = history.get("val_accuracy", [None])[-1]
    print(f"\nTraining complete — {total_epochs} total epoch(s).")
    if final_val_acc is not None:
        print(f"Final validation accuracy: {final_val_acc:.4f}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
