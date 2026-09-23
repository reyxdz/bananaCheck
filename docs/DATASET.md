# Dataset and Model Artifact Rules

## Source Images

Raw images live below `ml/data/`, which is ignored by Git except for its
instruction file. Never commit source photos, copied public datasets, augmented
images, train/validation/test outputs, or personal information captured in an
image.

### Folder Layout

Use the flat `Variety_Ripeness` naming convention — one folder per class:

```text
ml/data/
├── Cavendish_Unripe/
├── Cavendish_Ripe/
├── Cavendish_Overripe/
├── Senorita_Unripe/
├── Senorita_Ripe/
├── Senorita_Overripe/
├── Latundan_Unripe/
├── Latundan_Ripe/
├── Latundan_Overripe/
├── Cordova_Unripe/
├── Cordova_Ripe/
├── Cordova_Overripe/
├── Lakatan_Unripe/
├── Lakatan_Ripe/
├── Lakatan_Overripe/
├── Saba_Unripe/
├── Saba_Ripe/
└── Saba_Overripe/
```

Run `python -m ml.dataset_scaffold` to create all 18 folders automatically.
Run `python -m ml.dataset_scaffold --verify` to check the structure is complete.

### Target Varieties (6)

| Variety    | Description                          |
|------------|--------------------------------------|
| Cavendish  | Most common commercial banana        |
| Senorita   | Small, finger-sized dessert banana   |
| Latundan   | Thin-skinned, mildly sweet           |
| Cordova    | Regional Philippine cooking variety  |
| Lakatan    | Sweet, golden-yellow when ripe       |
| Saba       | Cooking banana, thick-skinned        |

### Ripeness Stages (3)

| Stage    | Visual Cues                                  |
|----------|----------------------------------------------|
| Unripe   | Green skin, firm flesh                       |
| Ripe     | Yellow skin (variety-dependent), soft flesh   |
| Overripe | Brown spots/fully brown, very soft flesh     |

**Total classes:** 6 × 3 = **18**

## Sourcing Strategy

### Public Datasets

Search these platforms for existing banana image datasets:

- **Kaggle** — search for "banana ripeness", "banana classification"
- **Roboflow** — pre-annotated datasets with augmentation options
- **Google Dataset Search** — academic and research datasets
- **iNaturalist** — community-contributed plant photographs

When using a public dataset, verify the license allows academic/research use
and record the source in the dataset record below.

### Own Photo Collection

For varieties not well-represented in public datasets (especially Cordova):

- Use a smartphone camera in natural lighting conditions
- Capture multiple angles per banana (top, side, end)
- Include varied backgrounds (table, hand, basket, field)
- Photograph at each ripeness stage as the same banana ages
- Minimum resolution: 640×480 pixels

### Image Requirements

- **Minimum 100 images per class** (ideally 200+ for robust training)
- Accepted formats: `.jpg`, `.jpeg`, `.png`
- No watermarked, heavily filtered, or composite images
- No images containing identifiable personal information

## Required Dataset Record

For each source or collection batch, record:

- provenance, owner/license, and permitted use;
- capture device and approximate conditions;
- varieties and ripeness definitions;
- image counts per class;
- removal and deduplication rules;
- privacy checks;
- split seed and train/validation/test ratios; and
- known imbalance, leakage, or quality risks.

Keep images from the same banana, burst, video, or collection session in one
split. Otherwise near-duplicates can leak into evaluation and inflate reported
accuracy.

## Dataset Validation & Quality Checks

Use `ml/dataset_organizer.py` to validate, audit, and report on the dataset
before starting preprocessing (B6).

### Full Report

```bash
python -m ml.dataset_organizer --report
```

Runs all checks and prints a single summary covering image counts, class
balance, invalid images, duplicates, and stray files.

### Individual Checks

| Command | What it checks |
|---------|----------------|
| `--validate` | Opens every image with Pillow to detect corrupt or unreadable files |
| `--duplicates` | Hashes all images (SHA-256) to find exact-content duplicates across classes |
| `--balance` | Reports per-class counts, min/max/mean, and flags classes below 100 images |
| `--clean` | Lists non-image files and hidden files inside class folders (dry-run only) |

All commands accept `--data-dir <path>` to override the default `ml/data/`.

### Minimum Requirements

- **100 images per class** — classes below this threshold are flagged
- **No empty classes** — the report exits non-zero when any class has 0 images
- **No duplicate images** — identical files across classes inflate training
  counts without adding information
- **No stray files** — non-image files may confuse the preprocessing pipeline

### Workflow

1. Run `python -m ml.dataset_organizer --report` after populating images
2. Address any flagged issues (remove duplicates, fill empty classes, delete
   stray files)
3. Re-run the report until it exits cleanly (exit code 0)
4. Proceed to preprocessing (B6)

## Preprocessing Contract

The app and ML implementation must share one written contract for input width
and height, RGB/BGR order, numeric dtype, normalization range, and any crop or
orientation behavior. Training-only augmentation must not silently become an
on-device preprocessing requirement.

See `ml/inference_contract.py` for the formal model I/O specification:
- Input: `(1, 224, 224, 3)` — RGB, normalized to `[0, 1]`
- Output: `(1, 18)` — probability vector over 18 classes

Tests should cover invalid paths and shapes, deterministic splitting, expected
normalization, and output label order before training artifacts are accepted.

## Generated Artifacts

Checkpoints (`.h5`, `.keras`) and TensorFlow Lite files are ignored by default.
Share experimental outputs through the team-approved artifact store, not Git.

A model may enter `app/assets/model/` only after the team records:

- the training data/split version;
- model and preprocessing configuration;
- validation/test metrics, including per-class results;
- original-versus-TFLite accuracy comparison;
- input/output tensor details;
- exact ordered `labels.txt`; and
- on-device size, latency, and physical-device validation.

Do not rename or reorder labels independently of the app. A label map and model
binary form one versioned release artifact.
