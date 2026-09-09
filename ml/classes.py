"""Banana variety and ripeness-stage taxonomy — single source of truth for
the ML pipeline.

All 21 class labels (7 varieties × 3 ripeness stages) are defined here.
Everything else in the codebase — dataset layout, model output indexing, and
the ``labels.txt`` file bundled with the Flutter app — derives from this
module so the two never drift apart.
"""

from __future__ import annotations

from enum import StrEnum
from pathlib import Path
from typing import NamedTuple

# ---------------------------------------------------------------------------
# Core taxonomy
# ---------------------------------------------------------------------------


class BananaVariety(StrEnum):
    """Seven Philippine banana varieties recognised by the classifier."""

    SABA = "Saba"
    LAKATAN = "Lakatan"
    SENORITA = "Senorita"
    LATUNDAN = "Latundan"
    MORADO = "Morado"
    CAVENDISH = "Cavendish"
    BUNGULAN = "Bungulan"


class RipenessStage(StrEnum):
    """Three ripeness stages the classifier distinguishes."""

    UNRIPE = "Unripe"
    RIPE = "Ripe"
    OVERRIPE = "Overripe"


# ---------------------------------------------------------------------------
# Combined class representation
# ---------------------------------------------------------------------------


class BananaClass(NamedTuple):
    """A single classification target: one variety at one ripeness stage."""

    variety: BananaVariety
    ripeness: RipenessStage

    @property
    def folder_name(self) -> str:
        """Dataset directory name, e.g. ``"Lakatan_Ripe"``."""
        return f"{self.variety}_{self.ripeness}"

    def __str__(self) -> str:
        return self.folder_name


# ---------------------------------------------------------------------------
# Ordered class list  (defines model output index ordering)
# ---------------------------------------------------------------------------
#
# Order: variety-first, then ripeness (Unripe → Ripe → Overripe).
# This order MUST match the order used when training the model and is
# reflected verbatim in ``app/assets/model/labels.txt``.

ALL_CLASSES: list[BananaClass] = [
    BananaClass(variety, ripeness)
    for variety in BananaVariety
    for ripeness in RipenessStage
]

NUM_CLASSES: int = len(ALL_CLASSES)  # 21


# ---------------------------------------------------------------------------
# Index ↔ class bijection helpers
# ---------------------------------------------------------------------------

_INDEX_TO_CLASS: dict[int, BananaClass] = {
    i: cls for i, cls in enumerate(ALL_CLASSES)
}
_CLASS_TO_INDEX: dict[BananaClass, int] = {
    cls: i for i, cls in enumerate(ALL_CLASSES)
}


def class_to_index(banana_class: BananaClass) -> int:
    """Return the 0-based model output index for *banana_class*.

    Raises
    ------
    KeyError
        If *banana_class* is not in ``ALL_CLASSES``.
    """
    try:
        return _CLASS_TO_INDEX[banana_class]
    except KeyError:
        raise KeyError(f"Unknown class: {banana_class!r}") from None


def index_to_class(index: int) -> BananaClass:
    """Return the :class:`BananaClass` for a model output *index*.

    Raises
    ------
    KeyError
        If *index* is outside ``[0, NUM_CLASSES)``.
    """
    try:
        return _INDEX_TO_CLASS[index]
    except KeyError:
        raise KeyError(
            f"Index {index} is out of range [0, {NUM_CLASSES})"
        ) from None


# ---------------------------------------------------------------------------
# labels.txt generator
# ---------------------------------------------------------------------------


def generate_labels_file(output_path: Path) -> Path:
    """Write a ``labels.txt`` file listing every class in index order.

    Each line contains one ``Variety_Ripeness`` label matching the model
    output index.  This file is bundled as a Flutter asset at
    ``app/assets/model/labels.txt``.

    Returns the resolved *output_path* for convenience.
    """
    output_path = output_path.resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        "\n".join(cls.folder_name for cls in ALL_CLASSES) + "\n",
        encoding="utf-8",
    )
    return output_path
