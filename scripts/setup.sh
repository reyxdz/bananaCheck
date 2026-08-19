#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$repo_root/scripts/preflight.sh"

(
  cd "$repo_root/app"
  flutter pub get
)

for workspace in ml backend; do
  workspace_path="$repo_root/$workspace"
  if [[ ! -x "$workspace_path/.venv/bin/python" ]]; then
    echo "Creating $workspace Python 3.11 environment..."
    python3.11 -m venv "$workspace_path/.venv"
  fi

  "$workspace_path/.venv/bin/python" -m pip install --upgrade pip
  "$workspace_path/.venv/bin/python" -m pip install \
    -r "$workspace_path/requirements-dev.txt"
done

echo
echo 'Local setup is ready.'
echo 'Run scripts/check.sh to verify the full workspace.'
