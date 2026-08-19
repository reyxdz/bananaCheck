# Banana Check

Banana Check is a mobile-first banana variety and ripeness classifier for
farmers and vendors. The shipped Flutter app is designed to run inference on
the device, without a runtime backend or internet connection.

This repository currently contains the **development foundation**, not the
finished eight-week product. The app runs with deterministic mock inference so
app work can proceed before a trained model exists. The ML and model-management
workspaces expose tested boundaries without fabricating data, models, or API
features.

## Start here

Clone the repository, enter its root, and run one setup command.

### Windows

```powershell
git clone https://github.com/reyxdz/bananaCheck.git
cd bananaCheck
scripts\setup.cmd
scripts\check.cmd
```

### macOS or Linux

```bash
git clone https://github.com/reyxdz/bananaCheck.git
cd bananaCheck
./scripts/setup.sh
./scripts/check.sh
```

The setup command resolves Flutter packages and creates separate Python 3.11
virtual environments in `ml/.venv` and `backend/.venv`. The check command runs
formatting, static analysis, linting, tests, and coverage across the monorepo.

## Host prerequisites

These SDKs remain host-level tools and are intentionally not committed:

- Git;
- Flutter stable with its bundled Dart SDK;
- Android SDK platform tools and a supported JDK;
- Python 3.11.x; and
- Xcode on macOS only when building the iOS target.

The foundation was verified with Flutter 3.22.3, Dart 3.4.4, Python 3.11.9,
JDK 17.0.8, and Android Debug Bridge 1.0.41. Run `scripts\preflight.cmd` on
Windows or `./scripts/preflight.sh` on macOS/Linux to inspect the local
toolchain. Windows developers should use the `.cmd` entry points; they handle
machines whose PowerShell script policy is restricted.

## Run a workspace

Flutter app:

```powershell
cd app
flutter run
```

Choose a connected Android device or emulator. iOS builds require macOS and
Xcode. Camera capture, SQLite persistence, and real TFLite inference are future
feature work; the current launch screen deliberately exercises
`MockInferenceService`.

FastAPI development service, from the repository root on Windows:

```powershell
backend\.venv\Scripts\python.exe -m uvicorn backend.app.main:app --reload
```

On macOS/Linux, use `backend/.venv/bin/python` instead. The implemented
verification endpoint is `GET http://127.0.0.1:8000/health`. Model upload and
retraining modules are extension boundaries only and do not expose fake
operations.

The ML commands live in `ml/train.py`, `ml/preprocess.py`, and
`ml/convert_to_tflite.py`. They validate their inputs and stop with actionable
messages until a real dataset or model artifact is supplied.

## Repository map

```text
app/       Flutter Android/iOS app, contracts, theme, mock, and tests
ml/        Python preprocessing/training/conversion boundaries and tests
backend/   Optional FastAPI model-management boundary and tests
docs/      Architecture, dataset, UI, and implementation documentation
scripts/   Cross-platform preflight, setup, and quality-gate commands
```

Read [Architecture](docs/ARCHITECTURE.md),
[Dataset rules](docs/DATASET.md), [UI guidelines](docs/UI_GUIDELINES.md), and
[Contributing](CONTRIBUTING.md) before beginning feature work. The complete
roadmap remains in [PROJECT_PLAN.md](PROJECT_PLAN.md).

GitHub-hosted automation, branch protection, issue templates, and collaborator
configuration remain intentionally deferred. Raw datasets, virtual
environments, secrets, generated models, and build output must not be committed.
