"""Tests for ml/dataset_organizer.py — dataset labeling and organization."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from ml.classes import ALL_CLASSES, NUM_CLASSES
from ml.dataset_organizer import (
    ClassBalanceReport,
    DuplicateGroup,
    StrayFile,
    compute_class_balance,
    find_duplicates,
    find_stray_files,
    generate_report,
    validate_image,
    _MIN_IMAGES_PER_CLASS,
)
from ml.dataset_scaffold import create_class_folders


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _create_tiny_image(path: Path, *, color: str = "red") -> Path:
    """Create a minimal 2×2 PNG image at *path*."""
    img = Image.new("RGB", (2, 2), color=color)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    return path


def _scaffold_with_images(
    tmp_path: Path,
    *,
    images_per_class: int = 0,
) -> Path:
    """Create the class folder layout and optionally populate with images."""
    create_class_folders(tmp_path)
    if images_per_class > 0:
        for cls in ALL_CLASSES:
            folder = tmp_path / cls.folder_name
            for i in range(images_per_class):
                _create_tiny_image(folder / f"img_{i}.png")
    return tmp_path


# ---------------------------------------------------------------------------
# validate_image
# ---------------------------------------------------------------------------


class TestValidateImage:
    def test_valid_image_returns_true(self, tmp_path: Path) -> None:
        img_path = _create_tiny_image(tmp_path / "valid.png")
        result = validate_image(img_path)
        assert result.is_valid is True
        assert result.width == 2
        assert result.height == 2
        assert result.format == "PNG"
        assert result.file_size > 0
        assert result.error == ""

    def test_nonexistent_file_returns_invalid(self, tmp_path: Path) -> None:
        result = validate_image(tmp_path / "missing.png")
        assert result.is_valid is False
        assert "does not exist" in result.error

    def test_zero_byte_file_returns_invalid(self, tmp_path: Path) -> None:
        empty = tmp_path / "empty.png"
        empty.touch()
        result = validate_image(empty)
        assert result.is_valid is False
        assert "empty" in result.error.lower()

    def test_corrupt_file_returns_invalid(self, tmp_path: Path) -> None:
        corrupt = tmp_path / "corrupt.jpg"
        corrupt.write_bytes(b"this is not an image at all")
        result = validate_image(corrupt)
        assert result.is_valid is False
        assert result.error != ""

    def test_valid_jpeg_image(self, tmp_path: Path) -> None:
        img_path = tmp_path / "test.jpg"
        img = Image.new("RGB", (10, 10), color="blue")
        img.save(img_path, format="JPEG")
        result = validate_image(img_path)
        assert result.is_valid is True
        assert result.format == "JPEG"
        assert result.width == 10
        assert result.height == 10


# ---------------------------------------------------------------------------
# find_duplicates
# ---------------------------------------------------------------------------


class TestFindDuplicates:
    def test_no_duplicates_returns_empty(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        # Create unique images in two classes
        cls0 = ALL_CLASSES[0]
        cls1 = ALL_CLASSES[1]
        _create_tiny_image(
            data_dir / cls0.folder_name / "a.png", color="red"
        )
        _create_tiny_image(
            data_dir / cls1.folder_name / "b.png", color="blue"
        )
        groups = find_duplicates(data_dir)
        assert groups == []

    def test_exact_duplicates_detected(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        cls0 = ALL_CLASSES[0]
        cls1 = ALL_CLASSES[1]
        # Create identical images in two different class folders
        original = _create_tiny_image(
            data_dir / cls0.folder_name / "dup.png", color="green"
        )
        content = original.read_bytes()
        copy_path = data_dir / cls1.folder_name / "dup_copy.png"
        copy_path.write_bytes(content)

        groups = find_duplicates(data_dir)
        assert len(groups) == 1
        assert len(groups[0].paths) == 2

    def test_duplicates_within_same_folder(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        cls0 = ALL_CLASSES[0]
        folder = data_dir / cls0.folder_name
        original = _create_tiny_image(folder / "img1.png", color="yellow")
        content = original.read_bytes()
        (folder / "img2.png").write_bytes(content)

        groups = find_duplicates(data_dir)
        assert len(groups) == 1

    def test_empty_dataset_returns_empty(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        groups = find_duplicates(data_dir)
        assert groups == []


# ---------------------------------------------------------------------------
# compute_class_balance
# ---------------------------------------------------------------------------


class TestComputeClassBalance:
    def test_empty_dataset_reports_all_zeros(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        bal = compute_class_balance(data_dir)
        assert bal.total == 0
        assert bal.min_count == 0
        assert bal.max_count == 0
        assert len(bal.empty_classes) == NUM_CLASSES
        assert bal.below_minimum == []

    def test_balanced_dataset(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(
            tmp_path, images_per_class=_MIN_IMAGES_PER_CLASS
        )
        bal = compute_class_balance(data_dir)
        assert bal.total == _MIN_IMAGES_PER_CLASS * NUM_CLASSES
        assert bal.min_count == _MIN_IMAGES_PER_CLASS
        assert bal.max_count == _MIN_IMAGES_PER_CLASS
        assert bal.empty_classes == []
        assert bal.below_minimum == []

    def test_imbalanced_dataset_flags_below_minimum(
        self, tmp_path: Path
    ) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        # Give one class 50 images (below minimum), another 200
        cls0 = ALL_CLASSES[0]
        cls1 = ALL_CLASSES[1]
        for i in range(50):
            _create_tiny_image(
                data_dir / cls0.folder_name / f"img_{i}.png"
            )
        for i in range(200):
            _create_tiny_image(
                data_dir / cls1.folder_name / f"img_{i}.png"
            )
        bal = compute_class_balance(data_dir)
        assert cls0.folder_name in bal.below_minimum
        assert cls1.folder_name not in bal.below_minimum

    def test_mean_count_is_correct(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        cls0 = ALL_CLASSES[0]
        for i in range(18):
            _create_tiny_image(
                data_dir / cls0.folder_name / f"img_{i}.png"
            )
        bal = compute_class_balance(data_dir)
        assert bal.mean_count == 18 / NUM_CLASSES


# ---------------------------------------------------------------------------
# find_stray_files
# ---------------------------------------------------------------------------


class TestFindStrayFiles:
    def test_clean_dataset_returns_empty(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path, images_per_class=1)
        # Add the expected README.md
        (data_dir / "README.md").write_text("dataset info")
        strays = find_stray_files(data_dir)
        assert strays == []

    def test_detects_non_image_in_class_folder(
        self, tmp_path: Path
    ) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        cls0 = ALL_CLASSES[0]
        stray_file = data_dir / cls0.folder_name / "notes.txt"
        stray_file.write_text("some notes")
        strays = find_stray_files(data_dir)
        assert len(strays) == 1
        assert strays[0].path == stray_file.resolve()
        assert ".txt" in strays[0].reason

    def test_detects_hidden_files(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        cls0 = ALL_CLASSES[0]
        hidden = data_dir / cls0.folder_name / ".DS_Store"
        hidden.touch()
        strays = find_stray_files(data_dir)
        assert any(s.path.name == ".DS_Store" for s in strays)

    def test_detects_files_in_data_root(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        (data_dir / "README.md").write_text("ok")
        stray = data_dir / "random_file.csv"
        stray.write_text("a,b,c")
        strays = find_stray_files(data_dir)
        assert any(s.path.name == "random_file.csv" for s in strays)

    def test_readme_in_root_is_not_stray(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        (data_dir / "README.md").write_text("dataset docs")
        strays = find_stray_files(data_dir)
        assert not any(s.path.name == "README.md" for s in strays)


# ---------------------------------------------------------------------------
# generate_report
# ---------------------------------------------------------------------------


class TestGenerateReport:
    def test_report_on_empty_dataset(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        report = generate_report(data_dir)
        assert report.total_images == 0
        assert len(report.class_counts) == NUM_CLASSES
        assert report.invalid_images == []
        assert report.duplicate_groups == []
        assert report.balance is not None
        assert len(report.balance.empty_classes) == NUM_CLASSES

    def test_report_counts_images_correctly(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path, images_per_class=3)
        report = generate_report(data_dir)
        assert report.total_images == 3 * NUM_CLASSES

    def test_report_captures_invalid_images(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        cls0 = ALL_CLASSES[0]
        corrupt = data_dir / cls0.folder_name / "bad.jpg"
        corrupt.write_bytes(b"not a real image")
        report = generate_report(data_dir)
        assert len(report.invalid_images) == 1

    def test_report_captures_stray_files(self, tmp_path: Path) -> None:
        data_dir = _scaffold_with_images(tmp_path)
        cls0 = ALL_CLASSES[0]
        (data_dir / cls0.folder_name / "notes.txt").write_text("hi")
        report = generate_report(data_dir)
        assert len(report.stray_files) == 1
