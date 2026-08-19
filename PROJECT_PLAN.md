# Project Plan
## Banana Variety and Ripeness Classification Using Convolutional Neural Network

**Developers:** Emanuel (App/UI) · Marc Paul (Dataset/Model) — 2 active contributors
**Project owner/monitor:** Rey — repo admin, PR reviews/approvals, progress tracking (not a coding contributor)
**Stack:** Flutter (frontend, offline, on-device TFLite inference) · Python/FastAPI (model training & retraining pipeline, dev-side only) · No runtime backend/database dependency in the shipped app
**Timeline:** 8 weeks (2 months) maximum
**Target users:** Farmers/vendors — assume low tech familiarity. Every design and UX decision below is written around that constraint.

---

## 1. Repository Structure

Monorepo — keeps the mobile app, ML training code, and docs versioned together and easy to coordinate between 2 developers without cross-repo PR juggling.

```
banana-classifier/
├── app/                        # Flutter application
│   ├── lib/
│   │   ├── main.dart
│   │   ├── theme/
│   │   │   ├── app_theme.dart       # single source of truth — see §7
│   │   │   └── design_tokens.dart   # colors, spacing, type scale
│   │   ├── screens/
│   │   │   ├── camera_screen.dart
│   │   │   ├── results_screen.dart
│   │   │   └── history_screen.dart
│   │   ├── services/
│   │   │   ├── inference_service.dart   # TFLite wrapper
│   │   │   └── storage_service.dart     # sqflite/Hive wrapper
│   │   ├── models/
│   │   └── widgets/
│   ├── assets/
│   │   └── model/               # bundled .tflite file + labels.txt
│   ├── test/                    # unit + widget tests
│   └── pubspec.yaml
│
├── ml/                          # Model training (Python, dev-only, not shipped)
│   ├── data/                    # (gitignored — dataset not committed)
│   ├── notebooks/
│   ├── train.py
│   ├── preprocess.py
│   ├── convert_to_tflite.py
│   ├── requirements.txt
│   └── tests/
│
├── backend/                     # FastAPI — retraining/model-mgmt only
│   ├── app/
│   │   ├── main.py
│   │   ├── routers/
│   │   └── services/
│   ├── tests/
│   └── requirements.txt
│
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DATASET.md
│   ├── UI_GUIDELINES.md          # can split §7 out here if it grows
│   └── flowcharts/               # exported PDFs/diagrams for the paper
│
├── .github/
│   ├── workflows/
│   │   ├── flutter-ci.yml
│   │   ├── python-ci.yml
│   │   └── pr-checks.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── ISSUE_TEMPLATE/
│
├── .gitignore
├── CONTRIBUTING.md
└── README.md
```

---

## 2. GitHub Repository Setup

### 2.1 Initial setup (Rey does this once)
1. Create repo (private, until ready to make public/for submission)
2. Add Emanuel and Marc Paul as collaborators with **Write** role. Rey holds **Admin** as project owner/monitor
3. Create the folder structure above with placeholder `README.md` files in each directory
4. Add a root `.gitignore` (Flutter + Python + IDE + dataset folders — see §2.4)
5. Set up branch protection on `main` (see §3)

### 2.2 Branching model

Simplified Git Flow:

| Branch | Purpose | Protected? |
|---|---|---|
| `main` | Always stable, deployable/demo-ready | Yes — see rules below |
| `develop` | Integration branch, where feature branches merge first | Yes (lighter rules) |
| `feature/<short-desc>` | One per task, e.g. `feature/camera-capture-flow` | No |
| `fix/<short-desc>` | Bug fixes | No |
| `experiment/<short-desc>` | Model experiments, not guaranteed to merge | No |

Flow: `feature/*` → PR into `develop` → tested → periodically `develop` → PR into `main` (only when a milestone/sprint is stable).

### 2.3 Naming conventions

- Branches: `feature/tflite-integration`, `fix/camera-permission-crash`, `docs/update-readme`
- Commits: [Conventional Commits](https://www.conventionalcommits.org/) style
  - `feat: add TFLite inference service`
  - `fix: handle null camera permission on Android 13`
  - `docs: update setup instructions`
  - `test: add unit tests for storage_service`
  - `chore: update dependencies`

### 2.4 `.gitignore` essentials
```
# Flutter
**/build/
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
*.iml

# Python
__pycache__/
*.pyc
venv/
.env

# Dataset & large files — never commit raw images
ml/data/
*.h5
*.tflite.bak

# IDE
.vscode/
.idea/

# Secrets
*.env
firebase_options.dart   # if any keys embedded, regenerate per-dev
```

**Important:** raw datasets and trained model checkpoints are large — keep them out of git. Use a shared Google Drive folder or DVC (Data Version Control) if the team wants dataset versioning.

---

## 3. Branch Protection Rules for `main`

Configure under **Settings → Branches → Add branch protection rule** for `main`:

- [x] **Require a pull request before merging** — no direct pushes, even for Rey
- [x] **Require approvals** — minimum **1 approval**. With only Emanuel and Marc Paul writing code, that approval typically comes from Rey (as project owner/monitor) or the other developer
- [x] **Dismiss stale approvals when new commits are pushed** — forces re-review after changes
- [x] **Require status checks to pass before merging** (see CI checks in §4) — non-negotiable:
  - `flutter-analyze`
  - `flutter-test`
  - `python-lint` (for `backend/` and `ml/` changes)
  - `python-test`
- [x] **Require branches to be up to date before merging** — prevents merging a stale branch that passed CI on old code
- [x] **Require conversation resolution before merging** — all PR comments must be marked resolved
- [x] **Do not allow bypassing the above settings** — applies to admins too (toggle "Include administrators")
- [ ] Require signed commits — optional, skip unless the team wants extra rigor

Apply a **lighter version** to `develop` (require PR + passing tests, but approvals optional) so the team can move faster during active work.

---

## 4. Required CI Checks (GitHub Actions)

Every PR into `main` must pass all of these before the merge button unlocks.

### 4.1 `flutter-ci.yml`
```yaml
name: Flutter CI
on:
  pull_request:
    paths:
      - 'app/**'

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'
      - run: flutter pub get
        working-directory: app
      - run: flutter analyze --fatal-infos
        working-directory: app
      - run: flutter test --coverage
        working-directory: app
```

**Required checks this enforces:**
- `flutter analyze` passes with zero errors/warnings (`--fatal-infos` makes info-level lints fail the build too)
- All widget/unit tests pass (`flutter test`)
- Code coverage doesn't regress below an agreed threshold (start at 60%, raise later)

### 4.2 `python-ci.yml`
```yaml
name: Python CI
on:
  pull_request:
    paths:
      - 'backend/**'
      - 'ml/**'

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install -r backend/requirements.txt -r ml/requirements.txt
      - run: pip install ruff pytest pytest-cov
      - run: ruff check backend/ ml/
      - run: pytest backend/tests ml/tests --cov --cov-fail-under=60
```

**Required checks:**
- `ruff` lint passes
- `pytest` — all tests pass
- Coverage threshold enforced (60% minimum, same as Flutter side)

### 4.3 PR template — `.github/PULL_REQUEST_TEMPLATE.md`
```markdown
## What does this PR do?


## Related issue/task


## Type of change
- [ ] New feature
- [ ] Bug fix
- [ ] Refactor
- [ ] Docs
- [ ] Tests

## Checklist
- [ ] I ran `flutter analyze` / `ruff check` locally with no errors
- [ ] I ran tests locally and they pass
- [ ] I added/updated tests for my changes
- [ ] I tested this on a physical device or emulator (for app changes)
- [ ] I followed the UI guidelines in §7 (for UI changes)
- [ ] I updated documentation if needed

## Screenshots/recording (for UI changes)

```

---

## 5. Minimum Testing Requirements Before Any PR to `main`

| Area | Required tests | Tooling |
|---|---|---|
| Flutter — services (`inference_service`, `storage_service`) | Unit tests mocking TFLite/DB calls | `flutter_test`, `mockito` |
| Flutter — screens | Widget tests for camera screen, results screen (at minimum: renders, handles empty/error state) | `flutter_test` |
| Model inference | Test that a known sample image produces expected class within confidence threshold | `pytest` in `ml/tests` |
| FastAPI backend | Endpoint tests (retraining trigger, model upload) | `pytest` + `httpx` |
| Manual (required, not automatable) | Test on at least one physical Android device before merging app UI/camera changes | — |

No PR merges into `main` without: analyzer/lint clean, all automated tests passing, and 1 peer approval — no exceptions, including for Rey.

### 5.1 "Your code, your tests" rule

Hard requirement, not a suggestion: **any PR that adds or changes functionality must include test cases for that change in the same PR.** A PR with zero new/updated tests for new logic should be rejected in review, even if existing tests still pass — passing old tests proves you didn't break anything, not that your new code works.

- New Flutter service/widget → add a matching file under `app/test/` (mirror the `lib/` folder structure)
- New model logic or preprocessing step → add a test under `ml/tests/`
- New FastAPI route → add a test under `backend/tests/`
- Bug fix → add a regression test that fails on the old code and passes on the fix, so it can't silently reappear

### 5.2 One shared test suite, not per-developer folders

Don't split tests by developer — that encourages people to only run/own their own slice. Instead, each dev's tests land in the **same shared folder**, organized by what they test, mirroring the source structure:

```
app/test/
├── services/
│   ├── inference_service_test.dart
│   └── storage_service_test.dart
├── screens/
│   ├── camera_screen_test.dart
│   └── results_screen_test.dart
└── widgets/

ml/tests/
├── test_preprocess.py
├── test_train.py
└── test_tflite_conversion.py

backend/tests/
├── test_retrain_endpoint.py
└── test_model_upload.py
```

Because CI (`flutter test` / `pytest`) always runs the **entire folder**, not just new files, this gives you exactly what enforces cross-developer safety: when Emanuel opens a PR, CI runs his new tests **plus every test Marc Paul has added so far**, and vice versa. If one of them breaks something the other built weeks ago, the PR fails automatically — no manual cross-checking needed.

---

## 6. Local Dev Environment Setup (per developer)

### 6.1 Prerequisites (Emanuel and Marc Paul install)
- Flutter SDK (stable channel) — `flutter doctor` must show no issues
- Android Studio or VS Code with Flutter/Dart extensions
- Python 3.11+ (for `ml/` and `backend/` work)
- Git + GitHub CLI (`gh`) recommended for PR workflow from terminal

### 6.2 First-time setup
```bash
git clone https://github.com/<org>/banana-classifier.git
cd banana-classifier

# Flutter app
cd app
flutter pub get
flutter doctor

# Python (ml + backend) — use separate venvs
cd ../ml
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt

cd ../backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
```

### 6.3 Running the app locally
```bash
cd app
flutter run   # select device/emulator
```

### 6.4 Before pushing any branch
```bash
# Flutter changes
flutter analyze
flutter test

# Python changes
ruff check .
pytest
```

---

## 7. UI/UX Design Rules — Mandatory, Not Optional

**Context driving every rule below:** the primary users are farmers and vendors who are largely non-technical. This is not a general design preference — it's a hard constraint. Any PR touching the UI that violates these rules should be rejected in review, same as a failing test.

### 7.1 Core principle: fewest taps possible

- **Target: app open → result shown in 2 taps maximum** — (1) tap capture button, (2) nothing else; result appears automatically after processing. No confirmation dialogs, no "are you sure you want to scan?" steps.
- **No multi-step wizards, no onboarding tutorial screens** on first launch. If guidance is needed, use a single unobtrusive overlay hint on the camera screen itself (e.g. "Point at banana and tap"), dismissible and never shown again — not a separate tutorial flow.
- **No hamburger menus, no nested navigation, no settings screens buried behind icons.** If history is included, it should be one tap away from the camera screen (a single visible icon/button), not inside a menu.
- **One primary action per screen.** The camera screen has exactly one button that matters: capture. The results screen has exactly one primary action: scan again.

### 7.2 Visual style

- **Modern, flat, card-based design** — rounded corners (12–16px radius), soft shadows, generous white space. No skeuomorphism, no cluttered gradients.
- **Color palette:** limited and consistent — one primary color (suggest a natural green, evoking agriculture/bananas, e.g. `#2E7D32`), one accent, and a neutral background (white/very light gray). Do not introduce ad-hoc colors per screen.
- **Typography:** one font family app-wide (e.g. Inter, Poppins, or Roboto — pick one and lock it in `design_tokens.dart`). Minimum body text size **16sp**, headers **20sp+** — no fine print. Avoid more than 2 font weights (e.g. Regular + Bold only).
- **Icons over text where possible**, but never icon-only for critical actions — always pair an icon with a short, plain-language label (e.g. a camera icon **and** the word "Scan," not just the icon).

### 7.3 Language and content

- **Plain language only — no technical jargon.** Never show raw terms like "confidence score," "inference," or "class probability" to the user. Translate to something a farmer immediately understands, e.g.:
  - Instead of "Confidence: 0.92" → "We're pretty sure" / a simple visual indicator (e.g. filled bars or a simple percentage with a friendly label)
  - Instead of "Classification: Lakatan / Ripe" → large, clear text: **"Lakatan — Ripe"** as the headline of the results screen
- **Error messages must be plain and actionable**, not technical. Instead of "Inference failed: low confidence," use something like: "Couldn't tell clearly — try moving closer or improving lighting," with one large retry button.
- Consider whether labels should be offered in the local language (e.g. Bisaya/Filipino) alongside or instead of English, given the target user base — worth deciding with Marc Paul/Emanuel before Sprint/Phase covering the results screen.

### 7.4 Touch targets and accessibility

- **Minimum touch target size: 48x48dp**, primary actions (capture button) should be larger — **64dp+** and impossible to miscount as anything but the main action (centered, high-contrast, clearly the biggest element on screen).
- **Never rely on color alone** to convey meaning (e.g. ripeness result) — always pair color with text/icon, since some users may have color vision differences and color alone doesn't translate across lighting conditions on cheap phone screens.
- High contrast between text and background at all times — test the app in bright outdoor sunlight conditions specifically, since this app will likely be used outdoors/in fields.

### 7.5 How this is enforced, not just suggested

- All colors, spacing, and font sizes must come from `lib/theme/design_tokens.dart` — **no hardcoded hex colors or font sizes inside individual screen/widget files.** A PR introducing a one-off color or font size outside the token file should be rejected in review.
- The PR template (§4.3) includes a checklist item confirming UI guideline compliance for any UI-touching PR.
- Recommend Emanuel build `design_tokens.dart` and a small set of reusable themed components (`PrimaryButton`, `ResultCard`, etc.) in Week 1 (see §9, task A1/A2 area) so every subsequent screen pulls from the same source instead of reinventing style per screen.

---

## 8. Role Split (2 developers + 1 project owner/monitor)

- **Emanuel — Mobile/UI:** Flutter screens, camera flow, results UI, local storage integration, widget tests, and owns the design token/theme system (§7.5)
- **Marc Paul — ML/Data:** Dataset prep, model training, TFLite conversion, accuracy evaluation, TFLite-Flutter wiring, FastAPI retraining pipeline
- **Rey — Project owner/monitor:** Repo setup and admin, CI/branch-protection configuration, PR review and approval, progress and UI-guideline compliance tracking. Not assigned feature-development tasks.

---

## 9. Task Breakdown — Why This Works With Only 2 Developers

**The trick:** agree on one small shared "contract" before either developer writes real logic — the interface between the app UI and the model.

```dart
// lib/services/inference_service.dart (interface + mock — written together, Day 1)

abstract class InferenceService {
  Future<ClassificationResult> classify(File imageFile);
}

class ClassificationResult {
  final String variety;      // e.g. "Lakatan", "Saba", "Cavendish"
  final String ripeness;     // e.g. "Unripe", "Ripe", "Overripe"
  final double confidence;   // 0.0–1.0
}

// A fake/mock implementation Emanuel can build the entire UI against
// immediately, without needing a trained model:
class MockInferenceService implements InferenceService {
  @override
  Future<ClassificationResult> classify(File imageFile) async {
    await Future.delayed(Duration(milliseconds: 800)); // simulate processing
    return ClassificationResult(variety: "Lakatan", ripeness: "Ripe", confidence: 0.92);
  }
}
```

This one file (~15 minutes of work, done together before splitting) removes all cross-dependency. **Emanuel builds the entire app against `MockInferenceService`.** **Marc Paul builds the real model completely separately**, and only has to implement the same `InferenceService` interface with real TFLite logic. When both are ready, swapping the mock for the real implementation is a **one-line change**:

```dart
final InferenceService inferenceService =
    useRealModel ? TFLiteInferenceService() : MockInferenceService();
```

Apply the same trick to local storage (agree on a `ScanRecord` data model shape upfront).

**The only real sync point** in the entire 8-week timeline is this swap, near the end of the timeline (Week 7 below) — everything else is fully parallel.

---

## 10. Granular Feature Timeline — 8 Weeks

### Track A — Emanuel (App / UI / Experience Layer)

| # | Feature | Est. Time | Week | Depends on |
|---|---|---|---|---|
| A1 | Flutter project skeleton, folder structure, repo scaffolding | 1 day | Wk 1 | None |
| A2 | Design tokens (`design_tokens.dart`) + core themed components per §7 | 1 day | Wk 1 | None |
| A3 | Define `ScanRecord` model + `StorageService` interface | 1 day | Wk 1 | None |
| A4 | (Joint w/ Marc Paul) Define `InferenceService` interface + `MockInferenceService` | 0.5 day | Wk 1 | None |
| A5 | Camera screen — permission handling (Android/iOS) | 1 day | Wk 2 | None |
| A6 | Camera screen — live preview | 1 day | Wk 2 | A5 |
| A7 | Camera screen — capture button (large, single primary action per §7.1) | 1 day | Wk 2 | A6 |
| A8 | Results screen — UI layout (variety, ripeness, plain-language confidence per §7.3) | 2 days | Wk 3 | A2, A4 |
| A9 | Results screen — wire to `MockInferenceService` | 1 day | Wk 3 | A7, A8 |
| A10 | "Scan Again" navigation loop | 1 day | Wk 3 | A9 |
| A11 | Local storage setup (sqflite/Hive) | 1 day | Wk 4 | A3 |
| A12 | Save scan result to local storage | 1 day | Wk 4 | A10, A11 |
| A13 | History screen — list past scans (one tap from camera screen, per §7.1) | 2 days | Wk 4 | A12 |
| A14 | History screen — delete/clear record | 1 day | Wk 4 | A13 |
| A15 | Loading/"Analyzing..." state UI | 1 day | Wk 5 | A9 |
| A16 | Error handling — plain-language messages per §7.3, large retry button | 2 days | Wk 5 | A15 |
| A17 | UI polish pass — full audit against §7 rules (touch targets, contrast, jargon check) | 2 days | Wk 5 | A8, A13 |
| A18 | Widget tests — camera screen | 1 day | Wk 6 | A7 |
| A19 | Widget tests — results screen | 1 day | Wk 6 | A10 |
| A20 | Widget tests — history screen | 1 day | Wk 6 | A14 |
| A21 | **Integration:** swap `MockInferenceService` → real `TFLiteInferenceService` | 1 day | Wk 7 | B13 (Marc Paul) |
| A22 | Device testing on physical Android phone(s), including outdoor sunlight readability check (§7.4) | 2 days | Wk 7 | A21 |
| A23 | Bug fixes from device testing | 2 days | Wk 7–8 | A22 |
| A24 | Final UI/UX pass + buffer | 2 days | Wk 8 | A23 |

**Track A total: ~27 days** (~5.4 weeks of work spread across 8 calendar weeks — built-in slack)

### Track B — Marc Paul (Dataset / Model / ML Layer)

| # | Feature | Est. Time | Week | Depends on |
|---|---|---|---|---|
| B1 | `ml/` project setup, Python env, `requirements.txt` | 1 day | Wk 1 | None |
| B2 | Define target classes (banana varieties × ripeness stages) | 1 day | Wk 1 | None |
| B3 | (Joint w/ Emanuel) Define `InferenceService` interface + output shape | 0.5 day | Wk 1 | None |
| B4 | Dataset sourcing (public datasets + own photo collection) — **start ASAP, see risk note below** | 5 days | Wk 2–3 | B2 |
| B5 | Dataset labeling & organizing (folder-per-class) | 3 days | Wk 3 | B4 |
| B6 | Preprocessing pipeline (resize, augment, normalize) | 2 days | Wk 4 | B5 |
| B7 | Train/validation/test split | 1 day | Wk 4 | B6 |
| B8 | Baseline model training (MobileNetV2 transfer learning) | 3 days | Wk 4–5 | B7 |
| B9 | Model evaluation (accuracy, confusion matrix) | 2 days | Wk 5 | B8 |
| B10 | Hyperparameter tuning / retraining iterations | 4 days | Wk 5–6 | B9 |
| B11 | Convert final model → TFLite | 1 day | Wk 6 | B10 |
| B12 | Validate TFLite accuracy vs. original model | 1 day | Wk 6 | B11 |
| B13 | Implement real `TFLiteInferenceService` in Dart (`tflite_flutter`) matching interface (B3) | 3 days | Wk 6–7 | B12, A4 |
| B14 | Unit tests — preprocessing pipeline | 1 day | Wk 7 | B6 |
| B15 | Unit tests — model output sanity checks | 1 day | Wk 7 | B8 |
| B16 | FastAPI backend skeleton (retraining pipeline, dev-tool only) | 2 days | Wk 7 | B1 |
| B17 | Document model metrics for the paper (accuracy, precision/recall per class) | 1 day | Wk 8 | B9, B10 |
| B18 | Final tuning / bug fixes from integration testing | 2 days | Wk 8 | A22 |

**Track B total: ~34 days** (~6.8 weeks — this is the longer pole; dataset work drives the timeline)

### Combined Week-by-Week View

| Week | Emanuel (Track A) | Marc Paul (Track B) |
|---|---|---|
| **1** | Project setup, design tokens, storage + interface definitions | Env setup, define classes, joint interface definition |
| **2** | Camera screen (permissions, preview, capture) | Dataset sourcing begins |
| **3** | Results screen + mock wiring, scan-again loop | Dataset sourcing continues, labeling |
| **4** | Local storage, history screen (list + delete) | Preprocessing, train/test split, baseline training starts |
| **5** | Loading state, error handling, full UI guideline audit | Baseline training finishes, evaluation, tuning begins |
| **6** | Widget tests (camera, results, history) | Tuning continues, TFLite conversion + validation, Dart integration starts |
| **7** | **Integration** (swap to real model), device testing incl. outdoor readability, bug fixes | Finish Dart integration, unit tests, FastAPI skeleton |
| **8** | Final bug fixes, UI/UX polish, buffer | Document metrics, final tuning, buffer |

### Why this fits 2 months safely

- **Emanuel's track (~27 days)** finishes its independent work by end of Week 6, leaving Weeks 7–8 free for integration, device testing, and polish — no crunch.
- **Marc Paul's track (~34 days)** is the critical path — dataset collection (B4) is the single biggest risk to the timeline. **Start B4 as early as possible in Week 2 (or scout candidate datasets during Week 1)** and treat it as the task to protect most.
- **Weeks 7–8 are the only shared buffer** — reserved for the one real sync point (integration) plus slack for whichever track runs behind.

**Risk flag:** if dataset collection (B4) takes longer than 5 days — common if photographing bananas yourselves rather than using an existing public dataset — that delay pushes directly into Marc Paul's entire downstream chain (B5–B13) and eats into the Week 7 integration buffer.

---

## 11. Full Week-by-Week Checklist

Checkboxes for every feature across both tracks, plus Rey's monitoring tasks each week. Use this as the literal weekly to-do list — check items off as PRs merge.

### Week 1 — Setup & Contracts
**Emanuel**
- [ ] A1 — Flutter project skeleton, folder structure, repo scaffolding
- [ ] A2 — Design tokens (`design_tokens.dart`) + core themed components per §7
- [ ] A3 — Define `ScanRecord` model + `StorageService` interface
- [ ] A4 — (Joint w/ Marc Paul) Define `InferenceService` interface + `MockInferenceService`

**Marc Paul**
- [ ] B1 — `ml/` project setup, Python env, `requirements.txt`
- [ ] B2 — Define target classes (banana varieties × ripeness stages)
- [ ] B3 — (Joint w/ Emanuel) Define `InferenceService` interface + output shape
- [ ] Start scouting/downloading candidate public datasets (de-risk B4 early, per §10 risk note)

**Rey (monitor)**
- [ ] Repo created, folder structure scaffolded, `.gitignore` added
- [ ] Branch protection rules configured on `main` (and lighter rules on `develop`)
- [ ] CI workflows (`flutter-ci.yml`, `python-ci.yml`) added, verified passing on a dummy PR
- [ ] Emanuel and Marc Paul added as collaborators (Write role); local environments verified
- [ ] Both developers briefed on §7 UI rules and §5 testing rules
- [ ] Week 1 tasks logged as GitHub Issues

---

### Week 2 — Camera & Dataset Sourcing
**Emanuel**
- [ ] A5 — Camera screen: permission handling (Android/iOS)
- [ ] A6 — Camera screen: live preview
- [ ] A7 — Camera screen: capture button (large, single primary action)

**Marc Paul**
- [ ] B4 — Dataset sourcing (public datasets + own photo collection) — in progress

**Rey (monitor)**
- [ ] Review/approve Emanuel's camera-screen PRs against §7 (touch target size, single primary action)
- [ ] Check dataset sourcing progress — flag early if B4 is trending past 5 days
- [ ] Confirm CI is catching lint/test failures on real PRs (not just the dummy one)

---

### Week 3 — Results Screen & Dataset Labeling
**Emanuel**
- [ ] A8 — Results screen: UI layout (variety, ripeness, plain-language confidence per §7.3)
- [ ] A9 — Results screen: wire to `MockInferenceService`
- [ ] A10 — "Scan Again" navigation loop

**Marc Paul**
- [ ] B4 — Dataset sourcing — finishing up
- [ ] B5 — Dataset labeling & organizing (folder-per-class)

**Rey (monitor)**
- [ ] Review Results screen copy against §7.3 (no jargon like "confidence score" exposed to user)
- [ ] Sanity-check dataset size/label balance with Marc Paul before preprocessing begins
- [ ] Track whether Week 1–2 tasks are fully merged to `develop`

---

### Week 4 — Local Storage, History & Model Training Start
**Emanuel**
- [ ] A11 — Local storage setup (sqflite/Hive)
- [ ] A12 — Save scan result to local storage
- [ ] A13 — History screen: list past scans (one tap from camera screen)
- [ ] A14 — History screen: delete/clear record

**Marc Paul**
- [ ] B6 — Preprocessing pipeline (resize, augment, normalize)
- [ ] B7 — Train/validation/test split
- [ ] B8 — Baseline model training (MobileNetV2 transfer learning) — started

**Rey (monitor)**
- [ ] Review History screen against §7.1 (must stay one tap away, no nested menus)
- [ ] Confirm `ScanRecord` shape actually matches what Marc Paul's output will need later
- [ ] Mid-project check-in: are both tracks still on pace for Week 7 integration?

---

### Week 5 — Error States, Polish & Model Evaluation
**Emanuel**
- [ ] A15 — Loading/"Analyzing..." state UI
- [ ] A16 — Error handling: plain-language messages per §7.3, large retry button
- [ ] A17 — Full UI guideline audit (touch targets, contrast, jargon check) against §7

**Marc Paul**
- [ ] B8 — Baseline model training — finishing up
- [ ] B9 — Model evaluation (accuracy, confusion matrix)
- [ ] B10 — Hyperparameter tuning / retraining iterations — started

**Rey (monitor)**
- [ ] Sit in on Emanuel's §7 audit pass — sign off before it's marked done
- [ ] Review Marc Paul's evaluation metrics — flag if accuracy is too low to proceed to TFLite conversion
- [ ] Confirm PR template checklist (§4.3) is actually being filled out, not skipped

---

### Week 6 — Tests, TFLite Conversion & Dart Integration Start
**Emanuel**
- [ ] A18 — Widget tests: camera screen
- [ ] A19 — Widget tests: results screen
- [ ] A20 — Widget tests: history screen

**Marc Paul**
- [ ] B10 — Hyperparameter tuning — finishing up
- [ ] B11 — Convert final model → TFLite
- [ ] B12 — Validate TFLite accuracy vs. original model
- [ ] B13 — Implement real `TFLiteInferenceService` in Dart — started

**Rey (monitor)**
- [ ] Confirm coverage threshold (60%) is met across Emanuel's new widget tests
- [ ] Verify TFLite model size/accuracy is acceptable for on-device use before integration week
- [ ] Schedule the Week 7 integration session with both developers

---

### Week 7 — Integration Week (the one real sync point)
**Emanuel**
- [ ] A21 — Integration: swap `MockInferenceService` → real `TFLiteInferenceService`
- [ ] A22 — Device testing on physical Android phone(s), including outdoor sunlight readability check (§7.4)
- [ ] A23 — Bug fixes from device testing — started

**Marc Paul**
- [ ] B13 — Finish Dart `TFLiteInferenceService` integration
- [ ] B14 — Unit tests: preprocessing pipeline
- [ ] B15 — Unit tests: model output sanity checks
- [ ] B16 — FastAPI backend skeleton (retraining pipeline, dev-tool only)

**Rey (monitor)**
- [ ] Actively coordinate the mock→real swap — this is the one week both devs truly depend on each other
- [ ] Review integration PR carefully — this touches both tracks' work at once
- [ ] Run/observe device testing session, confirm outdoor readability is acceptable

---

### Week 8 — Final Polish, Docs & Buffer
**Emanuel**
- [ ] A23 — Bug fixes from device testing — finishing up
- [ ] A24 — Final UI/UX pass + buffer

**Marc Paul**
- [ ] B17 — Document model metrics for the paper (accuracy, precision/recall per class)
- [ ] B18 — Final tuning / bug fixes from integration testing

**Rey (monitor)**
- [ ] Final full-app review against §7 UI rules before considering it demo/submission-ready
- [ ] Confirm all `main`-bound PRs are merged, CI green, no open blocking issues
- [ ] Collect Marc Paul's model metrics + Emanuel's screenshots for the paper/documentation
- [ ] Final go/no-go check against the 2-month deadline

---

## 12. First-Week Checklist (quick-reference summary)

- [ ] Repo created, structure scaffolded, protection rules on `main` configured
- [ ] Emanuel and Marc Paul added as collaborators, local environments verified (`flutter doctor`, `pytest` running)
- [ ] CI workflows added and confirmed passing on a dummy PR
- [ ] `design_tokens.dart` created and both developers briefed on §7 UI rules
- [ ] `CONTRIBUTING.md` written (branch naming, commit convention, PR process — can reuse §2–§5 and §7 of this doc)
- [ ] Week 1 tasks (A1–A4, B1–B3) created as GitHub Issues, assigned per track
- [ ] Dataset collection/labeling plan agreed and started (or dataset scouting started early per the risk note in §10)
