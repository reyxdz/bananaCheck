# Chapters I–III — what needs changing, checked against the repository

Read on 22 October 2026. Every claim below was verified with the command
shown, so you can re-run any of it. Page numbers are the PDF's.

Chapter 3 has almost no highlighted blanks — unlike Chapter 4, it is not
waiting on numbers. What it has instead are **statements that no longer match
the system you built**, and the most serious one is that an entire model class
is missing from the manuscript.

Ordered by how much trouble each would cause in a defence.

---

## 1. The NotBanana class does not appear anywhere in Chapters I–III

This is the big one. The chapters say **eighteen classes** and **3,600
images** throughout. The model you trained, converted and shipped has
**nineteen classes** and was trained on **4,000 images**:

```sh
cat app/assets/model/labels.txt | wc -l      # 19
for d in ml/data/*/; do echo -n "$(basename $d): "; ls "$d" | wc -l; done
```

```
…18 banana classes at 200 each = 3,600
NotBanana: 400
                            total 4,000
```

"3,600 banana images" is **correct**. The problem is that the 400 negative
images, and the class trained on them, are never mentioned — while **Chapter 4
reports on them**, stating 61 negative test images, all correctly recognised.
A reader going from Chapter 3 to Chapter 4 meets a nineteenth class that was
never introduced.

Places that say eighteen or 3,600 and need revising:

| Page | Text |
| --- | --- |
| 11 (Ch II) | "six varieties and three stages, or eighteen classes in total" |
| 21 | Figure 3.2 — "eighteen (18) classes… 3,600 images in total" |
| 24 | Figure 3.6 — "probabilities across the eighteen classes" |
| 26 | "200 images were gathered for each of the eighteen (18) classes" |
| 38 | Technical Background — "3,600… 200 for each of the eighteen classes" |
| 39 | Testing Plan — "the eighteen classes are not equally easy to separate" |
| 40 | Implementation Plan — "3,600 banana images, 200 for each of the eighteen" |

**Do not delete the class to make the chapters fit.** It is a genuine
contribution: it is why the application can say "that is not a banana" instead
of confidently naming a variety for a photograph of a shoe, and Chapter 4 can
show it working perfectly. Add it instead. Suggested paragraph for page 26,
after the sentence about 200 images per class:

> In addition to the eighteen banana classes, a nineteenth class of four
> hundred (400) negative images was gathered, consisting of objects, surfaces
> and other fruit that a user might photograph by mistake. Without such a
> class a classifier must assign every input to one of its known categories,
> and would name a banana variety for a photograph containing no banana at
> all. The complete dataset therefore consists of four thousand (4,000)
> images across nineteen (19) classes.

Two consequences elsewhere:

- **Chapter 1, Objective 1** (page 4) lists only the varieties and ripeness
  levels. Add a sub-item for the negative category, or the objectives do not
  cover a class the system has.
- **Chapter 1, Scope** (page 6) says "Any banana outside these categories…
  will not be classified correctly." Worth adding that non-banana images are
  rejected rather than misclassified, since that is now true and testable.

---

## 2. Chapter II opens with a sentence from a different thesis

Page 10, first paragraph:

> "…particularly those focusing on CNN and **Canine Digestive Health**."

Delete it before anything else. It is the kind of thing a panel reads aloud.

---

## 3. Figure 3.13 contradicts the Scope, the Objectives and the application

Page 35:

> "Images are captured through the device camera only, and the application
> does not accept images from the gallery or from any other source."

This is contradicted by:

- **Page 6 (Scope)** — "Images can be captured through the device camera or
  upload from the gallery"
- **Page 19 (Functional Objective 1)** — "capture a banana through the device
  camera **or upload an image from the device gallery**"
- **The application**, which uses `image_picker` and has a gallery button in
  the camera controls:

```sh
grep -n "ImageSource.gallery" app/lib/screens/camera_screen.dart   # line 72
```

Figure 3.13 is the only place that is wrong. Replace that sentence:

> This page displays the camera view together with a flash toggle, the capture
> button at the centre, and a gallery button for choosing an existing
> photograph. A short on-screen guide prompts the user to frame the banana
> clearly, since lighting, background, angle, and clarity have a noticeable
> effect on classification accuracy.

---

## 4. Scan history is listed as a future feature but is already built

Page 19:

> "features such as multi-language support and **the saving of past scans**
> were considered for future updates"

But **Figure 3.10** (page 31) shows *View History* as a use case for all three
actor types, and the application ships it:

```sh
ls app/lib/screens/history_screen.dart app/lib/services/sqflite_storage_service.dart
grep -n "tooltip: 'History'" app/lib/screens/camera_screen.dart   # line 687
```

Scans are stored locally in SQLite and browsable. Move it out of the
future-updates sentence and into the delivered features — otherwise Figure
3.10 shows a feature the text says you did not build. Multi-language support
genuinely is absent, so that half stands.

---

## 5. Naming is inconsistent in four different ways

| Where | Says | Should be |
| --- | --- | --- |
| Chapters 1–3 body text | **Cardava** | pick one |
| Table 3.1, row label (p. 28) | **Cordova** | pick one |
| `labels.txt`, dataset folders | **Cordova** | pick one |
| Survey, variety list (p. 43) | **Morado** | not a class the model has |
| Survey, Part IV heading (p. 45) | **BANASCAN** | Bananalyze |

The Table 3.1 row is the clearest symptom: the row is headed *Cordova*, its
description opens "Cordova (Cardava) bananas…", and the paragraph underneath
it calls the variety Cardava. Decide on one spelling and apply it to the
manuscript **and** `app/assets/model/labels.txt`, or a reader comparing them
will believe they are different varieties.

**Morado is the serious one.** The questionnaire handed to 35 respondents
names a variety the system does not classify, and omits one it does. If the
respondents answered "how familiar are you with Morado", that is a question
about a variety absent from the study. Say in Chapter 4 how you handled it.

---

## 6. The questionnaire in the appendix is not the instrument Chapter 4 reports

The appendix questionnaire has 22 items (numbered 1–18 then 20–22 — **19 is
missing**). Chapter 4 reports Tables 4.4–4.10 covering **Q1–Q16** and Tables
4.11–4.19 covering an **ISO 25010 instrument with Q1–Q31**.

Neither maps onto the questionnaire printed here. Either the appendix is an
earlier draft, or a second instrument exists that was never included. Attach
the instrument that actually produced the Chapter 4 tables — a panel comparing
them will ask where 31 questions came from.

---

## 7. Non-functional objectives written for a system you did not build

Page 20. Four of the eight describe a server-hosted multi-user application.

**Portability** — "shall be able to run on different operating system
environments" directly contradicts page 7: "developed for Android devices only
and will not run on iOS or desktop platforms." Suggested replacement:

> **Portability.** The application shall install and run on Android devices
> across the supported version range without modification.

**Compatibility** — "run smoothly when accessed by two or more users using
different devices." There is no shared state and no server; two users cannot
contend for anything. Suggested replacement:

> **Compatibility.** The application shall run correctly on Android devices
> of differing screen sizes, camera capabilities and processing power.

**Reliability** — "operational at least 95 percent of the time. Downtime after
failure shall not exceed one hour." An installed APK has no uptime and no
downtime; there is nothing to restore. Suggested replacement:

> **Reliability.** The application shall complete a scan and return a result
> without crashing or stalling, and shall recover to the camera view if a scan
> fails.

**Security** — this one is good, and stronger than it is written.

```sh
grep -i "uses-permission" app/android/app/src/main/AndroidManifest.xml
# <uses-permission android:name="android.permission.CAMERA"/>
```

`CAMERA` is the **only** permission the application declares. There is no
`INTERNET` permission, so the application is not merely designed not to
transmit images — Android will not let it. That is a verifiable claim, and
worth stating in exactly those terms.

---

## 8. Google Colab and Jupyter Notebook (page 38)

```sh
find . -name "*.ipynb"    # no results
```

There is no notebook in the repository. Training is a Python package of
command-line modules — `ml/train.py`, `ml/split.py`, `ml/evaluate.py`,
`ml/convert_to_tflite.py`, `ml/config.py` — run from a terminal with
arguments, which is also what makes the reported results reproducible.

If Colab was genuinely used for some runs, keep the sentence but say so
precisely. If the final model came from the scripts, describe the scripts: it
is the stronger claim, because a panel can ask you to re-run a script but
cannot ask you to re-run a notebook session that no longer exists.

> The CNN was implemented in TensorFlow and Keras as a set of command-line
> Python modules covering dataset splitting, training, evaluation and
> TensorFlow Lite conversion, so that each stage could be re-run with recorded
> arguments and reproduce the reported results.

---

## 9. "Resized to 224 by 224" needs one more clause

Pages 25, 38 and 40 all say the images were resized to 224 × 224. True, but
incomplete in the way that matters most to Chapter 4: the loader
**centre-crops each image to a square first**, then resizes.

```sh
grep -n "crop_to_aspect_ratio" ml/train.py    # lines 296, 305
```

This is not a detail. Training previously squashed rectangular photographs
into squares while the application centre-crops its camera frame, and
correcting exactly that mismatch is what lifted test accuracy from 96.62% to
98.48% and repaired the Saba classes. If Chapter 3 says only "resized", the
Chapter 4 discussion of that fix has nothing to refer back to.

> The images were centre-cropped to a square and then resized to 224 by 224
> pixels, matching the way the application crops the camera frame before
> classification, so that the model sees the same geometry during training and
> during use.

---

## 10. Figure 3.7's description of augmentation (page 25)

Page 25 describes augmentation layers inside the network, between the input
and the rescaling. The shipped model has none: the augmented copies are files
created during dataset preparation, and the training graph only rescales.
(This is the same point as §2 of the Chapter 4 document — fix both together,
with the same wording.)

---

## 11. Smaller items

**Table 3.2 contradicts Table 3.1.** Table 3.2's *Ripe* row says the peel is
"deep golden-brown in Cardava"; Table 3.1's Cordova row says the peel "turns
yellow as the fruit ripens". One of them is wrong.

**The split ratio is never stated.** Chapter 3 describes dividing the data
into three subsets but gives no proportions, while Chapter 4 reports the
counts. Add to page 26: 70/15/15, seed 42, split by whole source group so a
photograph and its augmented copies never land in different subsets
(`ml/split.py` lines 55–57 and `source_group()`).

**Missing figures and tables.** Table 3.3 (Gantt chart) is empty, Figure 3.3
is blank, and Figures 3.2, 3.4, 3.5, 3.6, 3.7 and 3.12–3.16 are all
`[ Insert … here ]` placeholders. I can generate 3.2, 3.7 and the split
diagram from the code if that helps; the UI mock-ups need screenshots from a
device.

**References.** Lu (2020), NE (2023) and Team (2024) are placeholder entries —
all three are cited in the body text, so they must be completed. Ucat & Dela
Cruz (2019) has no venue. Mahesh (2020), Biliran Island (n.d.) and Discover
the Philippines (2022) appear in the list; check each is actually cited, and
remove it if not.

---

## 12. What checks out

Verified so you do not have to defend these from memory:

- Six varieties, three ripeness stages, 200 images each, balanced by design. ✓
- 224 × 224 input, MobileNetV2, TensorFlow Lite, bundled in the APK. ✓
- On-device inference, no account, no login, no image transmitted. ✓
  (and no `INTERNET` permission at all — see §7)
- Camera **and** gallery input. ✓ (everywhere except Figure 3.13)
- Health benefits and consumption recommendation per variety and stage. ✓
  (`app/lib/models/banana_info_data.dart`, `widgets/health_benefits_card.dart`)
- Confidence value shown with the result. ✓
- Home/onboarding with a "Get Started" button, camera page with flash toggle,
  result page, information, About page. ✓ (all six screens exist)
- Updating the model requires releasing a new version of the application. ✓
- Lakatan and Latundan identified in advance as the pair most at risk of
  confusion — and Chapter 4 can now report what actually happened. ✓
