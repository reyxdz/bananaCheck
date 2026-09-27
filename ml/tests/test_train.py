"""Tests for ml.train — MobileNetV2 transfer-learning training pipeline (B8).

Strategy
--------
- **Unit tests** for ``TrainingConfig`` validation (mirrors the existing test
  style in ``test_config.py``).
- **Unit tests** for ``build_model`` — verifies architecture shapes, layer
  freezing, and edge cases without needing any dataset.
- **Integration tests** for ``load_datasets`` and ``train`` — use a tiny
  synthetic dataset to exercise the full pipeline end-to-end without
  downloading real images.
- **CLI tests** for ``main`` — mirror the existing ``test_train.py`` pattern.

All tests are designed to be fast by using minimal image dimensions (32 × 32)
and a single epoch.
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
from ml.train import (
    TrainingConfig,
    build_model,
    load_datasets,
    main,
    train,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Use tiny images for fast tests.
_TEST_IMG_SIZE = 32


def _create_synthetic_dataset(root: Path, subsets: tuple[str, ...] = ("train", "val")) -> Path:
    """Create a minimal folder-per-class dataset under *root*.

    Generates 3 tiny JPEG images per class per subset — just enough to
    exercise the data-loading and training code without being slow.
    """
    for subset in subsets:
        for cls in ALL_CLASSES:
            class_dir = root / subset / cls.folder_name
            class_dir.mkdir(parents=True, exist_ok=True)
            for i in range(3):
                img = Image.fromarray(
                    np.random.randint(0, 255, (_TEST_IMG_SIZE, _TEST_IMG_SIZE, 3), dtype=np.uint8)
                )
                img.save(class_dir / f"img_{i:03d}.jpg")
    return root


# ---------------------------------------------------------------------------
# TrainingConfig validation
# ---------------------------------------------------------------------------


class TestTrainingConfig:
    """Test the ``TrainingConfig`` dataclass validation."""

    def test_default_config_is_valid(self) -> None:
        config = TrainingConfig()
        assert config.epochs == 10
        assert config.fine_tune_epochs == 0
        assert config.dropout_rate == 0.2

    def test_custom_values(self, tmp_path: Path) -> None:
        config = TrainingConfig(
            data_dir=tmp_path / "data",
            output_dir=tmp_path / "out",
            epochs=5,
            fine_tune_epochs=3,
            learning_rate=5e-4,
            dropout_rate=0.5,
        )
        assert config.epochs == 5
        assert config.fine_tune_epochs == 3
        assert config.learning_rate == 5e-4

    def test_image_size_property(self) -> None:
        config = TrainingConfig(image_width=128, image_height=128)
        assert config.image_size == (128, 128)

    @pytest.mark.parametrize(
        "field,value,match",
        [
            ("epochs", 0, "epochs must be positive"),
            ("epochs", -1, "epochs must be positive"),
            ("fine_tune_epochs", -1, "non-negative"),
            ("batch_size", 0, "Batch size"),
            ("image_width", -1, "Image dimensions"),
            ("image_height", 0, "Image dimensions"),
            ("learning_rate", 0, "Learning rate must be positive"),
            ("learning_rate", -0.01, "Learning rate must be positive"),
            ("fine_tune_learning_rate", 0, "Fine-tune learning rate"),
            ("fine_tune_layers", 0, "Fine-tune layers"),
            ("dropout_rate", 1.0, "Dropout rate"),
            ("dropout_rate", -0.1, "Dropout rate"),
        ],
    )
    def test_rejects_invalid_values(self, field: str, value: float, match: str) -> None:
        with pytest.raises(ValueError, match=match):
            TrainingConfig(**{field: value})  # type: ignore[arg-type]


# ---------------------------------------------------------------------------
# build_model
# ---------------------------------------------------------------------------


class TestBuildModel:
    """Test MobileNetV2 transfer-learning model construction."""

    def test_output_shape_matches_num_classes(self) -> None:
        model = build_model(
            num_classes=NUM_CLASSES,
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
            dropout_rate=0.2,
        )
        # Output should be (None, NUM_CLASSES)
        assert model.output_shape == (None, NUM_CLASSES)

    def test_input_shape_matches_config(self) -> None:
        model = build_model(
            num_classes=5,
            image_width=64,
            image_height=64,
        )
        # Input shape excludes batch dimension in config
        assert model.input_shape == (None, 64, 64, 3)

    def test_base_model_is_frozen(self) -> None:
        model = build_model(
            num_classes=NUM_CLASSES,
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
        )
        # The second layer is the MobileNetV2 base (first is InputLayer)
        base_model = model.layers[1]
        assert not base_model.trainable

    def test_custom_num_classes(self) -> None:
        model = build_model(
            num_classes=5,
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
        )
        assert model.output_shape == (None, 5)

    def test_rejects_fewer_than_two_classes(self) -> None:
        with pytest.raises(ValueError, match="at least 2"):
            build_model(num_classes=1, image_width=_TEST_IMG_SIZE, image_height=_TEST_IMG_SIZE)

    def test_model_can_predict(self) -> None:
        model = build_model(
            num_classes=NUM_CLASSES,
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
        )
        model.compile(
            optimizer="adam",
            loss="sparse_categorical_crossentropy",
        )
        dummy_input = np.random.rand(1, _TEST_IMG_SIZE, _TEST_IMG_SIZE, 3).astype(np.float32)
        preds = model.predict(dummy_input, verbose=0)
        assert preds.shape == (1, NUM_CLASSES)
        # Softmax output should sum to ~1
        assert abs(float(np.sum(preds)) - 1.0) < 1e-5


# ---------------------------------------------------------------------------
# load_datasets
# ---------------------------------------------------------------------------


class TestLoadDatasets:
    """Test dataset loading from the split directory structure."""

    def test_loads_train_and_val(self, tmp_path: Path) -> None:
        _create_synthetic_dataset(tmp_path)
        config = TrainingConfig(
            data_dir=tmp_path,
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
            batch_size=4,
        )
        train_ds, val_ds = load_datasets(config)

        # Should be able to iterate and get batches
        for images, _labels in train_ds.take(1):
            assert images.shape[1:] == (_TEST_IMG_SIZE, _TEST_IMG_SIZE, 3)
            # Rescaled to [0, 1]
            assert float(tf.reduce_max(images)) <= 1.0
            assert float(tf.reduce_min(images)) >= 0.0
            break

    def test_raises_on_missing_train_dir(self, tmp_path: Path) -> None:
        config = TrainingConfig(data_dir=tmp_path)
        with pytest.raises(FileNotFoundError):
            load_datasets(config)

    def test_raises_on_missing_val_dir(self, tmp_path: Path) -> None:
        # Create only train/, not val/
        (tmp_path / "train").mkdir()
        config = TrainingConfig(data_dir=tmp_path)
        with pytest.raises(FileNotFoundError):
            load_datasets(config)


# ---------------------------------------------------------------------------
# train (end-to-end integration)
# ---------------------------------------------------------------------------


class TestTrain:
    """End-to-end training integration tests with synthetic data."""

    def test_feature_extraction_only(self, tmp_path: Path) -> None:
        _create_synthetic_dataset(tmp_path / "data")
        config = TrainingConfig(
            data_dir=tmp_path / "data",
            output_dir=tmp_path / "output",
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
            batch_size=4,
            epochs=1,
            fine_tune_epochs=0,
        )
        model = build_model(
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
        )

        history = train(model, config)

        # History should contain standard Keras keys
        assert "accuracy" in history
        assert "val_accuracy" in history
        assert "loss" in history
        assert "val_loss" in history
        assert len(history["accuracy"]) == 1

        # Model file saved
        model_path = tmp_path / "output" / "banana_classifier.keras"
        assert model_path.exists()

        # History JSON saved
        history_path = tmp_path / "output" / "training_history.json"
        assert history_path.exists()
        saved_history = json.loads(history_path.read_text())
        assert saved_history == history

    def test_with_fine_tuning(self, tmp_path: Path) -> None:
        _create_synthetic_dataset(tmp_path / "data")
        config = TrainingConfig(
            data_dir=tmp_path / "data",
            output_dir=tmp_path / "output",
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
            batch_size=4,
            epochs=1,
            fine_tune_epochs=1,
            fine_tune_layers=5,
        )
        model = build_model(
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
        )

        history = train(model, config)

        # Total 2 epochs (1 FE + 1 FT)
        assert len(history["accuracy"]) == 2

    def test_saved_model_is_loadable(self, tmp_path: Path) -> None:
        _create_synthetic_dataset(tmp_path / "data")
        config = TrainingConfig(
            data_dir=tmp_path / "data",
            output_dir=tmp_path / "output",
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
            batch_size=4,
            epochs=1,
        )
        model = build_model(
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
        )
        train(model, config)

        # Reload and verify
        loaded = tf.keras.models.load_model(tmp_path / "output" / "banana_classifier.keras")
        assert loaded.output_shape == (None, NUM_CLASSES)

    def test_output_dir_is_created_if_missing(self, tmp_path: Path) -> None:
        _create_synthetic_dataset(tmp_path / "data")
        output_dir = tmp_path / "nested" / "deeply" / "output"
        config = TrainingConfig(
            data_dir=tmp_path / "data",
            output_dir=output_dir,
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
            batch_size=4,
            epochs=1,
        )
        model = build_model(
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
        )
        train(model, config)
        assert (output_dir / "banana_classifier.keras").exists()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


class TestCLI:
    """Test the ``main`` CLI entry-point."""

    def test_missing_required_args(self) -> None:
        with pytest.raises(SystemExit):
            main([])

    def test_full_pipeline_via_cli(self, tmp_path: Path) -> None:
        _create_synthetic_dataset(tmp_path / "data")

        # Patch build_model to use tiny images (faster)
        with patch("ml.train.build_model") as mock_build, patch(
            "ml.train.train"
        ) as mock_train:
            mock_build.return_value = build_model(
                image_width=_TEST_IMG_SIZE,
                image_height=_TEST_IMG_SIZE,
            )
            mock_train.return_value = {"accuracy": [0.5], "val_accuracy": [0.4]}

            exit_code = main([
                "--data-dir", str(tmp_path / "data"),
                "--output-dir", str(tmp_path / "output"),
                "--epochs", "1",
            ])

        assert exit_code == 0
        mock_build.assert_called_once()
        mock_train.assert_called_once()

    def test_cli_passes_all_args_to_config(self, tmp_path: Path) -> None:
        """Verify that CLI arguments are forwarded to TrainingConfig."""
        _create_synthetic_dataset(tmp_path / "data")

        captured_config: list[TrainingConfig] = []

        def fake_train(model: tf.keras.Model, config: TrainingConfig) -> dict:
            captured_config.append(config)
            return {"accuracy": [0.5], "val_accuracy": [0.4]}

        with patch("ml.train.train", side_effect=fake_train):
            main([
                "--data-dir", str(tmp_path / "data"),
                "--output-dir", str(tmp_path / "output"),
                "--epochs", "5",
                "--fine-tune-epochs", "3",
                "--fine-tune-layers", "15",
                "--batch-size", "16",
                "--learning-rate", "0.005",
                "--fine-tune-lr", "0.0005",
                "--dropout", "0.3",
            ])

        assert len(captured_config) == 1
        cfg = captured_config[0]
        assert cfg.epochs == 5
        assert cfg.fine_tune_epochs == 3
        assert cfg.fine_tune_layers == 15
        assert cfg.batch_size == 16
        assert cfg.learning_rate == 0.005
        assert cfg.fine_tune_learning_rate == 0.0005
        assert cfg.dropout_rate == 0.3
