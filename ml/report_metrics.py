"""Document model metrics for the paper (B17).

Turns the machine-readable artefacts produced by evaluation (B9,
``evaluation_metrics.json``) and hyperparameter tuning (B10,
``tuning_results.json``) into a single human-readable Markdown report with the
tables the thesis needs: overall accuracy, per-class precision / recall / F1 /
support, macro and weighted averages, and the hyperparameters of the selected
model.

This module only *reads* existing metrics — it never re-runs inference — so it
is cheap and deterministic. The per-class numbers come straight from
:mod:`ml.evaluate`; the macro/weighted averages are computed here from the
per-class entries (``evaluation_metrics.json`` does not store them).

Usage
-----
CLI::

    python -m ml.report_metrics \\
        --metrics ml/output/evaluation_metrics.json \\
        --tuning ml/output/tuning_results.json \\
        --output ml/output/model_metrics_report.md

Programmatic::

    from ml.report_metrics import ReportConfig, generate_report

    generate_report(ReportConfig(
        metrics_path=Path("ml/output/evaluation_metrics.json"),
    ))
"""

from __future__ import annotations

import argparse
import json
from collections.abc import Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from ml.config import MLConfig

_DEFAULT_ML = MLConfig()

#: Image file (produced by ml.evaluate) the report links to for the matrix.
_CONFUSION_MATRIX_IMAGE = "confusion_matrix.png"


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class ReportConfig:
    """Immutable configuration for the metrics report.

    Parameters
    ----------
    metrics_path:
        Path to ``evaluation_metrics.json`` (from :mod:`ml.evaluate`).
    tuning_path:
        Optional path to ``tuning_results.json`` (from :mod:`ml.tune`).  When
        present, the selected hyperparameters are included in the report.
    output_path:
        Destination Markdown file.
    """

    metrics_path: Path = field(
        default_factory=lambda: _DEFAULT_ML.output_dir / "evaluation_metrics.json",
    )
    tuning_path: Path = field(
        default_factory=lambda: _DEFAULT_ML.output_dir / "tuning_results.json",
    )
    output_path: Path = field(
        default_factory=lambda: _DEFAULT_ML.output_dir / "model_metrics_report.md",
    )


# ---------------------------------------------------------------------------
# Averages
# ---------------------------------------------------------------------------


def compute_averages(per_class: Sequence[dict[str, Any]]) -> dict[str, dict[str, float]]:
    """Compute macro and support-weighted averages from per-class metrics.

    Parameters
    ----------
    per_class:
        List of ``{class, precision, recall, f1_score, support}`` dicts.

    Returns
    -------
    dict
        ``{"macro": {...}, "weighted": {...}}`` where each inner dict has
        ``precision``, ``recall``, and ``f1_score`` rounded to 4 dp.  Returns
        zeros when *per_class* is empty.
    """
    metric_keys = ("precision", "recall", "f1_score")
    if not per_class:
        zero = {key: 0.0 for key in metric_keys}
        return {"macro": dict(zero), "weighted": dict(zero)}

    n = len(per_class)
    total_support = sum(entry["support"] for entry in per_class)

    macro: dict[str, float] = {}
    weighted: dict[str, float] = {}
    for key in metric_keys:
        macro[key] = round(sum(entry[key] for entry in per_class) / n, 4)
        if total_support > 0:
            weighted[key] = round(
                sum(entry[key] * entry["support"] for entry in per_class)
                / total_support,
                4,
            )
        else:
            weighted[key] = 0.0

    return {"macro": macro, "weighted": weighted}


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------


def _format_summary(metrics: dict[str, Any], averages: dict[str, dict[str, float]]) -> list[str]:
    per_class = metrics.get("per_class", [])
    return [
        "## Summary",
        "",
        "| Metric | Value |",
        "|---|---|",
        f"| Overall accuracy | {metrics.get('overall_accuracy', 0.0):.4f} |",
        f"| Test samples | {metrics.get('num_samples', 0)} |",
        f"| Classes | {len(per_class)} |",
        f"| Macro avg F1 | {averages['macro']['f1_score']:.4f} |",
        f"| Weighted avg F1 | {averages['weighted']['f1_score']:.4f} |",
        "",
    ]


def _format_per_class(
    per_class: Sequence[dict[str, Any]],
    averages: dict[str, dict[str, float]],
) -> list[str]:
    lines = [
        "## Per-class metrics",
        "",
        "| Class | Precision | Recall | F1-score | Support |",
        "|---|---|---|---|---|",
    ]
    for entry in per_class:
        lines.append(
            f"| {entry['class']} | {entry['precision']:.4f} | "
            f"{entry['recall']:.4f} | {entry['f1_score']:.4f} | "
            f"{entry['support']} |"
        )

    total_support = sum(entry["support"] for entry in per_class)
    macro = averages["macro"]
    weighted = averages["weighted"]
    lines.append(
        f"| **Macro average** | {macro['precision']:.4f} | "
        f"{macro['recall']:.4f} | {macro['f1_score']:.4f} | {total_support} |"
    )
    lines.append(
        f"| **Weighted average** | {weighted['precision']:.4f} | "
        f"{weighted['recall']:.4f} | {weighted['f1_score']:.4f} | "
        f"{total_support} |"
    )
    lines.append("")
    return lines


def _format_tuning(tuning: dict[str, Any]) -> list[str]:
    lines = [
        "## Selected hyperparameters (B10)",
        "",
        "| Hyperparameter | Value |",
        "|---|---|",
    ]
    for name, value in tuning.get("best_hyperparameters", {}).items():
        lines.append(f"| {name} | {value} |")
    lines.append("")
    lines.append(
        f"Selected by **{tuning.get('metric', 'val_accuracy')}** = "
        f"{tuning.get('best_score')} "
        f"(trial {tuning.get('best_trial')} of {tuning.get('num_trials')})."
    )
    lines.append("")
    return lines


def format_report(
    metrics: dict[str, Any],
    tuning: dict[str, Any] | None = None,
) -> str:
    """Render the full Markdown report from *metrics* and optional *tuning*."""
    per_class = metrics.get("per_class", [])
    averages = compute_averages(per_class)

    lines = [
        "# Model Evaluation Metrics",
        "",
        "_Generated for the project paper (B17) from the evaluation (B9) and "
        "tuning (B10) artefacts._",
        "",
    ]
    lines += _format_summary(metrics, averages)
    lines += _format_per_class(per_class, averages)
    if tuning is not None:
        lines += _format_tuning(tuning)

    if metrics.get("confusion_matrix"):
        lines += [
            "## Confusion matrix",
            "",
            f"See `{_CONFUSION_MATRIX_IMAGE}` (generated by `ml.evaluate`).",
            "",
        ]

    return "\n".join(lines).rstrip() + "\n"


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------


def _load_json(path: Path) -> dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def generate_report(config: ReportConfig) -> Path:
    """Read the metrics artefacts and write the Markdown report.

    Parameters
    ----------
    config:
        Report configuration.

    Returns
    -------
    Path
        The resolved path of the written Markdown file.

    Raises
    ------
    FileNotFoundError
        If the evaluation metrics file does not exist.
    """
    metrics_path = Path(config.metrics_path).resolve()
    if not metrics_path.is_file():
        raise FileNotFoundError(f"Evaluation metrics not found: {metrics_path}")

    metrics = _load_json(metrics_path)

    # Tuning results are optional — include them only if present.
    tuning: dict[str, Any] | None = None
    tuning_path = Path(config.tuning_path)
    if tuning_path.is_file():
        tuning = _load_json(tuning_path)

    report = format_report(metrics, tuning)

    output_path = Path(config.output_path).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(report, encoding="utf-8")

    print(f"Metrics report saved to {output_path}")
    print(f"Overall accuracy: {metrics.get('overall_accuracy', 0.0):.4f}")
    if tuning is not None:
        print(f"Included tuning results from {tuning_path}")

    return output_path


# ---------------------------------------------------------------------------
# CLI entry-point
# ---------------------------------------------------------------------------


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entry-point for ``python -m ml.report_metrics``."""
    parser = argparse.ArgumentParser(
        description="Document model metrics for the paper (B17).",
    )
    parser.add_argument(
        "--metrics",
        required=True,
        type=Path,
        help="Path to evaluation_metrics.json (from ml.evaluate).",
    )
    parser.add_argument(
        "--tuning",
        type=Path,
        default=None,
        help="Optional path to tuning_results.json (from ml.tune).",
    )
    parser.add_argument(
        "--output",
        required=True,
        type=Path,
        help="Destination Markdown report file.",
    )

    args = parser.parse_args(argv)

    config = ReportConfig(
        metrics_path=args.metrics,
        tuning_path=args.tuning if args.tuning is not None else Path(args.metrics).parent
        / "tuning_results.json",
        output_path=args.output,
    )

    generate_report(config)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
