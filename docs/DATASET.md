# Dataset and Model Artifact Rules

## Source images

Raw images live below `ml/data/`, which is ignored by Git except for its
instruction file. Never commit source photos, copied public datasets, augmented
images, train/validation/test outputs, or personal information captured in an
image.

The working layout is variety first, then ripeness stage:

```text
ml/data/
|-- Lakatan/
|   |-- Unripe/
|   |-- Ripe/
|   `-- Overripe/
|-- Saba/
`-- Cavendish/
```

Those names are examples, not an approved final taxonomy. Before collection or
training, the team must record the final variety/ripeness combinations and
their exact label spelling here.

## Required dataset record

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

## Preprocessing contract

The app and ML implementation must share one written contract for input width
and height, RGB/BGR order, numeric dtype, normalization range, and any crop or
orientation behavior. Training-only augmentation must not silently become an
on-device preprocessing requirement.

Tests should cover invalid paths and shapes, deterministic splitting, expected
normalization, and output label order before training artifacts are accepted.

## Generated artifacts

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
