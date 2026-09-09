extends SceneTree

const TerrainScript = preload("res://src/domain/terrain_document.gd")

var failures: Array[String] = []


func _init() -> void:
	var terrain = TerrainScript.new()
	_check(terrain.create(8, 8, 1.0, 125, -4.0, -4.0), "Terrain creation accepts explicit dimensions, resolution, base height, and bounds")
	_check(terrain.data.grid.heights_cm.size() == 81 and terrain.data.grid.heights_cm.all(func(value): return value == 125), "Creation allocates the cell-plus-one height grid")
	_check(terrain.data.surfaces.weights.size() == 64 and terrain.data.surfaces.weights.all(func(value): return value == 255), "Creation establishes the base-surface invariant")
	terrain.data.grid.heights_cm[40] = 300
	_check(terrain.resize(12, 10, "north_west"), "Named-anchor expansion commits")
	_check(terrain.data.grid.width_cells == 12 and terrain.data.grid.depth_cells == 10 and terrain.data.grid.heights_cm[4 * 13 + 4] == 300, "North-west resize preserves overlapping authored samples")
	_check(terrain.undo() and terrain.data.grid.width_cells == 8, "Resize is one undo transaction")
	_check(terrain.redo() and terrain.data.grid.width_cells == 12, "Resize redo restores the exact result")
	_check(terrain.resize(16, 12, "center"), "Centered expansion commits")
	_check(terrain.data.grid.origin_x_m == -6.0 and terrain.data.grid.origin_z_m == -5.0, "Centered resize moves the origin so copied samples retain world-space positions")
	_check(terrain.sample_height(0.0, 0.0) == 3.0, "Centered resize preserves the authored height at its world coordinate")
	_check(terrain.undo(), "Centered resize is undoable")
	_check(terrain.reset(-50), "Reset commits")
	_check(terrain.data.grid.heights_cm.all(func(value): return value == -50), "Reset applies the chosen base height")
	_check(terrain.data.environment.sun_energy == 1.35 and terrain.data.attachments.is_empty(), "Reset preserves environment and attachment settings")
	_check(terrain.undo() and terrain.data.grid.heights_cm[4 * 13 + 4] == 300, "Reset undo restores authored terrain")
	var path := "user://terrain_foundation/terrain.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	_check(terrain.save(path), "Terrain saves through a protected transaction")
	_check(not terrain.dirty, "Successful save records the current history cursor")
	var center_index := 4 * 13 + 4
	_check(terrain.commit_tile_delta("Raise one sample", [{"path": ["grid", "heights_cm"], "indices": [center_index], "after": [450]}]), "A validated exact tile delta commits")
	_check(terrain.data.grid.heights_cm[center_index] == 450 and terrain.dirty, "Tile delta applies without replacing the terrain document")
	_check(terrain.undo() and not terrain.dirty, "Undoing to the saved cursor clears dirty state")
	_check(terrain.redo() and terrain.dirty, "Redoing past the saved cursor restores dirty state")
	_check(terrain.undo(), "Saved state can be restored before persistence determinism check")
	_check(terrain.replace(8, 8, 2.0, 10, -8.0, -8.0), "Replacing existing terrain commits as a structural transaction")
	_check(terrain.undo() and terrain.data.grid.width_cells == 12, "Replacing existing terrain is undoable")
	var first_bytes := FileAccess.get_file_as_string(path)
	var reopened = TerrainScript.new()
	_check(reopened.load_from_file(path), "Saved terrain reopens")
	_check(reopened.save(), "Reopened terrain saves deterministically")
	_check(FileAccess.get_file_as_string(path) == first_bytes, "Save-reopen-save bytes are deterministic")
	_check(terrain.history_bytes < TerrainScript.HISTORY_BUDGET_BYTES, "History accounts within its numeric memory budget")
	var invalid = TerrainScript.new()
	_check(not invalid.create(7, 8, 1.0, 0), "Terrain below the minimum dimensions is rejected")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PASS: terrain creation, resize, reset, history, and persistence")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
