"""Tests for ml/classes.py — the banana taxonomy module."""

from __future__ import annotations

from pathlib import Path

import pytest

from ml.classes import (
    ALL_CLASSES,
    NUM_CLASSES,
    BananaClass,
    BananaVariety,
    RipenessStage,
    class_to_index,
    generate_labels_file,
    index_to_class,
)

# ---------------------------------------------------------------------------
# Variety completeness
# ---------------------------------------------------------------------------


def test_all_six_varieties_are_defined() -> None:
    expected = {"Cavendish", "Senorita", "Latundan", "Cordova", "Lakatan", "Saba"}
    assert {v.value for v in BananaVariety} == expected


# ---------------------------------------------------------------------------
# Ripeness completeness
# ---------------------------------------------------------------------------


def test_all_three_ripeness_stages_are_defined() -> None:
    expected = {"Unripe", "Ripe", "Overripe"}
    assert {s.value for s in RipenessStage} == expected


# ---------------------------------------------------------------------------
# ALL_CLASSES list
# ---------------------------------------------------------------------------


def test_all_classes_has_exactly_18_entries() -> None:
    assert len(ALL_CLASSES) == 18
    assert NUM_CLASSES == 18


def test_all_classes_contains_no_duplicates() -> None:
    seen: set[BananaClass] = set()
    for cls in ALL_CLASSES:
        assert cls not in seen, f"Duplicate class: {cls}"
        seen.add(cls)


def test_all_classes_covers_every_variety_ripeness_combination() -> None:
    expected = {
        BananaClass(variety, ripeness)
        for variety in BananaVariety
        for ripeness in RipenessStage
    }
    assert set(ALL_CLASSES) == expected


def test_all_classes_is_ordered_variety_first_then_ripeness() -> None:
    """Validate the canonical variety-first, Unripe→Ripe→Overripe ordering."""
    expected_order = [
        BananaClass(variety, ripeness)
        for variety in BananaVariety
        for ripeness in RipenessStage
    ]
    assert expected_order == ALL_CLASSES


# ---------------------------------------------------------------------------
# folder_name
# ---------------------------------------------------------------------------


def test_folder_name_produces_expected_slug() -> None:
    cls = BananaClass(BananaVariety.LAKATAN, RipenessStage.RIPE)
    assert cls.folder_name == "Lakatan_Ripe"


def test_folder_name_for_every_class_uses_underscore_separator() -> None:
    for cls in ALL_CLASSES:
        assert "_" in cls.folder_name, f"No underscore in folder_name: {cls.folder_name}"


def test_str_of_banana_class_equals_folder_name() -> None:
    cls = BananaClass(BananaVariety.SABA, RipenessStage.UNRIPE)
    assert str(cls) == cls.folder_name


# ---------------------------------------------------------------------------
# Index ↔ class round-trips
# ---------------------------------------------------------------------------


def test_class_to_index_returns_unique_indices_for_all_classes() -> None:
    indices = [class_to_index(cls) for cls in ALL_CLASSES]
    assert sorted(indices) == list(range(NUM_CLASSES))


def test_index_to_class_round_trips_for_all_indices() -> None:
    for i, cls in enumerate(ALL_CLASSES):
        assert index_to_class(i) == cls


def test_class_to_index_then_index_to_class_is_identity() -> None:
    for cls in ALL_CLASSES:
        assert index_to_class(class_to_index(cls)) == cls


def test_index_to_class_then_class_to_index_is_identity() -> None:
    for i in range(NUM_CLASSES):
        assert class_to_index(index_to_class(i)) == i


def test_class_to_index_returns_correct_index_for_first_and_last_class() -> None:
    """Spot-check that the boundary entries resolve to the expected indices."""
    first = BananaClass(BananaVariety.CAVENDISH, RipenessStage.UNRIPE)
    last = BananaClass(BananaVariety.SABA, RipenessStage.OVERRIPE)
    assert class_to_index(first) == 0
    assert class_to_index(last) == NUM_CLASSES - 1


def test_index_to_class_raises_for_negative_index() -> None:
    with pytest.raises(KeyError, match="out of range"):
        index_to_class(-1)


def test_index_to_class_raises_for_index_at_boundary() -> None:
    with pytest.raises(KeyError, match="out of range"):
        index_to_class(NUM_CLASSES)


# ---------------------------------------------------------------------------
# StrEnum string identity
# ---------------------------------------------------------------------------


def test_banana_variety_str_equals_value() -> None:
    assert str(BananaVariety.SENORITA) == "Senorita"


def test_ripeness_stage_str_equals_value() -> None:
    assert str(RipenessStage.OVERRIPE) == "Overripe"


# ---------------------------------------------------------------------------
# generate_labels_file
# ---------------------------------------------------------------------------


def test_generate_labels_file_creates_file_with_18_lines(tmp_path: Path) -> None:
    output = tmp_path / "labels.txt"
    result = generate_labels_file(output)

    assert result.is_file()
    lines = result.read_text(encoding="utf-8").strip().splitlines()
    assert len(lines) == 18


def test_generate_labels_file_lines_match_all_classes_order(tmp_path: Path) -> None:
    output = tmp_path / "labels.txt"
    generate_labels_file(output)

    lines = output.read_text(encoding="utf-8").strip().splitlines()
    for i, line in enumerate(lines):
        assert line == ALL_CLASSES[i].folder_name, (
            f"Line {i} expected '{ALL_CLASSES[i].folder_name}', got '{line}'"
        )


def test_generate_labels_file_creates_parent_directories(tmp_path: Path) -> None:
    output = tmp_path / "nested" / "dir" / "labels.txt"
    result = generate_labels_file(output)
    assert result.is_file()
