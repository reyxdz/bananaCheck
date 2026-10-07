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

import random
import re
import shutil
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import NamedTuple

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



# ---------------------------------------------------------------------------
# Augmentation grouping
# ---------------------------------------------------------------------------
#
# The dataset contains augmented variants alongside their source photo
# (``Cavendish_Ripe_Bottom_0001_Aug_1693.jpg``, ``nb_000_aug0.jpg``).  Splitting
# per file lets variants of one photo land in both train and test, which leaks
# the test set: the model is scored on images it effectively memorised, and
# reported accuracy comes out far higher than real-world performance.
#
# Every split below therefore moves whole *groups* — a source photo and all of
# its augmentations travel together.

_AUG_SUFFIX = re.compile(r"_(?:aug_?\d*|orig)$", re.IGNORECASE)


def source_group(path: Path) -> str:
    """Return the source-photo key *path* belongs to.

    Augmented variants and their original collapse to one key, so a grouped
    split can keep them on the same side.

    >>> source_group(Path("Cavendish_Ripe_Bottom_0001_Aug_1693.jpg"))
    'Cavendish_Ripe_Bottom_0001'
    >>> source_group(Path("nb_000_aug0.jpg")) == source_group(Path("nb_000_orig.jpg"))
    True
    """
    return _AUG_SUFFIX.sub("", path.stem)


def _split_groups(
    items: list[tuple[Path, int]],
    cfg: SplitConfig,
) -> tuple[list[tuple[Path, int]], list[tuple[Path, int]], list[tuple[Path, int]]]:
    """Split *items* three ways without ever separating a source group.

    Groups are split within each class, so the result stays stratified by
    class while remaining leak-free across splits.
    """
    by_class: dict[int, dict[str, list[tuple[Path, int]]]] = defaultdict(
        lambda: defaultdict(list)
    )
    for path, label in items:
        by_class[label][source_group(path)].append((path, label))

    train: list[tuple[Path, int]] = []
    val: list[tuple[Path, int]] = []
    test: list[tuple[Path, int]] = []

    for label in sorted(by_class):
        groups = sorted(by_class[label])
        # Seed per class so adding one class cannot reshuffle the others.
        random.Random(f"{cfg.seed}:{label}").shuffle(groups)

        n = len(groups)
        n_test = max(1, round(n * cfg.test_ratio))
        n_val = max(1, round(n * cfg.val_ratio))
        if n_test + n_val >= n:  # tiny class — keep at least one group to train on
            n_test = n_val = 1

        for bucket, chunk in (
            (test, groups[:n_test]),
            (val, groups[n_test : n_test + n_val]),
            (train, groups[n_test + n_val :]),
        ):
            for group in chunk:
                bucket.extend(by_class[label][group])

    return train, val, test


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

    min_groups = min(
        len(
            {
                source_group(path)
                for path, lbl in zip(paths, labels, strict=True)
                if lbl == label
            }
        )
        for label in set(labels)
    )
    if min_groups < 3:
        raise ValueError(
            f"Every class must have at least 3 distinct source photos (not just "
            f"augmented copies) for a leak-free three-way split, but the "
            f"smallest class has only {min_groups}."
        )

    train_pairs, val_pairs, test_pairs = _split_groups(
        list(zip(paths, labels, strict=True)), cfg
    )

    return SplitResult(train=train_pairs, val=val_pairs, test=test_pairs)


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
