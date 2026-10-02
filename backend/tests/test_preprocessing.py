"""Shared preprocessing tests, including app↔model parity (B20).

The parity tests are the point of this file: they assert that the backend's
preprocessing reproduces ``ml/preprocess.py`` exactly, so the two cannot drift
apart unnoticed (PROJECT_PLAN §10).
"""

import io

import numpy as np
import pytest
from PIL import Image

from backend.app.services.preprocessing import (
    ALLOWED_IMAGE_FORMATS,
    DEFAULT_INPUT_SIZE,
    ML_PREPROCESS_RESAMPLE,
    TRAINING_RESAMPLE,
    InvalidImageError,
    UnsupportedImageFormatError,
    preprocess_bytes,
    preprocess_pil,
)
from ml.config import MLConfig
from ml.preprocess import PreprocessConfig
from ml.preprocess import preprocess_image as ml_preprocess_image


def _image(width: int = 97, height: int = 61, seed: int = 7) -> Image.Image:
    """A non-square, high-frequency image so resampling differences show up."""
    rng = np.random.default_rng(seed)
    return Image.fromarray(
        rng.integers(0, 255, (height, width, 3), dtype=np.uint8)
    )


def _jpeg(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, format="PNG")  # lossless, so parity is exact
    return buf.getvalue()


# ---------------------------------------------------------------------------
# Output contract
# ---------------------------------------------------------------------------


class TestOutputContract:
    def test_batched_shape_dtype_range(self) -> None:
        batch = preprocess_bytes(_jpeg(_image()))
        assert batch.shape == (1, DEFAULT_INPUT_SIZE, DEFAULT_INPUT_SIZE, 3)
        assert batch.dtype == np.float32
        assert batch.min() >= 0.0
        assert batch.max() <= 1.0

    def test_unbatched_shape(self) -> None:
        arr = preprocess_pil(_image(), size=64)
        assert arr.shape == (64, 64, 3)

    def test_custom_size(self) -> None:
        assert preprocess_bytes(_jpeg(_image()), size=32).shape == (1, 32, 32, 3)

    def test_white_maps_to_one_and_black_to_zero(self) -> None:
        white = preprocess_pil(Image.new("RGB", (8, 8), (255, 255, 255)), size=8)
        black = preprocess_pil(Image.new("RGB", (8, 8), (0, 0, 0)), size=8)
        np.testing.assert_allclose(white, 1.0)
        np.testing.assert_allclose(black, 0.0)

    def test_converts_non_rgb_modes(self) -> None:
        for mode, colour in (("L", 128), ("RGBA", (10, 20, 30, 128))):
            arr = preprocess_pil(Image.new(mode, (8, 8), colour), size=8)
            assert arr.shape == (8, 8, 3)

    def test_rejects_undecodable_bytes(self) -> None:
        with pytest.raises(InvalidImageError):
            preprocess_bytes(b"not an image at all")


# ---------------------------------------------------------------------------
# Parity with ml/preprocess.py — the anti-drift contract
# ---------------------------------------------------------------------------


class TestParityWithMlPreprocess:
    def test_default_size_matches_ml_config(self) -> None:
        """Backend and ml must agree on the model's input dimensions."""
        ml_config = MLConfig()
        assert DEFAULT_INPUT_SIZE == ml_config.image_width == ml_config.image_height

        preprocess_config = PreprocessConfig()
        assert preprocess_config.width == DEFAULT_INPUT_SIZE

    def test_pixel_identical_to_ml_preprocess(self, tmp_path) -> None:
        """With ml's resampling filter, output must match ml/preprocess.py exactly.

        If someone changes the resize or normalisation in either place, this
        fails — which is precisely the app↔model drift B20 guards against.
        """
        img = _image()
        path = tmp_path / "banana.png"
        img.save(path)

        ml_array = ml_preprocess_image(path).array
        backend_array = preprocess_pil(
            img, size=DEFAULT_INPUT_SIZE, resample=ML_PREPROCESS_RESAMPLE
        )

        assert backend_array.shape == ml_array.shape
        assert backend_array.dtype == ml_array.dtype
        np.testing.assert_array_equal(backend_array, ml_array)

    def test_batched_helper_matches_ml_preprocess(self, tmp_path) -> None:
        """The batched entry point differs from ml only by the batch dimension."""
        img = _image(seed=11)
        path = tmp_path / "banana.png"
        img.save(path)

        ml_array = ml_preprocess_image(path).array
        batch = preprocess_bytes(
            _jpeg(img), resample=ML_PREPROCESS_RESAMPLE
        )

        assert batch.shape == (1, *ml_array.shape)
        np.testing.assert_array_equal(batch[0], ml_array)


# ---------------------------------------------------------------------------
# Resampling filter is a real, deliberate choice
# ---------------------------------------------------------------------------


class TestResampleFilters:
    def test_training_and_ml_filters_differ(self) -> None:
        """Documents that the two filters are not interchangeable.

        ``ml/preprocess.py`` uses LANCZOS while the model was trained (and the
        Dart app runs) on bilinear — measurably different pixels, so the filter
        must stay explicit rather than implied.
        """
        assert TRAINING_RESAMPLE != ML_PREPROCESS_RESAMPLE

        img = _image(seed=3)
        bilinear = preprocess_pil(img, resample=TRAINING_RESAMPLE)
        lanczos = preprocess_pil(img, resample=ML_PREPROCESS_RESAMPLE)

        assert not np.array_equal(bilinear, lanczos)

    def test_default_is_the_training_filter(self) -> None:
        """The default must be what the shipped model actually sees."""
        img = _image(seed=5)
        np.testing.assert_array_equal(
            preprocess_pil(img),
            preprocess_pil(img, resample=TRAINING_RESAMPLE),
        )


# ---------------------------------------------------------------------------
# Upload format validation (B23)
# ---------------------------------------------------------------------------


class TestFormatValidation:
    def _encode(self, fmt: str) -> bytes:
        buf = io.BytesIO()
        _image(32, 32).save(buf, format=fmt)
        return buf.getvalue()

    def test_allowed_formats_are_jpeg_and_png(self) -> None:
        assert frozenset({"JPEG", "PNG"}) == ALLOWED_IMAGE_FORMATS

    @pytest.mark.parametrize("fmt", ["JPEG", "PNG"])
    def test_accepts_allowed_formats(self, fmt: str) -> None:
        assert preprocess_bytes(self._encode(fmt), size=16).shape == (1, 16, 16, 3)

    @pytest.mark.parametrize("fmt", ["BMP", "GIF", "TIFF", "WEBP"])
    def test_rejects_disallowed_formats(self, fmt: str) -> None:
        with pytest.raises(UnsupportedImageFormatError):
            preprocess_bytes(self._encode(fmt), size=16)

    def test_unsupported_format_is_an_invalid_image_error(self) -> None:
        """Subclassing keeps existing broad catches working."""
        assert issubclass(UnsupportedImageFormatError, InvalidImageError)

    def test_check_can_be_disabled(self) -> None:
        batch = preprocess_bytes(self._encode("BMP"), size=16, allowed_formats=None)
        assert batch.shape == (1, 16, 16, 3)
