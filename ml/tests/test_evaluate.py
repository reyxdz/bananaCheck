"""Tests for ml.evaluate — model evaluation pipeline (B9).

Strategy
--------
- **Unit tests** for ``EvaluationConfig`` validation (mirrors the existing
  test style in ``test_config.py`` / ``test_train.py``).
- **Unit tests** for ``compute_metrics`` — verifies metric computation with
  known inputs, no model or dataset required.
- **Unit tests** for ``plot_confusion_matrix`` — verifies that the image
  file is created without checking visual content.
- **Integration tests** for ``evaluate`` — uses a tiny synthetic dataset
  and a freshly-trained model to exercise the full pipeline end-to-end.
- **CLI tests** for ``main`` — mirror the existing ``test_train.py`` pattern.

All tests are designed to be fast by using minimal image dimensions (32 × 32)
and a single training epoch.
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
from ml.evaluate import (
    EvaluationConfig,
    compute_metrics,
    compute_predictions,
    evaluate,
    load_test_dataset,
    main,
    plot_confusion_matrix,
)
from ml.train import TrainingConfig, build_model, train

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Use tiny images for fast tests.
_TEST_IMG_SIZE = 32


def _create_synthetic_dataset(
    root: Path,
    subsets: tuple[str, ...] = ("train", "val", "test"),
) -> Path:
    """Create a minimal folder-per-class dataset under *root*.

    Generates 3 tiny JPEG images per class per subset — just enough to
    exercise the data-loading and evaluation code without being slow.
    """
    for subset in subsets:
        for cls in ALL_CLASSES:
            class_dir = root / subset / cls.folder_name
            class_dir.mkdir(parents=True, exist_ok=True)
            for i in range(3):
                img = Image.fromarray(
                    np.random.randint(
                        0, 255, (_TEST_IMG_SIZE, _TEST_IMG_SIZE, 3), dtype=np.uint8
                    )
                )
                img.save(class_dir / f"img_{i:03d}.jpg")
    return root


def _train_tiny_model(data_dir: Path, output_dir: Path) -> Path:
    """Train a minimal model and return the saved model path."""
    config = TrainingConfig(
        data_dir=data_dir,
        output_dir=output_dir,
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
    train(model, config)
    return output_dir / "banana_classifier.keras"


# ---------------------------------------------------------------------------
# EvaluationConfig validation
# ---------------------------------------------------------------------------


class TestEvaluationConfig:
    """Test the ``EvaluationConfig`` dataclass validation."""

    def test_default_config_is_valid(self) -> None:
        config = EvaluationConfig()
        assert config.image_width == 224
        assert config.image_height == 224
        assert config.batch_size == 32

    def test_custom_values(self, tmp_path: Path) -> None:
        config = EvaluationConfig(
            model_path=tmp_path / "model.keras",
            data_dir=tmp_path / "data",
            output_dir=tmp_path / "out",
            batch_size=16,
        )
        assert config.batch_size == 16
        assert config.model_path == tmp_path / "model.keras"

    def test_image_size_property(self) -> None:
        config = EvaluationConfig(image_width=128, image_height=128)
        assert config.image_size == (128, 128)

    @pytest.mark.parametrize(
        "field,value,match",
        [
            ("batch_size", 0, "Batch size"),
            ("batch_size", -1, "Batch size"),
            ("image_width", -1, "Image dimensions"),
            ("image_height", 0, "Image dimensions"),
        ],
    )
    def test_rejects_invalid_values(
        self, field: str, value: int, match: str
    ) -> None:
        with pytest.raises(ValueError, match=match):
            EvaluationConfig(**{field: value})  # type: ignore[arg-type]


# ---------------------------------------------------------------------------
# compute_metrics (pure unit tests — no model needed)
# ---------------------------------------------------------------------------


class TestComputeMetrics:
    """Test metric computation with known inputs."""

    def test_perfect_predictions(self) -> None:
        y_true = np.array([0, 1, 2, 0, 1, 2])
        y_pred = np.array([0, 1, 2, 0, 1, 2])
        class_names = ["ClassA", "ClassB", "ClassC"]

        metrics = compute_metrics(y_true, y_pred, class_names)

        assert metrics["overall_accuracy"] == 1.0
        assert metrics["num_samples"] == 6
        for entry in metrics["per_class"]:
            assert entry["precision"] == 1.0
            assert entry["recall"] == 1.0
            assert entry["f1_score"] == 1.0

    def test_completely_wrong_predictions(self) -> None:
        # Every prediction is wrong
        y_true = np.array([0, 0, 1, 1, 2, 2])
        y_pred = np.array([1, 2, 0, 2, 0, 1])
        class_names = ["ClassA", "ClassB", "ClassC"]

        metrics = compute_metrics(y_true, y_pred, class_names)

        assert metrics["overall_accuracy"] == 0.0
        for entry in metrics["per_class"]:
            assert entry["precision"] == 0.0
            assert entry["recall"] == 0.0

    def test_partial_accuracy(self) -> None:
        y_true = np.array([0, 0, 1, 1])
        y_pred = np.array([0, 1, 1, 0])
        class_names = ["ClassA", "ClassB"]

        metrics = compute_metrics(y_true, y_pred, class_names)

        assert metrics["overall_accuracy"] == 0.5
        assert metrics["num_samples"] == 4

    def test_confusion_matrix_shape(self) -> None:
        y_true = np.array([0, 1, 2, 0, 1])
        y_pred = np.array([0, 2, 2, 1, 1])
        class_names = ["A", "B", "C"]

        metrics = compute_metrics(y_true, y_pred, class_names)

        cm = metrics["confusion_matrix"]
        assert len(cm) == 3
        assert all(len(row) == 3 for row in cm)

    def test_confusion_matrix_values(self) -> None:
        y_true = np.array([0, 0, 1, 1, 2, 2])
        y_pred = np.array([0, 0, 1, 2, 2, 0])
        class_names = ["A", "B", "C"]

        metrics = compute_metrics(y_true, y_pred, class_names)

        cm = metrics["confusion_matrix"]
        # cm[true][pred]
        assert cm[0][0] == 2  # A correctly predicted
        assert cm[1][1] == 1  # B correctly predicted
        assert cm[1][2] == 1  # B predicted as C
        assert cm[2][2] == 1  # C correctly predicted
        assert cm[2][0] == 1  # C predicted as A

    def test_per_class_entries_match_class_names(self) -> None:
        y_true = np.array([0, 1, 2])
        y_pred = np.array([0, 1, 2])
        class_names = ["Cavendish_Ripe", "Saba_Unripe", "Lakatan_Overripe"]

        metrics = compute_metrics(y_true, y_pred, class_names)

        result_names = [entry["class"] for entry in metrics["per_class"]]
        assert result_names == class_names

    def test_support_counts(self) -> None:
        y_true = np.array([0, 0, 0, 1, 2, 2])
        y_pred = np.array([0, 0, 0, 1, 2, 2])
        class_names = ["A", "B", "C"]

        metrics = compute_metrics(y_true, y_pred, class_names)

        supports = {e["class"]: e["support"] for e in metrics["per_class"]}
        assert supports == {"A": 3, "B": 1, "C": 2}

    def test_metrics_are_json_serialisable(self) -> None:
        y_true = np.array([0, 1, 2, 0])
        y_pred = np.array([0, 2, 2, 1])
        class_names = ["A", "B", "C"]

        metrics = compute_metrics(y_true, y_pred, class_names)

        # Should not raise
        serialised = json.dumps(metrics)
        parsed = json.loads(serialised)
        assert parsed["overall_accuracy"] == metrics["overall_accuracy"]

    def test_handles_unseen_classes(self) -> None:
        """Classes with zero support should still appear with zero metrics."""
        y_true = np.array([0, 0, 0])
        y_pred = np.array([0, 0, 0])
        class_names = ["A", "B", "C"]

        metrics = compute_metrics(y_true, y_pred, class_names)

        # B and C have zero support
        assert len(metrics["per_class"]) == 3
        b_entry = next(e for e in metrics["per_class"] if e["class"] == "B")
        assert b_entry["support"] == 0
        assert b_entry["recall"] == 0.0


# ---------------------------------------------------------------------------
# plot_confusion_matrix
# ---------------------------------------------------------------------------


class TestPlotConfusionMatrix:
    """Test confusion matrix visualisation."""

    def test_creates_image_file(self, tmp_path: Path) -> None:
        cm = [[5, 1, 0], [0, 4, 2], [1, 0, 6]]
        class_names = ["A", "B", "C"]
        output_path = tmp_path / "cm.png"

        result = plot_confusion_matrix(cm, class_names, output_path)

        assert result.exists()
        assert result.stat().st_size > 0

    def test_creates_parent_directories(self, tmp_path: Path) -> None:
        cm = [[3, 0], [1, 2]]
        class_names = ["X", "Y"]
        output_path = tmp_path / "nested" / "deep" / "cm.png"

        result = plot_confusion_matrix(cm, class_names, output_path)

        assert result.exists()

    def test_custom_figsize(self, tmp_path: Path) -> None:
        cm = [[1, 0], [0, 1]]
        class_names = ["A", "B"]
        output_path = tmp_path / "cm.png"

        result = plot_confusion_matrix(
            cm, class_names, output_path, figsize=(6, 5)
        )

        assert result.exists()


# ---------------------------------------------------------------------------
# load_test_dataset
# ---------------------------------------------------------------------------


class TestLoadTestDataset:
    """Test loading the test split."""

    def test_loads_test_set(self, tmp_path: Path) -> None:
        _create_synthetic_dataset(tmp_path)
        config = EvaluationConfig(
            data_dir=tmp_path,
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
            batch_size=4,
        )

        test_ds, class_names = load_test_dataset(config)

        assert len(class_names) == NUM_CLASSES
        # The class → index mapping must be pinned to ALL_CLASSES so metrics
        # and labels.txt line up with the model's trained output indices.
        assert class_names == [cls.folder_name for cls in ALL_CLASSES]
        for images, _labels in test_ds.take(1):
            assert images.shape[1:] == (_TEST_IMG_SIZE, _TEST_IMG_SIZE, 3)
            # Rescaled to [0, 1]
            assert float(tf.reduce_max(images)) <= 1.0
            assert float(tf.reduce_min(images)) >= 0.0
            break

    def test_raises_on_missing_test_dir(self, tmp_path: Path) -> None:
        config = EvaluationConfig(data_dir=tmp_path)
        with pytest.raises(FileNotFoundError):
            load_test_dataset(config)


# ---------------------------------------------------------------------------
# compute_predictions
# ---------------------------------------------------------------------------


class TestComputePredictions:
    """Test prediction collection from a model and dataset."""

    def test_returns_correct_shapes(self, tmp_path: Path) -> None:
        _create_synthetic_dataset(tmp_path, subsets=("test",))
        config = EvaluationConfig(
            data_dir=tmp_path,
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
            batch_size=4,
        )
        test_ds, _class_names = load_test_dataset(config)

        model = build_model(
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
        )
        model.compile(
            optimizer="adam",
            loss="sparse_categorical_crossentropy",
        )

        y_true, y_pred = compute_predictions(model, test_ds)

        # 18 classes × 3 images each = 54 samples
        assert len(y_true) == NUM_CLASSES * 3
        assert len(y_pred) == NUM_CLASSES * 3
        assert y_true.dtype in (np.int32, np.int64)
        assert y_pred.dtype in (np.int32, np.int64)


# ---------------------------------------------------------------------------
# evaluate (end-to-end integration)
# ---------------------------------------------------------------------------


class TestEvaluate:
    """End-to-end evaluation integration tests with synthetic data."""

    def test_full_evaluation_pipeline(self, tmp_path: Path) -> None:
        data_dir = tmp_path / "data"
        output_dir = tmp_path / "output"
        _create_synthetic_dataset(data_dir)

        model_path = _train_tiny_model(data_dir, output_dir)

        config = EvaluationConfig(
            model_path=model_path,
            data_dir=data_dir,
            output_dir=output_dir,
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
            batch_size=4,
        )

        metrics = evaluate(config)

        # Metrics structure
        assert "overall_accuracy" in metrics
        assert "num_samples" in metrics
        assert "per_class" in metrics
        assert "confusion_matrix" in metrics
        assert 0.0 <= metrics["overall_accuracy"] <= 1.0
        assert metrics["num_samples"] == NUM_CLASSES * 3

        # Artefact files saved
        assert (output_dir / "evaluation_metrics.json").exists()
        assert (output_dir / "confusion_matrix.png").exists()

        # JSON is loadable and matches returned dict
        saved = json.loads(
            (output_dir / "evaluation_metrics.json").read_text()
        )
        assert saved == metrics

    def test_raises_on_missing_model(self, tmp_path: Path) -> None:
        config = EvaluationConfig(
            model_path=tmp_path / "nonexistent.keras",
            data_dir=tmp_path,
            output_dir=tmp_path / "output",
        )

        with pytest.raises(FileNotFoundError, match="Model file not found"):
            evaluate(config)

    def test_output_dir_is_created_if_missing(self, tmp_path: Path) -> None:
        data_dir = tmp_path / "data"
        output_dir = tmp_path / "nested" / "deep" / "output"
        _create_synthetic_dataset(data_dir)

        model_path = _train_tiny_model(data_dir, tmp_path / "model_out")

        config = EvaluationConfig(
            model_path=model_path,
            data_dir=data_dir,
            output_dir=output_dir,
            image_width=_TEST_IMG_SIZE,
            image_height=_TEST_IMG_SIZE,
            batch_size=4,
        )

        evaluate(config)

        assert (output_dir / "evaluation_metrics.json").exists()
        assert (output_dir / "confusion_matrix.png").exists()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


class TestCLI:
    """Test the ``main`` CLI entry-point."""

    def test_missing_required_args(self) -> None:
        with pytest.raises(SystemExit):
            main([])

    def test_full_pipeline_via_cli(self, tmp_path: Path) -> None:
        data_dir = tmp_path / "data"
        output_dir = tmp_path / "output"
        _create_synthetic_dataset(data_dir)

        model_path = _train_tiny_model(data_dir, tmp_path / "model_out")

        with patch("ml.evaluate.evaluate") as mock_eval:
            mock_eval.return_value = {
                "overall_accuracy": 0.5,
                "num_samples": 54,
                "per_class": [],
                "confusion_matrix": [],
            }

            exit_code = main([
                "--model-path", str(model_path),
                "--data-dir", str(data_dir),
                "--output-dir", str(output_dir),
            ])

        assert exit_code == 0
        mock_eval.assert_called_once()

    def test_cli_passes_all_args_to_config(self, tmp_path: Path) -> None:
        """Verify that CLI arguments are forwarded to EvaluationConfig."""
        captured_config: list[EvaluationConfig] = []

        def fake_evaluate(config: EvaluationConfig) -> dict:
            captured_config.append(config)
            return {
                "overall_accuracy": 0.5,
                "num_samples": 10,
                "per_class": [],
                "confusion_matrix": [],
            }

        with patch("ml.evaluate.evaluate", side_effect=fake_evaluate):
            main([
                "--model-path", str(tmp_path / "model.keras"),
                "--data-dir", str(tmp_path / "data"),
                "--output-dir", str(tmp_path / "output"),
                "--batch-size", "16",
            ])

        assert len(captured_config) == 1
        cfg = captured_config[0]
        assert cfg.batch_size == 16
        assert cfg.model_path == tmp_path / "model.keras"
        assert cfg.data_dir == tmp_path / "data"
        assert cfg.output_dir == tmp_path / "output"
