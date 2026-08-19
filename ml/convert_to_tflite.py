import argparse
from collections.abc import Sequence
from pathlib import Path


def require_model_file(path: Path) -> Path:
    resolved = path.resolve()
    if not resolved.is_file():
        raise FileNotFoundError(f"Model file not found: {resolved}")
    return resolved


def require_tflite_output(path: Path) -> Path:
    resolved = path.resolve()
    if resolved.suffix.lower() != ".tflite":
        raise ValueError("TFLite output path must end with .tflite")
    return resolved


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Convert a Keras model to TFLite.")
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)

    require_model_file(args.model)
    require_tflite_output(args.output)
    print(
        "Conversion command boundary is ready; "
        "conversion belongs to the model-development task."
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
