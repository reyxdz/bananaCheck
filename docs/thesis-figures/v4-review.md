# Manuscript v4 — what to change, and the values for the blanks

Checked 25 October 2026 against the repository on
`feature/model-on-live-detection`.

Most of the earlier problems are fixed. The negative class now runs through all
five chapters, Cardava is consistent, Figure 3.13 matches the app, the callbacks
claim is gone, Morado is out of the questionnaire, the references are complete
and the Gantt chart is filled. What follows is what is left.

---

## 1. The app question: nothing to change

`feature/model-on-live-detection` already carries all three things together:

```sh
md5sum app/assets/model/banana_classifier.tflite ml/output_crop/banana_classifier.tflite
# 2ed4b78c6d2522552dcce1e12d4fdf1b   (identical — the 98.48% model is the one shipping)
grep -n "liveClassifier" app/lib/main.dart app/lib/screens/camera_screen.dart
grep -n "cropUpload = autoCropToSubject" app/lib/screens/camera_screen.dart
```

- **98.48% model** — bundled as the app asset, byte-identical to `ml/output_crop/`.
- **Live detection** — `main.dart` passes the TFLite service as `liveClassifier`
  when it implements `LiveFrameClassifier`; the camera screen runs it on the
  reticle area of each frame.
- **Auto-crop** — gallery uploads go through `autoCropToSubject` before
  classification.

Verified on this branch: `flutter analyze --fatal-infos` clean, **435 tests
pass**. The combination has still never run on a physical device — that is the
one remaining check, and only you can do it.

---

## 2. ⚠ The ISO 25010 edition contradicts itself

**This is the most serious thing left.** Chapters I, II and III commit to
**ISO/IEC 25010:2023**, and the Definition of Terms (p. 9) correctly lists its
**nine** characteristics — functional suitability, performance efficiency,
compatibility, **interaction capability**, reliability, security,
maintainability, **flexibility**, safety. The non-functional objectives (p. 26–27)
use exactly those names.

Chapter IV then evaluates the **2011** edition. Page 82 says "eight areas" and
names *Usability* and *Portability*; Tables 4.11–4.19 and their
sub-characteristics are the 2011 set:

| Table | Chapter IV says | 2023 edition says |
| --- | --- | --- |
| 4.14 | **Usability** (appropriateness recognizability, learnability, operability, user error protection, UI aesthetics, accessibility) | **Interaction Capability** |
| 4.18 | **Portability** (adaptability, installability, replaceability) | **Flexibility** |
| p. 82 | "eight areas" | nine characteristics |

A panel reading page 9 and then page 82 will ask which standard you used. Two
ways out, and the choice depends on what your 35 respondents actually answered:

- **If the questionnaire used the 2011 names** (likely — Q1–Q31 match the 2011
  sub-characteristics exactly), change Chapters I–III back to **ISO/IEC
  25010:2011**, with eight characteristics, and drop the sentence about Safety
  being the ninth. This is the honest option and the smaller edit.
- **If you genuinely administered the 2023 set**, rename Table 4.14 to
  *Interaction Capability* and Table 4.18 to *Flexibility* throughout Chapter IV
  and Table 4.19, and change "eight areas" to nine.

Do not leave it split across the chapters.

---

## 3. ⚠ Two objectives have no results section

Objective 5.1 is **whitebox testing (ISO/IEC/IEEE 29119-4:2021)** and Objective 6
is **UTAUT2**. Chapter IV contains neither. Its sections answer objectives 1, 2, 3
and the application, then ISO 25010 — and stop. The abstract promises all three
("Based on whitebox testing, the ISO/IEC 25010:2023 software quality standard,
and the UTAUT2 model").

Every objective needs a results section. Two new headings are required, or the
objectives have to come back down to what you actually did.

**The whitebox half I can answer from the repo.** Structure-based testing exists
and is automated:

```sh
cd app && fvm flutter test --coverage    # 435 tests, all passing
```

The CI workflow gates every pull request on `flutter analyze --fatal-infos`,
`dart format --set-exit-if-changed`, `flutter test --coverage`, and
`ruff check ml backend`. That is statement-level coverage over the application
and ML code, generated as an LCOV report. Suggested wording for p. 62, replacing
*"state the techniques … and the tool or method used"*:

> Whitebox testing was carried out as automated unit and widget tests written
> against the internal structure of the application, executed with the Flutter
> test runner and reported as statement coverage through its LCOV output. The
> suite comprised 435 test cases covering the inference service, the image
> preprocessing and cropping services, the storage layer, and each screen, and
> was run automatically on every change together with static analysis.

Give me the coverage percentage target you want quoted and I will run
`flutter test --coverage` and read the exact figure out of `lcov.info`.

**The UTAUT2 half I cannot.** No UTAUT2 instrument or response data is in the
repo. Tables and a results section have to be written from your sheet.

---

## 4. Table 4.3 — every value, from `ml/output_crop/evaluation_metrics.json`

| Class | Precision | Recall | F1 | Support |
| --- | --- | --- | --- | --- |
| Lakatan – Unripe | 1.000 | 1.000 | 1.000 | 30 |
| Lakatan – Ripe | 0.968 | 1.000 | 0.984 | 30 |
| Lakatan – Overripe | 1.000 | 1.000 | 1.000 | 30 |
| Latundan – Unripe | 1.000 | 1.000 | 1.000 | 30 |
| Latundan – Ripe | 1.000 | 0.900 | 0.947 | 30 |
| Latundan – Overripe | 1.000 | 1.000 | 1.000 | 30 |
| Saba – Unripe | 0.966 | 0.966 | 0.966 | 29 |
| Saba – Ripe | 1.000 | 0.968 | 0.984 | 31 |
| Saba – Overripe | 1.000 | 0.955 | 0.977 | 22 |
| Cavendish – Unripe | 0.969 | 0.969 | 0.969 | 32 |
| Cavendish – Ripe | 0.967 | 1.000 | 0.983 | 29 |
| Cavendish – Overripe | 0.929 | 0.963 | 0.945 | 27 |
| Señorita – Unripe | 0.968 | 1.000 | 0.984 | 30 |
| Señorita – Ripe | 0.967 | 0.967 | 0.967 | 30 |
| Señorita – Overripe | 1.000 | 1.000 | 1.000 | 30 |
| Cardava – Unripe | 1.000 | 1.000 | 1.000 | 30 |
| Cardava – Ripe | 1.000 | 1.000 | 1.000 | 30 |
| Cardava – Overripe | 1.000 | 1.000 | 1.000 | 30 |
| Not a banana | 0.984 | 1.000 | 0.992 | 61 |
| **Overall accuracy** | | | **98.48%** | **591** |
| **Macro-averaged F1** | | | **0.984** | |

Supports total 591 (530 banana + 61 negative), which matches Table 4.2.
Macro precision 0.985, macro recall 0.984. Weighted F1 0.985.

**"The highest F1 scores were obtained by…"** — eight classes scored a perfect
1.000: all three Cardava classes, all three Latundan except ripe (unripe and
overripe), Lakatan unripe and overripe, and Señorita overripe. **"the lowest
were obtained by…"** — Cavendish overripe (0.945) and Latundan ripe (0.947).
Every one of the nineteen classes scored at least 0.945.

**"Name the classes that still need refinement"** — Cavendish overripe and
Latundan ripe, followed by Saba unripe (0.966) and Señorita ripe (0.967).

---

## 5. Figure 4.1 — the confusion matrix and its blanks

**The image already exists:** `ml/output_crop/confusion_matrix.png`
(2100 × 1800). Drop it straight in. It is not in git — `ml/output*/` is
ignored — but it is on your disk.

All nine errors, one image each:

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

Replacing the highlighted passage:

> The model achieved a perfect result in eight of the nineteen classes, correctly
> classifying every test image of all three Cardava classes, Lakatan unripe and
> overripe, Latundan unripe and overripe, and Señorita overripe. No single pair
> of classes accounted for more than one error. Grouped by variety, however,
> four of the nine errors were confusions between Saba and Cavendish, and three
> involved Latundan ripe, which was the weakest class by recall at 0.900. The
> negative class was classified correctly in all 61 of its test images; no
> non-banana image was mistaken for a banana, and one Latundan ripe image was
> rejected as a non-banana.

That last sentence answers the blank about the negative class exactly, and it is
worth keeping as written: the error the model does make on the negative boundary
is the safe direction — it declines to name a banana rather than inventing one.

---

## 6. Figure 4.2 — the curve values

From `ml/output_crop/training_history.json`:

| | Value |
| --- | --- |
| Final training accuracy (epoch 15) | **1.0000** |
| Final validation accuracy | **0.9788** |
| Best validation accuracy | **0.9821** (epoch 14) |
| Final training loss | 0.0048 |
| Final validation loss | **0.0641** — the lowest of the run |
| Validation accuracy at epoch 11 (fine-tuning begins) | 0.9494 |

Replacing the highlighted passage:

> Training accuracy rose to 100.0 percent, while validation accuracy reached
> 97.88 percent, with its highest value of 98.21 percent at epoch 14. Validation
> loss fell throughout and reached its lowest value of 0.0641 at the final epoch,
> so the curves converged rather than diverged and no overfitting was observed.
> The brief dip at epoch 11, where validation accuracy fell to 94.94 percent,
> marks the start of fine-tuning, when the last twenty layers of the base model
> were unfrozen; the model recovered within two epochs.

**One correction follows from this.** Page 69 and page 32 both say the saved
weights are "the one obtained at the end of epoch 15 rather than the epoch with
the lowest validation loss." For this run those are the *same epoch* — epoch 15
has the lowest validation loss of all fifteen. Keep the factual half and drop
the implied shortfall:

> No early stopping or checkpoint selection was used, so the weights from the
> final epoch were saved. For this run the final epoch also had the lowest
> validation loss, so no better epoch was passed over.

---

## 7. Remaining placeholders I can fill

**p. 34, "converted to TensorFlow Lite [with/without quantization]"** —
**without**. `ml/convert_to_tflite.py` defaults `quantize: bool = False`, and the
shipped file is 8.98 MB, the float32 size. Quantization is available behind a
`--quantize` flag but was not used.

> The trained Keras model was converted to TensorFlow Lite without quantization,
> preserving the accuracy of the original model exactly. Conversion was validated
> by classifying the full test set with both models: they agreed on 100 percent
> of the 591 images, both scored 98.48 percent, and the largest difference in
> any predicted probability was 1.5 × 10⁻⁵.

(`ml/output_crop/tflite_validation.json`. Worth adding to Chapter IV too — it is
evidence that bundling the model cost nothing, and nowhere in the chapter says so.)

**p. 27, Performance efficiency "target to be confirmed, e.g., five seconds or
less"** — I cannot measure this without a device. Time ten scans on the test
phone and quote the figure. Five seconds is a generous target for MobileNetV2 on
a mid-range phone; measure before committing to it, because a target you exceed
is worse than no target.

**p. 30, "the images were taken with device/camera model and resolution"** —
your capture devices; not recoverable from the repo.

**p. 62, "was not evaluated confirm because"** — stray word, delete "confirm".

---

## 8. Figures whose images contradict the text

The body text was corrected to nineteen classes; four diagrams were not.

| Figure | Image says | Should say |
| --- | --- | --- |
| 3.2 | "Data collection — 3,600 images, 18 classes" | 4,000 images, 19 classes |
| 3.3 | "Softmax 18 classes" and "variety (6) × ripeness (3) = 18 classes" | 19 classes, i.e. 18 banana + 1 negative |
| 3.6 | "Output Layer — Softmax, 18 classes" | 19 |
| 3.7 | `Dense(18, activation='softmax')` | `Dense(19, …)` |

Figure 3.7 has three further mismatches with its own caption and with the code:

- It shows a **Data Augmentation** box (`RandomFlip` → `RandomRotation`) inside
  the network, but the Data Augmentation section on p. 31 states plainly that
  "No augmentation layers were used in the network itself." Remove the box, or
  relabel it as a dataset-preparation step outside the model.
- It shows `loss='categorical_crossentropy'`; p. 32 and the code use
  **sparse** categorical cross-entropy.
- It has no centre-crop step, which is the one preprocessing detail Chapter IV
  turns on. Add it between the input layer and rescaling.

Two text blocks still say eighteen where they now mean nineteen:

- **p. 14 (Ch II)**, "across six varieties and three stages, or eighteen classes
  in total" — true of the study being cited, but reads as yours. Reword to
  "eighteen banana classes, to which this study adds a nineteenth negative class."
- **p. 39 (Figure 3.6 text)**, "probabilities across the eighteen classes" →
  nineteen.

---

## 9. Chapter III still does not mention the centre-crop

Page 30–31, *Image Resizing*, says only that images were "resized to 224 × 224
pixels in RGB". Page 69 of Chapter IV then builds its entire account of the
96.62% → 98.48% improvement on the fact that training **centre-cropped to a
square first**, and Chapter V's recommendations repeat it.

```sh
grep -n "crop_to_aspect_ratio" ml/train.py      # lines 296, 305
```

Chapter III is where the method belongs. Add to the end of *Image Resizing*:

> Before resizing, each image was centre-cropped to a square, matching the way
> the application crops the camera frame before classification, so that the model
> received the same geometry during training as it does in use.

Without this, Chapter IV refers back to a method Chapter III never described.

---

## 10. Who evaluated what — three statements disagree

- **p. 62**: the ISO 25010 and UTAUT2 evaluations involved **35 respondents, one
  agricultural technician and 34 vendors and farmers**.
- **p. 74**: the predictive model evaluation consulted "*number* agricultural
  technicians, *number* experienced banana farmers or vendors, and *number* **IT
  specialists**."
- **p. 83**: "*Number* **IT experts** evaluated the technical characteristics …
  while Usability involved *number* respondents, composed of *number* IT experts,
  *number* agricultural technicians, and *number* farmers, vendors, consumers,
  and students."

The abstract and p. 62 describe one group with no IT specialists in it; pages 74
and 83 describe panels that include them. Settle on who actually answered which
instrument and make all four passages agree. If there were no IT experts, remove
them from pages 74 and 83 rather than leaving a blank that implies a panel you
did not convene.

---

## 11. Smaller items

**Table 4.1's TOTAL row does not add up.** The three ripeness columns total
1,200 each, which is 3,600, but the row total reads 4,000. The 400 negative
images sit in a row with dashes in every column. Either add a fourth column for
the negative class or footnote the total.

**Figure 3.12's caption describes a screen that no longer exists.** The text says
the home page "displays the logo and name of the application and a button labeled
'Start'". The screenshot shows a camera-permission page with *Allow Camera* and
*Upload a Photo*. Page 52 then refers to "after clicking the start button on the
initial page", and page 56's description of the About page starts with "how to
access the application" where the screenshot's step 1 is "Hold one banana inside
the frame." Three captions written for an older build.

**"Seniorita"** on p. 30 — Señorita everywhere else. Also worth knowing: the
app's own `labels.txt` uses `Senorita` without the tilde, and the result screen in
Figure 3.14 renders **"Senorita"**. If you want the ñ on screen I can map the
label to a display name; it is a small change.

**Figure 3.8 is mislabelled.** It is titled *Ground Truth Labels* but the diagram
shows the train/validation/test split. Either retitle it *Dataset Partitioning*
or replace the image.

**p. 33 repeats itself.** The paragraph "The trained model was evaluated on the
testing set using accuracy and F1 score…" appears at the start of *Model
Evaluation* and again after the macro-average formula. Delete the second.

**Appendix B is still only the perception questionnaire** (Q1–21). Chapter IV
reports three other instruments: the predictive model evaluation (Q1–Q16), ISO
25010 (Q1–Q31), and UTAUT2. None is attached. Add them as further appendices.

**Chapter IV's fourth section is titled "Developed Mobile Application"** while
the other three are the objectives verbatim. Retitle it to objective 4 for
consistency.

**Page numbers.** The List of Figures and Tables are off by one to three pages
throughout (Figure 3.2 is listed at 30 but appears on 28; Table 3.1 at 46 but
appears on 44). Page 13 and page 91 each appear twice. Regenerate both lists
after the edits.

---

## 12. Verified as correct

- 4,000 images, 19 classes, 3,600 banana + 400 negative. ✓
- Split 2,796 / 613 / 591, grouped by source photograph, 3,204 groups, none in
  more than one subset. ✓
- 530 banana test images, 22–32 per class, 61 negative. ✓
- MobileNetV2, 154 layers, last 20 unfrozen, Adam, 1e-3 → 1e-4, batch 32,
  10 + 5 epochs, sparse categorical cross-entropy, 19-unit softmax. ✓
- 582 of 591 correct, 9 errors, 98.48%. ✓
- Saba overripe F1 0.977 and Saba ripe 0.984, up from 0.619 and 0.788. ✓
- Distinct photographs per class, including 52 for Saba unripe. ✓
- No `INTERNET` permission; `CAMERA` is the only one declared. ✓
- Camera and gallery input, flash prompt, "Couldn't tell clearly", confidence
  wording and three-bar meter, handling tip, health benefits, history, About. ✓
- Updating the model requires a new release. ✓
