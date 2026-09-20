# Dataset Workspace

Raw images belong in this ignored directory and must never be committed.

## Folder Structure

Use the `Variety_Ripeness` naming convention — one folder per class:

```text
data/
├── Saba_Unripe/
├── Saba_Ripe/
├── Saba_Overripe/
├── Lakatan_Unripe/
├── Lakatan_Ripe/
├── Lakatan_Overripe/
├── Senorita_Unripe/
├── Senorita_Ripe/
├── Senorita_Overripe/
├── Latundan_Unripe/
├── Latundan_Ripe/
├── Latundan_Overripe/
├── Morado_Unripe/
├── Morado_Ripe/
├── Morado_Overripe/
├── Cavendish_Unripe/
├── Cavendish_Ripe/
├── Cavendish_Overripe/
├── Bungulan_Unripe/
├── Bungulan_Ripe/
└── Bungulan_Overripe/
```

## Varieties (7)

| Variety    | Description                          |
|------------|--------------------------------------|
| Saba       | Cooking banana, thick-skinned        |
| Lakatan    | Sweet, golden-yellow when ripe       |
| Senorita   | Small, finger-sized dessert banana   |
| Latundan   | Thin-skinned, mildly sweet           |
| Morado     | Red/purple-skinned variety           |
| Cavendish  | Most common commercial banana        |
| Bungulan   | Fragrant, soft-textured dessert type |

## Ripeness Stages (3)

| Stage    | Visual cues                                  |
|----------|----------------------------------------------|
| Unripe   | Green skin, firm flesh                       |
| Ripe     | Yellow skin (variety-dependent), soft flesh   |
| Overripe | Brown spots/fully brown, very soft flesh     |

## Total Classes

7 varieties × 3 ripeness stages = **21 classes**

Store individual photographs inside the matching leaf folder. The folder names
**must** match the `ALL_CLASSES` order in `ml/classes.py` — use
`validate_dataset_structure()` from `ml/preprocess.py` to verify before training.
