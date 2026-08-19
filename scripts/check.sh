#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for workspace in ml backend; do
  if [[ ! -x "$repo_root/$workspace/.venv/bin/python" ]]; then
    echo "Missing $workspace/.venv. Run scripts/setup.sh first." >&2
    exit 1
  fi
done

(
  cd "$repo_root/app"
  dart format --output=none --set-exit-if-changed lib test
  flutter analyze
  flutter test --coverage
)

(
  cd "$repo_root/ml"
  .venv/bin/python -m ruff check .
  .venv/bin/python -m pytest -c pytest.ini
)

(
  cd "$repo_root/backend"
  .venv/bin/python -m ruff check .
  .venv/bin/python -m pytest -c pytest.ini
)

echo
echo 'All local checks passed.'
