#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
version="$($godot_bin --version 2>/dev/null || true)"

if [[ "$version" != 4.7.1.* ]]; then
  echo "Godot 4.7.1 is required; found '${version:-nothing}'. Set GODOT_BIN to the 4.7.1 executable." >&2
  exit 1
fi

exec "$godot_bin" --headless --path "$project_root" --script res://tests/test_shell.gd

