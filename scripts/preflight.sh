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
