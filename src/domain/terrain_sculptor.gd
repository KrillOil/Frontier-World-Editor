class_name TerrainSculptor
extends RefCounted

const MIN_HEIGHT_CM := -32768
const MAX_HEIGHT_CM := 32767
const NOISE_ALGORITHM_VERSION := 1
const TOOLS := ["raise", "lower", "flatten", "smooth", "plateau", "noise"]
const FALLOFFS := ["constant", "linear", "smooth"]

var terrain
var active := false
var tool := "raise"
var radius_m := 3.0
var strength := 20.0
var falloff := "smooth"
var target_height_cm := 0
var noise_seed := 1
var preview_heights: Array = []
var changed_indices: Dictionary = {}
var _last_point := Vector2.ZERO
var _distance_until_stamp := 0.0


func _init(document = null) -> void:
	terrain = document


func begin(selected_tool: String, world_point: Vector2, parameters := {}) -> bool:
	if terrain == null or selected_tool not in TOOLS:
		return false
	tool = selected_tool
	radius_m = clampf(float(parameters.get("radius_m", 3.0)), float(terrain.data.grid.cell_size_m), 64.0)
	strength = maxf(0.0, float(parameters.get("strength", 20.0)))
	falloff = parameters.get("falloff", "smooth")
	if falloff not in FALLOFFS:
		falloff = "smooth"
	target_height_cm = clampi(int(parameters.get("target_height_cm", roundi(terrain.sample_height(world_point.x, world_point.y) * 100.0))), MIN_HEIGHT_CM, MAX_HEIGHT_CM)
	noise_seed = int(parameters.get("noise_seed", 1))
	preview_heights = terrain.data.grid.heights_cm.duplicate()
	changed_indices.clear()
	_last_point = world_point
	_distance_until_stamp = 0.0
	active = true
	_stamp(world_point)
	_distance_until_stamp = _stamp_spacing()
	return true


func extend(world_point: Vector2) -> void:
	if not active:
		return
	var segment := world_point - _last_point
	var length := segment.length()
	if length <= 0.000001:
		return
	var direction := segment / length
	var travelled := 0.0
	while travelled + _distance_until_stamp <= length + 0.000001:
		travelled += _distance_until_stamp
		_stamp(_last_point + direction * travelled)
		_distance_until_stamp = _stamp_spacing()
	_distance_until_stamp -= length - travelled
	_last_point = world_point


func commit() -> bool:
	if not active:
		return false
	var indices: Array = changed_indices.keys()
	indices.sort()
	var after: Array = []
	for index in indices:
		after.append(preview_heights[index])
	active = false
	if indices.is_empty():
		return true
	return terrain.commit_tile_delta("Sculpt %s" % tool, [{"path": ["grid", "heights_cm"], "indices": indices, "after": after}])


func cancel() -> void:
	active = false
	preview_heights.clear()
	changed_indices.clear()


func preview_height_cm(index: int) -> int:
	return int(preview_heights[index] if active else terrain.data.grid.heights_cm[index])


func _stamp(world_point: Vector2) -> void:
	var grid: Dictionary = terrain.data.grid
	var cell := float(grid.cell_size_m)
	var center_x := (world_point.x - float(grid.origin_x_m)) / cell
	var center_z := (world_point.y - float(grid.origin_z_m)) / cell
	var sample_radius := radius_m / cell
	var x_min := maxi(0, floori(center_x - sample_radius))
	var x_max := mini(int(grid.width_cells), ceili(center_x + sample_radius))
	var z_min := maxi(0, floori(center_z - sample_radius))
	var z_max := mini(int(grid.depth_cells), ceili(center_z + sample_radius))
	var source := preview_heights.duplicate() if tool == "smooth" else preview_heights
	for z in range(z_min, z_max + 1):
		for x in range(x_min, x_max + 1):
			var distance := Vector2(float(x) - center_x, float(z) - center_z).length() * cell
			if distance > radius_m:
				continue
			var influence := _influence(distance / radius_m)
			var index := z * (int(grid.width_cells) + 1) + x
			var current := int(preview_heights[index])
			var result := current
			match tool:
				"raise": result = current + roundi(strength * influence)
				"lower": result = current - roundi(strength * influence)
				"flatten": result = roundi(lerpf(float(current), float(target_height_cm), minf(1.0, strength / 100.0) * influence))
				"plateau":
					var edge := 1.0 if distance / radius_m <= 0.65 else _influence((distance / radius_m - 0.65) / 0.35)
					result = roundi(lerpf(float(current), float(target_height_cm), minf(1.0, strength / 100.0) * edge))
				"smooth": result = roundi(lerpf(float(current), _neighbor_average(source, x, z), minf(1.0, strength / 100.0) * influence))
				"noise": result = current + roundi(strength * influence * _noise_value(x, z, noise_seed))
			result = clampi(result, MIN_HEIGHT_CM, MAX_HEIGHT_CM)
			if result != current:
				preview_heights[index] = result
				changed_indices[index] = true


func _neighbor_average(source: Array, x: int, z: int) -> float:
	var width := int(terrain.data.grid.width_cells)
	var depth := int(terrain.data.grid.depth_cells)
	var total := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var sample_x := clampi(x + dx, 0, width)
			var sample_z := clampi(z + dz, 0, depth)
			total += int(source[sample_z * (width + 1) + sample_x])
	return float(total) / 9.0


func _influence(normalized_distance: float) -> float:
	var remaining := clampf(1.0 - normalized_distance, 0.0, 1.0)
	if falloff == "constant":
		return 1.0
	if falloff == "linear":
		return remaining
	return remaining * remaining * (3.0 - 2.0 * remaining)


func _stamp_spacing() -> float:
	return maxf(float(terrain.data.grid.cell_size_m) * 0.25, radius_m * 0.25)


func _noise_value(x: int, z: int, seed: int) -> float:
	var value := (x * 374761393 + z * 668265263 + seed * 1442695041) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	value = value ^ (value >> 16)
	return float(value & 0xffff) / 32767.5 - 1.0
