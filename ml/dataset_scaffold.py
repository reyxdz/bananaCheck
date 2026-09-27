"""Dataset scaffold utility — creates the folder-per-class directory layout
and optionally verifies that all expected class folders exist and contain
images.

Usage
-----
Create folders::

    python -m ml.dataset_scaffold

Create folders at a custom path::

    python -m ml.dataset_scaffold --data-dir /path/to/data

Verify existing structure::

    python -m ml.dataset_scaffold --verify

Print a summary of image counts per class::

    python -m ml.dataset_scaffold --stats
"""

from __future__ import annotations

import argparse
from collections.abc import Sequence
from pathlib import Path

from ml.classes import ALL_CLASSES, NUM_CLASSES
from ml.config import MLConfig

_VALID_IMAGE_EXTENSIONS: frozenset[str] = frozenset(
    {".jpg", ".jpeg", ".png"}
)

_DEFAULT_DATA_DIR = MLConfig().data_dir


# ---------------------------------------------------------------------------
# Scaffold
# ---------------------------------------------------------------------------


def create_class_folders(data_dir: Path) -> list[Path]:
    """Create one subdirectory per class under *data_dir*.

    Returns the list of created (or already existing) directories.
    """
    created: list[Path] = []
    for banana_class in ALL_CLASSES:
        folder = data_dir / banana_class.folder_name
        folder.mkdir(parents=True, exist_ok=True)
        created.append(folder)
    return created


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------


def verify_structure(data_dir: Path) -> list[str]:
    """Return a list of missing class folder names under *data_dir*.

    An empty list means the structure is valid.
    """
    resolved = data_dir.resolve()
    return [
        cls.folder_name
        for cls in ALL_CLASSES
        if not (resolved / cls.folder_name).is_dir()
    ]


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------


def _count_images(folder: Path) -> int:
    """Count files with valid image extensions in *folder* (non-recursive)."""
    if not folder.is_dir():
        return 0
    return sum(
        1
        for f in folder.iterdir()
        if f.is_file() and f.suffix.lower() in _VALID_IMAGE_EXTENSIONS
    )


def dataset_stats(data_dir: Path) -> dict[str, int]:
    """Return a mapping of class folder name → image count."""
    resolved = data_dir.resolve()
    return {
        cls.folder_name: _count_images(resolved / cls.folder_name)
        for cls in ALL_CLASSES
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Scaffold or verify the dataset directory layout."
    )
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=_DEFAULT_DATA_DIR,
        help=f"Root dataset directory (default: {_DEFAULT_DATA_DIR})",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Verify that all class folders exist; exit non-zero if any are missing.",
    )
    parser.add_argument(
        "--stats",
        action="store_true",
        help="Print image counts per class folder.",
    )
    args = parser.parse_args(argv)

    data_dir: Path = args.data_dir.resolve()

    if args.verify:
        missing = verify_structure(data_dir)
        if missing:
            print(f"Missing {len(missing)} of {NUM_CLASSES} class folders:")
            for name in missing:
                print(f"  {name}")
            return 1
        print(f"All {NUM_CLASSES} class folders present in {data_dir}")
        return 0

    if args.stats:
        stats = dataset_stats(data_dir)
        total = 0
        print(f"{'Class':<25} {'Images':>6}")
        print("-" * 32)
        for name, count in stats.items():
            print(f"{name:<25} {count:>6}")
            total += count
        print("-" * 32)
        print(f"{'Total':<25} {total:>6}")
        empty = sum(1 for c in stats.values() if c == 0)
        if empty:
            print(f"\nWarning: {empty} class(es) have 0 images.")
        return 0

    # Default action: scaffold
    folders = create_class_folders(data_dir)
    print(f"Created/verified {len(folders)} class folders in {data_dir}:")
    for folder in folders:
        print(f"  {folder.name}/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
