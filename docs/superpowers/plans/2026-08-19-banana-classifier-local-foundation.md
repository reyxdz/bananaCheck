# Banana Classifier Local Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a pull-ready Flutter, ML, and FastAPI monorepo foundation that installs, runs, and passes local checks without implementing scheduled product features.

**Architecture:** The repository root coordinates three independently testable workspaces. Flutter owns mobile contracts, mock inference, design foundations, and compiling screen shells; `ml/` owns dataset/model pipeline entry-point boundaries; `backend/` owns a FastAPI health service and future extension boundaries. Root scripts validate host tools, bootstrap isolated dependencies, and run the complete local quality suite.

**Tech Stack:** Flutter 3.x/Dart, Android/iOS, Python 3.11, TensorFlow, FastAPI, Ruff, pytest, PowerShell, POSIX shell, local Git

**Spec:** `docs/superpowers/specs/2026-08-19-banana-classifier-local-foundation-design.md`

## Global Constraints

- Use the existing `bananaCheck` directory as the monorepo root; do not create a nested project root.
- Target Android and iOS only in Flutter; do not generate desktop or web applications.
- Keep Flutter startup independent of datasets and trained model files by using `MockInferenceService`.
- Use Python 3.11.x for both Python projects and create separate `ml/.venv` and `backend/.venv` environments.
- Keep all colors, spacing, radii, type sizes, and touch-target values in `app/lib/theme/design_tokens.dart`.
- Use a minimum body size of 16sp, headers of at least 20sp, touch targets of at least 48dp, and a 64dp primary capture action token.
- Configure only `https://github.com/reyxdz/bananaCheck.git` as `origin`; do not create `.github/` or add hosted repository configuration.
- Do not add datasets, trained models, secrets, generated build output, or scheduled feature implementations.
- Python test coverage must be at least 60 percent in both Python projects.
- Use tests before implementation for domain behavior, widgets, validation, and endpoints.
- Commit after each independently testable task using Conventional Commit messages.

## File Responsibility Map

### Root

- `.gitignore`: Flutter, Python, dataset/model, secret, IDE, and OS exclusions with README exceptions for ignored artifact directories.
- `.editorconfig`: shared whitespace, newline, and indentation behavior.
- `.python-version`: declares Python 3.11 for compatible version managers.
- `pyproject.toml`: shared Ruff defaults for both Python workspaces.
- `scripts/preflight.ps1`, `scripts/preflight.sh`: validate required host tools and Python version.
- `scripts/setup.ps1`, `scripts/setup.sh`: install Flutter packages and create both Python environments.
- `scripts/check.ps1`, `scripts/check.sh`: run all formatting, lint, test, and coverage checks.
- `README.md`: project overview and shortest successful setup path.
- `CONTRIBUTING.md`: local development, test, architecture, and UI rules.

### Flutter

- `app/lib/models/classification_result.dart`: immutable inference output with confidence validation.
- `app/lib/models/scan_record.dart`: immutable scan-history boundary.
- `app/lib/services/inference_service.dart`: file-to-classification interface.
- `app/lib/services/mock_inference_service.dart`: deterministic UI-development adapter.
- `app/lib/services/storage_service.dart`: scan-history persistence interface.
- `app/lib/theme/design_tokens.dart`: all design constants.
- `app/lib/theme/app_theme.dart`: Material theme assembled from tokens.
- `app/lib/widgets/primary_button.dart`: accessible labeled primary action.
- `app/lib/widgets/result_card.dart`: plain-language result summary.
- `app/lib/screens/camera_screen.dart`: runnable foundation landing screen, not camera capture.
- `app/lib/screens/results_screen.dart`: compiling result presentation shell.
- `app/lib/screens/history_screen.dart`: compiling empty-history shell.
- `app/lib/main.dart`: dependency composition and application entry point.

### ML

- `ml/preprocess.py`: preprocessing configuration and dataset-path validation boundary.
- `ml/train.py`: training command boundary and actionable scaffold exit.
- `ml/convert_to_tflite.py`: model-input/output-path validation boundary.
- `ml/requirements.txt`: runtime numerical, ML, image, and metrics dependencies.
- `ml/requirements-dev.txt`: Ruff, pytest, and coverage dependencies.
- `ml/pytest.ini`: ML test and coverage configuration.
- `ml/data/README.md`: expected ignored dataset layout.
- `ml/notebooks/README.md`: notebook hygiene rules.

### Backend

- `backend/__init__.py`: marks the backend workspace as an importable package.
- `backend/app/main.py`: FastAPI application factory and router composition.
- `backend/app/routers/health.py`: real health endpoint.
- `backend/app/routers/models.py`: empty model-management extension router.
- `backend/app/routers/retraining.py`: empty retraining extension router.
- `backend/app/services/model_storage.py`: future model-storage protocol.
- `backend/app/services/retraining.py`: future retraining protocol.
- `backend/requirements.txt`: FastAPI runtime dependencies.
- `backend/requirements-dev.txt`: HTTPX2, Ruff, pytest, and coverage dependencies.
- `backend/pytest.ini`: backend test and coverage configuration.

---

### Task 1: Root Repository Policy and Toolchain Preflight

**Files:**
- Create: `.gitignore`
- Create: `.editorconfig`
- Create: `.python-version`
- Create: `pyproject.toml`
- Create: `scripts/preflight.ps1`
- Create: `scripts/preflight.sh`

**Interfaces:**
- Consumes: host `flutter`, `dart`, `java`, `adb`, and Python 3.11 commands.
- Produces: preflight scripts that exit `0` only when the required local toolchain is available and print discovered versions.

- [ ] **Step 1: Verify that the preflight entry points do not exist yet**

Run:

```powershell
Test-Path scripts\preflight.ps1
Test-Path scripts\preflight.sh
```

Expected: both values are `False`.

- [ ] **Step 2: Create the repository-wide exclusions and editor policy**

Create `.gitignore` with these rules:

```gitignore
# Flutter and Dart
**/build/
**/.dart_tool/
**/.flutter-plugins
**/.flutter-plugins-dependencies
**/*.iml

# Python
**/__pycache__/
**/*.py[cod]
**/.pytest_cache/
**/.ruff_cache/
**/.coverage
**/htmlcov/
**/.venv/
**/venv/

# Dataset and generated model artifacts
ml/data/*
!ml/data/README.md
*.h5
*.keras
*.tflite
!app/assets/model/labels.example.txt
!app/assets/model/README.md

# Environment and secrets
.env
*.env

# IDE and operating system
.idea/
.vscode/
.DS_Store
Thumbs.db
```

Create `.editorconfig`:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.py]
indent_size = 4

[*.md]
trim_trailing_whitespace = false
```

Create `.python-version` containing exactly:

```text
3.11
```

Create `pyproject.toml`:

```toml
[tool.ruff]
target-version = "py311"
line-length = 100
extend-exclude = [".venv", "venv", "ml/data", "app"]

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "SIM"]
```

- [ ] **Step 3: Create the PowerShell preflight script**

Create `scripts/preflight.ps1`:

```powershell
$ErrorActionPreference = 'Stop'

function Require-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH. See README.md prerequisites."
    }
}

@('flutter', 'dart', 'java', 'adb', 'py') | ForEach-Object { Require-Command $_ }

$pythonVersion = & py -3.11 --version 2>&1
if ($LASTEXITCODE -ne 0 -or $pythonVersion -notmatch '^Python 3\.11\.') {
    throw "Python 3.11.x is required. Install it and ensure 'py -3.11' resolves correctly."
}

Write-Host (& flutter --version | Select-Object -First 1)
Write-Host (& dart --version 2>&1)
Write-Host $pythonVersion
Write-Host (& java -version 2>&1 | Select-Object -First 1)
Write-Host (& adb version | Select-Object -First 1)
Write-Host 'Toolchain preflight passed.'
```

- [ ] **Step 4: Create the POSIX preflight script**

Create `scripts/preflight.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command '$1' was not found on PATH. See README.md prerequisites." >&2
    exit 1
  }
}

for command_name in flutter dart java adb python3.11; do
  require_command "$command_name"
done

python_version="$(python3.11 --version 2>&1)"
case "$python_version" in
  "Python 3.11."*) ;;
  *) echo "Python 3.11.x is required; found: $python_version" >&2; exit 1 ;;
esac

flutter --version | head -n 1
dart --version
printf '%s\n' "$python_version"
java -version 2>&1 | head -n 1
adb version | head -n 1
echo 'Toolchain preflight passed.'
```

- [ ] **Step 5: Run the preflight and confirm the known Python mismatch is actionable**

Run:

```powershell
& .\scripts\preflight.ps1
```

Expected before installing Python 3.11: nonzero exit with `Python 3.11.x is required`. After Python 3.11 is installed, rerun and expect `Toolchain preflight passed.`

- [ ] **Step 6: Install the missing Python 3.11 runtime and rerun preflight**

The current workstation exposes only Python 3.10. On Windows, run the Chocolatey package installation in an elevated shell:

```powershell
choco install python311 --yes
refreshenv
py -3.11 --version
& .\scripts\preflight.ps1
```

Expected: `py -3.11 --version` reports Python 3.11.x and preflight prints `Toolchain preflight passed.`. On macOS/Linux, install Python 3.11 with the platform package manager, ensure `python3.11` is on PATH, and run `./scripts/preflight.sh`.

- [ ] **Step 7: Check repository whitespace and commit**

Run:

```powershell
git diff --check
git add .gitignore .editorconfig .python-version pyproject.toml scripts/preflight.ps1 scripts/preflight.sh
git commit -m "chore: add local toolchain preflight"
```

Expected: the diff check is clean and the commit succeeds.

---

### Task 2: Flutter Project, Domain Contracts, and Mock Inference

**Files:**
- Generate: `app/android/`, `app/ios/`, and Flutter tool files
- Modify: `app/pubspec.yaml`
- Modify: `app/analysis_options.yaml`
- Create: `app/assets/model/README.md`
- Create: `app/assets/model/labels.example.txt`
- Create: `app/lib/models/classification_result.dart`
- Create: `app/lib/models/scan_record.dart`
- Create: `app/lib/services/inference_service.dart`
- Create: `app/lib/services/mock_inference_service.dart`
- Create: `app/lib/services/storage_service.dart`
- Create: `app/test/models/classification_result_test.dart`
- Create: `app/test/models/scan_record_test.dart`
- Create: `app/test/services/mock_inference_service_test.dart`

**Interfaces:**
- Consumes: `dart:io File` as the future camera/model adapter boundary.
- Produces: `ClassificationResult`, `ScanRecord`, `InferenceService.classify(File)`, `MockInferenceService.classify(File)`, and the `StorageService` CRUD contract.

- [ ] **Step 1: Generate the mobile-only Flutter workspace**

Run from the repository root:

```powershell
flutter create --platforms=android,ios --org com.bananaclassifier --project-name banana_classifier app
```

Expected: Flutter generates `app/`, resolves the starter dependencies, and reports successful creation.

- [ ] **Step 2: Add the architectural dependencies**

Run:

```powershell
Set-Location app
flutter pub add camera permission_handler tflite_flutter sqflite path_provider path
flutter pub add --dev mocktail
Set-Location ..
```

Expected: `app/pubspec.yaml` and `app/pubspec.lock` contain compatible resolved versions. Keep the generated `flutter_lints` dependency.

- [ ] **Step 3: Register the model asset directory and strengthen analysis**

Add this asset entry beneath the generated Flutter section in `app/pubspec.yaml`:

```yaml
  assets:
    - assets/model/
```

Replace `app/analysis_options.yaml` with:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    always_declare_return_types: true
    avoid_print: true
    prefer_final_locals: true
    sort_constructors_first: true
```

Create `app/assets/model/labels.example.txt`:

```text
Lakatan|Unripe
Lakatan|Ripe
Lakatan|Overripe
Saba|Unripe
Saba|Ripe
Saba|Overripe
Cavendish|Unripe
Cavendish|Ripe
Cavendish|Overripe
```

Create `app/assets/model/README.md` explaining that a validated `.tflite` file and finalized `labels.txt` will be added during model integration, and that the scaffold deliberately uses mock inference.

- [ ] **Step 4: Write failing domain and mock tests**

Create `app/test/models/classification_result_test.dart`:

```dart
import 'package:banana_classifier/models/classification_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts normalized confidence values', () {
    final result = ClassificationResult(
      variety: 'Lakatan',
      ripeness: 'Ripe',
      confidence: 0.92,
    );

    expect(result.variety, 'Lakatan');
    expect(result.ripeness, 'Ripe');
    expect(result.confidence, 0.92);
  });

  test('rejects confidence outside zero to one', () {
    expect(
      () => ClassificationResult(
        variety: 'Lakatan',
        ripeness: 'Ripe',
        confidence: 1.1,
      ),
      throwsArgumentError,
    );
  });
}
```

Create `app/test/services/mock_inference_service_test.dart`:

```dart
import 'dart:io';

import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/services/mock_inference_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns its deterministic configured result', () async {
    final expected = ClassificationResult(
      variety: 'Saba',
      ripeness: 'Unripe',
      confidence: 0.88,
    );
    final service = MockInferenceService(result: expected);

    final actual = await service.classify(File('unused.jpg'));

    expect(actual, same(expected));
  });
}
```

Create `app/test/models/scan_record_test.dart`:

```dart
import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/models/scan_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the agreed scan persistence fields', () {
    final scannedAt = DateTime.utc(2026, 8, 19);
    final result = ClassificationResult(
      variety: 'Lakatan',
      ripeness: 'Ripe',
      confidence: 0.92,
    );

    final record = ScanRecord(
      id: 'scan-1',
      imagePath: 'images/scan-1.jpg',
      result: result,
      scannedAt: scannedAt,
    );

    expect(record.id, 'scan-1');
    expect(record.imagePath, 'images/scan-1.jpg');
    expect(record.result, same(result));
    expect(record.scannedAt, scannedAt);
  });
}
```

- [ ] **Step 5: Run the focused tests to verify they fail**

Run:

```powershell
Set-Location app
flutter test test/models/classification_result_test.dart test/models/scan_record_test.dart test/services/mock_inference_service_test.dart
Set-Location ..
```

Expected: failure because the model and service libraries do not exist.

- [ ] **Step 6: Implement the domain models**

Create `app/lib/models/classification_result.dart`:

```dart
class ClassificationResult {
  ClassificationResult({
    required this.variety,
    required this.ripeness,
    required this.confidence,
  }) {
    if (confidence < 0 || confidence > 1) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'must be between 0.0 and 1.0',
      );
    }
  }

  final String variety;
  final String ripeness;
  final double confidence;
}
```

Create `app/lib/models/scan_record.dart`:

```dart
import 'classification_result.dart';

class ScanRecord {
  ScanRecord({
    required this.id,
    required this.imagePath,
    required this.result,
    required this.scannedAt,
  });

  final String id;
  final String imagePath;
  final ClassificationResult result;
  final DateTime scannedAt;
}
```

- [ ] **Step 7: Implement the service contracts and deterministic mock**

Create `app/lib/services/inference_service.dart`:

```dart
import 'dart:io';

import '../models/classification_result.dart';

abstract interface class InferenceService {
  Future<ClassificationResult> classify(File imageFile);
}
```

Create `app/lib/services/mock_inference_service.dart`:

```dart
import 'dart:io';

import '../models/classification_result.dart';
import 'inference_service.dart';

class MockInferenceService implements InferenceService {
  MockInferenceService({
    this.delay = Duration.zero,
    ClassificationResult? result,
  }) : result = result ??
            ClassificationResult(
              variety: 'Lakatan',
              ripeness: 'Ripe',
              confidence: 0.92,
            );

  final Duration delay;
  final ClassificationResult result;

  @override
  Future<ClassificationResult> classify(File imageFile) async {
    await Future<void>.delayed(delay);
    return result;
  }
}
```

Create `app/lib/services/storage_service.dart`:

```dart
import '../models/scan_record.dart';

abstract interface class StorageService {
  Future<List<ScanRecord>> getRecords();
  Future<void> saveRecord(ScanRecord record);
  Future<void> deleteRecord(String id);
  Future<void> clearRecords();
}
```

- [ ] **Step 8: Run focused tests and analysis**

Run:

```powershell
Set-Location app
dart format lib/models lib/services test/models test/services
flutter analyze
flutter test test/models/classification_result_test.dart test/models/scan_record_test.dart test/services/mock_inference_service_test.dart
Set-Location ..
```

Expected: formatting makes no subsequent changes, analysis is clean, and both test files pass.

- [ ] **Step 9: Commit the Flutter contracts**

Run:

```powershell
git add app
git commit -m "feat: scaffold Flutter domain contracts"
```

Expected: generated mobile files, dependencies, contracts, assets guidance, and tests are committed together.

---

### Task 3: Flutter Design System, Reusable Widgets, and Runnable Shell

**Files:**
- Replace: `app/lib/main.dart`
- Create: `app/lib/theme/design_tokens.dart`
- Create: `app/lib/theme/app_theme.dart`
- Create: `app/lib/widgets/primary_button.dart`
- Create: `app/lib/widgets/result_card.dart`
- Create: `app/lib/screens/camera_screen.dart`
- Create: `app/lib/screens/results_screen.dart`
- Create: `app/lib/screens/history_screen.dart`
- Replace: `app/test/widget_test.dart`
- Create: `app/test/widgets/primary_button_test.dart`

**Interfaces:**
- Consumes: `ClassificationResult` and `InferenceService` from Task 2.
- Produces: `BananaClassifierApp`, token-driven theme/widgets, and compiling screen shells for feature developers.

- [ ] **Step 1: Write failing widget and application tests**

Replace `app/test/widget_test.dart`:

```dart
import 'package:banana_classifier/main.dart';
import 'package:banana_classifier/services/mock_inference_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts on the scan foundation screen', (tester) async {
    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );

    expect(find.text('Banana Check'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });
}
```

Create `app/test/widgets/primary_button_test.dart`:

```dart
import 'package:banana_classifier/theme/design_tokens.dart';
import 'package:banana_classifier/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pairs its icon with a label and meets target height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            icon: Icons.camera_alt,
            label: 'Scan',
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(tester.getSize(find.byType(PrimaryButton)).height,
        greaterThanOrEqualTo(DesignTokens.minimumTouchTarget));
  });
}
```

- [ ] **Step 2: Run the widget tests to verify they fail**

Run:

```powershell
Set-Location app
flutter test test/widget_test.dart test/widgets/primary_button_test.dart
Set-Location ..
```

Expected: failure because the app, tokens, and widget do not exist.

- [ ] **Step 3: Implement tokens and the application theme**

Create `app/lib/theme/design_tokens.dart`:

```dart
import 'package:flutter/material.dart';

abstract final class DesignTokens {
  static const Color primary = Color(0xFF2E7D32);
  static const Color accent = Color(0xFFF9A825);
  static const Color background = Color(0xFFF7F8F4);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1F2A1F);
  static const Color textSecondary = Color(0xFF526052);

  static const double spacingSmall = 8;
  static const double spacingMedium = 16;
  static const double spacingLarge = 24;
  static const double radiusMedium = 16;
  static const double minimumTouchTarget = 48;
  static const double primaryActionSize = 64;
  static const double bodyTextSize = 16;
  static const double headingTextSize = 24;
}
```

Create `app/lib/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

import 'design_tokens.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: DesignTokens.primary,
      primary: DesignTokens.primary,
      secondary: DesignTokens.accent,
      surface: DesignTokens.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: DesignTokens.background,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: DesignTokens.bodyTextSize,
        ),
        titleLarge: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: DesignTokens.headingTextSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: const CardTheme(
        color: DesignTokens.surface,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignTokens.radiusMedium),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement reusable widgets**

Create `app/lib/widgets/primary_button.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: DesignTokens.minimumTouchTarget,
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
```

Create `app/lib/widgets/result_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../models/classification_result.dart';
import '../theme/design_tokens.dart';

class ResultCard extends StatelessWidget {
  const ResultCard({required this.result, super.key});

  final ClassificationResult result;

  String get certaintyLabel {
    if (result.confidence >= 0.85) return "We're pretty sure";
    if (result.confidence >= 0.65) return 'This looks likely';
    return 'Try another photo to be sure';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${result.variety} — ${result.ripeness}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: DesignTokens.spacingSmall),
            Text(certaintyLabel),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implement the screen shells**

Create `app/lib/screens/camera_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../widgets/primary_button.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({
    required this.onScan,
    required this.onHistory,
    super.key,
  });

  final VoidCallback onScan;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingLarge),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Banana Check',
                      style: Theme.of(context).textTheme.titleLarge),
                  TextButton.icon(
                    onPressed: onHistory,
                    icon: const Icon(Icons.history),
                    label: const Text('History'),
                  ),
                ],
              ),
              const Expanded(
                child: Center(
                  child: Text('Point at a banana and tap Scan.'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: DesignTokens.primaryActionSize,
                child: PrimaryButton(
                  icon: Icons.camera_alt,
                  label: 'Scan',
                  onPressed: onScan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Create `app/lib/screens/results_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../models/classification_result.dart';
import '../theme/design_tokens.dart';
import '../widgets/primary_button.dart';
import '../widgets/result_card.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    required this.result,
    required this.onScanAgain,
    super.key,
  });

  final ClassificationResult result;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ResultCard(result: result),
            const SizedBox(height: DesignTokens.spacingLarge),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                icon: Icons.camera_alt,
                label: 'Scan Again',
                onPressed: onScanAgain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Create `app/lib/screens/history_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(DesignTokens.spacingLarge),
          child: Text('Your past scans will appear here.'),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Compose the runnable application**

Replace `app/lib/main.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';

import 'screens/camera_screen.dart';
import 'screens/history_screen.dart';
import 'services/inference_service.dart';
import 'services/mock_inference_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(BananaClassifierApp(inferenceService: MockInferenceService()));
}

class BananaClassifierApp extends StatelessWidget {
  const BananaClassifierApp({required this.inferenceService, super.key});

  final InferenceService inferenceService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banana Check',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _HomeScreen(inferenceService: inferenceService),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({required this.inferenceService});

  final InferenceService inferenceService;

  @override
  Widget build(BuildContext context) {
    return CameraScreen(
      onScan: () async {
        final result = await inferenceService.classify(File('mock-scan.jpg'));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Mock ready: ${result.variety} — ${result.ripeness}. '
              'Camera capture is ready for feature development.',
            ),
          ),
        );
      },
      onHistory: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const HistoryScreen(),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 7: Run focused tests, then all Flutter checks**

Run:

```powershell
Set-Location app
dart format lib test
flutter analyze
flutter test --coverage
Set-Location ..
```

Expected: analysis reports no issues, all domain/widget tests pass, and `app/coverage/lcov.info` is generated.

- [ ] **Step 8: Commit the runnable Flutter foundation**

Run:

```powershell
git add app
git commit -m "feat: add Flutter design foundation"
```

Expected: theme, widgets, screen shells, application composition, and tests are committed.

---

### Task 4: ML Pipeline Boundaries and Tests

**Files:**
- Create: `ml/__init__.py`
- Create: `ml/preprocess.py`
- Create: `ml/train.py`
- Create: `ml/convert_to_tflite.py`
- Create: `ml/requirements.txt`
- Create: `ml/requirements-dev.txt`
- Create: `ml/pytest.ini`
- Create: `ml/data/README.md`
- Create: `ml/notebooks/README.md`
- Create: `ml/tests/test_preprocess.py`
- Create: `ml/tests/test_train.py`
- Create: `ml/tests/test_tflite_conversion.py`

**Interfaces:**
- Consumes: filesystem paths to future datasets and Keras model artifacts.
- Produces: `PreprocessConfig`, `require_directory(Path)`, `TrainingConfig`, `require_model_file(Path)`, and `require_tflite_output(Path)` validation boundaries.

- [ ] **Step 1: Define runtime and development dependencies**

Create `ml/requirements.txt`:

```text
tensorflow>=2.16,<3
numpy>=1.26,<2
Pillow>=10,<12
scikit-learn>=1.5,<2
matplotlib>=3.9,<4
seaborn>=0.13,<1
```

Create `ml/requirements-dev.txt`:

```text
-r requirements.txt
pytest>=8,<9
pytest-cov>=5,<7
ruff>=0.7,<1
```

Create `ml/pytest.ini`:

```ini
[pytest]
testpaths = tests
pythonpath = ..
addopts = -ra --strict-markers --cov=ml --cov-report=term-missing --cov-fail-under=60
```

- [ ] **Step 2: Write failing input-boundary tests**

Create `ml/tests/test_preprocess.py`:

```python
from pathlib import Path

import pytest

from ml.preprocess import PreprocessConfig, require_directory


def test_preprocess_config_rejects_non_positive_dimensions() -> None:
    with pytest.raises(ValueError, match="positive"):
        PreprocessConfig(width=0, height=224)


def test_require_directory_accepts_existing_directory(tmp_path: Path) -> None:
    assert require_directory(tmp_path) == tmp_path.resolve()


def test_require_directory_rejects_missing_path(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="Dataset directory not found"):
        require_directory(tmp_path / "missing")
```

Create `ml/tests/test_train.py`:

```python
from pathlib import Path

import pytest

from ml.train import TrainingConfig, main


def test_training_config_keeps_dataset_and_output_boundaries(tmp_path: Path) -> None:
    config = TrainingConfig(
        data_dir=tmp_path / "data",
        output_dir=tmp_path / "models",
        epochs=10,
    )

    assert config.epochs == 10
    assert config.output_dir.name == "models"


def test_training_config_rejects_non_positive_epochs(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="positive"):
        TrainingConfig(
            data_dir=tmp_path / "data",
            output_dir=tmp_path / "models",
            epochs=0,
        )


def test_training_command_reports_boundary(tmp_path: Path, capsys) -> None:
    exit_code = main(
        [
            "--data-dir",
            str(tmp_path),
            "--output-dir",
            str(tmp_path / "models"),
        ]
    )

    assert exit_code == 2
    assert "Training command boundary is ready" in capsys.readouterr().out
```

Create `ml/tests/test_tflite_conversion.py`:

```python
from pathlib import Path

import pytest

from ml.convert_to_tflite import main, require_model_file, require_tflite_output


def test_require_model_file_rejects_missing_model(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="Model file not found"):
        require_model_file(tmp_path / "model.keras")


def test_require_tflite_output_rejects_wrong_extension(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match=".tflite"):
        require_tflite_output(tmp_path / "model.bin")


def test_conversion_command_reports_boundary(tmp_path: Path, capsys) -> None:
    model_path = tmp_path / "model.keras"
    model_path.write_bytes(b"model")

    exit_code = main(
        [
            "--model",
            str(model_path),
            "--output",
            str(tmp_path / "model.tflite"),
        ]
    )

    assert exit_code == 2
    assert "Conversion command boundary is ready" in capsys.readouterr().out
```

- [ ] **Step 3: Run tests to verify missing-module failures**

Run after the Python 3.11 environment exists:

```powershell
& ml\.venv\Scripts\python -m pytest -c ml\pytest.ini ml\tests
```

Expected: collection errors because the ML modules do not exist.

- [ ] **Step 4: Implement preprocessing validation**

Create an empty `ml/__init__.py`, then create `ml/preprocess.py`:

```python
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class PreprocessConfig:
    width: int = 224
    height: int = 224

    def __post_init__(self) -> None:
        if self.width <= 0 or self.height <= 0:
            raise ValueError("Image dimensions must be positive integers.")


def require_directory(path: Path) -> Path:
    resolved = path.resolve()
    if not resolved.is_dir():
        raise FileNotFoundError(f"Dataset directory not found: {resolved}")
    return resolved
```

- [ ] **Step 5: Implement training and conversion command boundaries**

Create `ml/train.py`:

```python
import argparse
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

from ml.preprocess import require_directory


@dataclass(frozen=True)
class TrainingConfig:
    data_dir: Path
    output_dir: Path
    epochs: int = 10

    def __post_init__(self) -> None:
        if self.epochs <= 0:
            raise ValueError("Training epochs must be positive.")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Train the banana classifier.")
    parser.add_argument("--data-dir", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--epochs", default=10, type=int)
    args = parser.parse_args(argv)

    config = TrainingConfig(args.data_dir, args.output_dir, args.epochs)
    require_directory(config.data_dir)
    print(
        "Training command boundary is ready; "
        "dataset training belongs to the model-development task."
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
```

Create `ml/convert_to_tflite.py`:

```python
import argparse
from collections.abc import Sequence
from pathlib import Path


def require_model_file(path: Path) -> Path:
    resolved = path.resolve()
    if not resolved.is_file():
        raise FileNotFoundError(f"Model file not found: {resolved}")
    return resolved


def require_tflite_output(path: Path) -> Path:
    resolved = path.resolve()
    if resolved.suffix.lower() != ".tflite":
        raise ValueError("TFLite output path must end with .tflite")
    return resolved


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Convert a Keras model to TFLite.")
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)

    require_model_file(args.model)
    require_tflite_output(args.output)
    print(
        "Conversion command boundary is ready; "
        "conversion belongs to the model-development task."
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 6: Document ignored data and notebook conventions**

Create `ml/data/README.md` with the expected hierarchy `variety/ripeness/image.jpg`, the initial example varieties/ripeness labels, and a warning that raw images never belong in Git.

Create `ml/notebooks/README.md` requiring cleared outputs before sharing notebooks and directing reusable logic into Python modules.

- [ ] **Step 7: Run ML lint and tests**

Run:

```powershell
& ml\.venv\Scripts\python -m ruff check ml
& ml\.venv\Scripts\python -m pytest -c ml\pytest.ini ml\tests
```

Expected: Ruff passes; all tests pass; total ML coverage is at least 60 percent.

- [ ] **Step 8: Commit the ML foundation**

Run:

```powershell
git add ml
git commit -m "feat: scaffold ML pipeline boundaries"
```

Expected: manifests, boundaries, documentation, and tests are committed without data or generated models.

---

### Task 5: FastAPI Health Service and Extension Boundaries

**Files:**
- Create: `backend/__init__.py`
- Create: `backend/app/__init__.py`
- Create: `backend/app/main.py`
- Create: `backend/app/routers/__init__.py`
- Create: `backend/app/routers/health.py`
- Create: `backend/app/routers/models.py`
- Create: `backend/app/routers/retraining.py`
- Create: `backend/app/services/__init__.py`
- Create: `backend/app/services/model_storage.py`
- Create: `backend/app/services/retraining.py`
- Create: `backend/requirements.txt`
- Create: `backend/requirements-dev.txt`
- Create: `backend/pytest.ini`
- Create: `backend/tests/test_health.py`
- Create: `backend/tests/test_boundaries.py`

**Interfaces:**
- Consumes: no model or dataset for startup.
- Produces: `create_app() -> FastAPI`, `GET /health`, `ModelStorage` protocol, and `RetrainingService` protocol.

- [ ] **Step 1: Define backend dependencies and test configuration**

Create `backend/requirements.txt`:

```text
fastapi>=0.115,<1
uvicorn[standard]>=0.30,<1
pydantic>=2.9,<3
python-multipart>=0.0.20,<1
```

Create `backend/requirements-dev.txt`:

```text
-r requirements.txt
httpx2>=2.9,<3
pytest>=8,<9
pytest-cov>=5,<7
ruff>=0.7,<1
```

Create `backend/pytest.ini`:

```ini
[pytest]
testpaths = tests
pythonpath = ..
addopts = -ra --strict-markers --cov=backend.app --cov-report=term-missing --cov-fail-under=60
```

- [ ] **Step 2: Write failing endpoint and boundary tests**

Create `backend/tests/test_health.py`:

```python
from fastapi.testclient import TestClient

from backend.app.main import create_app


def test_health_reports_service_ready() -> None:
    client = TestClient(create_app())

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "banana-classifier-model-management",
    }
```

Create `backend/tests/test_boundaries.py`:

```python
from backend.app.routers.models import router as models_router
from backend.app.routers.retraining import router as retraining_router


def test_future_routers_have_stable_prefixes() -> None:
    assert models_router.prefix == "/models"
    assert retraining_router.prefix == "/retraining"
    assert models_router.routes == []
    assert retraining_router.routes == []
```

- [ ] **Step 3: Run tests to verify missing-module failures**

Run after the backend Python 3.11 environment exists:

```powershell
& backend\.venv\Scripts\python -m pytest -c backend\pytest.ini backend\tests
```

Expected: collection errors because the backend package does not exist.

- [ ] **Step 4: Implement the health endpoint and application factory**

Create empty package marker files for `backend`, `backend/app`, `backend/app/routers`, and `backend/app/services`.

Create `backend/app/routers/health.py`:

```python
from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(tags=["health"])


class HealthResponse(BaseModel):
    status: Literal["ok"]
    service: str


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        service="banana-classifier-model-management",
    )
```

Create `backend/app/main.py`:

```python
from fastapi import FastAPI

from .routers import health, models, retraining


def create_app() -> FastAPI:
    app = FastAPI(
        title="Banana Classifier Model Management",
        version="0.1.0",
    )
    app.include_router(health.router)
    app.include_router(models.router, prefix="/api")
    app.include_router(retraining.router, prefix="/api")
    return app


app = create_app()
```

- [ ] **Step 5: Implement explicit empty routers and service protocols**

Create `backend/app/routers/models.py`:

```python
from fastapi import APIRouter

router = APIRouter(prefix="/models", tags=["models"])
```

Create `backend/app/routers/retraining.py`:

```python
from fastapi import APIRouter

router = APIRouter(prefix="/retraining", tags=["retraining"])
```

Create `backend/app/services/model_storage.py`:

```python
from pathlib import Path
from typing import Protocol, runtime_checkable


@runtime_checkable
class ModelStorage(Protocol):
    async def save(self, filename: str, content: bytes) -> Path:
        ...
```

Create `backend/app/services/retraining.py`:

```python
from pathlib import Path
from typing import Protocol, runtime_checkable


@runtime_checkable
class RetrainingService(Protocol):
    async def start(self, dataset_path: Path) -> str:
        ...
```

- [ ] **Step 6: Run backend lint and tests**

Run:

```powershell
& backend\.venv\Scripts\python -m ruff check backend
& backend\.venv\Scripts\python -m pytest -c backend\pytest.ini backend\tests
```

Expected: Ruff passes; health and boundary tests pass; backend coverage is at least 60 percent.

- [ ] **Step 7: Smoke-start FastAPI without model assets**

Run:

```powershell
& backend\.venv\Scripts\python -c "from backend.app.main import app; print(app.title)"
```

Expected output: `Banana Classifier Model Management`.

- [ ] **Step 8: Commit the backend foundation**

Run:

```powershell
git add backend
git commit -m "feat: scaffold model management API"
```

Expected: the health service, empty extension routers, service protocols, manifests, and tests are committed.

---

### Task 6: Cross-Platform Bootstrap and Verification Commands

**Files:**
- Create: `scripts/setup.ps1`
- Create: `scripts/setup.sh`
- Create: `scripts/check.ps1`
- Create: `scripts/check.sh`

**Interfaces:**
- Consumes: Task 1 preflight scripts and all dependency manifests.
- Produces: one setup command and one full verification command per supported shell.

- [ ] **Step 1: Verify setup and check entry points are absent**

Run:

```powershell
Test-Path scripts\setup.ps1
Test-Path scripts\check.ps1
```

Expected: both values are `False`.

- [ ] **Step 2: Create the PowerShell setup script**

Create `scripts/setup.ps1`:

```powershell
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot 'preflight.ps1')

Push-Location (Join-Path $root 'app')
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency installation failed.' }
}
finally {
    Pop-Location
}

function Install-PythonProject {
    param(
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $true)][string]$Requirements
    )

    $environment = Join-Path $root "$Project\.venv"
    & py -3.11 -m venv $environment
    if ($LASTEXITCODE -ne 0) { throw "Could not create $Project virtual environment." }

    $python = Join-Path $environment 'Scripts\python.exe'
    & $python -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) { throw "Could not upgrade pip for $Project." }

    & $python -m pip install -r (Join-Path $root $Requirements)
    if ($LASTEXITCODE -ne 0) { throw "Could not install dependencies for $Project." }
}

Install-PythonProject -Project 'ml' -Requirements 'ml\requirements-dev.txt'
Install-PythonProject -Project 'backend' -Requirements 'backend\requirements-dev.txt'

Write-Host 'Run Flutter: cd app; flutter run'
Write-Host 'Run API: backend\.venv\Scripts\python -m uvicorn backend.app.main:app --reload'
Write-Host 'Verify all: .\scripts\check.ps1'
Write-Host 'Setup complete.'
```

- [ ] **Step 3: Create the POSIX setup script**

Create `scripts/setup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$root_dir/scripts/preflight.sh"

(
  cd "$root_dir/app"
  flutter pub get
)

install_python_project() {
  local project="$1"
  local requirements="$2"
  local environment="$root_dir/$project/.venv"

  python3.11 -m venv "$environment"
  "$environment/bin/python" -m pip install --upgrade pip
  "$environment/bin/python" -m pip install -r "$root_dir/$requirements"
}

install_python_project ml ml/requirements-dev.txt
install_python_project backend backend/requirements-dev.txt

echo 'Run Flutter: cd app && flutter run'
echo 'Run API: backend/.venv/bin/python -m uvicorn backend.app.main:app --reload'
echo 'Verify all: ./scripts/check.sh'
echo 'Setup complete.'
```

- [ ] **Step 4: Create the PowerShell verification script**

Create `scripts/check.ps1`:

```powershell
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$Description
    )

    & $Action
    if ($LASTEXITCODE -ne 0) { throw "$Description failed." }
}

$mlPython = Join-Path $root 'ml\.venv\Scripts\python.exe'
$backendPython = Join-Path $root 'backend\.venv\Scripts\python.exe'
foreach ($python in @($mlPython, $backendPython)) {
    if (-not (Test-Path $python)) {
        throw "Missing environment interpreter '$python'. Run .\scripts\setup.ps1 first."
    }
}

Push-Location (Join-Path $root 'app')
try {
    Invoke-Checked { & dart format --output=none --set-exit-if-changed lib test } 'Dart formatting'
    Invoke-Checked { & flutter analyze } 'Flutter analysis'
    Invoke-Checked { & flutter test --coverage } 'Flutter tests'
}
finally {
    Pop-Location
}

Invoke-Checked { & $mlPython -m ruff check (Join-Path $root 'ml') } 'ML lint'
Invoke-Checked { & $mlPython -m pytest -c (Join-Path $root 'ml\pytest.ini') (Join-Path $root 'ml\tests') } 'ML tests'

Invoke-Checked { & $backendPython -m ruff check (Join-Path $root 'backend') } 'Backend lint'
Invoke-Checked { & $backendPython -m pytest -c (Join-Path $root 'backend\pytest.ini') (Join-Path $root 'backend\tests') } 'Backend tests'

Write-Host 'All local checks passed.'
```

- [ ] **Step 5: Create the POSIX verification script**

Create `scripts/check.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ml_python="$root_dir/ml/.venv/bin/python"
backend_python="$root_dir/backend/.venv/bin/python"

for python_path in "$ml_python" "$backend_python"; do
  if [[ ! -x "$python_path" ]]; then
    echo "Missing environment interpreter '$python_path'. Run ./scripts/setup.sh first." >&2
    exit 1
  fi
done

(
  cd "$root_dir/app"
  dart format --output=none --set-exit-if-changed lib test
  flutter analyze
  flutter test --coverage
)

"$ml_python" -m ruff check "$root_dir/ml"
"$ml_python" -m pytest -c "$root_dir/ml/pytest.ini" "$root_dir/ml/tests"
"$backend_python" -m ruff check "$root_dir/backend"
"$backend_python" -m pytest -c "$root_dir/backend/pytest.ini" "$root_dir/backend/tests"

echo 'All local checks passed.'
```

- [ ] **Step 6: Run setup from the repository root**

Run:

```powershell
& .\scripts\setup.ps1
```

Expected: preflight passes, Flutter packages resolve, both Python 3.11 environments install independently, and the script prints `Setup complete.`.

- [ ] **Step 7: Run the complete verification command**

Run:

```powershell
& .\scripts\check.ps1
```

Expected: Flutter formatting/analyze/tests pass, both Ruff runs pass, both pytest suites pass at 60 percent or better coverage, and the script prints `All local checks passed.`.

- [ ] **Step 8: Commit the setup commands**

Run:

```powershell
git add scripts
git update-index --chmod=+x scripts/preflight.sh scripts/setup.sh scripts/check.sh
git commit -m "chore: add local setup and check commands"
```

Expected: all four cross-platform commands are committed.

---

### Task 7: Architecture, Dataset, UI, and Developer Handoff Documentation

**Files:**
- Create: `README.md`
- Create: `CONTRIBUTING.md`
- Create: `docs/ARCHITECTURE.md`
- Create: `docs/DATASET.md`
- Create: `docs/UI_GUIDELINES.md`
- Create: `docs/flowcharts/README.md`

**Interfaces:**
- Consumes: the verified commands and source boundaries from Tasks 1–6.
- Produces: a new-developer path from clone to first successful check and authoritative local architecture rules.

- [ ] **Step 1: Write the root README**

Document:

1. purpose and offline/on-device product architecture;
2. prerequisites: the exact verified Flutter/Dart/JDK versions, Python 3.11, Android SDK, Git, and Xcode for iOS developers;
3. Windows first run: `scripts\setup.ps1`, then `scripts\check.ps1`;
4. macOS/Linux first run: `./scripts/setup.sh`, then `./scripts/check.sh`;
5. Flutter run command: `cd app && flutter run`;
6. backend run command from root: `backend/.venv/bin/python -m uvicorn backend.app.main:app --reload` and its PowerShell equivalent;
7. exact workspace ownership for `app/`, `ml/`, `backend/`, and `docs/`;
8. a statement that mock inference is intentional until a validated TFLite model exists; and
9. the configured `origin` URL and a statement that hosted GitHub configuration is deferred.

- [ ] **Step 2: Write local contribution rules**

Create `CONTRIBUTING.md` with Conventional Commit examples, branch-name examples for later hosting, the `your code, your tests` rule, local check commands, shared test-folder organization, raw-data/model restrictions, and the mandatory UI constraints from the spec. Keep hosted PR approvals and branch-protection configuration out of the file.

- [ ] **Step 3: Write focused architecture and data documentation**

Create `docs/ARCHITECTURE.md` with the app service boundary, mock-to-real adapter swap, ML artifact flow, FastAPI's dev-only role, and the no-runtime-backend invariant.

Create `docs/DATASET.md` with the example `variety/ripeness/image` folder layout, initial example labels, train/validation/test separation guidance, class-balance checks, privacy/consent guidance for collected photos, and the rule that raw data is never committed.

Create `docs/flowcharts/README.md` describing that exported diagrams for the paper belong there and naming conventions such as `inference-flow.pdf` and `training-pipeline.pdf`.

- [ ] **Step 4: Write the authoritative UI guidelines**

Create `docs/UI_GUIDELINES.md` by extracting the nontechnical-user constraints from `PROJECT_PLAN.md`: two taps maximum, one primary action, no onboarding wizard or nested menu, token-only styling, green/accent/neutral palette, 16sp body and 20sp-plus headers, labeled critical icons, plain-language certainty/error copy, 48dp touch targets, 64dp capture action, no color-only meaning, and outdoor contrast testing.

- [ ] **Step 5: Verify documentation commands and links**

Run:

```powershell
rg -n "scripts[/\\](setup|check)|flutter run|uvicorn|Python 3\.11|MockInferenceService" README.md CONTRIBUTING.md docs
rg -n "TBD|TODO|FIXME|\.github/workflows" README.md CONTRIBUTING.md docs
```

Expected: setup/run concepts are present; the placeholder/hosted-workflow scan returns no matches except quoted historical context in the approved spec.

- [ ] **Step 6: Run final verification from a clean command entry point**

Run:

```powershell
& .\scripts\check.ps1
git diff --check
git status --short
```

Expected: all checks pass, whitespace is clean, and only the documentation files from this task are uncommitted.

- [ ] **Step 7: Commit the developer handoff**

Run:

```powershell
git add README.md CONTRIBUTING.md docs/ARCHITECTURE.md docs/DATASET.md docs/UI_GUIDELINES.md docs/flowcharts/README.md
git commit -m "docs: add local developer handoff"
```

Expected: documentation is committed without GitHub-hosted assets.

- [ ] **Step 8: Record final evidence**

Run:

```powershell
git log --oneline --decorate -8
git status --short
git remote -v
flutter --version
flutter doctor -v
& py -3.11 --version
```

Expected: logical task commits are visible, the worktree is clean, `git remote -v` shows only `https://github.com/reyxdz/bananaCheck.git`, Flutter is stable 3.x, Android development has no blocking doctor issue, and Python reports 3.11.x. Windows-only desktop warnings and the absence of Xcode on Windows are not blockers for this Android/iOS mobile scaffold.
