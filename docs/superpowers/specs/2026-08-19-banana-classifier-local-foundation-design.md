# Banana Classifier Local Foundation Design

**Date:** 2026-08-19

**Status:** Approved for implementation

**Source:** `PROJECT_PLAN.md`

## Purpose

Create a pull-ready monorepo foundation for the Banana Variety and Ripeness
Classification project. A developer who has the documented host SDKs installed
must be able to clone the repository, run one setup command, open either the
Flutter or Python workspace, and start feature work immediately.

This foundation establishes structure, dependencies, interfaces, development
commands, documentation, and smoke tests. It does not implement the eight-week
feature roadmap.

## Scope

The existing `bananaCheck` directory becomes the monorepo root. The setup will
contain:

- a generated Flutter mobile project under `app/`, targeting Android and iOS;
- Python 3.11 projects under `ml/` and `backend/`, each with an isolated virtual
  environment;
- the planned service contracts, models, design system foundations, and a mock
  inference implementation;
- dependency manifests and resolved lockfiles where the ecosystem supports
  them;
- cross-platform setup and verification commands;
- repository documentation and local Git history; and
- small tests proving that the scaffold installs, imports, starts, and obeys
  its contracts.

## Explicit Non-Goals

The foundation will not include:

- GitHub Actions workflows, branch protection, issue templates, pull request
  templates, collaborators, or other hosted configuration;
- camera capture, live preview, production navigation flows, scan history UI,
  database persistence, or finished results screens;
- dataset collection, labeling, model training, evaluation, or a trained model;
- production TFLite inference;
- retraining or model-upload API behavior beyond structural modules; or
- Docker as a required development path.

## Repository Architecture

```text
bananaCheck/
|-- app/
|   |-- android/
|   |-- ios/
|   |-- assets/model/
|   |-- lib/
|   |   |-- main.dart
|   |   |-- models/
|   |   |-- screens/
|   |   |-- services/
|   |   |-- theme/
|   |   `-- widgets/
|   |-- test/
|   `-- pubspec.yaml
|-- ml/
|   |-- data/
|   |-- notebooks/
|   |-- tests/
|   |-- train.py
|   |-- preprocess.py
|   |-- convert_to_tflite.py
|   `-- requirements.txt
|-- backend/
|   |-- app/
|   |   |-- routers/
|   |   |-- services/
|   |   `-- main.py
|   |-- tests/
|   `-- requirements.txt
|-- docs/
|   |-- ARCHITECTURE.md
|   |-- DATASET.md
|   |-- UI_GUIDELINES.md
|   `-- flowcharts/
|-- scripts/
|-- .editorconfig
|-- .gitignore
|-- CONTRIBUTING.md
|-- PROJECT_PLAN.md
`-- README.md
```

The Flutter generator may add required platform and tool files within `app/`.
Generated desktop and web targets are excluded because the shipped product is a
mobile app.

## Flutter Foundation

The Flutter project will compile and start without a dataset or TFLite model.
It will use `MockInferenceService` as its safe development implementation.

The foundational source files are:

- `design_tokens.dart`: the only source for application colors, spacing,
  radii, touch-target sizes, and type sizes;
- `app_theme.dart`: Material theme construction from the design tokens;
- `classification_result.dart`: variety, ripeness, and normalized confidence;
- `scan_record.dart`: the agreed persistence boundary for a completed scan;
- `inference_service.dart`: the asynchronous classification contract;
- `mock_inference_service.dart`: deterministic sample behavior for UI work;
- `storage_service.dart`: the asynchronous scan-history persistence contract;
- small reusable `PrimaryButton` and `ResultCard` foundations; and
- compiling placeholder camera, results, and history screens that communicate
  their development status without pretending the features are complete.

The dependency manifest will include the planned camera and permission tools,
TFLite runtime, SQLite storage, path utilities, lint rules, and test mocking.
Exact compatible dependency versions will be resolved during scaffolding and
recorded in `pubspec.lock`. The exact Flutter and Dart versions used for
successful verification will be recorded in the local setup documentation.

## ML Foundation

The ML project targets Python 3.11. Its dependency manifest will include
TensorFlow, NumPy, Pillow, scikit-learn, and the plotting/metrics packages needed
by the planned MobileNetV2 workflow. Ruff, pytest, and pytest-cov provide local
quality checks.

`preprocess.py`, `train.py`, and `convert_to_tflite.py` will be importable command
entry points with documented boundaries. They will validate required inputs and
report that feature implementation or data is missing instead of fabricating
training output. The ignored `ml/data/` directory will retain a committed README
that documents the future class-folder layout. The notebooks directory will
contain guidance but no generated notebook output.

## Backend Foundation

The backend also targets Python 3.11 in its own virtual environment. Its runtime
dependencies will include FastAPI, Uvicorn, Pydantic, multipart support, and
HTTPX-compatible test support. Ruff, pytest, and pytest-cov provide local checks.

The application will expose a real `/health` endpoint so developers can verify
the service. Retraining and model-management router/service modules will be
present as documented extension points, but no endpoint will claim those
operations work until their scheduled implementation.

## Contracts and Future Data Flow

The app boundary is:

```text
camera input
  -> InferenceService
  -> ClassificationResult
  -> result presentation
  -> StorageService
  -> history presentation
```

The foundation defines these contracts and validates the mock result. Feature
developers later provide the camera, SQLite, presentation, and TFLite adapters
without changing the consumer-facing interfaces.

The ML artifact flow is:

```text
ignored dataset
  -> preprocessing
  -> training and evaluation
  -> TFLite conversion
  -> app/assets/model/
```

The model directory contains instructions and a labels example, not a fake
binary. Consequently, the app remains on mock inference until the real artifact
passes the planned validation work.

## Toolchain and Developer Setup

Host SDKs cannot be stored in source control. The repository will instead make
their requirements executable and visible:

- Flutter stable 3.x and its matching Dart SDK;
- Android SDK/platform tools plus a supported JDK;
- Xcode only for developers building iOS on macOS;
- Python 3.11.x; and
- Git.

PowerShell and POSIX setup scripts will:

1. check required host executables and versions;
2. install Flutter packages;
3. create `ml/.venv` and `backend/.venv` with Python 3.11;
4. install each Python project's dependencies; and
5. print the commands for running and verifying each subsystem.

They will never silently use Python 3.10 or merge the two Python environments.
If a host prerequisite is absent, setup stops with a precise remediation
message. The current workstation's Python 3.10 default must therefore be
supplemented with Python 3.11 before Python setup can pass.

## Error Handling

- The Flutter scaffold does not load a nonexistent model and therefore starts
  with mock inference reliably.
- Missing dataset/model paths in ML entry points produce actionable messages and
  a nonzero process exit, without partial artifacts.
- The backend health check has no model or dataset dependency.
- Setup scripts stop at the failed subsystem, identify the failed command, and
  leave already-created virtual environments recoverable for a rerun.
- No secrets, raw images, generated models, virtual environments, build output,
  or IDE state are committed.

## Verification Design

The root verification scripts run the same checks developers should run before
sharing changes:

- Flutter formatting check, `flutter analyze`, and `flutter test`;
- Ruff and pytest with coverage for `ml/`; and
- Ruff and pytest with coverage for `backend/`.

Initial Flutter tests cover app startup, design-token/theme availability,
contract model validation, and deterministic mock inference. ML tests cover
configuration/input validation and module imports without requiring a dataset.
Backend tests cover application startup and `/health` response shape.

Python coverage starts at the project-plan threshold of 60 percent. Flutter
coverage is generated and documented; automated enforcement of a numeric
Flutter threshold remains a future CI concern because GitHub configuration is
out of scope.

## Local Git Boundary

The directory is a Git repository on `main`, and the approved design plus
scaffold will be committed in logical steps. The user-provided repository at
`https://github.com/reyxdz/bananaCheck.git` is configured as `origin`. Direct
setup work on `main` is explicitly authorized for this initial foundation;
GitHub policy and hosted automation remain deferred.

## Acceptance Criteria

The foundation is complete when:

1. the documented directory and source architecture exists;
2. `app/` resolves dependencies, analyzes cleanly, and passes its tests;
3. both Python 3.11 environments install independently;
4. Ruff and pytest pass for `ml/` and `backend/`, including 60 percent coverage;
5. the FastAPI health endpoint responds correctly in its test client;
6. setup and verification scripts work from the monorepo root;
7. documentation tells a new developer exactly how to begin; and
8. no GitHub-hosted configuration, datasets, trained models, secrets, or
   scheduled product features are included.
