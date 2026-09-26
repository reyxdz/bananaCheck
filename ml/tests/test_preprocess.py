"""Tests for ml/preprocess.py — preprocessing pipeline (resize, augment, normalize)."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from ml.classes import ALL_CLASSES, NUM_CLASSES
from ml.preprocess import (
    DEFAULT_AUGMENT,
    AugmentConfig,
    PreprocessConfig,
    PreprocessedImage,
    augment_image,
    load_image,
    normalize_image,
    preprocess_directory,
    preprocess_image,
    require_directory,
    resize_image,
    validate_dataset_structure,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _create_test_image(
    path: Path, *, width: int = 100, height: int = 80, color: str = "red"
) -> Path:
    """Create a test image at *path*."""
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
            _create_test_image(folder / f"img_{i}.jpg", color="blue")
    return tmp_path


# ---------------------------------------------------------------------------
# PreprocessConfig
# ---------------------------------------------------------------------------


class TestPreprocessConfig:
    def test_default_dimensions_match_mobilenet(self) -> None:
        cfg = PreprocessConfig()
        assert cfg.width == 224
        assert cfg.height == 224

    def test_default_normalize_is_true(self) -> None:
        assert PreprocessConfig().normalize is True

    def test_rejects_non_positive_dimensions(self) -> None:
        with pytest.raises(ValueError, match="positive"):
            PreprocessConfig(width=0, height=224)

    def test_accepts_custom_dimensions(self) -> None:
        cfg = PreprocessConfig(width=128, height=128)
        assert cfg.width == 128


# ---------------------------------------------------------------------------
# AugmentConfig
# ---------------------------------------------------------------------------


class TestAugmentConfig:
    def test_default_is_disabled(self) -> None:
        cfg = AugmentConfig()
        assert cfg.is_enabled is False

    def test_flip_enables(self) -> None:
        cfg = AugmentConfig(horizontal_flip=True)
        assert cfg.is_enabled is True

    def test_rotation_enables(self) -> None:
        cfg = AugmentConfig(max_rotation_degrees=10.0)
        assert cfg.is_enabled is True

    def test_brightness_enables(self) -> None:
        cfg = AugmentConfig(brightness_range=(0.9, 1.1))
        assert cfg.is_enabled is True

    def test_contrast_enables(self) -> None:
        cfg = AugmentConfig(contrast_range=(0.9, 1.1))
        assert cfg.is_enabled is True

    def test_crop_enables(self) -> None:
        cfg = AugmentConfig(random_crop_fraction=0.9)
        assert cfg.is_enabled is True

    def test_rejects_negative_rotation(self) -> None:
        with pytest.raises(ValueError, match="non-negative"):
            AugmentConfig(max_rotation_degrees=-5)

    def test_rejects_invalid_brightness_range(self) -> None:
        with pytest.raises(ValueError, match="brightness_range"):
            AugmentConfig(brightness_range=(1.5, 0.5))

    def test_rejects_invalid_contrast_range(self) -> None:
        with pytest.raises(ValueError, match="contrast_range"):
            AugmentConfig(contrast_range=(0.0, 1.0))

    def test_rejects_invalid_crop_fraction(self) -> None:
        with pytest.raises(ValueError, match="random_crop_fraction"):
            AugmentConfig(random_crop_fraction=0.0)

    def test_rejects_crop_fraction_above_one(self) -> None:
        with pytest.raises(ValueError, match="random_crop_fraction"):
            AugmentConfig(random_crop_fraction=1.5)

    def test_default_augment_preset_is_enabled(self) -> None:
        assert DEFAULT_AUGMENT.is_enabled is True


# ---------------------------------------------------------------------------
# require_directory / validate_dataset_structure (preserved behaviour)
# ---------------------------------------------------------------------------


class TestDirectoryHelpers:
    def test_require_directory_accepts_existing(self, tmp_path: Path) -> None:
        assert require_directory(tmp_path) == tmp_path.resolve()

    def test_require_directory_rejects_missing(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError, match="Dataset directory"):
            require_directory(tmp_path / "nope")

    def test_validate_passes_with_all_folders(self, tmp_path: Path) -> None:
        _scaffold_dataset(tmp_path)
        validate_dataset_structure(tmp_path)  # must not raise

    def test_validate_raises_on_missing(self, tmp_path: Path) -> None:
        for cls in ALL_CLASSES[:3]:
            (tmp_path / cls.folder_name).mkdir()
        with pytest.raises(FileNotFoundError):
            validate_dataset_structure(tmp_path)


# ---------------------------------------------------------------------------
# load_image
# ---------------------------------------------------------------------------


class TestLoadImage:
    def test_loads_valid_image_as_rgb(self, tmp_path: Path) -> None:
        path = _create_test_image(tmp_path / "test.png")
        img = load_image(path)
        assert img.mode == "RGB"
        assert img.size == (100, 80)

    def test_converts_rgba_to_rgb(self, tmp_path: Path) -> None:
        path = tmp_path / "rgba.png"
        Image.new("RGBA", (10, 10), (255, 0, 0, 128)).save(path)
        img = load_image(path)
        assert img.mode == "RGB"

    def test_converts_grayscale_to_rgb(self, tmp_path: Path) -> None:
        path = tmp_path / "gray.png"
        Image.new("L", (10, 10), 128).save(path)
        img = load_image(path)
        assert img.mode == "RGB"

    def test_raises_on_missing_file(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError, match="Image file not found"):
            load_image(tmp_path / "nope.jpg")

    def test_raises_on_corrupt_file(self, tmp_path: Path) -> None:
        bad = tmp_path / "bad.jpg"
        bad.write_bytes(b"not an image")
        with pytest.raises(ValueError, match="Cannot open image"):
            load_image(bad)


# ---------------------------------------------------------------------------
# resize_image
# ---------------------------------------------------------------------------


class TestResizeImage:
    def test_resizes_to_default_224x224(self) -> None:
        img = Image.new("RGB", (640, 480))
        resized = resize_image(img)
        assert resized.size == (224, 224)

    def test_resizes_to_custom_dimensions(self) -> None:
        img = Image.new("RGB", (640, 480))
        cfg = PreprocessConfig(width=128, height=96)
        resized = resize_image(img, cfg)
        assert resized.size == (128, 96)

    def test_preserves_mode(self) -> None:
        img = Image.new("RGB", (50, 50))
        resized = resize_image(img)
        assert resized.mode == "RGB"


# ---------------------------------------------------------------------------
# normalize_image
# ---------------------------------------------------------------------------


class TestNormalizeImage:
    def test_output_dtype_is_float32(self) -> None:
        img = Image.new("RGB", (10, 10), color=(128, 128, 128))
        arr = normalize_image(img)
        assert arr.dtype == np.float32

    def test_output_range_is_0_to_1(self) -> None:
        img = Image.new("RGB", (10, 10), color=(255, 255, 255))
        arr = normalize_image(img)
        assert arr.max() <= 1.0
        assert arr.min() >= 0.0

    def test_white_normalizes_to_ones(self) -> None:
        img = Image.new("RGB", (2, 2), color=(255, 255, 255))
        arr = normalize_image(img)
        np.testing.assert_allclose(arr, 1.0)

    def test_black_normalizes_to_zeros(self) -> None:
        img = Image.new("RGB", (2, 2), color=(0, 0, 0))
        arr = normalize_image(img)
        np.testing.assert_allclose(arr, 0.0)

    def test_output_shape_is_hwc(self) -> None:
        img = Image.new("RGB", (10, 8))
        arr = normalize_image(img)
        assert arr.shape == (8, 10, 3)  # (height, width, channels)


# ---------------------------------------------------------------------------
# augment_image
# ---------------------------------------------------------------------------


class TestAugmentImage:
    def test_disabled_augment_returns_same_image(self) -> None:
        img = Image.new("RGB", (50, 50), color="red")
        cfg = AugmentConfig()  # all disabled
        result = augment_image(img, cfg)
        assert result is img  # identity, not a copy

    def test_augment_returns_same_size(self) -> None:
        img = Image.new("RGB", (100, 80), color="blue")
        result = augment_image(img, DEFAULT_AUGMENT)
        assert result.size == img.size

    def test_augment_returns_rgb(self) -> None:
        img = Image.new("RGB", (50, 50), color="green")
        result = augment_image(img, DEFAULT_AUGMENT)
        assert result.mode == "RGB"

    def test_flip_only_preserves_size(self) -> None:
        img = Image.new("RGB", (50, 50))
        cfg = AugmentConfig(horizontal_flip=True)
        result = augment_image(img, cfg)
        assert result.size == (50, 50)

    def test_rotation_only_preserves_size(self) -> None:
        img = Image.new("RGB", (50, 50))
        cfg = AugmentConfig(max_rotation_degrees=30)
        result = augment_image(img, cfg)
        assert result.size == (50, 50)

    def test_crop_only_preserves_size(self) -> None:
        img = Image.new("RGB", (100, 100))
        cfg = AugmentConfig(random_crop_fraction=0.8)
        result = augment_image(img, cfg)
        assert result.size == (100, 100)


# ---------------------------------------------------------------------------
# preprocess_image (end-to-end)
# ---------------------------------------------------------------------------


class TestPreprocessImage:
    def test_returns_preprocessed_image_type(self, tmp_path: Path) -> None:
        path = _create_test_image(tmp_path / "test.jpg")
        result = preprocess_image(path)
        assert isinstance(result, PreprocessedImage)

    def test_output_shape_matches_config(self, tmp_path: Path) -> None:
        path = _create_test_image(tmp_path / "test.jpg", width=640, height=480)
        result = preprocess_image(path)
        assert result.array.shape == (224, 224, 3)

    def test_output_normalized_by_default(self, tmp_path: Path) -> None:
        path = _create_test_image(tmp_path / "test.jpg")
        result = preprocess_image(path)
        assert result.array.dtype == np.float32
        assert result.array.max() <= 1.0
        assert result.array.min() >= 0.0

    def test_output_unnormalized_when_disabled(self, tmp_path: Path) -> None:
        path = _create_test_image(
            tmp_path / "test.jpg", color="white"
        )
        cfg = PreprocessConfig(normalize=False)
        result = preprocess_image(path, config=cfg)
        assert result.array.max() == 255.0

    def test_source_path_is_resolved(self, tmp_path: Path) -> None:
        path = _create_test_image(tmp_path / "test.jpg")
        result = preprocess_image(path)
        assert result.source_path == path.resolve()

    def test_custom_dimensions(self, tmp_path: Path) -> None:
        path = _create_test_image(tmp_path / "test.jpg")
        cfg = PreprocessConfig(width=128, height=96)
        result = preprocess_image(path, config=cfg)
        assert result.array.shape == (96, 128, 3)

    def test_with_augmentation(self, tmp_path: Path) -> None:
        path = _create_test_image(tmp_path / "test.jpg", width=200, height=200)
        aug = AugmentConfig(horizontal_flip=True)
        result = preprocess_image(path, augment=aug)
        assert result.array.shape == (224, 224, 3)

    def test_without_augmentation_is_deterministic(
        self, tmp_path: Path
    ) -> None:
        path = _create_test_image(tmp_path / "test.jpg")
        r1 = preprocess_image(path)
        r2 = preprocess_image(path)
        np.testing.assert_array_equal(r1.array, r2.array)


# ---------------------------------------------------------------------------
# preprocess_directory
# ---------------------------------------------------------------------------


class TestPreprocessDirectory:
    def test_processes_all_images(self, tmp_path: Path) -> None:
        _scaffold_dataset(tmp_path, images_per_class=2)
        results = preprocess_directory(tmp_path)
        assert len(results) == 2 * NUM_CLASSES

    def test_returns_correct_class_indices(self, tmp_path: Path) -> None:
        _scaffold_dataset(tmp_path, images_per_class=1)
        results = preprocess_directory(tmp_path)
        indices = [idx for _, idx in results]
        assert indices == list(range(NUM_CLASSES))

    def test_each_result_has_correct_shape(self, tmp_path: Path) -> None:
        _scaffold_dataset(tmp_path, images_per_class=1)
        results = preprocess_directory(tmp_path)
        for img, _ in results:
            assert img.array.shape == (224, 224, 3)
            assert img.array.dtype == np.float32

    def test_raises_on_invalid_structure(self, tmp_path: Path) -> None:
        # Missing class folders
        with pytest.raises(FileNotFoundError):
            preprocess_directory(tmp_path)

    def test_empty_folders_return_empty_list(self, tmp_path: Path) -> None:
        _scaffold_dataset(tmp_path, images_per_class=0)
        results = preprocess_directory(tmp_path)
        assert results == []
