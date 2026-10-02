"""Hyperparameter tuning / retraining iterations (B10).

Runs a grid search over the tunable knobs of the baseline training pipeline
(:mod:`ml.train`) and keeps the model that scores best on the **validation**
split.  The test split is deliberately untouched here — it stays held out for
the final, unbiased evaluation in :mod:`ml.evaluate` (B9).

For every combination in the search grid this module:

1. Builds a fresh MobileNetV2 model with that combination's ``dropout_rate``.
2. Trains it via :func:`ml.train.train` into a per-trial subdirectory.
3. Scores the trial by the last-epoch validation accuracy from the returned
   training history.

After all trials complete, the winning trial's artefacts are copied to the
canonical locations that downstream tasks expect
(``output_dir/banana_classifier.keras`` and ``output_dir/training_history.json``,
matching :mod:`ml.train`), so B11 (TFLite conversion) and B9 (evaluation) find
the tuned model exactly where they look for the baseline one.

Generated artefacts (saved to ``output_dir``):

- ``banana_classifier.keras`` — the best trial's saved model (canonical path).
- ``training_history.json`` — the best trial's training history.
- ``tuning_results.json`` — every trial's hyperparameters and score, plus the
  selected winner (feeds the tuning decisions in B10 and the paper in B17).
- ``trials/trial_NN/`` — each trial's own model + history (kept for inspection
  unless ``cleanup_trials`` is set).

Usage
-----
CLI::

    python -m ml.tune \\
        --data-dir ml/data_split \\
        --output-dir ml/output \\
        --learning-rates 1e-3 1e-4 \\
        --dropout-rates 0.2 0.3 \\
        --fine-tune-epochs 0 5

Programmatic::

    from ml.tune import HyperparameterGrid, TuningConfig, tune

    grid = HyperparameterGrid(
        learning_rates=(1e-3, 1e-4),
        dropout_rates=(0.2, 0.3),
        fine_tune_epochs=(0, 5),
    )
    config = TuningConfig(data_dir=Path("ml/data_split"))
    results = tune(grid, config)
"""

from __future__ import annotations

import argparse
import itertools
import json
import shutil
from collections.abc import Iterator, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from ml.config import MLConfig
from ml.train import TrainingConfig, build_model, train

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

_DEFAULT_ML = MLConfig()

#: Metric key (from the Keras training history) used to rank trials.
_DEFAULT_METRIC = "val_accuracy"


@dataclass(frozen=True)
class HyperparameterGrid:
    """Search grid — the tunable knobs of :class:`ml.train.TrainingConfig`.

    Each field is a tuple of candidate values.  :func:`tune` explores the full
    Cartesian product, so the number of trials is the product of every tuple's
    length.  Keep the grid small — each trial trains a model from scratch.

    Parameters
    ----------
    learning_rates:
        Candidate feature-extraction learning rates.
    dropout_rates:
        Candidate dropout rates before the classification head.
    fine_tune_epochs:
        Candidate fine-tuning epoch counts (``0`` disables fine-tuning).
    fine_tune_layers:
        Candidate counts of top MobileNetV2 layers to unfreeze.  Only takes
        effect for trials whose ``fine_tune_epochs > 0``.
    batch_sizes:
        Candidate mini-batch sizes.
    """

    learning_rates: tuple[float, ...] = (1e-3, 1e-4)
    dropout_rates: tuple[float, ...] = (0.2, 0.3)
    fine_tune_epochs: tuple[int, ...] = (0, 5)
    fine_tune_layers: tuple[int, ...] = (20,)
    batch_sizes: tuple[int, ...] = (32,)

    def __post_init__(self) -> None:
        for name in (
            "learning_rates",
            "dropout_rates",
            "fine_tune_epochs",
            "fine_tune_layers",
            "batch_sizes",
        ):
            if len(getattr(self, name)) == 0:
                raise ValueError(f"{name} must contain at least one value.")

    @property
    def num_combinations(self) -> int:
        """Total number of hyperparameter combinations in the grid."""
        return (
            len(self.learning_rates)
            * len(self.dropout_rates)
            * len(self.fine_tune_epochs)
            * len(self.fine_tune_layers)
            * len(self.batch_sizes)
        )


@dataclass(frozen=True)
class TuningConfig:
    """Immutable configuration shared across all trials.

    Fixed (non-tuned) settings live here; the tuned knobs come from a
    :class:`HyperparameterGrid`.

    Parameters
    ----------
    data_dir:
        Root of the split dataset (must contain ``train/`` and ``val/``).
    output_dir:
        Directory where tuning artefacts and the winning model are saved.
    image_width, image_height:
        Input image dimensions (must match preprocessing / MobileNetV2).
    epochs:
        Feature-extraction epochs used for every trial.
    fine_tune_learning_rate:
        Learning rate for the fine-tuning phase (shared by all trials).
    metric:
        History key used to rank trials (default: ``"val_accuracy"``).
    max_trials:
        Optional cap on the number of trials.  ``None`` runs the full grid;
        otherwise only the first ``max_trials`` combinations are evaluated.
    cleanup_trials:
        When ``True``, the per-trial ``trials/`` directory is removed after the
        winner is copied to the canonical output paths.
    """

    data_dir: Path = field(default_factory=lambda: _DEFAULT_ML.data_dir)
    output_dir: Path = field(default_factory=lambda: _DEFAULT_ML.output_dir)
    image_width: int = _DEFAULT_ML.image_width
    image_height: int = _DEFAULT_ML.image_height
    epochs: int = _DEFAULT_ML.epochs
    fine_tune_learning_rate: float = 1e-4
    metric: str = _DEFAULT_METRIC
    max_trials: int | None = None
    cleanup_trials: bool = False

    def __post_init__(self) -> None:
        if self.image_width <= 0 or self.image_height <= 0:
            raise ValueError("Image dimensions must be positive integers.")
        if self.epochs <= 0:
            raise ValueError("Training epochs must be positive.")
        if self.fine_tune_learning_rate <= 0:
            raise ValueError("Fine-tune learning rate must be positive.")
        if not self.metric:
            raise ValueError("Metric must be a non-empty history key.")
        if self.max_trials is not None and self.max_trials <= 0:
            raise ValueError("max_trials must be a positive integer or None.")


# ---------------------------------------------------------------------------
# Grid expansion
# ---------------------------------------------------------------------------


def iter_trial_configs(
    grid: HyperparameterGrid,
    config: TuningConfig,
    *,
    trials_dir: Path,
) -> Iterator[TrainingConfig]:
    """Yield one :class:`ml.train.TrainingConfig` per grid combination.

    The Cartesian product is walked in a stable order so runs are reproducible.
    Each yielded config writes into its own ``trials_dir/trial_NN`` directory.

    Parameters
    ----------
    grid:
        Hyperparameter search grid.
    config:
        Shared (fixed) tuning configuration.
    trials_dir:
        Parent directory under which per-trial output directories are placed.

    Yields
    ------
    ml.train.TrainingConfig
        A fully-specified training configuration for one trial.
    """
    combinations = itertools.product(
        grid.learning_rates,
        grid.dropout_rates,
        grid.fine_tune_epochs,
        grid.fine_tune_layers,
        grid.batch_sizes,
    )

    for index, (lr, dropout, ft_epochs, ft_layers, batch) in enumerate(combinations):
        if config.max_trials is not None and index >= config.max_trials:
            return
        yield TrainingConfig(
            data_dir=config.data_dir,
            output_dir=trials_dir / f"trial_{index:02d}",
            image_width=config.image_width,
            image_height=config.image_height,
            batch_size=batch,
            epochs=config.epochs,
            fine_tune_epochs=ft_epochs,
            fine_tune_layers=ft_layers,
            learning_rate=lr,
            fine_tune_learning_rate=config.fine_tune_learning_rate,
            dropout_rate=dropout,
        )


def _trial_hyperparameters(trial_config: TrainingConfig) -> dict[str, Any]:
    """Extract the tuned knobs from a trial config as a JSON-serialisable dict."""
    return {
        "learning_rate": trial_config.learning_rate,
        "dropout_rate": trial_config.dropout_rate,
        "fine_tune_epochs": trial_config.fine_tune_epochs,
        "fine_tune_layers": trial_config.fine_tune_layers,
        "batch_size": trial_config.batch_size,
        "epochs": trial_config.epochs,
    }


# ---------------------------------------------------------------------------
# Scoring and selection
# ---------------------------------------------------------------------------


def score_history(history: dict[str, Any], metric: str) -> float | None:
    """Return the last-epoch value of *metric* from a training *history*.

    Parameters
    ----------
    history:
        The serialised history dict returned by :func:`ml.train.train`.
    metric:
        History key to read (e.g. ``"val_accuracy"``).

    Returns
    -------
    float | None
        The final recorded value, or ``None`` if the metric is absent or empty.
    """
    values = history.get(metric)
    if not values:
        return None
    return float(values[-1])


def select_best_trial(trials: Sequence[dict[str, Any]]) -> dict[str, Any]:
    """Return the trial with the highest score.

    Parameters
    ----------
    trials:
        Trial summary dicts, each carrying a numeric ``"score"`` (trials whose
        score is ``None`` are ignored).

    Returns
    -------
    dict
        The winning trial summary.

    Raises
    ------
    ValueError
        If *trials* is empty or no trial produced a usable score.
    """
    scored = [t for t in trials if t.get("score") is not None]
    if not scored:
        raise ValueError("No trial produced a usable score to select from.")
    return max(scored, key=lambda t: t["score"])


# ---------------------------------------------------------------------------
# Tuning orchestration
# ---------------------------------------------------------------------------


def run_trial(trial_config: TrainingConfig, metric: str) -> dict[str, Any]:
    """Train one model for *trial_config* and return its trial summary.

    Parameters
    ----------
    trial_config:
        Fully-specified training configuration for this trial.
    metric:
        History key used to score the trial.

    Returns
    -------
    dict
        Summary with ``hyperparameters``, ``score``, ``metric``, and the saved
        ``model_path`` (as a string).
    """
    model = build_model(
        image_width=trial_config.image_width,
        image_height=trial_config.image_height,
        dropout_rate=trial_config.dropout_rate,
    )
    history = train(model, trial_config)

    model_path = Path(trial_config.output_dir).resolve() / "banana_classifier.keras"
    return {
        "hyperparameters": _trial_hyperparameters(trial_config),
        "score": score_history(history, metric),
        "metric": metric,
        "model_path": str(model_path),
    }


def tune(grid: HyperparameterGrid, config: TuningConfig) -> dict[str, Any]:
    """Run the full grid search and persist the winning model + a summary.

    Parameters
    ----------
    grid:
        Hyperparameter search grid.
    config:
        Shared tuning configuration.

    Returns
    -------
    dict
        Summary containing ``metric``, ``num_trials``, ``best_trial`` (index),
        ``best_score``, ``best_hyperparameters``, and the full ``trials`` list.

    Raises
    ------
    ValueError
        If no trial produced a usable score.
    """
    output_dir = Path(config.output_dir).resolve()
    trials_dir = output_dir / "trials"
    trials_dir.mkdir(parents=True, exist_ok=True)

    trials: list[dict[str, Any]] = []
    for index, trial_config in enumerate(
        iter_trial_configs(grid, config, trials_dir=trials_dir)
    ):
        print(
            f"\n=== Trial {index} — {_trial_hyperparameters(trial_config)} ==="
        )
        summary = run_trial(trial_config, config.metric)
        summary["trial"] = index
        trials.append(summary)
        print(f"Trial {index} {config.metric}: {summary['score']}")

    best = select_best_trial(trials)

    # Copy the winner to the canonical paths ml.train / ml.evaluate expect.
    best_model_src = Path(best["model_path"])
    best_history_src = best_model_src.parent / "training_history.json"
    shutil.copy2(best_model_src, output_dir / "banana_classifier.keras")
    if best_history_src.exists():
        shutil.copy2(best_history_src, output_dir / "training_history.json")

    results = {
        "metric": config.metric,
        "num_trials": len(trials),
        "best_trial": best["trial"],
        "best_score": best["score"],
        "best_hyperparameters": best["hyperparameters"],
        "trials": trials,
    }

    results_path = output_dir / "tuning_results.json"
    results_path.write_text(
        json.dumps(results, indent=2) + "\n",
        encoding="utf-8",
    )

    if config.cleanup_trials:
        shutil.rmtree(trials_dir, ignore_errors=True)

    print(f"\nTuning complete — {len(trials)} trial(s).")
    print(f"Best trial: {best['trial']} ({config.metric}={best['score']})")
    print(f"Best hyperparameters: {best['hyperparameters']}")
    print(f"Winning model copied to {output_dir / 'banana_classifier.keras'}")
    print(f"Tuning summary saved to {results_path}")

    return results


# ---------------------------------------------------------------------------
# CLI entry-point
# ---------------------------------------------------------------------------


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entry-point for ``python -m ml.tune``."""
    parser = argparse.ArgumentParser(
        description="Grid-search hyperparameters for the banana classifier (B10).",
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
        help="Directory to save tuning artefacts and the winning model.",
    )
    parser.add_argument(
        "--learning-rates",
        nargs="+",
        default=[1e-3, 1e-4],
        type=float,
        help="Candidate feature-extraction learning rates (default: 1e-3 1e-4).",
    )
    parser.add_argument(
        "--dropout-rates",
        nargs="+",
        default=[0.2, 0.3],
        type=float,
        help="Candidate dropout rates (default: 0.2 0.3).",
    )
    parser.add_argument(
        "--fine-tune-epochs",
        nargs="+",
        default=[0, 5],
        type=int,
        help="Candidate fine-tuning epoch counts (default: 0 5).",
    )
    parser.add_argument(
        "--fine-tune-layers",
        nargs="+",
        default=[20],
        type=int,
        help="Candidate counts of top layers to unfreeze (default: 20).",
    )
    parser.add_argument(
        "--batch-sizes",
        nargs="+",
        default=[32],
        type=int,
        help="Candidate mini-batch sizes (default: 32).",
    )
    parser.add_argument(
        "--epochs",
        default=10,
        type=int,
        help="Feature-extraction epochs per trial (default: 10).",
    )
    parser.add_argument(
        "--fine-tune-lr",
        default=1e-4,
        type=float,
        help="Learning rate for the fine-tuning phase (default: 1e-4).",
    )
    parser.add_argument(
        "--metric",
        default=_DEFAULT_METRIC,
        help="History key used to rank trials (default: val_accuracy).",
    )
    parser.add_argument(
        "--max-trials",
        default=None,
        type=int,
        help="Cap on the number of trials (default: run the full grid).",
    )
    parser.add_argument(
        "--cleanup-trials",
        action="store_true",
        help="Remove per-trial artefacts after selecting the winner.",
    )

    args = parser.parse_args(argv)

    grid = HyperparameterGrid(
        learning_rates=tuple(args.learning_rates),
        dropout_rates=tuple(args.dropout_rates),
        fine_tune_epochs=tuple(args.fine_tune_epochs),
        fine_tune_layers=tuple(args.fine_tune_layers),
        batch_sizes=tuple(args.batch_sizes),
    )
    config = TuningConfig(
        data_dir=args.data_dir,
        output_dir=args.output_dir,
        epochs=args.epochs,
        fine_tune_learning_rate=args.fine_tune_lr,
        metric=args.metric,
        max_trials=args.max_trials,
        cleanup_trials=args.cleanup_trials,
    )

    tune(grid, config)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
