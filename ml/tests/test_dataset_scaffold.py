"""Tests for ml/dataset_scaffold.py — dataset folder scaffolding utility."""

from __future__ import annotations

from pathlib import Path

import pytest

from ml.classes import ALL_CLASSES, NUM_CLASSES
from ml.dataset_scaffold import (
    _VALID_IMAGE_EXTENSIONS,
    create_class_folders,
    dataset_stats,
    verify_structure,
)


# ---------------------------------------------------------------------------
# create_class_folders
# ---------------------------------------------------------------------------


def test_create_class_folders_creates_all_18_folders(tmp_path: Path) -> None:
    folders = create_class_folders(tmp_path)
    assert len(folders) == NUM_CLASSES
    for folder in folders:
        assert folder.is_dir()


def test_create_class_folders_names_match_all_classes(tmp_path: Path) -> None:
    folders = create_class_folders(tmp_path)
    names = {f.name for f in folders}
    expected = {cls.folder_name for cls in ALL_CLASSES}
    assert names == expected


def test_create_class_folders_is_idempotent(tmp_path: Path) -> None:
    """Running twice should not raise or duplicate folders."""
    create_class_folders(tmp_path)
    folders = create_class_folders(tmp_path)
    assert len(folders) == NUM_CLASSES


# ---------------------------------------------------------------------------
# verify_structure
# ---------------------------------------------------------------------------


def test_verify_structure_returns_empty_when_all_present(tmp_path: Path) -> None:
    create_class_folders(tmp_path)
    assert verify_structure(tmp_path) == []


def test_verify_structure_returns_all_missing_on_empty_dir(tmp_path: Path) -> None:
    missing = verify_structure(tmp_path)
    assert len(missing) == NUM_CLASSES


def test_verify_structure_returns_specific_missing_folders(tmp_path: Path) -> None:
    # Create only the first 3 class folders
    for cls in ALL_CLASSES[:3]:
        (tmp_path / cls.folder_name).mkdir()

    missing = verify_structure(tmp_path)
    assert len(missing) == NUM_CLASSES - 3
    # The first 3 should not be in the missing list
    for cls in ALL_CLASSES[:3]:
        assert cls.folder_name not in missing


# ---------------------------------------------------------------------------
# dataset_stats
# ---------------------------------------------------------------------------


def test_dataset_stats_returns_zero_counts_for_empty_folders(tmp_path: Path) -> None:
    create_class_folders(tmp_path)
    stats = dataset_stats(tmp_path)
    assert len(stats) == NUM_CLASSES
    assert all(count == 0 for count in stats.values())


def test_dataset_stats_counts_valid_image_files(tmp_path: Path) -> None:
    create_class_folders(tmp_path)
    first_class = ALL_CLASSES[0]
    folder = tmp_path / first_class.folder_name

    # Create valid image files
    (folder / "img1.jpg").touch()
    (folder / "img2.jpeg").touch()
    (folder / "img3.png").touch()
    # Create an invalid file (should not be counted)
    (folder / "notes.txt").touch()

    stats = dataset_stats(tmp_path)
    assert stats[first_class.folder_name] == 3


def test_dataset_stats_ignores_subdirectories(tmp_path: Path) -> None:
    create_class_folders(tmp_path)
    first_class = ALL_CLASSES[0]
    folder = tmp_path / first_class.folder_name

    (folder / "subdir").mkdir()
    (folder / "img.jpg").touch()

    stats = dataset_stats(tmp_path)
    assert stats[first_class.folder_name] == 1


def test_dataset_stats_returns_zero_for_missing_folder(tmp_path: Path) -> None:
    # Don't create any folders
    stats = dataset_stats(tmp_path)
    assert all(count == 0 for count in stats.values())


# ---------------------------------------------------------------------------
# Valid image extensions
# ---------------------------------------------------------------------------


def test_valid_image_extensions_include_common_formats() -> None:
    assert ".jpg" in _VALID_IMAGE_EXTENSIONS
    assert ".jpeg" in _VALID_IMAGE_EXTENSIONS
    assert ".png" in _VALID_IMAGE_EXTENSIONS


def test_valid_image_extensions_exclude_non_image_formats() -> None:
    assert ".txt" not in _VALID_IMAGE_EXTENSIONS
    assert ".csv" not in _VALID_IMAGE_EXTENSIONS
    assert ".h5" not in _VALID_IMAGE_EXTENSIONS
