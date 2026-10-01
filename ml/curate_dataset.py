"""Non-destructive dataset cleaning + balancing to a fixed per-class target.

Complements :mod:`ml.dataset_organizer` (which only *reports*) by actually
curating ``ml/data`` so every class folder ends up with exactly
``target_per_class`` images — keeping the **clearest** images and never
deleting anything.

What it does, per class:

1. **Clean** — move unreadable/corrupt images and exact-content duplicates out
   of the class folder.
2. **Keep the sharpest** — rank the remaining valid, unique images by sharpness
   (variance of the Laplacian) and keep the top ``target_per_class``; move the
   surplus out.
3. **Top up a deficit** — if a class has fewer than the target, synthesise the
   shortfall from clearly-marked (``aug_`` prefix) augmented copies of its
   sharpest images.

Nothing is destroyed. Removed images are **moved** into a quarantine tree at
``data_dir/_quarantine/<reason>/<class>/`` (ignored by git and invisible to the
training pipeline, which only reads the 18 named class folders). Augmented
files are additive and carry the ``aug_`` prefix, so the whole operation is
reversible.

Usage
-----
Preview without changing anything::

    python -m ml.curate_dataset --dry-run

Apply::

    python -m ml.curate_dataset --target 200
"""

from __future__ import annotations

import argparse
import shutil
from collections.abc import Sequence
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance

from ml.classes import ALL_CLASSES
from ml.config import MLConfig
from ml.dataset_organizer import _file_hash, validate_image
from ml.dataset_scaffold import _VALID_IMAGE_EXTENSIONS

_DEFAULT_DATA_DIR = MLConfig().data_dir
_DEFAULT_TARGET = 200
_QUARANTINE_DIRNAME = "_quarantine"
_AUGMENTED_PREFIX = "aug_"

#: Side length images are scaled to before scoring sharpness (speed vs. signal).
_SHARPNESS_SIZE = 128


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class CurationConfig:
    """Immutable configuration for the curation pass.

    Parameters
    ----------
    data_dir:
        Root of the folder-per-class dataset.
    target_per_class:
        Desired number of images in every class folder.
    augment_deficit:
        When ``True``, top up classes below the target with augmented copies.
        When ``False``, such classes are left as-is (short of target).
    dry_run:
        When ``True``, compute and report the plan without moving/creating
        any files.
    """

    data_dir: Path = field(default_factory=lambda: _DEFAULT_DATA_DIR)
    target_per_class: int = _DEFAULT_TARGET
    augment_deficit: bool = True
    dry_run: bool = False

    def __post_init__(self) -> None:
        if self.target_per_class <= 0:
            raise ValueError("target_per_class must be a positive integer.")

    @property
    def quarantine_dir(self) -> Path:
        """Directory (inside the gitignored data root) that holds removed files."""
        return self.data_dir / _QUARANTINE_DIRNAME


# ---------------------------------------------------------------------------
# Result types
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class ClassPlan:
    """Planned curation actions for a single class."""

    class_name: str
    keep: tuple[Path, ...]
    invalid: tuple[Path, ...]
    duplicates: tuple[Path, ...]
    surplus: tuple[Path, ...]
    deficit: int

    @property
    def quarantined_count(self) -> int:
        return len(self.invalid) + len(self.duplicates) + len(self.surplus)


@dataclass(frozen=True)
class ClassOutcome:
    """What actually happened (or would happen) for a single class."""

    class_name: str
    kept: int
    quarantined: int
    augmented: int
    final_count: int


# ---------------------------------------------------------------------------
# Sharpness scoring
# ---------------------------------------------------------------------------


def sharpness_score(path: Path) -> float:
    """Return the variance of the Laplacian for the image at *path*.

    Higher means sharper (more high-frequency detail); blurry or flat images
    score low. The image is converted to grayscale and downscaled first so the
    score is comparable across differing resolutions and fast to compute.

    Returns ``0.0`` if the image cannot be read.
    """
    try:
        with Image.open(path) as img:
            gray = img.convert("L").resize(
                (_SHARPNESS_SIZE, _SHARPNESS_SIZE)
            )
            array = np.asarray(gray, dtype=np.float64)
    except Exception:  # noqa: BLE001 — unreadable image scores lowest.
        return 0.0

    # 4-neighbour Laplacian via rolls; drop the wrapped border before variance.
    laplacian = (
        -4.0 * array
        + np.roll(array, 1, axis=0)
        + np.roll(array, -1, axis=0)
        + np.roll(array, 1, axis=1)
        + np.roll(array, -1, axis=1)
    )
    return float(laplacian[1:-1, 1:-1].var())


# ---------------------------------------------------------------------------
# Planning
# ---------------------------------------------------------------------------


def _image_files(folder: Path) -> list[Path]:
    """Return image files directly inside *folder* (non-recursive), sorted."""
    if not folder.is_dir():
        return []
    return sorted(
        f
        for f in folder.iterdir()
        if f.is_file() and f.suffix.lower() in _VALID_IMAGE_EXTENSIONS
    )


def plan_class(folder: Path, class_name: str, target: int) -> ClassPlan:
    """Decide which images to keep, quarantine, and how many to synthesise.

    Selection order:

    1. drop unreadable images,
    2. drop exact-content duplicates (keeping the sharpest of each group),
    3. rank the survivors by sharpness and keep the top *target*; the rest are
       surplus.
    """
    invalid: list[Path] = []
    unique: list[Path] = []
    seen_hashes: dict[str, Path] = {}
    duplicates: list[Path] = []

    # Score survivors so duplicate groups keep their sharpest member.
    scores: dict[Path, float] = {}

    for path in _image_files(folder):
        if not validate_image(path).is_valid:
            invalid.append(path)
            continue
        digest = _file_hash(path)
        score = sharpness_score(path)
        scores[path] = score
        existing = seen_hashes.get(digest)
        if existing is None:
            seen_hashes[digest] = path
            unique.append(path)
        elif score > scores[existing]:
            # New copy is sharper — demote the previous keeper to a duplicate.
            duplicates.append(existing)
            unique[unique.index(existing)] = path
            seen_hashes[digest] = path
        else:
            duplicates.append(path)

    # Rank unique images sharpest-first; keep the top `target`.
    unique.sort(key=lambda p: scores[p], reverse=True)
    keep = unique[:target]
    surplus = unique[target:]
    deficit = max(0, target - len(keep))

    return ClassPlan(
        class_name=class_name,
        keep=tuple(keep),
        invalid=tuple(invalid),
        duplicates=tuple(duplicates),
        surplus=tuple(surplus),
        deficit=deficit,
    )


# ---------------------------------------------------------------------------
# Applying a plan
# ---------------------------------------------------------------------------


def _quarantine(path: Path, quarantine_dir: Path, reason: str, class_name: str) -> None:
    """Move *path* into ``quarantine_dir/reason/class_name`` without clobbering."""
    dest_dir = quarantine_dir / reason / class_name
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / path.name
    counter = 1
    while dest.exists():
        dest = dest_dir / f"{path.stem}_{counter}{path.suffix}"
        counter += 1
    shutil.move(str(path), str(dest))


def _augment_once(source: Path, dest: Path, variant: int) -> None:
    """Write an augmented copy of *source* to *dest*.

    Applies a small, label-preserving transform chosen from *variant* so that
    repeated top-ups of the same source still differ.
    """
    with Image.open(source) as img:
        out = img.convert("RGB")
        choice = variant % 4
        if choice == 0:
            out = out.transpose(Image.FLIP_LEFT_RIGHT)
        elif choice == 1:
            out = ImageEnhance.Brightness(out).enhance(1.15)
        elif choice == 2:
            out = ImageEnhance.Brightness(out).enhance(0.85)
        else:
            out = out.rotate(8, expand=False)
        out.save(dest)


def augment_to_target(
    folder: Path,
    sources: Sequence[Path],
    deficit: int,
) -> list[Path]:
    """Create *deficit* augmented images in *folder* from *sources*.

    Cycles through the sharpest *sources* applying rotating transforms. Returns
    the paths created. Files are named ``aug_NNNN`` so they are obvious and
    removable. Does nothing (returns ``[]``) if *deficit* ≤ 0 or no sources.
    """
    if deficit <= 0 or not sources:
        return []

    created: list[Path] = []
    for i in range(deficit):
        source = sources[i % len(sources)]
        dest = folder / f"{_AUGMENTED_PREFIX}{i:04d}{source.suffix.lower()}"
        counter = 1
        while dest.exists():
            dest = folder / f"{_AUGMENTED_PREFIX}{i:04d}_{counter}{source.suffix.lower()}"
            counter += 1
        _augment_once(source, dest, i)
        created.append(dest)

    return created


def apply_plan(plan: ClassPlan, config: CurationConfig) -> ClassOutcome:
    """Execute *plan* for one class and return the resulting counts.

    Honours ``config.dry_run`` (reports counts without touching the filesystem)
    and ``config.augment_deficit``.
    """
    folder = config.data_dir / plan.class_name
    augmented = 0

    if not config.dry_run:
        for path in plan.invalid:
            _quarantine(path, config.quarantine_dir, "invalid", plan.class_name)
        for path in plan.duplicates:
            _quarantine(path, config.quarantine_dir, "duplicate", plan.class_name)
        for path in plan.surplus:
            _quarantine(path, config.quarantine_dir, "surplus", plan.class_name)

    if config.augment_deficit and plan.deficit > 0:
        if config.dry_run:
            augmented = plan.deficit
        else:
            augmented = len(
                augment_to_target(folder, plan.keep, plan.deficit)
            )

    final_count = len(plan.keep) + augmented
    return ClassOutcome(
        class_name=plan.class_name,
        kept=len(plan.keep),
        quarantined=plan.quarantined_count,
        augmented=augmented,
        final_count=final_count,
    )


def curate(config: CurationConfig) -> list[ClassOutcome]:
    """Run the full clean + balance pass across all classes."""
    outcomes: list[ClassOutcome] = []
    for cls in ALL_CLASSES:
        folder = config.data_dir / cls.folder_name
        plan = plan_class(folder, cls.folder_name, config.target_per_class)
        outcomes.append(apply_plan(plan, config))
    return outcomes


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _format_outcomes(outcomes: Sequence[ClassOutcome], *, dry_run: bool) -> str:
    header = "PLANNED (dry run)" if dry_run else "DONE"
    lines = [
        f"DATASET CURATION — {header}",
        "-" * 60,
        f"{'Class':<22}{'kept':>6}{'quar.':>7}{'aug':>6}{'final':>7}",
        "-" * 60,
    ]
    for o in outcomes:
        lines.append(
            f"{o.class_name:<22}{o.kept:>6}{o.quarantined:>7}"
            f"{o.augmented:>6}{o.final_count:>7}"
        )
    lines.append("-" * 60)
    off_target = [o.class_name for o in outcomes if o.final_count != _DEFAULT_TARGET]
    totals = sum(o.final_count for o in outcomes)
    lines.append(f"{'Total images':<22}{totals:>26}")
    if off_target:
        lines.append(f"Not at target: {', '.join(off_target)}")
    return "\n".join(lines)


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entry-point for ``python -m ml.curate_dataset``."""
    parser = argparse.ArgumentParser(
        description="Clean and balance the dataset to a fixed per-class target "
        "(non-destructive — removed files are quarantined, not deleted).",
    )
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=_DEFAULT_DATA_DIR,
        help=f"Root dataset directory (default: {_DEFAULT_DATA_DIR}).",
    )
    parser.add_argument(
        "--target",
        type=int,
        default=_DEFAULT_TARGET,
        help=f"Target images per class (default: {_DEFAULT_TARGET}).",
    )
    parser.add_argument(
        "--no-augment",
        dest="augment",
        action="store_false",
        help="Do not top up under-target classes with augmented images.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report the plan without moving or creating any files.",
    )

    args = parser.parse_args(argv)

    config = CurationConfig(
        data_dir=args.data_dir,
        target_per_class=args.target,
        augment_deficit=args.augment,
        dry_run=args.dry_run,
    )

    outcomes = curate(config)
    print(_format_outcomes(outcomes, dry_run=config.dry_run))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
