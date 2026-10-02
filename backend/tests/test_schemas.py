"""Tests for the Pydantic schemas mirroring the app's ClassificationResult (B21).

These lock the dev-backend ↔ Flutter contract (PROJECT_PLAN §10). The Dart class
(``app/lib/models/classification_result.dart``) has exactly three fields —
``variety``, ``ripeness``, ``confidence`` — serialises them with those keys via
``toMap()``, and rejects a confidence outside ``[0, 1]``. If either side drifts,
a test here should fail.
"""

import json

import pytest
from pydantic import ValidationError

from backend.app.models.schemas import ClassificationResponse

#: Exactly the keys Dart's ``ClassificationResult.toMap()`` produces.
_DART_KEYS = {"variety", "ripeness", "confidence"}


def _valid() -> ClassificationResponse:
    return ClassificationResponse(variety="Lakatan", ripeness="Ripe", confidence=0.92)


# ---------------------------------------------------------------------------
# Field mirror
# ---------------------------------------------------------------------------


class TestFieldMirror:
    def test_fields_match_dart_exactly(self) -> None:
        """No extra, missing or renamed fields relative to the Dart class."""
        assert set(ClassificationResponse.model_fields) == _DART_KEYS

    def test_serialised_keys_match_dart_to_map(self) -> None:
        assert set(_valid().model_dump()) == _DART_KEYS

    def test_rejects_unknown_fields(self) -> None:
        """extra="forbid" keeps the mirror honest."""
        with pytest.raises(ValidationError):
            ClassificationResponse(
                variety="Saba", ripeness="Ripe", confidence=0.5, extra_field="nope"
            )

    @pytest.mark.parametrize("missing", sorted(_DART_KEYS))
    def test_all_fields_are_required(self, missing: str) -> None:
        payload = {"variety": "Saba", "ripeness": "Ripe", "confidence": 0.5}
        del payload[missing]
        with pytest.raises(ValidationError):
            ClassificationResponse(**payload)


# ---------------------------------------------------------------------------
# Confidence bounds — mirrors Dart's ArgumentError guard
# ---------------------------------------------------------------------------


class TestConfidenceBounds:
    @pytest.mark.parametrize("value", [0.0, 0.5, 1.0])
    def test_accepts_values_in_range(self, value: float) -> None:
        assert ClassificationResponse(
            variety="Saba", ripeness="Ripe", confidence=value
        ).confidence == pytest.approx(value)

    @pytest.mark.parametrize("value", [-0.1, 1.1, 2.0, -1.0])
    def test_rejects_values_out_of_range(self, value: float) -> None:
        with pytest.raises(ValidationError):
            ClassificationResponse(variety="Saba", ripeness="Ripe", confidence=value)

    def test_rejects_non_numeric_confidence(self) -> None:
        with pytest.raises(ValidationError):
            ClassificationResponse(
                variety="Saba", ripeness="Ripe", confidence="very sure"
            )

    def test_coerces_integer_confidence_to_float(self) -> None:
        result = ClassificationResponse(variety="Saba", ripeness="Ripe", confidence=1)
        assert isinstance(result.confidence, float)


# ---------------------------------------------------------------------------
# Round-trip — mirrors Dart toMap() / fromMap()
# ---------------------------------------------------------------------------


class TestRoundTrip:
    def test_dump_then_validate_reproduces_the_model(self) -> None:
        original = _valid()
        restored = ClassificationResponse.model_validate(original.model_dump())
        assert restored == original

    def test_json_round_trip(self) -> None:
        original = _valid()
        restored = ClassificationResponse.model_validate(
            json.loads(original.model_dump_json())
        )
        assert restored == original

    def test_accepts_a_dart_style_map(self) -> None:
        """A map shaped like Dart's toMap() output validates unchanged."""
        dart_map = {"variety": "Cavendish", "ripeness": "Unripe", "confidence": 0.87}
        result = ClassificationResponse.model_validate(dart_map)
        assert result.variety == "Cavendish"
        assert result.ripeness == "Unripe"
        assert result.confidence == pytest.approx(0.87)
        assert result.model_dump() == dart_map
