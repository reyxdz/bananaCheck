"""Response schemas for the dev backend.

``ClassificationResponse`` mirrors the Flutter app's ``ClassificationResult``
field-for-field (variety, ripeness, confidence) so the dev backend and the
shipped app agree on the output shape — see PROJECT_PLAN §10.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class ClassificationResponse(BaseModel):
    """A single image's predicted variety, ripeness, and confidence."""

    variety: str = Field(description='Predicted banana variety, e.g. "Lakatan".')
    ripeness: str = Field(description='Predicted ripeness stage, e.g. "Ripe".')
    confidence: float = Field(
        ge=0.0,
        le=1.0,
        description="Maximum softmax probability (0.0–1.0).",
    )
