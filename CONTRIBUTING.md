# Contributing

## Before coding

1. Run the setup command from the repository root.
2. Read `docs/ARCHITECTURE.md` and the guidance for your workspace.
3. Confirm the shared contract before changing a model or service interface.
4. Keep the scope to one coherent change.

Emanuel owns the Flutter app and UI track. Marc Paul owns the dataset and model
track. The inference result shape, bundled labels, model input, and TFLite
integration are shared boundaries and must be coordinated rather than changed
unilaterally. The optional backend supports development-time model management;
the mobile app must never depend on it at runtime.

## Local branches and commits

Use a short branch name such as `feature/camera-capture`,
`fix/permission-message`, or `docs/dataset-layout`. During this initial setup,
the foundation was authorized directly on `main`; subsequent feature work
should use focused branches once the hosted workflow is configured.

Use Conventional Commit subjects:

- `feat: add camera permission flow`
- `fix: reject an invalid confidence value`
- `test: cover low-light scan guidance`
- `docs: record dataset class mapping`
- `chore: update development dependency`

Do not mix formatting-only or unrelated workspace changes into a feature
commit.

## Your code, your tests

Every behavior change includes a test in the same change. Begin with a failing
test when adding a feature or fixing a bug, then implement the smallest behavior
that makes it pass.

- Flutter source under `app/lib/` is tested under the matching area in
  `app/test/`.
- ML behavior is tested in `ml/tests/`.
- FastAPI behavior is tested in `backend/tests/`.
- A bug fix includes a regression test that would fail without the fix.

Run the whole shared suite before handing work to another developer:

```powershell
scripts\check.cmd
```

or:

```bash
./scripts/check.sh
```

Do not weaken the 60% Python coverage floor. Flutter coverage is generated at
`app/coverage/lcov.info`; its numeric CI policy will be added with the deferred
hosted automation.

## Workspace rules

### Flutter

- Depend on `InferenceService` and `StorageService`, not concrete adapters in
  screens.
- Keep one primary action per screen and the scan-to-result flow at two taps or
  fewer.
- Use `DesignTokens` and `AppTheme`; do not add one-off colors, spacing, type
  sizes, or undersized touch targets.
- Never expose terms such as inference, class probability, or raw model errors
  to end users.
- Test camera changes on at least one physical Android device before calling
  them complete.

### ML

- Use Python 3.11 and the isolated `ml/.venv`.
- Treat class names, label order, input dimensions, normalization, and output
  interpretation as a versioned interface with the Flutter app.
- Keep raw images, augmented data, checkpoints, exports, and notebooks with
  generated output out of Git.
- Record reproducible split and preprocessing decisions in `docs/DATASET.md`.

### Backend

- Use the isolated `backend/.venv`.
- Keep routes thin and put future storage/retraining behavior behind the service
  boundaries.
- Do not add a runtime dependency from the shipped app to this service.
- Do not expose placeholder endpoints that claim an unimplemented operation
  succeeded.

## Definition of done

A change is ready to share when formatting and linting are clean, all tests
pass, new behavior is covered, user-facing text follows the UI guidelines, and
the relevant documentation reflects any changed contract or developer command.
