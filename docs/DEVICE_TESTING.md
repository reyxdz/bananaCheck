# A22 — Device Testing Protocol (Physical Android)

Manual test pass required before A23/B18 and before merging app/camera changes
(§5, "Manual — not automatable"). Run it on **at least one physical Android
phone**; an emulator cannot cover the camera, sunlight or orientation checks.

Record outcomes in the results table at the bottom and attach it to the PR.

## 0. Pre-flight (already verified — no need to redo)

| Check | Status |
|---|---|
| `flutter analyze --fatal-infos` | clean |
| `flutter test` | passing |
| Debug APK builds | ✅ `build/app/outputs/flutter-apk/app-debug.apk` |
| `banana_classifier.tflite` inside APK | ✅ 8,976,432 bytes at `assets/flutter_assets/assets/model/` |
| `labels.txt` inside APK | ✅ 273 bytes, same path |
| Native TFLite libs | ✅ `arm64-v8a`, `armeabi-v7a` (plus `x86` for emulators) |
| CAMERA permission declared | ✅ |

Install with:

```bash
cd app
fvm flutter run            # debug build — needed for the DEMO ribbon check below
```

Use a **debug** build: the DEMO ribbon only renders when `kDebugMode` is true.

## 1. Is the real model actually running? (do this first)

Everything else is meaningless if the app silently fell back to the mock.

- [ ] **No orange "DEMO" ribbon** anywhere on screen.
- [ ] `flutter logs` shows **no** `⚠️ DEMO MODE — real TFLite model unavailable`.
- [ ] Scan three *different* bananas — results must differ. The mock always
      returns the identical `Saba / Ripe / 0.92`; if every scan gives exactly
      that, you are on the mock.

**Stop and fix if any of these fail** — do not continue the pass.

## 2. Model behaviour on real fruit

Expected test-set accuracy is **97.0%** (540 held-out images). Per-class metrics
put these classes weakest, so weight the sample toward them:

| Class | F1 | What to watch |
|---|---|---|
| Cavendish_Unripe | 0.862 | confusion with Cavendish_Ripe |
| Saba_Unripe | 0.867 | confusion across Saba ripeness |
| Saba_Ripe | 0.877 | ripeness boundary, not variety |
| Saba_Overripe | 0.906 | ripeness boundary |

- [ ] Scan ≥ 3 bananas per available variety; log predicted vs actual.
- [ ] Specifically probe **Saba ripe vs overripe** — the model's known weak edge.
- [ ] Confirm wrong answers still look *plausible* (right variety, adjacent
      ripeness) rather than nonsensical.

> ⚠️ Caveat for the paper: ~8% of the test set is augmented derivatives, so
> 97.0% is optimistic. Real-world accuracy here is the honest signal — record it.

## 3. Outdoor sunlight readability (§7.4 — the named requirement)

Do this **outdoors in direct midday sun**, not by a window.

- [ ] Result headline ("Lakatan — Ripe") readable at arm's length without shading
      the screen.
- [ ] Confidence indicator distinguishable in glare.
- [ ] Ripeness conveyed by **text/icon, not colour alone** — verify by judging
      the result with the screen washed out.
- [ ] Camera preview usable enough to frame a banana.
- [ ] Repeat at ~50% brightness (farmers often run low battery).

## 4. Camera screen & scan guidance (§7.1, §7.4, §7.9)

- [ ] **2 taps max**: open app → tap shutter → result appears. No extra dialogs.
- [ ] Shutter is unmistakably the primary control (80dp), gallery 56dp.
- [ ] All controls comfortably hittable one-handed (≥48dp).
- [ ] Hint pill cycles correctly: "Point at a banana" → "Looks good, tap Scan"
      → "Too dark, turn on flash" in dim light.
- [ ] Each hint state has its own **icon** (colour is never the only cue).
- [ ] Flash toggles the torch; no-flash phones show a disabled button + message.
- [ ] Note any false "Looks good" on non-bananas (yellow/green objects) — the
      hint is a cheap colour check, thresholds are tunable.

## 5. Gallery upload (§7.8)

- [ ] Gallery button opens the native picker; chosen photo classifies normally.
- [ ] Cancelling the picker does nothing (no error, no navigation).
- [ ] **Portrait photo taken in portrait orientation** classifies as well as a
      landscape one.

> ⚠️ **Known unverified risk — EXIF orientation.** The Python side provably
> ignores EXIF rotation; the Dart decoder's behaviour was not confirmed. If
> portrait photos classify noticeably worse than landscape, EXIF orientation is
> the likely cause — log it as a bug for A23.

## 6. Permissions & failure paths

- [ ] Deny camera permission → plain-language screen with "Allow Camera" plus an
      outlined "Upload a Photo" button; upload still works.
- [ ] Revoke permission from Settings while backgrounded → app recovers sanely.
- [ ] Airplane mode on → everything still works (app must never need network).
- [ ] Scan a non-banana → plain-language "Couldn't tell clearly" per §7.3, with a
      large retry button. No raw error text or stack traces.

## 7. History & persistence

- [ ] Scans appear in History, one tap from the camera screen.
- [ ] Delete/clear works.
- [ ] Force-quit and relaunch → history persists; onboarding does **not** reappear.

## 8. Performance

- [ ] Time from shutter tap to result: ______ s (target: comfortably < 3 s).
- [ ] No ANR/freeze during inference.
- [ ] App size acceptable (debug APK is ~180 MB with all ABIs + symbols; a
      release build with `--split-per-abi` is far smaller — measure that if size
      matters for distribution).

## Results

| Device | Android | Tester | Date |
|---|---|---|---|
|  |  |  |  |

| § | Area | Pass/Fail | Notes |
|---|---|---|---|
| 1 | Real model running |  |  |
| 2 | Accuracy on real fruit |  |  |
| 3 | Outdoor readability |  |  |
| 4 | Camera + scan guidance |  |  |
| 5 | Gallery upload |  |  |
| 6 | Permissions / errors |  |  |
| 7 | History |  |  |
| 8 | Performance |  |  |

**Bugs found (feed into A23 / B18):**

1.
2.
