# Training the model

How to retrain the banana classifier (MobileNetV2 transfer learning) and turn
it into the `.tflite` file the app uses.

All commands run from the repository root and use the ML virtualenv. On
Windows, replace `ml/.venv/bin/python` with `ml\.venv\Scripts\python.exe` and
put each command on one line.

Add `--help` to any command to see every flag.

## 1. Split the dataset

Only needed after adding, removing or moving photos in `ml/data/`. If
`ml/data_split/` already has `train/`, `val/` and `test/`, skip this step.

```bash
ml/.venv/bin/python -m ml.split --data-dir ml/data --output-dir ml/data_split
```

The default split is 70 / 15 / 15 (train / val / test) with a fixed seed, so
the same photos always produce the same split. Add `--symlinks` to link the
images instead of copying them.

## 2. Train

```bash
ml/.venv/bin/python -m ml.train \
  --data-dir ml/data_split \
  --output-dir ml/output \
  --epochs 10 \
  --fine-tune-epochs 5
```

This trains in two phases: 10 epochs on the classification head with
MobileNetV2 frozen, then 5 epochs fine-tuning its top layers. It writes
`banana_classifier.keras` and `training_history.json` to the output directory.

> **Warning:** training overwrites the model in `--output-dir`. To keep the
> current model, copy `ml/output/` first or train into a new folder, such as
> `--output-dir ml/output_v2`.

### Reproducing the bundled model

The model shipped in the app (98.48% test accuracy) was trained without
lighting augmentation. To reproduce it, add:

```bash
  --no-lighting-augmentation
```

Without that flag, random brightness and contrast are applied during training.
That version scored about 97.97%.

### Training flags

| Flag | Default | Meaning |
| --- | --- | --- |
| `--data-dir` | required | Split dataset root (needs `train/` and `val/`) |
| `--output-dir` | required | Where the model and history are saved |
| `--epochs` | 10 | Epochs training the head only |
| `--fine-tune-epochs` | 0 | Fine-tuning epochs afterwards (0 = skip) |
| `--fine-tune-layers` | 20 | MobileNetV2 layers unfrozen for fine-tuning |
| `--batch-size` | 32 | Mini-batch size |
| `--learning-rate` | 1e-3 | Learning rate for the head phase |
| `--fine-tune-lr` | 1e-4 | Learning rate for fine-tuning |
| `--dropout` | 0.2 | Dropout before the classification head |
| `--no-lighting-augmentation` | off | Disable random brightness and contrast |

## 3. Evaluate on the test set

```bash
ml/.venv/bin/python -m ml.evaluate \
  --model-path ml/output/banana_classifier.keras \
  --data-dir ml/data_split \
  --output-dir ml/output
```

This writes `evaluation_metrics.json` and `confusion_matrix.png`.

## 4. Convert to TFLite

```bash
ml/.venv/bin/python -m ml.convert_to_tflite \
  --model ml/output/banana_classifier.keras \
  --output ml/output/banana_classifier.tflite
```

A `labels.txt` file is written next to the `.tflite` model (add `--no-labels`
to skip it). Add `--quantize` for a smaller model with dynamic-range
quantization. If you do, run step 5 to check it is still accurate.

## 5. Validate the TFLite model

```bash
ml/.venv/bin/python -m ml.validate_tflite \
  --keras-model ml/output/banana_classifier.keras \
  --tflite-model ml/output/banana_classifier.tflite \
  --data-dir ml/data_split \
  --output-dir ml/output
```

This compares the TFLite model's predictions with the Keras model's on the test
set. It passes when at least 99% of predictions agree (change this with
`--agreement-threshold`) and writes `tflite_validation.json`. The command exits
with code 1 if validation fails.

## 6. Ship it

Copy `banana_classifier.tflite` and `labels.txt` into `app/assets/model/`.
