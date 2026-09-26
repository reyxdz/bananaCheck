"""Train / validation / test split for the banana-classifier dataset.

Splits a folder-per-class dataset into three non-overlapping subsets while
preserving the class distribution (stratified split).  This is feature **B7**
in the project plan and sits between the preprocessing pipeline (B6) and
baseline model training (B8).

Two output modes are supported:

1. **Path-based** — returns ``SplitResult`` containing lists of
   ``(path, class_index)`` tuples.  Nothing is written to disk; downstream
   code reads images from the original dataset directory.
2. **Directory-based** — physically copies (or symlinks) images into
   ``train/``, ``val/``, ``test/`` subdirectories under an output root,
   ready for ``tf.keras.utils.image_dataset_from_directory``.

Default ratios are **70 / 15 / 15** (train / val / test).

Usage
-----
Path-based (in-memory)::

    from ml.split import split_dataset, SplitConfig

    result = split_dataset(Path("ml/data"))
    print(len(result.train), len(result.val), len(result.test))

Directory-based (on-disk)::

    from ml.split import split_dataset_to_dirs, SplitConfig

    split_dataset_to_dirs(
        data_dir=Path("ml/data"),
        output_dir=Path("ml/data_split"),
    )
"""

from __future__ import annotations

import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import NamedTuple

from sklearn.model_selection import train_test_split

from ml.classes import ALL_CLASSES, BananaClass
from ml.preprocess import VALID_IMAGE_EXTENSIONS, require_directory, validate_dataset_structure

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

_DEFAULT_TRAIN_RATIO = 0.70
_DEFAULT_VAL_RATIO = 0.15
_DEFAULT_TEST_RATIO = 0.15
_DEFAULT_SEED = 42


@dataclass(frozen=True)
class SplitConfig:
    """Configuration for dataset splitting.

    Parameters
    ----------
    train_ratio:
        Fraction of data allocated to the training set.
    val_ratio:
        Fraction of data allocated to the validation set.
    test_ratio:
        Fraction of data allocated to the test set.
    seed:
        Random seed for reproducibility.
    """

    train_ratio: float = _DEFAULT_TRAIN_RATIO
    val_ratio: float = _DEFAULT_VAL_RATIO
    test_ratio: float = _DEFAULT_TEST_RATIO
    seed: int = _DEFAULT_SEED

    def __post_init__(self) -> None:
        for name, value in [
            ("train_ratio", self.train_ratio),
            ("val_ratio", self.val_ratio),
            ("test_ratio", self.test_ratio),
        ]:
            if not 0.0 < value < 1.0:
                raise ValueError(
                    f"{name} must be in (0, 1), got {value}."
                )

        total = self.train_ratio + self.val_ratio + self.test_ratio
        if abs(total - 1.0) > 1e-9:
            raise ValueError(
                f"Ratios must sum to 1.0, got {total:.6f} "
                f"({self.train_ratio} + {self.val_ratio} + {self.test_ratio})."
            )


# ---------------------------------------------------------------------------
# Split result
# ---------------------------------------------------------------------------


class SplitResult(NamedTuple):
    """Three non-overlapping subsets of ``(image_path, class_index)`` pairs."""

    train: list[tuple[Path, int]]
    val: list[tuple[Path, int]]
    test: list[tuple[Path, int]]


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _collect_image_paths(data_dir: Path) -> tuple[list[Path], list[int]]:
    """Walk the dataset directory and return parallel lists of paths and labels.

    Parameters
    ----------
    data_dir:
        Root dataset directory (already validated).

    Returns
    -------
    (paths, labels):
        ``paths[i]`` is an image file, ``labels[i]`` its class index.
    """
    paths: list[Path] = []
    labels: list[int] = []

    for class_index, banana_class in enumerate(ALL_CLASSES):
        class_dir = data_dir / banana_class.folder_name
        for img_path in sorted(class_dir.iterdir()):
            if (
                img_path.is_file()
                and img_path.suffix.lower() in VALID_IMAGE_EXTENSIONS
            ):
                paths.append(img_path)
                labels.append(class_index)

    return paths, labels


def _min_class_count(labels: list[int]) -> int:
    """Return the count of the rarest class in *labels*."""
    from collections import Counter

    counts = Counter(labels)
    return min(counts.values()) if counts else 0


# ---------------------------------------------------------------------------
# Public API — path-based split
# ---------------------------------------------------------------------------


def split_dataset(
    data_dir: Path,
    *,
    config: SplitConfig | None = None,
) -> SplitResult:
    """Split a folder-per-class dataset into train / val / test subsets.

    The split is **stratified** — every class is represented in each subset
    in roughly the same proportions as the original dataset.

    Parameters
    ----------
    data_dir:
        Root dataset directory containing one subfolder per class.
    config:
        Split configuration.  ``None`` uses 70/15/15 with seed 42.

    Returns
    -------
    SplitResult
        Named tuple with ``.train``, ``.val``, and ``.test`` lists of
        ``(Path, class_index)`` pairs.

    Raises
    ------
    FileNotFoundError
        If *data_dir* does not exist or is missing class subdirectories.
    ValueError
        If any class has fewer than 3 images (minimum needed for a
        three-way stratified split with at least 1 image per subset).
    """
    cfg = config or SplitConfig()
    resolved = require_directory(data_dir)
    validate_dataset_structure(resolved)

    paths, labels = _collect_image_paths(resolved)

    if len(paths) == 0:
        return SplitResult(train=[], val=[], test=[])

    min_count = _min_class_count(labels)
    if min_count < 3:
        raise ValueError(
            f"Every class must have at least 3 images for a three-way "
            f"stratified split, but the smallest class has only {min_count}."
        )

    # First split: separate test set from the rest.
    # test_ratio relative to the whole dataset.
    paths_trainval, paths_test, labels_trainval, labels_test = train_test_split(
        paths,
        labels,
        test_size=cfg.test_ratio,
        random_state=cfg.seed,
        stratify=labels,
    )

    # Second split: separate validation set from the train+val remainder.
    # val_ratio relative to (train + val) fraction.
    val_relative = cfg.val_ratio / (cfg.train_ratio + cfg.val_ratio)
    paths_train, paths_val, labels_train, labels_val = train_test_split(
        paths_trainval,
        labels_trainval,
        test_size=val_relative,
        random_state=cfg.seed,
        stratify=labels_trainval,
    )

    def _zip_pairs(
        ps: list[Path], ls: list[int]
    ) -> list[tuple[Path, int]]:
        return list(zip(ps, ls, strict=True))

    return SplitResult(
        train=_zip_pairs(paths_train, labels_train),
        val=_zip_pairs(paths_val, labels_val),
        test=_zip_pairs(paths_test, labels_test),
    )


# ---------------------------------------------------------------------------
# Public API — directory-based split (copies files)
# ---------------------------------------------------------------------------


def split_dataset_to_dirs(
    data_dir: Path,
    output_dir: Path,
    *,
    config: SplitConfig | None = None,
    use_symlinks: bool = False,
) -> SplitResult:
    """Split the dataset and write each subset into its own directory tree.

    Creates the following layout under *output_dir*::

        output_dir/
          train/
            Cavendish_Unripe/
            Cavendish_Ripe/
            ...
          val/
            Cavendish_Unripe/
            ...
          test/
            Cavendish_Unripe/
            ...

    Parameters
    ----------
    data_dir:
        Source dataset root with folder-per-class layout.
    output_dir:
        Destination root.  Will be created if it does not exist.
        **Must not already contain ``train/``, ``val/``, or ``test/``
        subdirectories** to prevent accidental data mixing.
    config:
        Split configuration.
    use_symlinks:
        If ``True``, create symbolic links instead of copying files.
        Saves disk space but requires the source to stay in place.

    Returns
    -------
    SplitResult
        The same path/label pairs that were written.

    Raises
    ------
    FileExistsError
        If *output_dir* already contains ``train/``, ``val/``, or ``test/``.
    """
    output = Path(output_dir).resolve()
    for subset in ("train", "val", "test"):
        subset_dir = output / subset
        if subset_dir.exists():
            raise FileExistsError(
                f"Output directory already contains '{subset}/': {subset_dir}. "
                f"Remove it first to avoid mixing data from different splits."
            )

    result = split_dataset(data_dir, config=config)

    link_fn = shutil.copy2
    if use_symlinks:
        def link_fn(src: Path, dst: Path) -> None:  # type: ignore[misc]
            dst.symlink_to(src.resolve())

    for subset_name, pairs in [
        ("train", result.train),
        ("val", result.val),
        ("test", result.test),
    ]:
        for img_path, class_index in pairs:
            banana_class: BananaClass = ALL_CLASSES[class_index]
            dest_dir = output / subset_name / banana_class.folder_name
            dest_dir.mkdir(parents=True, exist_ok=True)
            link_fn(img_path, dest_dir / img_path.name)

    return result


# ---------------------------------------------------------------------------
# CLI entry-point
# ---------------------------------------------------------------------------


def _build_parser() -> __import__("argparse").ArgumentParser:
    """Build the argument parser for ``python -m ml.split``."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Split the banana-classifier dataset into train/val/test.",
    )
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=Path(__file__).resolve().parent / "data",
        help="Root dataset directory (default: ml/data).",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parent / "data_split",
        help="Output directory for the split (default: ml/data_split).",
    )
    parser.add_argument(
        "--train-ratio",
        type=float,
        default=_DEFAULT_TRAIN_RATIO,
        help=f"Training fraction (default: {_DEFAULT_TRAIN_RATIO}).",
    )
    parser.add_argument(
        "--val-ratio",
        type=float,
        default=_DEFAULT_VAL_RATIO,
        help=f"Validation fraction (default: {_DEFAULT_VAL_RATIO}).",
    )
    parser.add_argument(
        "--test-ratio",
        type=float,
        default=_DEFAULT_TEST_RATIO,
        help=f"Test fraction (default: {_DEFAULT_TEST_RATIO}).",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=_DEFAULT_SEED,
        help=f"Random seed (default: {_DEFAULT_SEED}).",
    )
    parser.add_argument(
        "--symlinks",
        action="store_true",
        help="Use symbolic links instead of copying files.",
    )
    return parser


def main() -> None:
    """CLI entry-point for ``python -m ml.split``."""
    parser = _build_parser()
    args = parser.parse_args()

    cfg = SplitConfig(
        train_ratio=args.train_ratio,
        val_ratio=args.val_ratio,
        test_ratio=args.test_ratio,
        seed=args.seed,
    )

    result = split_dataset_to_dirs(
        data_dir=args.data_dir,
        output_dir=args.output_dir,
        config=cfg,
        use_symlinks=args.symlinks,
    )

    print(f"Split complete → {args.output_dir}")
    print(f"  train: {len(result.train):>5} images")
    print(f"  val:   {len(result.val):>5} images")
    print(f"  test:  {len(result.test):>5} images")
    print(f"  total: {len(result.train) + len(result.val) + len(result.test):>5} images")


if __name__ == "__main__":
    main()
