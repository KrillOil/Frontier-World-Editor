class_name TerrainCliffWater
extends RefCounted

const CLIFF_HEIGHT_CM := 200
const SHALLOW_MAX_CM := 100

var terrain


func _init(document = null) -> void:
	terrain = document


func change_level(x: int, z: int, delta: int) -> bool:
	if not _valid_cell(x, z) or delta not in [-1, 1]:
		return false
	var candidate: Dictionary = terrain.data.duplicate(true)
	var index := z * int(candidate.grid.width_cells) + x
	candidate.cliffs.levels[index] = int(candidate.cliffs.levels[index]) + delta
	if not _legal_topology(candidate):
		var topology_errors: Array[String] = ["Cliff edit would create a neighbor difference above one without an authored ramp"]
		terrain.errors = topology_errors
		return false
	return terrain.commit_tile_delta("Raise cliff" if delta > 0 else "Lower cliff", [{"path": ["cliffs", "levels"], "indices": [index], "after": [candidate.cliffs.levels[index]]}])


func set_style(style_id: String) -> bool:
	if style_id.is_empty():
		return false
	var candidate: Dictionary = terrain.data.duplicate(true)
	candidate.cliffs.style_id = style_id
	return terrain.commit_structural("Replace cliff style", candidate)


func add_ramp(x: int, z: int, direction: String) -> bool:
	if not _valid_cell(x, z) or direction not in ["north", "east", "south", "west"]:
		return false
	var ramp := {"direction": direction, "x": x, "z": z}
	var candidate: Dictionary = terrain.data.duplicate(true)
	if ramp in candidate.cliffs.ramps:
		return false
	candidate.cliffs.ramps.append(ramp)
	candidate.cliffs.ramps.sort_custom(func(a, b): return [a.z, a.x, a.direction] < [b.z, b.x, b.direction])
	return terrain.commit_structural("Add cliff ramp", candidate)


func set_water(enabled: bool, level_cm: int) -> bool:
	if level_cm < -32768 or level_cm > 32767:
		return false
	var candidate: Dictionary = terrain.data.duplicate(true)
	candidate.water = {"enabled": enabled, "level_cm": level_cm}
	return terrain.commit_structural("Set water level", candidate)


func water_class_at_cell(x: int, z: int) -> String:
	if not terrain.data.water.enabled or not _valid_cell(x, z):
		return "dry"
	var center_x := float(terrain.data.grid.origin_x_m) + (float(x) + 0.5) * float(terrain.data.grid.cell_size_m)
	var center_z := float(terrain.data.grid.origin_z_m) + (float(z) + 0.5) * float(terrain.data.grid.cell_size_m)
	var index := z * int(terrain.data.grid.width_cells) + x
	var ground_cm := roundi(terrain.sample_height(center_x, center_z) * 100.0) + int(terrain.data.cliffs.levels[index]) * CLIFF_HEIGHT_CM
	var depth := int(terrain.data.water.level_cm) - ground_cm
	if depth <= 0: return "dry"
	if depth <= SHALLOW_MAX_CM: return "shallow"
	return "deep"


func derived_shores() -> Array[Dictionary]:
	var shores: Array[Dictionary] = []
	for z in int(terrain.data.grid.depth_cells):
		for x in int(terrain.data.grid.width_cells):
			var current := water_class_at_cell(x, z)
			if x + 1 < int(terrain.data.grid.width_cells) and (current == "dry") != (water_class_at_cell(x + 1, z) == "dry"):
				shores.append({"direction": "east", "x": x, "z": z})
			if z + 1 < int(terrain.data.grid.depth_cells) and (current == "dry") != (water_class_at_cell(x, z + 1) == "dry"):
				shores.append({"direction": "south", "x": x, "z": z})
	return shores


func edge_has_ramp(x: int, z: int, direction: String) -> bool:
	if {"direction": direction, "x": x, "z": z} in terrain.data.cliffs.ramps:
		return true
	var reciprocal_direction: String = {"north": "south", "east": "west", "south": "north", "west": "east"}[direction]
	var neighbor_x := x + (1 if direction == "east" else -1 if direction == "west" else 0)
	var neighbor_z := z + (1 if direction == "south" else -1 if direction == "north" else 0)
	return {"direction": reciprocal_direction, "x": neighbor_x, "z": neighbor_z} in terrain.data.cliffs.ramps


func _valid_cell(x: int, z: int) -> bool:
	return terrain != null and x >= 0 and z >= 0 and x < int(terrain.data.grid.width_cells) and z < int(terrain.data.grid.depth_cells)


func _legal_topology(candidate: Dictionary) -> bool:
	var width := int(candidate.grid.width_cells)
	var depth := int(candidate.grid.depth_cells)
	for z in depth:
		for x in width:
			var level := int(candidate.cliffs.levels[z * width + x])
			if x + 1 < width and absi(level - int(candidate.cliffs.levels[z * width + x + 1])) > 1 and not _has_ramp(candidate, x, z, "east"):
				return false
			if z + 1 < depth and absi(level - int(candidate.cliffs.levels[(z + 1) * width + x])) > 1 and not _has_ramp(candidate, x, z, "south"):
				return false
	return true


func _has_ramp(candidate: Dictionary, x: int, z: int, direction: String) -> bool:
	return {"direction": direction, "x": x, "z": z} in candidate.cliffs.ramps
