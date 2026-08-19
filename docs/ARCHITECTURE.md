# Architecture

## Product boundary

Banana Check is an offline-first Flutter mobile application. The production
classification path stays on the device; neither scanning nor scan history may
require the FastAPI service or an internet connection.

```text
camera image
    |
    v
InferenceService  --->  ClassificationResult
                              |
                              +--> result presentation
                              |
                              v
                         StorageService  --->  history presentation
```

The interfaces are stable seams. Feature developers can build camera, TFLite,
and SQLite adapters independently while screens and tests continue to use the
same contracts. During foundation work, `MockInferenceService` is the only
wired implementation so the app can start without a fake model file.

## Monorepo boundaries

### `app/`

The Flutter workspace targets Android and iOS only.

- `lib/models/` contains data passed between layers.
- `lib/services/` owns abstract interfaces and future adapters.
- `lib/screens/` owns screen-level presentation and navigation callbacks.
- `lib/widgets/` owns small reusable presentation components.
- `lib/theme/` is the only source of design values and Material theming.
- `assets/model/` accepts only a validated `.tflite` model and its exact labels
  during the future integration milestone.

Screens should receive service dependencies or callbacks. They should not open
the database, load TensorFlow Lite, or know how images are stored.

### `ml/`

The Python 3.11 ML workspace is a development tool and is not shipped in the
mobile app. Its intended artifact flow is:

```text
ignored source images
    -> validated preprocessing and split
    -> training and evaluation
    -> validated TensorFlow Lite conversion
    -> app/assets/model/
```

`preprocess.py`, `train.py`, and `convert_to_tflite.py` currently define and
test input/command boundaries. Dataset acquisition, training, evaluation, and
real export remain scheduled feature work.

### `backend/`

FastAPI is an optional development-time model-management boundary. The real
`/health` route makes startup testable. Model storage and retraining modules are
present as protocols/extension points only. Future routes should delegate to
those services and report unsupported work honestly until implemented.

## Shared model contract

`ClassificationResult` contains:

- `variety`: a displayable name matching the versioned label map;
- `ripeness`: a displayable ripeness stage; and
- `confidence`: a normalized value from 0.0 through 1.0.

`ScanRecord` adds an ID, local image path, result, and scan timestamp. Changing
either shape affects UI, inference, storage, and tests and therefore requires a
coordinated contract change.

Before replacing the mock, the app and ML owners must agree on model input
dimensions, color order, normalization, label order, output tensor shape, and
the rule used to translate model scores into plain-language certainty.

## Dependency direction

Presentation depends on contracts and models. Concrete adapters depend on
platform libraries and implement those contracts. Contracts never import a UI,
database, camera, or TensorFlow implementation.

The mobile app does not import the Python workspaces. Model files are the only
deployment artifact crossing from ML to Flutter. FastAPI is not in the shipped
application data path.

## Current status

The foundation proves compilation, imports, contracts, theme behavior, mock
inference, ML command validation, and backend health. Placeholder screens are
deliberately honest about unfinished camera/history work. Refer to
`PROJECT_PLAN.md` for feature order; the existence of a module does not mean
its roadmap feature is complete.
