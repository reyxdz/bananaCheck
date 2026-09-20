# Dataset Workspace

Raw images belong in this ignored directory and must never be committed.

## Folder Structure

Use the `Variety_Ripeness` naming convention — one folder per class:

```text
data/
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

## Varieties (6)

| Variety    | Description                          |
|------------|--------------------------------------|
| Cavendish  | Most common commercial banana        |
| Senorita   | Small, finger-sized dessert banana   |
| Latundan   | Thin-skinned, mildly sweet           |
| Cordova    | Regional Philippine cooking variety  |
| Lakatan    | Sweet, golden-yellow when ripe       |
| Saba       | Cooking banana, thick-skinned        |

## Ripeness Stages (3)

| Stage    | Visual cues                                  |
|----------|----------------------------------------------|
| Unripe   | Green skin, firm flesh                       |
| Ripe     | Yellow skin (variety-dependent), soft flesh   |
| Overripe | Brown spots/fully brown, very soft flesh     |

## Total Classes

6 varieties × 3 ripeness stages = **18 classes**

## Minimum Requirements

- **At least 100 images per class** (ideally 200+) for reliable training.
- Accepted formats: `.jpg`, `.jpeg`, `.png`.
- Images should capture varied angles, lighting, and backgrounds.
- Avoid watermarked or heavily filtered images.

## Sourcing Checklist

- [ ] Search public datasets (Kaggle, Roboflow, Google Images)
- [ ] Photograph bananas locally for each variety × ripeness combination
- [ ] Verify class balance — no class should have fewer than 50% of the largest
- [ ] Run `python -m ml.dataset_scaffold --verify` to check folder structure

## Setup

Run the scaffold script to create all 18 class folders:

```bash
cd ml
python -m ml.dataset_scaffold
```

Then place images into the matching `Variety_Ripeness/` folder.

Store individual photographs inside the matching leaf folder. The folder names
**must** match the `ALL_CLASSES` order in `ml/classes.py` — use
`validate_dataset_structure()` from `ml/preprocess.py` to verify before training.
