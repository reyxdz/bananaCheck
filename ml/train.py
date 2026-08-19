import argparse
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

from ml.preprocess import require_directory


@dataclass(frozen=True)
class TrainingConfig:
    data_dir: Path
    output_dir: Path
    epochs: int = 10

    def __post_init__(self) -> None:
        if self.epochs <= 0:
            raise ValueError("Training epochs must be positive.")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Train the banana classifier.")
    parser.add_argument("--data-dir", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--epochs", default=10, type=int)
    args = parser.parse_args(argv)

    config = TrainingConfig(args.data_dir, args.output_dir, args.epochs)
    require_directory(config.data_dir)
    print(
        "Training command boundary is ready; "
        "dataset training belongs to the model-development task."
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
