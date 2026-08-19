from pathlib import Path

import pytest
from _pytest.capture import CaptureFixture

from ml.train import TrainingConfig, main


def test_training_config_keeps_dataset_and_output_boundaries(tmp_path: Path) -> None:
    config = TrainingConfig(
        data_dir=tmp_path / "data",
        output_dir=tmp_path / "models",
        epochs=10,
    )

    assert config.epochs == 10
    assert config.output_dir.name == "models"


def test_training_config_rejects_non_positive_epochs(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="positive"):
        TrainingConfig(
            data_dir=tmp_path / "data",
            output_dir=tmp_path / "models",
            epochs=0,
        )


def test_training_command_reports_boundary(
    tmp_path: Path,
    capsys: CaptureFixture[str],
) -> None:
    exit_code = main(
        [
            "--data-dir",
            str(tmp_path),
            "--output-dir",
            str(tmp_path / "models"),
        ]
    )

    assert exit_code == 2
    assert "Training command boundary is ready" in capsys.readouterr().out
