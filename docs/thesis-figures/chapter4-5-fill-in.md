# Chapter IV & V — values for the highlighted blanks

Every number below was read from the repository on 22 October 2026, not
recalled. The command that produced each one is named so you can re-run it.

**Two decisions are yours before you use any of this.** They are in §0.

---

## 0. Decide these first

### 0.1 Which model is this chapter about?

The chapter is written around **96.62%**, and it is internally consistent:
Table 4.3, Figure 4.1 and the Saba discussion all match `ml/output/`, the
original model.

The application now bundles a **different** model at **98.48%**, trained after
a train/serve bug was fixed. Its numbers are different in ways that matter:

| | 96.62% (in the chapter) | 98.48% (in the app) |
| --- | --- | --- |
| Errors / 591 | 20 | 9 |
| Saba_Overripe F1 | 0.619 | 0.977 |
| Saba_Ripe F1 | 0.788 | 0.984 |
| Perfect classes | 10 | 8 |

Either keep the chapter at 96.62% and ship that model, or update the chapter
throughout and ship 98.48%. **Do not mix them** — a chapter reporting 96.62%
beside an app containing a different model is the kind of gap a panel finds.

If you update, the Saba discussion on pages 5 and 7 has to be rewritten: the
Saba weakness is gone, so the explanation offered there no longer applies.
See §5.

### 0.2 Table 4.1 is not quite "gathered"

Every class holds exactly 200 files, but several reach 200 by including
augmented copies of the same photograph. Distinct source photographs per class:

| Class | Files | Distinct photos |
| --- | --- | --- |
| Cordova (all three) | 200 each | **200 each** |
| Lakatan (all three) | 200 each | **200 each** |
| Latundan (all three) | 200 each | **200 each** |
| Señorita (all three) | 200 each | **200 each** |
| Cavendish – Overripe | 200 | **76** |
| Cavendish – Ripe | 200 | **99** |
| Cavendish – Unripe | 200 | **82** |
| Saba – Overripe | 200 | **78** |
| Saba – Ripe | 200 | **91** |
| Saba – Unripe | 200 | **52** |
| Not a banana | 400 | **312** |

```sh
python3 -c "
import re
from pathlib import Path
for d in sorted(Path('ml/data').iterdir()):
    if not d.is_dir() or d.name=='_quarantine': continue
    g={re.sub(r'_Aug_\d+$|_aug\d+$','',p.stem) for p in d.glob('*.jpg')}
    print(d.name, len(list(d.glob('*.jpg'))), len(g))"
```

Table 4.1 is headed *Dataset Gathering Result*, so as written it implies 200
photographs were taken per class. **Say so plainly instead** — the text already
mentions that removed images were "replaced", and this is what that means.
Suggested sentence for page 2:

> Classes for which fewer than 200 usable photographs were obtained were
> brought up to 200 with augmented copies of the photographs already gathered.
> Saba unripe, with 52 distinct photographs, relied on this most heavily, and
> the Cavendish and Saba classes relied on it more than the other varieties.

**This is worth volunteering rather than waiting to be asked**, because it
also gives you a better explanation for the Saba weakness than the one
currently on page 5 (see §5).

### 0.3 A naming inconsistency

The chapter says **Cardava** throughout. The dataset folders, `labels.txt` and
the model's output classes all say **Cordova**. Pick one and make the model's
labels and the manuscript agree, or a reader comparing them will think they are
different varieties.

---

## 1. Table 4.2 — Dataset Split  *(page 2)*

| Subset | Images | Share | Remarks |
| --- | --- | --- | --- |
| Training | **2,796** | **69.9%** | Used to learn the weights |
| Validation | **613** | **15.3%** | Used for tuning and monitoring |
| Testing | 591 | 14.8% | Held out for the final evaluation |
| **TOTAL** | 4,000 | 100% | |

```sh
for d in train val test; do echo -n "$d: "; \
  find ml/data_split/$d -type f -iname "*.jpg" | wc -l; done
```

### "State the number of training and validation images and their shares."

> Of the 4,000 images, 2,796 (69.9 percent) were used for training and 613
> (15.3 percent) for validation, with the remaining 591 (14.8 percent) held out
> for testing.

### "images of the same banana were placed in only one subset; confirm this"

**Confirmed, and verifiable.** `ml/split.py` splits whole *source groups*: a
photograph and every augmented copy derived from it move together
(`source_group()`, line 178). Checked across the actual split:

```
source groups: 3204
groups appearing in more than one split: 0
```

Suggested replacement for the highlighted clause:

> …and images of the same banana were placed in only one subset. This was
> enforced by splitting whole groups, so that a photograph and every augmented
> copy derived from it always fell in the same subset; none of the 3,204 source
> groups appears in more than one subset.

---

## 2. Training setup  *(page 3)*

### "MobileNetV2; confirm"

**Confirmed.** `ml/train.py` `build_model()` uses
`tf.keras.applications.MobileNetV2(include_top=False, weights="imagenet")`,
followed by `GlobalAveragePooling2D`, `Dropout`, and a 19-unit softmax `Dense`.

### "state which layers of the base model were unfrozen"

MobileNetV2 has **154 layers**. Fine-tuning unfroze the **last 20** (indices 134
to 153), which is the final inverted-residual stage from `block_15_expand`
onward plus the closing convolution; the first 134 stayed frozen.

> …in which the last 20 of the 154 layers of the base model were unfrozen and
> trained further at a lower learning rate.

### "at a lower learning rate, if applicable"

**Applicable.** 1 × 10⁻³ in phase one, **1 × 10⁻⁴** in phase two — a tenfold
reduction.

### "optimizer" / "learning rate of value" / "batch size of value"

> The model used the **Adam** optimizer at a learning rate of **0.001**
> (reduced to **0.0001** for fine-tuning) and a batch size of **32**.

Defaults in `ml/config.py`; optimizer at `ml/train.py` lines 359 and 384.

### ⚠ "Callbacks were used … saving the best weights and stopping early"

**This sentence is not true of the code and must be removed or rewritten.**
Both `model.fit()` calls pass only `train_ds`, `validation_data` and `epochs` —
there is no `callbacks` argument anywhere in `ml/`:

```sh
grep -rn "EarlyStopping\|ModelCheckpoint" ml/*.py   # no matches
```

There was no checkpointing and no early stopping. The weights saved are the
**final epoch's**, not the best epoch's. Suggested replacement:

> Training ran for a fixed number of epochs in both phases, and the weights
> from the final epoch were saved. No early stopping or checkpoint selection
> was used, so the reported model is the one obtained at the end of epoch 15
> rather than the epoch with the lowest validation loss.

This is a smaller claim, but it is the true one, and it is consistent with
Figure 4.2, where validation accuracy at epoch 15 (~96%) is slightly below its
best (~97% at epoch 13).

### ⚠ "Images were augmented through flipping and rotation"

True of **dataset preparation**, not of the training pipeline. The augmented
copies exist as files on disk (see §0.2); `ml/train.py` itself only rescales to
[0, 1]. Worth rewording so a reader does not expect augmentation layers in the
network:

> Augmented copies produced by flipping and rotation were created during
> dataset preparation and stored alongside the originals; during training the
> images were rescaled and fed to the network at 224 by 224 pixels.

---

## 3. Figure 4.2 and the 15 epochs

Both phase lengths are correct as written: **epochs 1–10** feature extraction,
**epochs 11–15** fine-tuning (`--epochs 10 --fine-tune-epochs 5`).

Exact end-of-training values from `ml/output/training_history.json`, if you want
to replace the approximations:

| | Value |
| --- | --- |
| Final training accuracy | 0.9996 |
| Final validation accuracy | 0.9788 |
| Best validation accuracy | 0.9821 (epoch 14) |
| Validation accuracy at epoch 11 (fine-tuning begins) | 0.9494 |

Note the dip at epoch 11 is to **94.9%**, not the "about 87 percent" stated on
page 5. Check this against the figure you actually plotted before changing it —
if your figure shows ~87%, it was plotted from a different run than
`ml/output/`, and that discrepancy needs resolving.

---

## 4. "State whether the result meets the minimum accuracy set by the researchers"

**No minimum accuracy target appears anywhere in the repository.** If one was
set in your proposal or Chapter 1, quote it here and compare. If none was set,
say so directly:

> No minimum accuracy threshold was set at the outset of the study, so the
> 96.62 percent test accuracy is reported as an absolute result rather than
> against a predetermined criterion.

Panels generally accept this. What they do not accept is a threshold that
appears for the first time in Chapter 4 and happens to sit just below the
result obtained.

---

## 5. "Confirm this explanation by reviewing the misclassified Saba images"

The explanation currently given — that Saba peel colour changes gradually
between ripe and overripe — **was tested and does not hold.**

Retraining with one change, making the training loader centre-crop images to
a square instead of squashing them (`crop_to_aspect_ratio=True`), moved
Saba_Overripe F1 from **0.619 to 0.977** and Saba_Ripe from **0.788 to 0.984**,
with no relabelling and no new images. A boundary that is genuinely ambiguous in
the fruit cannot be fixed by changing how images are resized.

What was actually wrong: training squashed whole 4:3 and 3:4 photographs into
squares, while the application centre-crops to its camera frame. Saba
photographs are disproportionately landscape, so Saba suffered most from the
distortion.

**If you keep the 96.62% model**, replace the explanation on page 5 with
something defensible, for example:

> A review of the misclassified Saba images found no consistent visual
> boundary problem. The Saba classes are instead supported by the fewest
> distinct photographs in the dataset — 52 for unripe, 78 for overripe and 91
> for ripe, against 200 for each Lakatan, Latundan, Cordova and Señorita class
> — so the model saw fewer genuinely different Saba bananas than any other
> variety.

**If you update to the 98.48% model**, the Saba paragraphs on pages 5 and 7
should be replaced by an account of the geometry fix, and Chapter V's
"errors concentrated in the ripe and overripe stages of Saba" with it.

---

## 6. What I cannot supply

Everything with `0.00` and `Description` is your survey data from the 35
respondents, and the surrounding sentences follow from it:

- Tables 4.4–4.10 (predictive model evaluation, Q1–Q16)
- Tables 4.11–4.19 (ISO 25010, Q1–Q31)
- "had a generally positive understanding", "agreed or strongly agreed",
  "level of agreement", "level of confidence", "level of satisfaction"
- "Identify the highest and lowest rated attributes and state what they imply"
- "Name the highest-rated sub-characteristic" (Table 4.14)
- "Note any area rated lower and what it implies" (Table 4.16)
- "affects or does not affect the ratings" (Table 4.17)
- "Summarize the additional comments or suggestions from respondents"
- Chapter V: both `0.00` overall means, "highest/lowest rated characteristic"

Give me the response sheet and I will compute every mean, map each to its
interpretation band, and draft the surrounding paragraphs.

Two of these do have repo-side answers once you have the means:

- **Table 4.17, Maintainability.** The model is bundled in the APK, so updating
  it requires a new release. True as written.
- **Table 4.16, Security.** Classification is on-device, no image leaves the
  phone, no account, no network permission needed. True as written.

---

## 7. Claims already in the chapter that check out

Verified so you do not have to defend them from memory:

- 591 test images; 22–32 per banana class; 61 negative. ✓
- All 61 negative test images recognised as not a banana. ✓
- TFLite conversion: both models 0.9662, agreement 100%, max probability
  difference 1.4 × 10⁻⁵. ✓ (`ml/output/tflite_validation.json`)
- Ten classes at F1 1.00; seventeen of nineteen at ≥ 0.96. ✓
- 571 of 591 correct, 20 errors. ✓
- Macro average 0.9629 / 0.9592 / 0.9606; weighted F1 0.9661. ✓
- On-device, offline, no account, no image transmitted. ✓
- The app prompts for flash when the scene is dark, and shows "Couldn't tell
  clearly" rather than forcing a variety. ✓
