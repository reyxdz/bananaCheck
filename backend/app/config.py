"""Configuration for the development-only model-testing backend (B16).

Centralises the backend's settings — the TFLite model path, the class-labels
file, the confidence threshold, and the CORS origins allowed during local
development — so the rest of the app imports from one place instead of
scattering magic values. Mirrors the frozen-dataclass style of ``ml.config``.

Every value can be overridden with a ``BANANA_*`` environment variable, so the
backend can point at a freshly trained model without code changes::

    BANANA_MODEL_PATH=/path/to/banana_classifier.tflite \\
    BANANA_LABELS_PATH=/path/to/labels.txt \\
    uvicorn backend.app.main:app

**Offline-only reminder:** this backend is a local developer tool (batch model
testing / preprocessing parity). It is never shipped and the mobile app never
calls it, so the CORS defaults intentionally cover only localhost origins.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

_BACKEND_ROOT = Path(__file__).resolve().parent
# Default to the *same* artefacts the Flutter app bundles, so the dev backend
# tests exactly what ships on-device (PROJECT_PLAN §10).
_REPO_ROOT = _BACKEND_ROOT.parent.parent
_APP_MODEL_DIR = _REPO_ROOT / "app" / "assets" / "model"
_DEFAULT_MODEL_PATH = _APP_MODEL_DIR / "banana_classifier.tflite"
_DEFAULT_LABELS_PATH = _APP_MODEL_DIR / "labels.txt"
_DEFAULT_CONFIDENCE_THRESHOLD = 0.5
_DEFAULT_CORS_ORIGINS: tuple[str, ...] = (
    "http://localhost",
    "http://localhost:8000",
    "http://127.0.0.1",
    "http://127.0.0.1:8000",
)


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class BackendConfig:
    """Immutable backend settings.

    Parameters
    ----------
    title, version:
        FastAPI application metadata.
    model_path:
        Path to the ``.tflite`` model the backend loads for batch testing.
    labels_path:
        Path to the ``labels.txt`` whose ordering matches the model output.
        The backend reads the **same** file the app bundles so the two never
        drift (see PROJECT_PLAN §10).
    confidence_threshold:
        Minimum max-probability below which a prediction is considered
        unreliable (matches the app's low-confidence gate).
    cors_allow_origins:
        Origins permitted by the CORS middleware. Localhost-only by default.
    """

    title: str = "Banana Classifier Model Management"
    version: str = "0.1.0"
    model_path: Path = field(default_factory=lambda: _DEFAULT_MODEL_PATH)
    labels_path: Path = field(default_factory=lambda: _DEFAULT_LABELS_PATH)
    confidence_threshold: float = _DEFAULT_CONFIDENCE_THRESHOLD
    cors_allow_origins: tuple[str, ...] = _DEFAULT_CORS_ORIGINS

    def __post_init__(self) -> None:
        if not 0.0 <= self.confidence_threshold <= 1.0:
            raise ValueError("confidence_threshold must be in [0, 1].")
        if not self.cors_allow_origins:
            raise ValueError("cors_allow_origins must not be empty.")

    def load_labels(self) -> list[str]:
        """Return the class labels from ``labels_path`` in file order.

        Returns an empty list if the file does not exist — the skeleton ships
        without a model/labels file, so callers must treat "no labels" as a
        valid not-yet-provisioned state rather than an error.
        """
        path = Path(self.labels_path)
        if not path.is_file():
            return []
        return [
            line.strip()
            for line in path.read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]


# ---------------------------------------------------------------------------
# Environment loading
# ---------------------------------------------------------------------------


def _split_origins(raw: str) -> tuple[str, ...]:
    """Parse a comma-separated origins string into a tuple."""
    return tuple(origin.strip() for origin in raw.split(",") if origin.strip())


def get_config() -> BackendConfig:
    """Build a :class:`BackendConfig` from ``BANANA_*`` env vars (with defaults).

    Read fresh each call so tests (and a restarted process) pick up the current
    environment; the app creates one instance at startup via ``create_app``.
    """
    overrides: dict[str, object] = {}
    if model_path := os.getenv("BANANA_MODEL_PATH"):
        overrides["model_path"] = Path(model_path)
    if labels_path := os.getenv("BANANA_LABELS_PATH"):
        overrides["labels_path"] = Path(labels_path)
    if threshold := os.getenv("BANANA_CONFIDENCE_THRESHOLD"):
        overrides["confidence_threshold"] = float(threshold)
    if origins := os.getenv("BANANA_CORS_ORIGINS"):
        overrides["cors_allow_origins"] = _split_origins(origins)
    return BackendConfig(**overrides)
