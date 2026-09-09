class_name TerrainDocument
extends RefCounted

const FORMAT_VERSION := 1
const ALGORITHM_VERSION := 1
const CELL_SIZES := [0.5, 1.0, 2.0, 4.0]
const MIN_CELLS := 8
const MAX_CELLS := 512

var data: Dictionary = {}
var errors: Array[String] = []
var source_path := ""


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
	return true


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
