# Manuscript v4 — the two missing figures, and the edits that go with them

Prepared 25 October 2026, checked against `ml/output_crop/` on
`feature/model-on-live-detection`.

**Read [`v4-review.md`](v4-review.md) first.** It already lists every prose edit,
every placeholder value and every contradiction in the manuscript, and I have
re-verified its numbers against the evaluation artefacts — they are correct. This
file does not repeat them. It covers the one thing that review could not give
you: **the two Chapter IV figures, which did not exist until now**, plus one
correction to that review and the replacement text that goes with each figure.

---

## 1. The two figures

Both are generated from the shipped 98.48% model's own artefacts, so they cannot
drift from Table 4.3.

| Figure | File | Replaces |
| --- | --- | --- |
| 4.1 | `ml/output/figure-4-1-confusion-matrix.png` | the yellow `[Insert Figure 4.1 image …]` box on p. 70 |
| 4.2 | `ml/output/figure-4-2-training-curves.png` | the yellow `[Insert Figure 4.2 image …]` box on p. 71 |

Regenerate either with:

```sh
python3 -I docs/thesis-figures/make_figures.py
```

### What they show

**Figure 4.1** is the 19 × 19 confusion matrix: 582 on the diagonal, 9 off it,
every error shown in bold so a reader can find all nine without counting. The
`Not a banana` row reads 61 / 61 with nothing elsewhere on it.

**Figure 4.2** is two panels, accuracy and loss, over the 15 epochs, with a
dashed line at epoch 11 marking the start of fine-tuning. The dip at that epoch
is visible in both panels and recovers within two epochs — worth leaving visible
rather than smoothing, because the text explains it.

---

## 2. ⚠ Correction to `v4-review.md` §5

That section says of `ml/output_crop/confusion_matrix.png`: *"Drop it straight
in."* **Do not.** That image labels the sixth variety **`Cordova`** and writes
**`Senorita`** without the tilde, because those are the internal class names in
`app/assets/model/labels.txt`. The manuscript says **Cardava** and **Señorita**
throughout. Dropping that PNG into Chapter IV would put a seventh variety name
into the thesis on the one page a panelist is most likely to study.

`figure-4-1-confusion-matrix.png` is the same matrix with the labels mapped to
the manuscript's spelling (`Cordova → Cardava`, `Senorita → Señorita`,
`NotBanana → Not a banana`). The counts are untouched.

This does not affect the app: `Cordova` is an internal identifier and the result
screen derives its display text from it. But if you ever regenerate a figure from
the repo, map the names first.

---

## 3. Replacement text — Figure 4.1 (p. 70)

Delete the highlighted sentences beginning *"The model achieved its best results
in classes with the highest correct counts…"* and use:

> The model achieved a perfect result in eight of the nineteen classes, correctly
> classifying every test image of all three Cardava classes, Lakatan unripe and
> overripe, Latundan unripe and overripe, and Señorita overripe. No single pair of
> classes accounted for more than one error. Grouped by variety, however, four of
> the nine errors were confusions between Saba and Cavendish, and three involved
> Latundan ripe, which was the weakest class by recall at 0.900. The negative
> class was classified correctly in all 61 of its test images; no non-banana image
> was mistaken for a banana, and one Latundan ripe image was rejected as a
> non-banana.

The nine errors, one image each:

| True class | Predicted as |
| --- | --- |
| Latundan – Ripe | Lakatan – Ripe |
| Latundan – Ripe | Señorita – Ripe |
| Latundan – Ripe | **Not a banana** |
| Saba – Overripe | Cavendish – Overripe |
| Saba – Ripe | Cavendish – Overripe |
| Saba – Unripe | Cavendish – Unripe |
| Cavendish – Unripe | Saba – Unripe |
| Cavendish – Overripe | Cavendish – Ripe |
| Señorita – Ripe | Señorita – Unripe |

The last sentence of the replacement is worth keeping exactly as written. The one
error the model makes at the negative boundary is in the safe direction: it
declines to name a banana rather than inventing one. That is the answer to the
panel question this figure invites.

---

## 4. Replacement text — Figure 4.2 (p. 71)

Delete the highlighted sentences beginning *"Training accuracy rose to about
value…"* and use:

> Training accuracy rose to 100.0 percent, while validation accuracy reached
> 97.88 percent, with its highest value of 98.21 percent at epoch 14. Validation
> loss fell throughout and reached its lowest value of 0.0641 at the final epoch,
> so the curves converged rather than diverged and no overfitting was observed.
> The brief dip at epoch 11, where validation accuracy fell to 94.94 percent,
> marks the start of fine-tuning, when the last twenty layers of the base model
> were unfrozen; the model recovered within two epochs.

Values behind that paragraph, from `ml/output_crop/training_history.json`:

| | Value |
| --- | --- |
| Final training accuracy (epoch 15) | 1.0000 |
| Final validation accuracy | 0.9788 |
| Best validation accuracy | 0.9821 (epoch 14) |
| Final training loss | 0.0048 |
| Final validation loss | 0.0641 — lowest of the run |
| Validation accuracy at epoch 11 | 0.9494 |

**A correction this forces, on pp. 32 and 69.** Both say the saved weights are
"the one obtained at the end of epoch 15 rather than the epoch with the lowest
validation loss." For this run those are the same epoch — epoch 15 has the
lowest validation loss of all fifteen. Keep the factual half, drop the implied
shortfall:

> No early stopping or checkpoint selection was used, so the weights from the
> final epoch were saved. For this run the final epoch also had the lowest
> validation loss, so no better epoch was passed over.

---

## 5. One number to settle in Table 4.3

`v4-review.md` lists Cavendish – Overripe F1 as **0.945**; the stored value is
**0.9455**, which rounds to 0.946. Either is defensible — just use the same rule
for the whole table. Everything else in that table I re-verified digit for digit.

For the two summary blanks: **macro-averaged F1 = 0.984** (0.9840), weighted
F1 = 0.985 (0.9847).

---

## 6. What still needs you

Neither figure closes these, and no one else can:

- **The ISO 25010 edition contradiction** (`v4-review.md` §2) — still the most
  serious item in the manuscript, and it depends on which questionnaire your 35
  respondents actually answered.
- **Every `0.00` in Tables 4.4–4.19** — survey data I do not have.
- **Who evaluated what** (§10) — three passages disagree on whether IT
  specialists took part.
- **The performance-efficiency target** (p. 27) — needs a timing on a real phone.
- **The four diagrams that still say 18 classes** (§8) — Figures 3.2, 3.3, 3.6
  and 3.7 are images, so they need redrawing, not a text edit. Figure 3.7 also
  shows `Dense(18, …)` with `categorical_crossentropy` where the text says 19
  outputs and sparse categorical cross-entropy.

---

## 7. ⚠ The Colab / GPU claim on p. 60 does not match the reported model

Page 60 says:

> For the development and training of the system model, the researchers utilized
> Google Colab and Jupyter Notebook. Google Colab provided a cloud-based
> environment with access to GPU resources, which accelerated the training process
> of the CNN. Jupyter Notebook was used for interactive development and
> experimentation…

The evidence in this repository says the 98.48% model was trained **locally, on
the CPU**:

```sh
# the saved model records the Keras that wrote it
python3 -c "import zipfile,json; print(json.load(zipfile.ZipFile(
  'ml/output_crop/banana_classifier.keras').open('metadata.json')))"
# {'keras_version': '3.15.1', 'date_saved': '2026-10-16@03:32:34'}

ml/.venv/bin/python -c "import tensorflow as tf, keras, sys; print(sys.version, tf.__version__, keras.__version__)"
# 3.11.13  2.21.0  3.15.1   + "Could not find cuda drivers ... GPU will not be used"
```

- **No notebook exists.** There is no `.ipynb` anywhere in the repository, and no
  reference to Colab, GPU or CUDA in `ml/` or `docs/`.
- **The Keras version matches the local virtualenv exactly** — 3.15.1 — for all
  three trained models (`ml/output`, `ml/output_crop`, `ml/output_lighting`).
- **The output files form one continuous local run.** In `ml/output_crop/`: model
  and history written at 03:32:35, metrics 03:33:06, confusion matrix 03:33:07,
  labels 03:33:26, TFLite validation 03:34:17 — a two-minute pipeline, which is
  what `ml/train.py` → `evaluate.py` → `convert_to_tflite.py` does.
- **This machine has no CUDA drivers**, so the run that produced these files used
  the CPU.

### What to do with the suggestion to run a Colab cell

**Don't.** Running `tf.__version__` / `nvidia-smi` in some Colab notebook would
document an environment that did not produce the model you are reporting. It
would make a wrong claim look sourced, which is worse than leaving it vague.

Replace the p. 60 paragraph with what actually happened:

> The CNN was built and trained with TensorFlow 2.21.0 and Keras 3.15.1 on Python
> 3.11.13, running locally on the researchers' workstation rather than on a hosted
> service. Training was performed on the CPU. Training, evaluation and the
> conversion to TensorFlow Lite were driven by command-line scripts
> (`ml/train.py`, `ml/evaluate.py`, `ml/convert_to_tflite.py`), so that each run
> was reproducible from the same dataset and configuration and the reported model
> can be rebuilt from the repository.

Check the Definition of Terms and the Gantt chart for the same claim before you
submit.

**One thing only you know.** If you did use Colab earlier in the project — for
exploration, or for a run that is not in this repository — then say which stage
used which environment, and make clear that the reported 98.48% model is the
local one. What the manuscript cannot say is that the model it reports was
trained on a Colab GPU, because the artefacts say otherwise.

### Checked and correct: the augmentation claim

While verifying the above I also checked p. 31's claim that "no augmentation
layers were used in the network itself" and that "color changes were avoided
because color is the main indicator of ripeness." Both are **correct** for the
shipped model:

```
ml/output_crop    layers: input, mobilenetv2_1.00_224, GAP, dropout, dense
ml/output_lighting layers: input, random_brightness, random_contrast, mobilenetv2_base, GAP, dropout, dense
```

The `RandomBrightness` and `RandomContrast` layers in `ml/train.py` sit behind an
`augment_lighting` flag and appear only in `ml/output_lighting` (97.97%), which is
**not** the model you ship. No edit needed.
