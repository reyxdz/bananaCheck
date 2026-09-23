"""Dataset labeling and organization utilities — validates, audits, and
reports on the folder-per-class image dataset.

Complements :mod:`ml.dataset_scaffold` (which creates the directory layout)
by checking that images inside each class folder are valid, detecting
duplicates, analysing class balance, and flagging stray files.

Usage
-----
Full report::

    python -m ml.dataset_organizer --report

Validate images::

    python -m ml.dataset_organizer --validate

Find duplicates::

    python -m ml.dataset_organizer --duplicates

Class balance analysis::

    python -m ml.dataset_organizer --balance

Detect stray files::

    python -m ml.dataset_organizer --clean --dry-run
"""

from __future__ import annotations

import argparse
import hashlib
from collections.abc import Sequence
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image

from ml.classes import ALL_CLASSES, NUM_CLASSES
from ml.config import MLConfig
from ml.dataset_scaffold import _VALID_IMAGE_EXTENSIONS

_DEFAULT_DATA_DIR = MLConfig().data_dir
_MIN_IMAGES_PER_CLASS = 100


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class ImageValidationResult:
    """Result of validating a single image file."""

    path: Path
    is_valid: bool
    width: int = 0
    height: int = 0
    format: str = ""
    file_size: int = 0
    error: str = ""


@dataclass(frozen=True)
class DuplicateGroup:
    """A group of files that share the same content hash."""

    hash: str
    paths: tuple[Path, ...]


@dataclass(frozen=True)
class StrayFile:
    """A file that does not belong in the dataset directory."""

    path: Path
    reason: str


@dataclass(frozen=True)
class ClassBalanceReport:
    """Summary statistics for class balance across the dataset."""

    counts: dict[str, int]
    total: int
    min_count: int
    max_count: int
    mean_count: float
    below_minimum: list[str]
    empty_classes: list[str]


@dataclass
class DatasetReport:
    """Comprehensive dataset quality report."""

    data_dir: Path
    total_images: int = 0
    class_counts: dict[str, int] = field(default_factory=dict)
    invalid_images: list[ImageValidationResult] = field(default_factory=list)
    duplicate_groups: list[DuplicateGroup] = field(default_factory=list)
    stray_files: list[StrayFile] = field(default_factory=list)
    balance: ClassBalanceReport | None = None


# ---------------------------------------------------------------------------
# Image validation
# ---------------------------------------------------------------------------


def validate_image(path: Path) -> ImageValidationResult:
    """Open *path* with Pillow and verify it is a readable image.

    Returns an :class:`ImageValidationResult` with metadata on success, or
    with ``is_valid=False`` and an error description on failure.
    """
    resolved = path.resolve()
    if not resolved.is_file():
        return ImageValidationResult(
            path=resolved, is_valid=False, error="File does not exist"
        )

    file_size = resolved.stat().st_size
    if file_size == 0:
        return ImageValidationResult(
            path=resolved,
            is_valid=False,
            file_size=0,
            error="File is empty (0 bytes)",
        )

    try:
        with Image.open(resolved) as img:
            img.verify()
        # Re-open after verify (Pillow docs recommend this)
        with Image.open(resolved) as img:
            width, height = img.size
            fmt = img.format or ""
    except Exception as exc:  # noqa: BLE001
        return ImageValidationResult(
            path=resolved,
            is_valid=False,
            file_size=file_size,
            error=str(exc),
        )

    return ImageValidationResult(
        path=resolved,
        is_valid=True,
        width=width,
        height=height,
        format=fmt,
        file_size=file_size,
    )


# ---------------------------------------------------------------------------
# Duplicate detection
# ---------------------------------------------------------------------------

_HASH_CHUNK_SIZE = 8192


def _file_hash(path: Path) -> str:
    """Return the SHA-256 hex digest of *path*."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(_HASH_CHUNK_SIZE):
            h.update(chunk)
    return h.hexdigest()


def find_duplicates(data_dir: Path) -> list[DuplicateGroup]:
    """Detect exact-content duplicate images across all class folders.

    Returns a list of :class:`DuplicateGroup` objects, each containing the
    shared hash and a tuple of paths with identical content.  Groups with
    only a single file are excluded.
    """
    resolved = data_dir.resolve()
    hash_to_paths: dict[str, list[Path]] = {}

    for cls in ALL_CLASSES:
        folder = resolved / cls.folder_name
        if not folder.is_dir():
            continue
        for f in folder.iterdir():
            if f.is_file() and f.suffix.lower() in _VALID_IMAGE_EXTENSIONS:
                digest = _file_hash(f)
                hash_to_paths.setdefault(digest, []).append(f)

    return [
        DuplicateGroup(hash=h, paths=tuple(paths))
        for h, paths in hash_to_paths.items()
        if len(paths) > 1
    ]


# ---------------------------------------------------------------------------
# Class balance analysis
# ---------------------------------------------------------------------------


def _count_images_in_folder(folder: Path) -> int:
    """Count valid image files in *folder* (non-recursive)."""
    if not folder.is_dir():
        return 0
    return sum(
        1
        for f in folder.iterdir()
        if f.is_file() and f.suffix.lower() in _VALID_IMAGE_EXTENSIONS
    )


def compute_class_balance(data_dir: Path) -> ClassBalanceReport:
    """Analyse per-class image counts and return a balance report."""
    resolved = data_dir.resolve()
    counts: dict[str, int] = {}
    for cls in ALL_CLASSES:
        counts[cls.folder_name] = _count_images_in_folder(
            resolved / cls.folder_name
        )

    total = sum(counts.values())
    count_values = list(counts.values())
    min_count = min(count_values) if count_values else 0
    max_count = max(count_values) if count_values else 0
    mean_count = total / NUM_CLASSES if NUM_CLASSES else 0.0

    below_minimum = [
        name
        for name, c in counts.items()
        if 0 < c < _MIN_IMAGES_PER_CLASS
    ]
    empty_classes = [name for name, c in counts.items() if c == 0]

    return ClassBalanceReport(
        counts=counts,
        total=total,
        min_count=min_count,
        max_count=max_count,
        mean_count=mean_count,
        below_minimum=below_minimum,
        empty_classes=empty_classes,
    )


# ---------------------------------------------------------------------------
# Stray file detection
# ---------------------------------------------------------------------------


def find_stray_files(data_dir: Path) -> list[StrayFile]:
    """Detect files that do not belong in the dataset directory.

    Stray files include:
    - Non-image files inside class folders (excluding ``README.md``)
    - Files in the data root that are not ``README.md``
    - Hidden files (dot-prefixed) anywhere in the data tree
    """
    resolved = data_dir.resolve()
    strays: list[StrayFile] = []

    # Check data root for unexpected files
    for item in resolved.iterdir():
        if item.is_file() and item.name != "README.md":
            strays.append(
                StrayFile(path=item, reason="Unexpected file in data root")
            )

    # Check inside class folders
    for cls in ALL_CLASSES:
        folder = resolved / cls.folder_name
        if not folder.is_dir():
            continue
        for item in folder.iterdir():
            if item.name.startswith("."):
                strays.append(
                    StrayFile(path=item, reason="Hidden file")
                )
            elif (
                item.is_file()
                and item.suffix.lower() not in _VALID_IMAGE_EXTENSIONS
            ):
                strays.append(
                    StrayFile(
                        path=item,
                        reason=f"Non-image file ({item.suffix})",
                    )
                )

    return strays


# ---------------------------------------------------------------------------
# Full report
# ---------------------------------------------------------------------------


def generate_report(data_dir: Path) -> DatasetReport:
    """Run all quality checks and return a comprehensive dataset report."""
    resolved = data_dir.resolve()
    report = DatasetReport(data_dir=resolved)

    # Class balance
    report.balance = compute_class_balance(resolved)
    report.class_counts = report.balance.counts
    report.total_images = report.balance.total

    # Image validation (check every image)
    for cls in ALL_CLASSES:
        folder = resolved / cls.folder_name
        if not folder.is_dir():
            continue
        for f in sorted(folder.iterdir()):
            if f.is_file() and f.suffix.lower() in _VALID_IMAGE_EXTENSIONS:
                result = validate_image(f)
                if not result.is_valid:
                    report.invalid_images.append(result)

    # Duplicates
    report.duplicate_groups = find_duplicates(resolved)

    # Stray files
    report.stray_files = find_stray_files(resolved)

    return report


# ---------------------------------------------------------------------------
# Report formatting
# ---------------------------------------------------------------------------


def _format_report(report: DatasetReport) -> str:
    """Format a :class:`DatasetReport` as human-readable text."""
    lines: list[str] = []
    lines.append("=" * 60)
    lines.append("DATASET QUALITY REPORT")
    lines.append(f"Directory: {report.data_dir}")
    lines.append("=" * 60)

    # Class counts
    lines.append("")
    lines.append(f"{'Class':<25} {'Images':>6}")
    lines.append("-" * 32)
    for name, count in report.class_counts.items():
        marker = ""
        if count == 0:
            marker = " ← EMPTY"
        elif count < _MIN_IMAGES_PER_CLASS:
            marker = f" ← below minimum ({_MIN_IMAGES_PER_CLASS})"
        lines.append(f"{name:<25} {count:>6}{marker}")
    lines.append("-" * 32)
    lines.append(f"{'Total':<25} {report.total_images:>6}")

    # Balance summary
    if report.balance:
        bal = report.balance
        lines.append("")
        lines.append("CLASS BALANCE")
        lines.append(f"  Min: {bal.min_count}  Max: {bal.max_count}  "
                      f"Mean: {bal.mean_count:.1f}")
        if bal.max_count > 0:
            ratio = bal.min_count / bal.max_count
            lines.append(f"  Imbalance ratio (min/max): {ratio:.2f}")
        if bal.empty_classes:
            lines.append(
                f"  Empty classes ({len(bal.empty_classes)}): "
                + ", ".join(bal.empty_classes)
            )
        if bal.below_minimum:
            lines.append(
                f"  Below {_MIN_IMAGES_PER_CLASS} images "
                f"({len(bal.below_minimum)}): "
                + ", ".join(bal.below_minimum)
            )

    # Invalid images
    lines.append("")
    if report.invalid_images:
        lines.append(f"INVALID IMAGES ({len(report.invalid_images)})")
        for inv in report.invalid_images:
            lines.append(f"  {inv.path}: {inv.error}")
    else:
        lines.append("INVALID IMAGES: None found ✓")

    # Duplicates
    lines.append("")
    if report.duplicate_groups:
        total_dups = sum(
            len(g.paths) - 1 for g in report.duplicate_groups
        )
        lines.append(
            f"DUPLICATES ({len(report.duplicate_groups)} groups, "
            f"{total_dups} extra files)"
        )
        for group in report.duplicate_groups:
            lines.append(f"  Hash: {group.hash[:12]}...")
            for p in group.paths:
                lines.append(f"    {p}")
    else:
        lines.append("DUPLICATES: None found ✓")

    # Stray files
    lines.append("")
    if report.stray_files:
        lines.append(f"STRAY FILES ({len(report.stray_files)})")
        for stray in report.stray_files:
            lines.append(f"  {stray.path}: {stray.reason}")
    else:
        lines.append("STRAY FILES: None found ✓")

    lines.append("")
    lines.append("=" * 60)
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate, audit, and report on the dataset layout."
    )
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=_DEFAULT_DATA_DIR,
        help=f"Root dataset directory (default: {_DEFAULT_DATA_DIR})",
    )

    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "--validate",
        action="store_true",
        help="Validate all images for corruption/readability.",
    )
    group.add_argument(
        "--duplicates",
        action="store_true",
        help="Find duplicate images across class folders.",
    )
    group.add_argument(
        "--balance",
        action="store_true",
        help="Show class balance analysis.",
    )
    group.add_argument(
        "--clean",
        action="store_true",
        help="Detect stray (non-image) files.",
    )
    group.add_argument(
        "--report",
        action="store_true",
        help="Generate a full dataset quality report.",
    )

    args = parser.parse_args(argv)
    data_dir: Path = args.data_dir.resolve()

    if args.validate:
        return _cmd_validate(data_dir)
    if args.duplicates:
        return _cmd_duplicates(data_dir)
    if args.balance:
        return _cmd_balance(data_dir)
    if args.clean:
        return _cmd_clean(data_dir)

    # Default / --report
    return _cmd_report(data_dir)


def _cmd_validate(data_dir: Path) -> int:
    """Check every image for readability."""
    invalid: list[ImageValidationResult] = []
    checked = 0
    for cls in ALL_CLASSES:
        folder = data_dir / cls.folder_name
        if not folder.is_dir():
            continue
        for f in sorted(folder.iterdir()):
            if f.is_file() and f.suffix.lower() in _VALID_IMAGE_EXTENSIONS:
                checked += 1
                result = validate_image(f)
                if not result.is_valid:
                    invalid.append(result)
                    print(f"  INVALID: {result.path} — {result.error}")

    if invalid:
        print(f"\n{len(invalid)} of {checked} images are invalid.")
        return 1
    print(f"All {checked} images passed validation ✓")
    return 0


def _cmd_duplicates(data_dir: Path) -> int:
    """Find and display duplicate images."""
    groups = find_duplicates(data_dir)
    if not groups:
        print("No duplicate images found ✓")
        return 0

    total_extras = sum(len(g.paths) - 1 for g in groups)
    print(f"Found {len(groups)} duplicate group(s) "
          f"({total_extras} extra file(s)):\n")
    for group in groups:
        print(f"  Hash: {group.hash[:12]}...")
        for p in group.paths:
            print(f"    {p}")
        print()
    return 1


def _cmd_balance(data_dir: Path) -> int:
    """Show class balance statistics."""
    bal = compute_class_balance(data_dir)
    print(f"{'Class':<25} {'Images':>6}")
    print("-" * 32)
    for name, count in bal.counts.items():
        print(f"{name:<25} {count:>6}")
    print("-" * 32)
    print(f"{'Total':<25} {bal.total:>6}")
    print()
    print(f"Min: {bal.min_count}  Max: {bal.max_count}  "
          f"Mean: {bal.mean_count:.1f}")
    if bal.max_count > 0:
        print(f"Imbalance ratio (min/max): "
              f"{bal.min_count / bal.max_count:.2f}")
    if bal.empty_classes:
        print(f"\nEmpty classes: {', '.join(bal.empty_classes)}")
    if bal.below_minimum:
        print(f"Below {_MIN_IMAGES_PER_CLASS}: "
              f"{', '.join(bal.below_minimum)}")

    has_issues = bool(bal.empty_classes or bal.below_minimum)
    return 1 if has_issues else 0


def _cmd_clean(data_dir: Path) -> int:
    """Detect stray files (dry-run only — never deletes automatically)."""
    strays = find_stray_files(data_dir)
    if not strays:
        print("No stray files found ✓")
        return 0

    print(f"Found {len(strays)} stray file(s):\n")
    for stray in strays:
        print(f"  {stray.path}")
        print(f"    Reason: {stray.reason}")
    print("\nRemove these files manually after review.")
    return 1


def _cmd_report(data_dir: Path) -> int:
    """Generate and print the full dataset quality report."""
    report = generate_report(data_dir)
    print(_format_report(report))

    has_issues = bool(
        report.invalid_images
        or report.duplicate_groups
        or report.stray_files
        or (report.balance and report.balance.empty_classes)
    )
    return 1 if has_issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
