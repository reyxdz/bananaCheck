"""Tests for ml.curate_dataset — non-destructive clean + balance pass."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from ml.curate_dataset import (
    CurationConfig,
    augment_to_target,
    curate,
    plan_class,
    sharpness_score,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _save_noise(path: Path, size: int = 64, seed: int = 0) -> Path:
    """Save a high-frequency noise image (sharp — high Laplacian variance)."""
    rng = np.random.default_rng(seed)
    array = rng.integers(0, 255, (size, size, 3), dtype=np.uint8)
    Image.fromarray(array).save(path)
    return path


def _save_flat(path: Path, size: int = 64, value: int = 127) -> Path:
    """Save a flat, uniform image (blurry — near-zero Laplacian variance)."""
    array = np.full((size, size, 3), value, dtype=np.uint8)
    Image.fromarray(array).save(path)
    return path


# ---------------------------------------------------------------------------
# CurationConfig
# ---------------------------------------------------------------------------


class TestCurationConfig:
    def test_rejects_non_positive_target(self) -> None:
        with pytest.raises(ValueError, match="target_per_class"):
            CurationConfig(target_per_class=0)

    def test_quarantine_dir_is_inside_data_dir(self, tmp_path: Path) -> None:
        config = CurationConfig(data_dir=tmp_path)
        assert config.quarantine_dir == tmp_path / "_quarantine"


# ---------------------------------------------------------------------------
# sharpness_score
# ---------------------------------------------------------------------------


class TestSharpnessScore:
    def test_noise_scores_higher_than_flat(self, tmp_path: Path) -> None:
        noisy = _save_noise(tmp_path / "noisy.png")
        flat = _save_flat(tmp_path / "flat.png")
        assert sharpness_score(noisy) > sharpness_score(flat)

    def test_unreadable_image_scores_zero(self, tmp_path: Path) -> None:
        broken = tmp_path / "broken.jpg"
        broken.write_bytes(b"not an image")
        assert sharpness_score(broken) == 0.0


# ---------------------------------------------------------------------------
# plan_class
# ---------------------------------------------------------------------------


class TestPlanClass:
    def test_keeps_sharpest_up_to_target(self, tmp_path: Path) -> None:
        folder = tmp_path / "Saba_Ripe"
        folder.mkdir()
        # 2 sharp + 2 flat; target 2 → keep the two sharp ones.
        sharp = [_save_noise(folder / f"s{i}.png", seed=i) for i in range(2)]
        _save_flat(folder / "f0.png", value=120)
        _save_flat(folder / "f1.png", value=130)

        plan = plan_class(folder, "Saba_Ripe", target=2)

        assert len(plan.keep) == 2
        assert set(plan.keep) == set(sharp)
        assert len(plan.surplus) == 2
        assert plan.deficit == 0

    def test_detects_duplicates(self, tmp_path: Path) -> None:
        folder = tmp_path / "Lakatan_Ripe"
        folder.mkdir()
        _save_noise(folder / "a.png", seed=1)
        # Exact byte-for-byte copy.
        (folder / "a_copy.png").write_bytes((folder / "a.png").read_bytes())

        plan = plan_class(folder, "Lakatan_Ripe", target=10)

        assert len(plan.duplicates) == 1
        assert len(plan.keep) == 1

    def test_flags_invalid_images(self, tmp_path: Path) -> None:
        folder = tmp_path / "Cordova_Unripe"
        folder.mkdir()
        _save_noise(folder / "good.png", seed=3)
        (folder / "bad.jpg").write_bytes(b"corrupt")

        plan = plan_class(folder, "Cordova_Unripe", target=10)

        assert len(plan.invalid) == 1
        assert len(plan.keep) == 1

    def test_reports_deficit(self, tmp_path: Path) -> None:
        folder = tmp_path / "Senorita_Overripe"
        folder.mkdir()
        _save_noise(folder / "a.png", seed=4)

        plan = plan_class(folder, "Senorita_Overripe", target=5)

        assert plan.deficit == 4


# ---------------------------------------------------------------------------
# augment_to_target
# ---------------------------------------------------------------------------


class TestAugmentToTarget:
    def test_creates_the_requested_number(self, tmp_path: Path) -> None:
        folder = tmp_path / "cls"
        folder.mkdir()
        source = _save_noise(folder / "src.png", seed=5)

        created = augment_to_target(folder, [source], 3)

        assert len(created) == 3
        assert all(p.exists() for p in created)
        assert all(p.name.startswith("aug_") for p in created)

    def test_noop_when_no_deficit(self, tmp_path: Path) -> None:
        folder = tmp_path / "cls"
        folder.mkdir()
        source = _save_noise(folder / "src.png", seed=6)
        assert augment_to_target(folder, [source], 0) == []


# ---------------------------------------------------------------------------
# curate (end-to-end, non-destructive)
# ---------------------------------------------------------------------------


class TestCurate:
    def _build_one_class(self, data_dir: Path, name: str, n_sharp: int,
                         n_flat: int) -> None:
        folder = data_dir / name
        folder.mkdir(parents=True)
        for i in range(n_sharp):
            _save_noise(folder / f"s{i}.png", seed=100 + i)
        for i in range(n_flat):
            _save_flat(folder / f"f{i}.png", value=100 + i)

    def _count_images(self, folder: Path) -> int:
        return len([p for p in folder.iterdir() if p.suffix == ".png"])

    def test_trims_surplus_to_target_non_destructively(
        self, tmp_path: Path
    ) -> None:
        # One class with 5 images, target 3 → 2 go to quarantine.
        self._build_one_class(tmp_path, "Saba_Ripe", n_sharp=3, n_flat=2)
        total_before = self._count_images(tmp_path / "Saba_Ripe")

        config = CurationConfig(data_dir=tmp_path, target_per_class=3)
        # Only the one class we built participates; others are absent (0 imgs).
        outcomes = curate(config)

        saba = next(o for o in outcomes if o.class_name == "Saba_Ripe")
        assert saba.final_count == 3
        assert self._count_images(tmp_path / "Saba_Ripe") == 3

        # Nothing deleted — the 2 surplus live in quarantine.
        quarantined = list(
            (config.quarantine_dir / "surplus" / "Saba_Ripe").iterdir()
        )
        assert len(quarantined) == 2
        assert total_before == 3 + len(quarantined)

    def test_augments_deficit_to_target(self, tmp_path: Path) -> None:
        self._build_one_class(tmp_path, "Senorita_Overripe", n_sharp=2,
                              n_flat=0)

        config = CurationConfig(data_dir=tmp_path, target_per_class=5)
        outcomes = curate(config)

        senorita = next(
            o for o in outcomes if o.class_name == "Senorita_Overripe"
        )
        assert senorita.final_count == 5
        assert senorita.augmented == 3
        assert self._count_images(tmp_path / "Senorita_Overripe") == 5

    def test_dry_run_changes_nothing(self, tmp_path: Path) -> None:
        self._build_one_class(tmp_path, "Saba_Ripe", n_sharp=3, n_flat=2)
        before = self._count_images(tmp_path / "Saba_Ripe")

        config = CurationConfig(
            data_dir=tmp_path, target_per_class=3, dry_run=True
        )
        outcomes = curate(config)

        saba = next(o for o in outcomes if o.class_name == "Saba_Ripe")
        assert saba.final_count == 3  # planned
        assert self._count_images(tmp_path / "Saba_Ripe") == before  # untouched
        assert not config.quarantine_dir.exists()
