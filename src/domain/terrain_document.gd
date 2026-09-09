class_name TerrainDocument
extends RefCounted

const FORMAT_VERSION := 1
const ALGORITHM_VERSION := 1
const CELL_SIZES := [0.5, 1.0, 2.0, 4.0]
const MIN_CELLS := 8
const MAX_CELLS := 512
const HISTORY_BUDGET_BYTES := 256 * 1024 * 1024
const TILE_CELLS := 32

var data: Dictionary = {}
var errors: Array[String] = []
var source_path := ""
var dirty := false
var history: Array[Dictionary] = []
var redo_history: Array[Dictionary] = []
var history_bytes := 0
var history_evicted := false
var revision := 0
var saved_revision := 0
var _next_revision := 1


func load_from_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors = ["%s: could not be opened" % path]
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		errors = ["%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()]]
		return false
	if not json.data is Dictionary:
		errors = ["terrain.json: root must be an object"]
		return false
	var failures := validate(json.data)
	if not failures.is_empty():
		errors = failures
		return false
	data = json.data.duplicate(true)
	source_path = path
	errors.clear()
	dirty = false
	history.clear()
	redo_history.clear()
	history_bytes = 0
	revision = 0
	saved_revision = 0
	_next_revision = 1
	return true


func create(width_cells: int, depth_cells: int, cell_size_m: float, base_height_cm: int, origin_x_m := 0.0, origin_z_m := 0.0) -> bool:
	var candidate := make_default(width_cells, depth_cells, cell_size_m, base_height_cm, origin_x_m, origin_z_m)
	var failures := validate(candidate)
	if not failures.is_empty():
		errors = failures
		return false
	data = candidate
	errors.clear()
	dirty = true
	history.clear()
	redo_history.clear()
	history_bytes = 0
	revision = 1
	saved_revision = 0
	_next_revision = 2
	return true


func replace(width_cells: int, depth_cells: int, cell_size_m: float, base_height_cm: int, origin_x_m := 0.0, origin_z_m := 0.0) -> bool:
	if data.is_empty():
		return create(width_cells, depth_cells, cell_size_m, base_height_cm, origin_x_m, origin_z_m)
	return _commit_structural_delta("Replace terrain", make_default(width_cells, depth_cells, cell_size_m, base_height_cm, origin_x_m, origin_z_m))


func commit_structural(label: String, candidate: Dictionary) -> bool:
	return _commit_structural_delta(label, candidate)


func make_default(width_cells: int, depth_cells: int, cell_size_m: float, base_height_cm: int, origin_x_m: float, origin_z_m: float) -> Dictionary:
	var cells := width_cells * depth_cells
	var heights: Array = []
	heights.resize((width_cells + 1) * (depth_cells + 1))
	heights.fill(base_height_cm)
	var weights: Array = []
	weights.resize(cells)
	weights.fill(255)
	var zeros: Array = []
	zeros.resize(cells)
	zeros.fill(0)
	var inherit: Array = []
	inherit.resize(cells)
	inherit.fill("inherit")
	return {
		"algorithm_version": 1,
		"attachments": [],
		"cliffs": {"levels": zeros.duplicate(), "ramps": [], "style_id": "cliff_crimsdale_stone"},
		"environment": {"ambient_color_linear": [0.25, 0.3, 0.35], "ambient_energy": 0.8, "fog_color_linear": [0.35, 0.4, 0.45], "fog_density": 0.01, "fog_enabled": false, "fog_end_m": 120.0, "fog_start_m": 20.0, "sky_id": "sky_crimsdale_day", "sun_azimuth_deg": 35.0, "sun_color_linear": [1.0, 0.86, 0.68], "sun_elevation_deg": 52.0, "sun_energy": 1.35},
		"grid": {"cell_size_m": cell_size_m, "depth_cells": depth_cells, "heights_cm": heights, "origin_x_m": origin_x_m, "origin_z_m": origin_z_m, "width_cells": width_cells},
		"pathing": {"movement": inherit.duplicate(), "placement": inherit.duplicate()},
		"surfaces": {"layer_ids": ["surface_crimsdale_grass"], "weights": weights},
		"terrain_format_version": 1,
		"water": {"enabled": false, "level_cm": 0},
	}


func resize(width_cells: int, depth_cells: int, anchor := "center") -> bool:
	if data.is_empty():
		errors = ["No terrain document is open"]
		return false
	var candidate: Dictionary = make_default(width_cells, depth_cells, float(data.grid.cell_size_m), 0, float(data.grid.origin_x_m), float(data.grid.origin_z_m))
	candidate.environment = data.environment.duplicate(true)
	candidate.surfaces.layer_ids = data.surfaces.layer_ids.duplicate()
	candidate.cliffs.style_id = data.cliffs.style_id
	candidate.water = data.water.duplicate(true)
	candidate.attachments = data.attachments.duplicate(true)
	var offsets: Dictionary = _resize_offsets(int(data.grid.width_cells), int(data.grid.depth_cells), width_cells, depth_cells, anchor)
	var old_start: Vector2i = offsets.old_start
	var new_start: Vector2i = offsets.new_start
	var cell_size := float(data.grid.cell_size_m)
	candidate.grid.origin_x_m = float(data.grid.origin_x_m) + float(old_start.x - new_start.x) * cell_size
	candidate.grid.origin_z_m = float(data.grid.origin_z_m) + float(old_start.y - new_start.y) * cell_size
	var copy_width := mini(int(data.grid.width_cells), width_cells)
	var copy_depth := mini(int(data.grid.depth_cells), depth_cells)
	var layers: int = data.surfaces.layer_ids.size()
	candidate.surfaces.weights.resize(width_cells * depth_cells * layers)
	for index in candidate.surfaces.weights.size():
		candidate.surfaces.weights[index] = 255 if index % layers == 0 else 0
	for z in copy_depth + 1:
		for x in copy_width + 1:
			candidate.grid.heights_cm[(z + new_start.y) * (width_cells + 1) + x + new_start.x] = data.grid.heights_cm[(z + old_start.y) * (int(data.grid.width_cells) + 1) + x + old_start.x]
	for z in copy_depth:
		for x in copy_width:
			var old_cell := (z + old_start.y) * int(data.grid.width_cells) + x + old_start.x
			var new_cell := (z + new_start.y) * width_cells + x + new_start.x
			candidate.cliffs.levels[new_cell] = data.cliffs.levels[old_cell]
			candidate.pathing.movement[new_cell] = data.pathing.movement[old_cell]
			candidate.pathing.placement[new_cell] = data.pathing.placement[old_cell]
			for layer in layers:
				candidate.surfaces.weights[new_cell * layers + layer] = data.surfaces.weights[old_cell * layers + layer]
	return _commit_structural_delta("Resize terrain", candidate)


func reset(base_height_cm: int) -> bool:
	var candidate: Dictionary = make_default(int(data.grid.width_cells), int(data.grid.depth_cells), float(data.grid.cell_size_m), base_height_cm, float(data.grid.origin_x_m), float(data.grid.origin_z_m))
	candidate.environment = data.environment.duplicate(true)
	candidate.surfaces.layer_ids = data.surfaces.layer_ids.duplicate()
	candidate.cliffs.style_id = data.cliffs.style_id
	candidate.attachments = data.attachments.duplicate(true)
	var layers: int = candidate.surfaces.layer_ids.size()
	candidate.surfaces.weights.resize(int(data.grid.width_cells) * int(data.grid.depth_cells) * layers)
	for index in candidate.surfaces.weights.size():
		candidate.surfaces.weights[index] = 255 if index % layers == 0 else 0
	return _commit_structural_delta("Reset terrain", candidate)


func save(path := "") -> bool:
	var target := path if not path.is_empty() else source_path
	if target.is_empty():
		errors = ["No terrain path is available"]
		return false
	var failures := validate(data)
	if not failures.is_empty():
		errors = failures
		return false
	var temporary := target + ".tmp"
	var backup := target + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		errors = ["%s: temporary terrain file could not be written" % target]
		return false
	file.store_string(_canonical_json(data) + "\n")
	file.close()
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(target) and DirAccess.rename_absolute(target, backup) != OK:
		errors = ["%s: existing terrain could not be protected" % target]
		return false
	if DirAccess.rename_absolute(temporary, target) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, target)
		errors = ["%s: terrain transaction could not be committed" % target]
		return false
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	source_path = target
	saved_revision = revision
	dirty = false
	errors.clear()
	return true


func serialize() -> String:
	return _canonical_json(data) + "\n"


func mark_saved(path: String) -> void:
	source_path = path
	saved_revision = revision
	dirty = false


func undo() -> bool:
	if history.is_empty():
		return false
	var entry: Dictionary = history.pop_back()
	history_bytes -= int(entry.bytes)
	redo_history.append(entry)
	_apply_history(entry, false)
	revision = int(entry.before_revision)
	dirty = revision != saved_revision
	return true


func redo() -> bool:
	if redo_history.is_empty():
		return false
	var entry: Dictionary = redo_history.pop_back()
	_apply_history(entry, true)
	history.append(entry)
	history_bytes += int(entry.bytes)
	revision = int(entry.after_revision)
	dirty = revision != saved_revision
	return true


func can_undo() -> bool:
	return not history.is_empty()


func can_redo() -> bool:
	return not redo_history.is_empty()


func prospective_bounds(width_cells: int, depth_cells: int, anchor := "center") -> Rect2:
	var offsets := _resize_offsets(int(data.grid.width_cells), int(data.grid.depth_cells), width_cells, depth_cells, anchor)
	var cell_size := float(data.grid.cell_size_m)
	var origin := Vector2(
		float(data.grid.origin_x_m) + float(offsets.old_start.x - offsets.new_start.x) * cell_size,
		float(data.grid.origin_z_m) + float(offsets.old_start.y - offsets.new_start.y) * cell_size
	)
	return Rect2(origin, Vector2(width_cells * cell_size, depth_cells * cell_size))


func commit_tile_delta(label: String, changes: Array) -> bool:
	var normalized: Array[Dictionary] = []
	for change in changes:
		var path: Array = change.get("path", [])
		var indices: Array = change.get("indices", [])
		var after: Array = change.get("after", [])
		var target = _array_at_path(path)
		if target == null or indices.size() != after.size():
			errors = ["%s contains an invalid tile delta" % label]
			return false
		var before: Array = []
		for index in indices:
			if not index is int or index < 0 or index >= target.size():
				errors = ["%s contains an out-of-range tile index" % label]
				return false
			before.append(target[index])
		normalized.append({"path": path.duplicate(), "indices": indices.duplicate(), "before": before, "after": after.duplicate()})
	var candidate := data.duplicate(true)
	_apply_tile_changes(candidate, normalized, true)
	var failures := validate(candidate)
	if not failures.is_empty():
		errors = failures
		return false
	var entry := {"kind": "tiles", "label": label, "changes": normalized}
	entry.bytes = _canonical_json(normalized).length()
	return _commit_history_entry(entry, func(): data = candidate)


func validate(candidate: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	_require_keys(candidate, ["terrain_format_version", "algorithm_version", "grid", "surfaces", "cliffs", "water", "pathing", "environment", "attachments"], "terrain.json", failures)
	if candidate.get("terrain_format_version") != FORMAT_VERSION:
		failures.append("terrain.json: unsupported terrain_format_version '%s'" % candidate.get("terrain_format_version"))
	if candidate.get("algorithm_version") != ALGORITHM_VERSION:
		failures.append("terrain.json: unsupported algorithm_version '%s'" % candidate.get("algorithm_version"))
	for domain in ["grid", "surfaces", "cliffs", "water", "pathing", "environment"]:
		if not candidate.get(domain) is Dictionary:
			failures.append("terrain.json.%s must be an object" % domain)
	if not candidate.get("attachments") is Array:
		failures.append("terrain.json.attachments must be an array")
	if not failures.is_empty():
		return failures
	_validate_grid(candidate.grid, failures)
	_validate_surfaces(candidate.surfaces, int(candidate.grid.get("width_cells", 0)) * int(candidate.grid.get("depth_cells", 0)), failures)
	_validate_cell_array(candidate.cliffs.get("levels"), _cell_count(candidate), "cliffs.levels", failures)
	_validate_cell_array(candidate.pathing.get("movement"), _cell_count(candidate), "pathing.movement", failures)
	_validate_cell_array(candidate.pathing.get("placement"), _cell_count(candidate), "pathing.placement", failures)
	for field in ["movement", "placement"]:
		if candidate.pathing.get(field) is Array:
			for value in candidate.pathing[field]:
				if value not in ["inherit", "blocked"]:
					failures.append("terrain.json.pathing.%s contains unsupported value '%s'" % [field, value])
					break
	return failures


func canonical_hash() -> String:
	return FileAccess.get_sha256(source_path) if not source_path.is_empty() else ""


func sample_height(world_x: float, world_z: float) -> float:
	var grid: Dictionary = data.grid
	var local_x: float = (world_x - float(grid.origin_x_m)) / float(grid.cell_size_m)
	var local_z: float = (world_z - float(grid.origin_z_m)) / float(grid.cell_size_m)
	local_x = clampf(local_x, 0.0, float(grid.width_cells))
	local_z = clampf(local_z, 0.0, float(grid.depth_cells))
	var x0 := mini(floori(local_x), int(grid.width_cells) - 1)
	var z0 := mini(floori(local_z), int(grid.depth_cells) - 1)
	var x1 := x0 + 1
	var z1 := z0 + 1
	var tx := local_x - float(x0)
	var tz := local_z - float(z0)
	var north := lerpf(float(_height_cm(x0, z0)), float(_height_cm(x1, z0)), tx)
	var south := lerpf(float(_height_cm(x0, z1)), float(_height_cm(x1, z1)), tx)
	return lerpf(north, south, tz) / 100.0


func cell_index(x: int, z: int) -> int:
	return z * int(data.grid.width_cells) + x


func pathing_reasons(x: int, z: int, layer := "movement") -> Array[String]:
	var reasons: Array[String] = []
	if x < 0 or z < 0 or x >= int(data.grid.width_cells) or z >= int(data.grid.depth_cells):
		return ["bounds"]
	if data.pathing[layer][cell_index(x, z)] == "blocked":
		reasons.append("authored_block")
	return reasons


func _height_cm(x: int, z: int) -> int:
	return int(data.grid.heights_cm[z * (int(data.grid.width_cells) + 1) + x])


func _cell_count(candidate: Dictionary) -> int:
	return int(candidate.grid.get("width_cells", 0)) * int(candidate.grid.get("depth_cells", 0))


func _validate_grid(grid: Dictionary, failures: Array[String]) -> void:
	_require_keys(grid, ["origin_x_m", "origin_z_m", "cell_size_m", "width_cells", "depth_cells", "heights_cm"], "terrain.json.grid", failures)
	var width := int(grid.get("width_cells", 0))
	var depth := int(grid.get("depth_cells", 0))
	if width < MIN_CELLS or width > MAX_CELLS or depth < MIN_CELLS or depth > MAX_CELLS:
		failures.append("terrain.json.grid dimensions must be 8..512 cells")
	if float(grid.get("cell_size_m", 0.0)) not in CELL_SIZES:
		failures.append("terrain.json.grid.cell_size_m is unsupported")
	var heights: Variant = grid.get("heights_cm")
	if not heights is Array or heights.size() != (width + 1) * (depth + 1):
		failures.append("terrain.json.grid.heights_cm length must equal (width_cells + 1) * (depth_cells + 1)")
	elif heights.any(func(value): return not _is_json_integer(value) or value < -32768 or value > 32767):
		failures.append("terrain.json.grid.heights_cm values must be signed centimetre integers")


func _validate_surfaces(surfaces: Dictionary, cells: int, failures: Array[String]) -> void:
	var layers: Variant = surfaces.get("layer_ids")
	var weights: Variant = surfaces.get("weights")
	if not layers is Array or layers.size() < 1 or layers.size() > 4:
		failures.append("terrain.json.surfaces.layer_ids must contain 1..4 layers")
		return
	var unique_layers := {}
	for layer_id in layers:
		if not layer_id is String or layer_id.is_empty() or unique_layers.has(layer_id):
			failures.append("terrain.json.surfaces.layer_ids must contain unique non-empty logical IDs")
			return
		unique_layers[layer_id] = true
	if not weights is Array or weights.size() != cells * layers.size():
		failures.append("terrain.json.surfaces.weights length must equal cells * layers")
		return
	for cell in cells:
		var total := 0
		for layer in layers.size():
			var weight: Variant = weights[cell * layers.size() + layer]
			if not _is_json_integer(weight) or weight < 0 or weight > 255:
				failures.append("terrain.json.surfaces.weights must be unsigned bytes")
				return
			total += weight
		if total != 255:
			failures.append("terrain.json.surfaces.weights cell %d sums to %d, expected 255" % [cell, total])
			return


func _validate_cell_array(values: Variant, cells: int, name: String, failures: Array[String]) -> void:
	if not values is Array or values.size() != cells:
		failures.append("terrain.json.%s length must equal width_cells * depth_cells" % name)


func _require_keys(value: Dictionary, required: Array, context: String, failures: Array[String]) -> void:
	for key in required:
		if not value.has(key):
			failures.append("%s: missing required field '%s'" % [context, key])


func _is_json_integer(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(value, roundf(value)))


func _resize_offsets(old_width: int, old_depth: int, new_width: int, new_depth: int, anchor: String) -> Dictionary:
	var horizontal := anchor.split("_")[1] if "_" in anchor else anchor
	var vertical := anchor.split("_")[0] if "_" in anchor else anchor
	var old_start := Vector2i.ZERO
	var new_start := Vector2i.ZERO
	if horizontal == "east":
		old_start.x = maxi(0, old_width - new_width)
		new_start.x = maxi(0, new_width - old_width)
	elif horizontal == "center" or anchor == "center":
		old_start.x = maxi(0, (old_width - new_width) / 2)
		new_start.x = maxi(0, (new_width - old_width) / 2)
	if vertical == "south":
		old_start.y = maxi(0, old_depth - new_depth)
		new_start.y = maxi(0, new_depth - old_depth)
	elif vertical == "center" or anchor == "center":
		old_start.y = maxi(0, (old_depth - new_depth) / 2)
		new_start.y = maxi(0, (new_depth - old_depth) / 2)
	return {"old_start": old_start, "new_start": new_start}


func _commit_structural_delta(label: String, candidate: Dictionary) -> bool:
	var failures := validate(candidate)
	if not failures.is_empty():
		errors = failures
		return false
	var entry := {"kind": "structure", "label": label, "before": data.duplicate(true), "after": candidate.duplicate(true)}
	entry.bytes = (_canonical_json(entry.before).length() + _canonical_json(entry.after).length())
	return _commit_history_entry(entry, func(): data = candidate)


func _commit_history_entry(entry: Dictionary, apply_change: Callable) -> bool:
	if int(entry.bytes) > HISTORY_BUDGET_BYTES:
		errors = ["%s exceeds the 256 MiB terrain history budget" % entry.label]
		return false
	while history_bytes + int(entry.bytes) > HISTORY_BUDGET_BYTES and not history.is_empty():
		history_bytes -= int(history[0].bytes)
		history.pop_front()
		history_evicted = true
	entry.before_revision = revision
	entry.after_revision = _next_revision
	_next_revision += 1
	history.append(entry)
	history_bytes += int(entry.bytes)
	redo_history.clear()
	apply_change.call()
	revision = int(entry.after_revision)
	dirty = revision != saved_revision
	errors.clear()
	return true


func _apply_history(entry: Dictionary, forward: bool) -> void:
	if entry.kind == "structure":
		data = (entry.after if forward else entry.before).duplicate(true)
	else:
		_apply_tile_changes(data, entry.changes, forward)


func _apply_tile_changes(target_data: Dictionary, changes: Array, forward: bool) -> void:
	for change in changes:
		var target = _array_at_path(change.path, target_data)
		var values: Array = change.after if forward else change.before
		for offset in change.indices.size():
			target[change.indices[offset]] = values[offset]


func _array_at_path(path: Array, root: Dictionary = data):
	var value: Variant = root
	for segment in path:
		if not value is Dictionary or not value.has(segment):
			return null
		value = value[segment]
	return value if value is Array else null


func _canonical_json(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var members: Array[String] = []
		for key in keys:
			members.append("%s:%s" % [JSON.stringify(str(key)), _canonical_json(value[key])])
		return "{%s}" % ",".join(members)
	if value is Array:
		var members: Array[String] = []
		for item in value:
			members.append(_canonical_json(item))
		return "[%s]" % ",".join(members)
	if value is float and is_equal_approx(value, roundf(value)):
		return str(int(value))
	return JSON.stringify(value)
