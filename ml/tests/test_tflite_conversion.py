from pathlib import Path

import pytest
from _pytest.capture import CaptureFixture

from ml.convert_to_tflite import main, require_model_file, require_tflite_output


def test_require_model_file_rejects_missing_model(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="Model file not found"):
        require_model_file(tmp_path / "model.keras")


def test_require_tflite_output_rejects_wrong_extension(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match=r"\.tflite"):
        require_tflite_output(tmp_path / "model.bin")


def test_conversion_command_reports_boundary(
    tmp_path: Path,
    capsys: CaptureFixture[str],
) -> None:
    model_path = tmp_path / "model.keras"
    model_path.write_bytes(b"model")

    exit_code = main(
        [
            "--model",
            str(model_path),
            "--output",
            str(tmp_path / "model.tflite"),
        ]
    )

    assert exit_code == 2
    assert "Conversion command boundary is ready" in capsys.readouterr().out
