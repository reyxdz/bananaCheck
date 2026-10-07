"""Response schemas for the dev backend.

``ClassificationResponse`` mirrors the Flutter app's ``ClassificationResult``
field-for-field (variety, ripeness, confidence) so the dev backend and the
shipped app agree on the output shape — see PROJECT_PLAN §10.
"""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class ClassificationResponse(BaseModel):
    """A single image's predicted variety, ripeness, and confidence.

    The field names and the ``confidence`` bounds deliberately match the Dart
    class, so a payload from this backend can be fed straight into
    ``ClassificationResult.fromMap`` and vice versa.  ``extra="forbid"`` keeps
    that mirror honest: an added or renamed field fails loudly here rather than
    silently diverging from the app.
    """

    model_config = ConfigDict(extra="forbid")

    variety: str = Field(description='Predicted banana variety, e.g. "Lakatan".')
    ripeness: str = Field(description='Predicted ripeness stage, e.g. "Ripe".')
    confidence: float = Field(
        ge=0.0,
        le=1.0,
        description="Maximum softmax probability (0.0–1.0).",
    )
