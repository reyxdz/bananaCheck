"""Tests for ml/config.py — the ML pipeline configuration module."""

from __future__ import annotations

from pathlib import Path

import pytest

from ml.config import MLConfig

# ---------------------------------------------------------------------------
# Default values
# ---------------------------------------------------------------------------


def test_default_config_has_expected_image_dimensions() -> None:
    config = MLConfig()
    assert config.image_width == 224
    assert config.image_height == 224


def test_default_config_has_expected_training_params() -> None:
    config = MLConfig()
    assert config.batch_size == 32
    assert config.learning_rate == 1e-3
    assert config.epochs == 10


def test_image_size_property_returns_width_height_tuple() -> None:
    config = MLConfig(image_width=128, image_height=128)
    assert config.image_size == (128, 128)


# ---------------------------------------------------------------------------
# Custom values
# ---------------------------------------------------------------------------


def test_config_accepts_custom_paths(tmp_path: Path) -> None:
    config = MLConfig(data_dir=tmp_path / "data", output_dir=tmp_path / "out")
    assert config.data_dir == tmp_path / "data"
    assert config.output_dir == tmp_path / "out"


def test_config_accepts_custom_training_params() -> None:
    config = MLConfig(batch_size=64, learning_rate=5e-4, epochs=50)
    assert config.batch_size == 64
    assert config.learning_rate == 5e-4
    assert config.epochs == 50


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------


def test_config_rejects_non_positive_image_width() -> None:
    with pytest.raises(ValueError, match="Image dimensions"):
        MLConfig(image_width=0)


def test_config_rejects_negative_image_height() -> None:
    with pytest.raises(ValueError, match="Image dimensions"):
        MLConfig(image_height=-1)


def test_config_rejects_non_positive_batch_size() -> None:
    with pytest.raises(ValueError, match="Batch size"):
        MLConfig(batch_size=0)


def test_config_rejects_non_positive_learning_rate() -> None:
    with pytest.raises(ValueError, match="Learning rate"):
        MLConfig(learning_rate=0.0)


def test_config_rejects_non_positive_epochs() -> None:
    with pytest.raises(ValueError, match="epochs"):
        MLConfig(epochs=-5)


# ---------------------------------------------------------------------------
# Immutability
# ---------------------------------------------------------------------------


def test_config_is_frozen() -> None:
    config = MLConfig()
    with pytest.raises(AttributeError):
        config.epochs = 99  # type: ignore[misc]
