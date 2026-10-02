"""Tests for ml.report_metrics — paper metrics document (B17)."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from ml.report_metrics import (
    ReportConfig,
    compute_averages,
    format_report,
    generate_report,
    main,
)

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _metrics() -> dict:
    return {
        "overall_accuracy": 0.75,
        "num_samples": 4,
        "per_class": [
            {
                "class": "Saba_Ripe",
                "precision": 1.0,
                "recall": 0.5,
                "f1_score": 0.6667,
                "support": 2,
            },
            {
                "class": "Lakatan_Unripe",
                "precision": 0.5,
                "recall": 1.0,
                "f1_score": 0.6667,
                "support": 2,
            },
        ],
        "confusion_matrix": [[1, 1], [0, 2]],
    }


def _tuning() -> dict:
    return {
        "metric": "val_accuracy",
        "num_trials": 4,
        "best_trial": 2,
        "best_score": 0.9,
        "best_hyperparameters": {"learning_rate": 0.001, "dropout_rate": 0.2},
        "trials": [],
    }


# ---------------------------------------------------------------------------
# compute_averages
# ---------------------------------------------------------------------------


class TestComputeAverages:
    def test_macro_and_weighted_equal_with_balanced_support(self) -> None:
        # Equal support → macro == weighted.
        averages = compute_averages(_metrics()["per_class"])
        assert averages["macro"]["precision"] == 0.75
        assert averages["weighted"]["precision"] == 0.75

    def test_weighted_reflects_support(self) -> None:
        per_class = [
            {"class": "A", "precision": 1.0, "recall": 1.0, "f1_score": 1.0, "support": 9},
            {"class": "B", "precision": 0.0, "recall": 0.0, "f1_score": 0.0, "support": 1},
        ]
        averages = compute_averages(per_class)
        assert averages["macro"]["precision"] == 0.5
        assert averages["weighted"]["precision"] == 0.9  # 9/10

    def test_empty_per_class_returns_zeros(self) -> None:
        averages = compute_averages([])
        assert averages["macro"]["f1_score"] == 0.0
        assert averages["weighted"]["f1_score"] == 0.0

    def test_zero_support_does_not_divide_by_zero(self) -> None:
        per_class = [
            {"class": "A", "precision": 0.0, "recall": 0.0, "f1_score": 0.0, "support": 0},
        ]
        averages = compute_averages(per_class)
        assert averages["weighted"]["precision"] == 0.0


# ---------------------------------------------------------------------------
# format_report
# ---------------------------------------------------------------------------


class TestFormatReport:
    def test_includes_accuracy_and_per_class_rows(self) -> None:
        report = format_report(_metrics())
        assert "Overall accuracy" in report
        assert "0.7500" in report
        assert "Saba_Ripe" in report
        assert "Lakatan_Unripe" in report

    def test_includes_average_rows(self) -> None:
        report = format_report(_metrics())
        assert "Macro average" in report
        assert "Weighted average" in report

    def test_includes_tuning_section_when_provided(self) -> None:
        report = format_report(_metrics(), _tuning())
        assert "Selected hyperparameters" in report
        assert "learning_rate" in report
        assert "val_accuracy" in report

    def test_omits_tuning_section_when_absent(self) -> None:
        report = format_report(_metrics())
        assert "Selected hyperparameters" not in report

    def test_references_confusion_matrix_image(self) -> None:
        report = format_report(_metrics())
        assert "confusion_matrix.png" in report

    def test_omits_confusion_section_when_absent(self) -> None:
        metrics = _metrics()
        del metrics["confusion_matrix"]
        report = format_report(metrics)
        assert "Confusion matrix" not in report

    def test_ends_with_single_newline(self) -> None:
        report = format_report(_metrics())
        assert report.endswith("\n")
        assert not report.endswith("\n\n")


# ---------------------------------------------------------------------------
# generate_report
# ---------------------------------------------------------------------------


class TestGenerateReport:
    def test_writes_markdown_file(self, tmp_path: Path) -> None:
        metrics_path = tmp_path / "evaluation_metrics.json"
        metrics_path.write_text(json.dumps(_metrics()), encoding="utf-8")
        output_path = tmp_path / "report.md"

        result = generate_report(
            ReportConfig(metrics_path=metrics_path, output_path=output_path)
        )

        assert result == output_path.resolve()
        assert output_path.exists()
        assert "Overall accuracy" in output_path.read_text(encoding="utf-8")

    def test_includes_tuning_when_file_present(self, tmp_path: Path) -> None:
        (tmp_path / "evaluation_metrics.json").write_text(
            json.dumps(_metrics()), encoding="utf-8"
        )
        (tmp_path / "tuning_results.json").write_text(
            json.dumps(_tuning()), encoding="utf-8"
        )
        output_path = tmp_path / "report.md"

        generate_report(
            ReportConfig(
                metrics_path=tmp_path / "evaluation_metrics.json",
                tuning_path=tmp_path / "tuning_results.json",
                output_path=output_path,
            )
        )

        assert "Selected hyperparameters" in output_path.read_text(encoding="utf-8")

    def test_skips_tuning_when_file_absent(self, tmp_path: Path) -> None:
        (tmp_path / "evaluation_metrics.json").write_text(
            json.dumps(_metrics()), encoding="utf-8"
        )
        output_path = tmp_path / "report.md"

        generate_report(
            ReportConfig(
                metrics_path=tmp_path / "evaluation_metrics.json",
                tuning_path=tmp_path / "missing.json",
                output_path=output_path,
            )
        )

        assert "Selected hyperparameters" not in output_path.read_text(
            encoding="utf-8"
        )

    def test_creates_missing_output_dir(self, tmp_path: Path) -> None:
        (tmp_path / "evaluation_metrics.json").write_text(
            json.dumps(_metrics()), encoding="utf-8"
        )
        output_path = tmp_path / "nested" / "deep" / "report.md"

        generate_report(
            ReportConfig(
                metrics_path=tmp_path / "evaluation_metrics.json",
                output_path=output_path,
            )
        )

        assert output_path.exists()

    def test_raises_on_missing_metrics(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError, match="Evaluation metrics not found"):
            generate_report(
                ReportConfig(
                    metrics_path=tmp_path / "nope.json",
                    output_path=tmp_path / "report.md",
                )
            )


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


class TestCLI:
    def test_missing_required_args(self) -> None:
        with pytest.raises(SystemExit):
            main([])

    def test_full_run_via_cli(self, tmp_path: Path) -> None:
        metrics_path = tmp_path / "evaluation_metrics.json"
        metrics_path.write_text(json.dumps(_metrics()), encoding="utf-8")
        output_path = tmp_path / "report.md"

        exit_code = main([
            "--metrics", str(metrics_path),
            "--output", str(output_path),
        ])

        assert exit_code == 0
        assert output_path.exists()

    def test_cli_includes_explicit_tuning(self, tmp_path: Path) -> None:
        metrics_path = tmp_path / "evaluation_metrics.json"
        metrics_path.write_text(json.dumps(_metrics()), encoding="utf-8")
        tuning_path = tmp_path / "tuning_results.json"
        tuning_path.write_text(json.dumps(_tuning()), encoding="utf-8")
        output_path = tmp_path / "report.md"

        main([
            "--metrics", str(metrics_path),
            "--tuning", str(tuning_path),
            "--output", str(output_path),
        ])

        assert "Selected hyperparameters" in output_path.read_text(
            encoding="utf-8"
        )
