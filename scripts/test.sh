#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
version="$($godot_bin --version 2>/dev/null || true)"

if [[ "$version" != 4.7.1.* ]]; then
  echo "Godot 4.7.1 is required; found '${version:-nothing}'. Set GODOT_BIN to the 4.7.1 executable." >&2
  exit 1
fi

"$godot_bin" --headless --path "$project_root" --script res://tests/test_shell.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/test_world_package.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/test_editor_integration.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/test_terrain_contract.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/test_terrain_foundation.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/test_terrain_sculptor.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/test_terrain_surfaces.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/test_terrain_cliff_water.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/test_terrain_pathing.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/test_terrain_environment.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/test_terrain_workflow.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/test_terrain_delivery.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/test_scenario_contract.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/test_scenario_regions.gd
