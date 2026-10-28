"""Print the model's accuracy figures from the saved run artefacts.

Reads the JSON artefacts already written by training (``training_history.json``),
evaluation (B9, ``evaluation_metrics.json``) and TFLite validation
(``tflite_validation.json``) and prints a short accuracy summary.

Like :mod:`ml.report_metrics`, this module only *reads* existing artefacts — it
never loads the model or runs inference — so it needs no TensorFlow, model
file, or dataset.  Missing optional artefacts are skipped.

Usage
-----
CLI::

    python -m ml.show_accuracy
    python -m ml.show_accuracy --output-dir ml/output
"""

from __future__ import annotations

import argparse
import json
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from ml.config import MLConfig
from ml.report_metrics import compute_averages

_DEFAULT_ML = MLConfig()


def _load_json(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def _pct(value: float) -> str:
    return f"{value * 100:.2f}%"


def format_summary(output_dir: Path) -> str:
    """Build the accuracy summary text from the artefacts in *output_dir*.

    Raises
    ------
    FileNotFoundError
        If ``evaluation_metrics.json`` does not exist.
    """
    metrics_path = output_dir / "evaluation_metrics.json"
    metrics = _load_json(metrics_path)
    if metrics is None:
        raise FileNotFoundError(f"Evaluation metrics not found: {metrics_path}")

    per_class = metrics.get("per_class", [])
    averages = compute_averages(per_class)
    cm = metrics.get("confusion_matrix", [])
    correct = sum(cm[i][i] for i in range(len(cm)))
    total = metrics.get("num_samples", 0)

    lines = [
        "Banana classifier accuracy",
        "==========================",
        f"Test accuracy:      {_pct(metrics.get('overall_accuracy', 0.0))}"
        f"  ({correct} / {total} test images correct)",
        f"Classes:            {len(per_class)}",
        f"Macro avg F1:       {averages['macro']['f1_score']:.4f}",
        f"Weighted avg F1:    {averages['weighted']['f1_score']:.4f}",
    ]

    tflite = _load_json(output_dir / "tflite_validation.json")
    if tflite is not None:
        lines.append(
            f"TFLite (app) model: {_pct(tflite['tflite_accuracy'])}"
            f"  (Keras {_pct(tflite['keras_accuracy'])},"
            f" agreement {_pct(tflite['agreement'])})"
        )

    history = _load_json(output_dir / "training_history.json")
    if history is not None and history.get("val_accuracy"):
        val = history["val_accuracy"]
        best = max(range(len(val)), key=val.__getitem__)
        lines.append(
            f"Validation:         {_pct(val[-1])} final,"
            f" {_pct(val[best])} best (epoch {best + 1} of {len(val)})"
        )
    if history is not None and history.get("accuracy"):
        lines.append(f"Training:           {_pct(history['accuracy'][-1])} final")

    lines += ["", "Per-class F1 (lowest first):"]
    for entry in sorted(per_class, key=lambda e: e["f1_score"]):
        lines.append(
            f"  {entry['class']:<20} F1 {entry['f1_score']:.4f}"
            f"  (precision {entry['precision']:.4f},"
            f" recall {entry['recall']:.4f}, n={entry['support']})"
        )

    return "\n".join(lines) + "\n"


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entry-point for ``python -m ml.show_accuracy``."""
    parser = argparse.ArgumentParser(
        description="Print the model's accuracy from the saved evaluation artefacts.",
    )
    parser.add_argument(
        "--output-dir",
        default=_DEFAULT_ML.output_dir,
        type=Path,
        help="Directory holding the evaluation artefacts (default: ml/output).",
    )
    args = parser.parse_args(argv)

    print(format_summary(Path(args.output_dir).resolve()), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
