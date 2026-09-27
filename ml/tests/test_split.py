"""Tests for ml/split.py — train/validation/test dataset splitting."""

from __future__ import annotations

from pathlib import Path

import pytest
from PIL import Image

from ml.classes import ALL_CLASSES, NUM_CLASSES
from ml.split import (
    SplitConfig,
    SplitResult,
    _collect_image_paths,
    _min_class_count,
    split_dataset,
    split_dataset_to_dirs,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _create_test_image(
    path: Path, *, width: int = 50, height: int = 50, color: str = "red"
) -> Path:
    """Create a minimal test image at *path*."""
    img = Image.new("RGB", (width, height), color=color)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    return path


def _scaffold_dataset(tmp_path: Path, *, images_per_class: int = 0) -> Path:
    """Create the 18-class folder structure with optional images."""
    for cls in ALL_CLASSES:
        folder = tmp_path / cls.folder_name
        folder.mkdir(parents=True, exist_ok=True)
        for i in range(images_per_class):
            _create_test_image(folder / f"img_{i:03d}.jpg")
    return tmp_path


# ---------------------------------------------------------------------------
# SplitConfig
# ---------------------------------------------------------------------------


class TestSplitConfig:
    def test_default_ratios(self) -> None:
        cfg = SplitConfig()
        assert cfg.train_ratio == pytest.approx(0.70)
        assert cfg.val_ratio == pytest.approx(0.15)
        assert cfg.test_ratio == pytest.approx(0.15)
        assert cfg.seed == 42

    def test_custom_ratios(self) -> None:
        cfg = SplitConfig(train_ratio=0.8, val_ratio=0.1, test_ratio=0.1)
        assert cfg.train_ratio == pytest.approx(0.8)
        assert cfg.val_ratio == pytest.approx(0.1)
        assert cfg.test_ratio == pytest.approx(0.1)

    def test_ratios_must_sum_to_one(self) -> None:
        with pytest.raises(ValueError, match="sum to 1.0"):
            SplitConfig(train_ratio=0.5, val_ratio=0.2, test_ratio=0.2)

    def test_ratio_out_of_range_zero(self) -> None:
        with pytest.raises(ValueError, match="must be in"):
            SplitConfig(train_ratio=0.0, val_ratio=0.5, test_ratio=0.5)

    def test_ratio_out_of_range_one(self) -> None:
        with pytest.raises(ValueError, match="must be in"):
            SplitConfig(train_ratio=1.0, val_ratio=0.0, test_ratio=0.0)

    def test_negative_ratio(self) -> None:
        with pytest.raises(ValueError, match="must be in"):
            SplitConfig(train_ratio=-0.1, val_ratio=0.6, test_ratio=0.5)


# ---------------------------------------------------------------------------
# _collect_image_paths
# ---------------------------------------------------------------------------


class TestCollectImagePaths:
    def test_empty_dataset(self, tmp_path: Path) -> None:
        root = _scaffold_dataset(tmp_path, images_per_class=0)
        paths, labels = _collect_image_paths(root)
        assert paths == []
        assert labels == []

    def test_collects_images(self, tmp_path: Path) -> None:
        root = _scaffold_dataset(tmp_path, images_per_class=3)
        paths, labels = _collect_image_paths(root)
        assert len(paths) == NUM_CLASSES * 3
        assert len(labels) == NUM_CLASSES * 3
        # Labels should cover all classes
        assert set(labels) == set(range(NUM_CLASSES))

    def test_ignores_non_image_files(self, tmp_path: Path) -> None:
        root = _scaffold_dataset(tmp_path, images_per_class=2)
        # Drop a .txt file into one class folder
        stray = root / ALL_CLASSES[0].folder_name / "notes.txt"
        stray.write_text("not an image")
        paths, labels = _collect_image_paths(root)
        assert len(paths) == NUM_CLASSES * 2
        assert not any(p.suffix == ".txt" for p in paths)


# ---------------------------------------------------------------------------
# _min_class_count
# ---------------------------------------------------------------------------


class TestMinClassCount:
    def test_balanced(self) -> None:
        labels = [0, 0, 1, 1, 2, 2]
        assert _min_class_count(labels) == 2

    def test_imbalanced(self) -> None:
        labels = [0, 0, 0, 1, 2, 2]
        assert _min_class_count(labels) == 1

    def test_empty(self) -> None:
        assert _min_class_count([]) == 0


# ---------------------------------------------------------------------------
# split_dataset (path-based)
# ---------------------------------------------------------------------------


class TestSplitDataset:
    def test_empty_dataset_returns_empty_result(self, tmp_path: Path) -> None:
        root = _scaffold_dataset(tmp_path, images_per_class=0)
        result = split_dataset(root)
        assert result == SplitResult(train=[], val=[], test=[])

    def test_too_few_images_per_class_raises(self, tmp_path: Path) -> None:
        root = _scaffold_dataset(tmp_path, images_per_class=2)
        with pytest.raises(ValueError, match="at least 3 images"):
            split_dataset(root)

    def test_basic_split_sizes(self, tmp_path: Path) -> None:
        """With 10 images × 18 classes = 180 total, split should be ~126/27/27."""
        root = _scaffold_dataset(tmp_path, images_per_class=10)
        result = split_dataset(root)

        total = len(result.train) + len(result.val) + len(result.test)
        assert total == NUM_CLASSES * 10

        # Each subset should be non-empty
        assert len(result.train) > 0
        assert len(result.val) > 0
        assert len(result.test) > 0

        # Train should be the largest
        assert len(result.train) > len(result.val)
        assert len(result.train) > len(result.test)

    def test_no_overlap_between_splits(self, tmp_path: Path) -> None:
        root = _scaffold_dataset(tmp_path, images_per_class=10)
        result = split_dataset(root)

        train_paths = {p for p, _ in result.train}
        val_paths = {p for p, _ in result.val}
        test_paths = {p for p, _ in result.test}

        assert train_paths.isdisjoint(val_paths)
        assert train_paths.isdisjoint(test_paths)
        assert val_paths.isdisjoint(test_paths)

    def test_all_classes_represented_in_each_split(self, tmp_path: Path) -> None:
        root = _scaffold_dataset(tmp_path, images_per_class=10)
        result = split_dataset(root)

        for subset_name, subset in [
            ("train", result.train),
            ("val", result.val),
            ("test", result.test),
        ]:
            class_indices = {label for _, label in subset}
            assert class_indices == set(range(NUM_CLASSES)), (
                f"{subset_name} is missing classes: "
                f"{set(range(NUM_CLASSES)) - class_indices}"
            )

    def test_reproducible_with_same_seed(self, tmp_path: Path) -> None:
        root = _scaffold_dataset(tmp_path, images_per_class=10)
        cfg = SplitConfig(seed=123)

        result1 = split_dataset(root, config=cfg)
        result2 = split_dataset(root, config=cfg)

        assert result1.train == result2.train
        assert result1.val == result2.val
        assert result1.test == result2.test

    def test_different_seed_produces_different_split(self, tmp_path: Path) -> None:
        root = _scaffold_dataset(tmp_path, images_per_class=10)

        result_a = split_dataset(root, config=SplitConfig(seed=1))
        result_b = split_dataset(root, config=SplitConfig(seed=2))

        # The exact paths in train should differ
        train_paths_a = {p for p, _ in result_a.train}
        train_paths_b = {p for p, _ in result_b.train}
        assert train_paths_a != train_paths_b

    def test_custom_ratios(self, tmp_path: Path) -> None:
        root = _scaffold_dataset(tmp_path, images_per_class=20)
        cfg = SplitConfig(train_ratio=0.6, val_ratio=0.2, test_ratio=0.2)
        result = split_dataset(root, config=cfg)

        total = NUM_CLASSES * 20
        # Approximate check — stratification may round slightly
        assert abs(len(result.train) / total - 0.6) < 0.05
        assert abs(len(result.val) / total - 0.2) < 0.05
        assert abs(len(result.test) / total - 0.2) < 0.05

    def test_missing_class_dir_raises(self, tmp_path: Path) -> None:
        _scaffold_dataset(tmp_path, images_per_class=5)
        # Remove one class folder
        import shutil

        shutil.rmtree(tmp_path / ALL_CLASSES[0].folder_name)
        with pytest.raises(FileNotFoundError, match="missing"):
            split_dataset(tmp_path)

    def test_nonexistent_dir_raises(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError):
            split_dataset(tmp_path / "does_not_exist")


# ---------------------------------------------------------------------------
# split_dataset_to_dirs (directory-based)
# ---------------------------------------------------------------------------


class TestSplitDatasetToDirs:
    def test_creates_directory_structure(self, tmp_path: Path) -> None:
        data_dir = _scaffold_dataset(tmp_path / "data", images_per_class=20)
        output_dir = tmp_path / "split_out"

        split_dataset_to_dirs(data_dir, output_dir)

        # Directories exist
        assert (output_dir / "train").is_dir()
        assert (output_dir / "val").is_dir()
        assert (output_dir / "test").is_dir()

        # Class subdirs exist in each subset
        for subset in ("train", "val", "test"):
            for cls in ALL_CLASSES:
                assert (output_dir / subset / cls.folder_name).is_dir()

        # Files were actually copied
        copied_count = sum(
            1
            for subset in ("train", "val", "test")
            for cls in ALL_CLASSES
            for f in (output_dir / subset / cls.folder_name).iterdir()
            if f.is_file()
        )
        assert copied_count == NUM_CLASSES * 20

    def test_file_exists_error_prevents_overwrite(self, tmp_path: Path) -> None:
        data_dir = _scaffold_dataset(tmp_path / "data", images_per_class=4)
        output_dir = tmp_path / "split_out"
        (output_dir / "train").mkdir(parents=True)

        with pytest.raises(FileExistsError, match="train"):
            split_dataset_to_dirs(data_dir, output_dir)

    def test_symlinks_mode(self, tmp_path: Path) -> None:
        data_dir = _scaffold_dataset(tmp_path / "data", images_per_class=20)
        output_dir = tmp_path / "split_out"

        split_dataset_to_dirs(data_dir, output_dir, use_symlinks=True)

        # At least one entry should be a symlink
        any_symlink = any(
            f.is_symlink()
            for subset in ("train", "val", "test")
            for cls in ALL_CLASSES
            for f in (output_dir / subset / cls.folder_name).iterdir()
        )
        assert any_symlink

    def test_result_matches_path_split(self, tmp_path: Path) -> None:
        data_dir = _scaffold_dataset(tmp_path / "data", images_per_class=20)
        output_dir = tmp_path / "split_out"
        cfg = SplitConfig(seed=99)

        dir_result = split_dataset_to_dirs(data_dir, output_dir, config=cfg)
        path_result = split_dataset(data_dir, config=cfg)

        assert len(dir_result.train) == len(path_result.train)
        assert len(dir_result.val) == len(path_result.val)
        assert len(dir_result.test) == len(path_result.test)
