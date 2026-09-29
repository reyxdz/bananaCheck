"""Tests for ml.tune — hyperparameter tuning / retraining iterations (B10).

Strategy
--------
- **Unit tests** for ``HyperparameterGrid`` / ``TuningConfig`` validation
  (mirrors ``test_train.py`` / ``test_evaluate.py``).
- **Unit tests** for grid expansion (``iter_trial_configs``) — no training.
- **Unit tests** for scoring / selection helpers with known inputs.
- **Integration test** for ``tune`` — tiny synthetic dataset + a 2-trial grid
  exercises the full search, winner-copy, and summary-writing path.
- **CLI tests** for ``main`` — mirror the ``test_evaluate.py`` pattern.

All tests use tiny 32×32 images and single-epoch trials to stay fast.
"""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import patch

import numpy as np
import pytest
from PIL import Image

from ml.classes import ALL_CLASSES
from ml.train import TrainingConfig
from ml.tune import (
    HyperparameterGrid,
    TuningConfig,
    iter_trial_configs,
    main,
    score_history,
    select_best_trial,
    tune,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_TEST_IMG_SIZE = 32


def _create_synthetic_dataset(
    root: Path,
    subsets: tuple[str, ...] = ("train", "val"),
) -> Path:
    """Create a minimal folder-per-class dataset under *root*."""
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


def _tiny_grid() -> HyperparameterGrid:
    """A 2-combination grid (learning rate only) for fast integration tests."""
    return HyperparameterGrid(
        learning_rates=(1e-3, 1e-4),
        dropout_rates=(0.2,),
        fine_tune_epochs=(0,),
        fine_tune_layers=(20,),
        batch_sizes=(4,),
    )


def _tiny_config(data_dir: Path, output_dir: Path, **kwargs) -> TuningConfig:
    return TuningConfig(
        data_dir=data_dir,
        output_dir=output_dir,
        image_width=_TEST_IMG_SIZE,
        image_height=_TEST_IMG_SIZE,
        epochs=1,
        **kwargs,
    )


# ---------------------------------------------------------------------------
# HyperparameterGrid
# ---------------------------------------------------------------------------


class TestHyperparameterGrid:
    """Test the search-grid dataclass."""

    def test_default_combination_count(self) -> None:
        # 2 lr × 2 dropout × 2 ft_epochs × 1 ft_layers × 1 batch = 8
        assert HyperparameterGrid().num_combinations == 8

    def test_custom_combination_count(self) -> None:
        grid = HyperparameterGrid(
            learning_rates=(1e-3, 1e-4, 1e-5),
            dropout_rates=(0.2, 0.3),
            fine_tune_epochs=(0,),
        )
        assert grid.num_combinations == 6

    def test_rejects_empty_axis(self) -> None:
        with pytest.raises(ValueError, match="learning_rates"):
            HyperparameterGrid(learning_rates=())


# ---------------------------------------------------------------------------
# TuningConfig
# ---------------------------------------------------------------------------


class TestTuningConfig:
    """Test the shared tuning configuration validation."""

    def test_defaults(self) -> None:
        config = TuningConfig()
        assert config.metric == "val_accuracy"
        assert config.max_trials is None
        assert config.cleanup_trials is False

    @pytest.mark.parametrize(
        "kwargs,match",
        [
            ({"epochs": 0}, "Training epochs"),
            ({"image_width": -1}, "Image dimensions"),
            ({"fine_tune_learning_rate": 0}, "Fine-tune learning rate"),
            ({"metric": ""}, "Metric"),
            ({"max_trials": 0}, "max_trials"),
        ],
    )
    def test_rejects_invalid_values(self, kwargs: dict, match: str) -> None:
        with pytest.raises(ValueError, match=match):
            TuningConfig(**kwargs)


# ---------------------------------------------------------------------------
# iter_trial_configs
# ---------------------------------------------------------------------------


class TestIterTrialConfigs:
    """Test grid expansion into TrainingConfig instances."""

    def test_yields_one_config_per_combination(self, tmp_path: Path) -> None:
        grid = HyperparameterGrid(
            learning_rates=(1e-3, 1e-4),
            dropout_rates=(0.2, 0.3),
            fine_tune_epochs=(0,),
        )
        config = TuningConfig(output_dir=tmp_path)

        configs = list(
            iter_trial_configs(grid, config, trials_dir=tmp_path / "trials")
        )

        assert len(configs) == grid.num_combinations == 4
        assert all(isinstance(c, TrainingConfig) for c in configs)

    def test_hyperparameters_are_forwarded(self, tmp_path: Path) -> None:
        grid = HyperparameterGrid(
            learning_rates=(1e-3,),
            dropout_rates=(0.42,),
            fine_tune_epochs=(3,),
            fine_tune_layers=(15,),
            batch_sizes=(8,),
        )
        config = TuningConfig(output_dir=tmp_path, epochs=7)

        (trial,) = list(
            iter_trial_configs(grid, config, trials_dir=tmp_path / "trials")
        )

        assert trial.learning_rate == 1e-3
        assert trial.dropout_rate == 0.42
        assert trial.fine_tune_epochs == 3
        assert trial.fine_tune_layers == 15
        assert trial.batch_size == 8
        assert trial.epochs == 7

    def test_distinct_output_dirs(self, tmp_path: Path) -> None:
        grid = HyperparameterGrid(
            learning_rates=(1e-3, 1e-4),
            dropout_rates=(0.2,),
            fine_tune_epochs=(0,),
        )
        config = TuningConfig(output_dir=tmp_path)

        dirs = [
            c.output_dir
            for c in iter_trial_configs(grid, config, trials_dir=tmp_path / "t")
        ]
        assert len(set(dirs)) == len(dirs)

    def test_respects_max_trials(self, tmp_path: Path) -> None:
        grid = HyperparameterGrid()  # 8 combinations
        config = TuningConfig(output_dir=tmp_path, max_trials=3)

        configs = list(
            iter_trial_configs(grid, config, trials_dir=tmp_path / "trials")
        )
        assert len(configs) == 3


# ---------------------------------------------------------------------------
# score_history / select_best_trial
# ---------------------------------------------------------------------------


class TestScoreHistory:
    """Test extracting the trial score from a training history."""

    def test_returns_last_epoch_value(self) -> None:
        history = {"val_accuracy": [0.4, 0.6, 0.8]}
        assert score_history(history, "val_accuracy") == 0.8

    def test_missing_metric_returns_none(self) -> None:
        assert score_history({"accuracy": [0.5]}, "val_accuracy") is None

    def test_empty_metric_returns_none(self) -> None:
        assert score_history({"val_accuracy": []}, "val_accuracy") is None


class TestSelectBestTrial:
    """Test picking the winning trial."""

    def test_picks_highest_score(self) -> None:
        trials = [
            {"trial": 0, "score": 0.5},
            {"trial": 1, "score": 0.9},
            {"trial": 2, "score": 0.7},
        ]
        assert select_best_trial(trials)["trial"] == 1

    def test_ignores_none_scores(self) -> None:
        trials = [
            {"trial": 0, "score": None},
            {"trial": 1, "score": 0.3},
        ]
        assert select_best_trial(trials)["trial"] == 1

    def test_raises_when_no_usable_score(self) -> None:
        with pytest.raises(ValueError, match="usable score"):
            select_best_trial([{"trial": 0, "score": None}])

    def test_raises_on_empty(self) -> None:
        with pytest.raises(ValueError, match="usable score"):
            select_best_trial([])


# ---------------------------------------------------------------------------
# tune (end-to-end integration)
# ---------------------------------------------------------------------------


class TestTune:
    """End-to-end grid-search integration tests with synthetic data."""

    def test_full_tuning_run(self, tmp_path: Path) -> None:
        data_dir = tmp_path / "data"
        output_dir = tmp_path / "output"
        _create_synthetic_dataset(data_dir)

        results = tune(_tiny_grid(), _tiny_config(data_dir, output_dir))

        # Summary structure
        assert results["num_trials"] == 2
        assert results["metric"] == "val_accuracy"
        assert 0 <= results["best_trial"] < 2
        assert results["best_score"] is not None
        assert "best_hyperparameters" in results
        assert len(results["trials"]) == 2

        # Winner copied to the canonical paths downstream tools expect.
        assert (output_dir / "banana_classifier.keras").exists()
        assert (output_dir / "training_history.json").exists()

        # Summary persisted and matches the returned dict.
        saved = json.loads((output_dir / "tuning_results.json").read_text())
        assert saved == results

        # Per-trial artefacts retained by default.
        assert (output_dir / "trials" / "trial_00").exists()

    def test_cleanup_trials_removes_trial_dir(self, tmp_path: Path) -> None:
        data_dir = tmp_path / "data"
        output_dir = tmp_path / "output"
        _create_synthetic_dataset(data_dir)

        tune(
            _tiny_grid(),
            _tiny_config(data_dir, output_dir, cleanup_trials=True),
        )

        assert not (output_dir / "trials").exists()
        # Winning model still present at the canonical path.
        assert (output_dir / "banana_classifier.keras").exists()

    def test_best_hyperparameters_match_a_trial(self, tmp_path: Path) -> None:
        data_dir = tmp_path / "data"
        output_dir = tmp_path / "output"
        _create_synthetic_dataset(data_dir)

        results = tune(_tiny_grid(), _tiny_config(data_dir, output_dir))

        best_idx = results["best_trial"]
        best_trial = next(t for t in results["trials"] if t["trial"] == best_idx)
        assert results["best_hyperparameters"] == best_trial["hyperparameters"]
        assert results["best_score"] == best_trial["score"]


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


class TestCLI:
    """Test the ``main`` CLI entry-point."""

    def test_missing_required_args(self) -> None:
        with pytest.raises(SystemExit):
            main([])

    def test_cli_forwards_grid_and_config(self, tmp_path: Path) -> None:
        captured: list[tuple[HyperparameterGrid, TuningConfig]] = []

        def fake_tune(grid: HyperparameterGrid, config: TuningConfig) -> dict:
            captured.append((grid, config))
            return {
                "metric": config.metric,
                "num_trials": 0,
                "best_trial": 0,
                "best_score": 0.0,
                "best_hyperparameters": {},
                "trials": [],
            }

        with patch("ml.tune.tune", side_effect=fake_tune):
            exit_code = main([
                "--data-dir", str(tmp_path / "data"),
                "--output-dir", str(tmp_path / "out"),
                "--learning-rates", "0.001", "0.0001",
                "--dropout-rates", "0.2",
                "--fine-tune-epochs", "0",
                "--batch-sizes", "8",
                "--epochs", "3",
                "--max-trials", "2",
                "--cleanup-trials",
            ])

        assert exit_code == 0
        assert len(captured) == 1
        grid, config = captured[0]
        assert grid.learning_rates == (0.001, 0.0001)
        assert grid.dropout_rates == (0.2,)
        assert grid.batch_sizes == (8,)
        assert config.epochs == 3
        assert config.max_trials == 2
        assert config.cleanup_trials is True
        assert config.data_dir == tmp_path / "data"
        assert config.output_dir == tmp_path / "out"
