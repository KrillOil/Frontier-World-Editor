class_name TerrainSurfacePainter
extends RefCounted

const MAX_LAYERS := 4
const FALLOFFS := ["constant", "linear", "smooth"]

var terrain
var active := false
var erase := false
var selected_layer := 0
var radius_m := 3.0
var opacity := 0.25
var falloff := "smooth"
var preview_weights: Array = []
var changed_cells: Dictionary = {}
var _last_point := Vector2.ZERO
var _distance_until_stamp := 0.0


func _init(document = null) -> void:
	terrain = document


func begin(layer_index: int, world_point: Vector2, parameters := {}) -> bool:
	var count: int = terrain.data.surfaces.layer_ids.size() if terrain != null else 0
	if layer_index < 0 or layer_index >= count:
		return false
	selected_layer = layer_index
	erase = bool(parameters.get("erase", false))
	radius_m = clampf(float(parameters.get("radius_m", 3.0)), float(terrain.data.grid.cell_size_m), 64.0)
	opacity = clampf(float(parameters.get("opacity", 0.25)), 0.0, 1.0)
	falloff = parameters.get("falloff", "smooth")
	if falloff not in FALLOFFS:
		falloff = "smooth"
	preview_weights = terrain.data.surfaces.weights.duplicate()
	changed_cells.clear()
	_last_point = world_point
	_distance_until_stamp = _spacing()
	active = true
	_stamp(world_point)
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
		_distance_until_stamp = _spacing()
	_distance_until_stamp -= length - travelled
	_last_point = world_point


func commit() -> bool:
	if not active:
		return false
	var layers: int = terrain.data.surfaces.layer_ids.size()
	var indices: Array = []
	var after: Array = []
	var cells: Array = changed_cells.keys()
	cells.sort()
	for cell in cells:
		for layer in layers:
			var index: int = cell * layers + layer
			indices.append(index)
			after.append(preview_weights[index])
	active = false
	if indices.is_empty():
		return true
	return terrain.commit_tile_delta("Erase surface" if erase else "Paint surface", [{"path": ["surfaces", "weights"], "indices": indices, "after": after}])


func cancel() -> void:
	active = false
	preview_weights.clear()
	changed_cells.clear()


func add_layer(surface_id: String) -> bool:
	var ids: Array = terrain.data.surfaces.layer_ids
	if surface_id in ids or ids.size() >= MAX_LAYERS:
		return false
	var candidate: Dictionary = terrain.data.duplicate(true)
	var old_layers := ids.size()
	candidate.surfaces.layer_ids.append(surface_id)
	var expanded: Array = []
	for cell in int(terrain.data.grid.width_cells) * int(terrain.data.grid.depth_cells):
		for layer in old_layers:
			expanded.append(terrain.data.surfaces.weights[cell * old_layers + layer])
		expanded.append(0)
	candidate.surfaces.weights = expanded
	return terrain.commit_structural("Add surface layer", candidate)


func reorder_layers(order: Array) -> bool:
	var ids: Array = terrain.data.surfaces.layer_ids
	if order.size() != ids.size() or order.duplicate().all(func(id): return id in ids) == false:
		return false
	var candidate: Dictionary = terrain.data.duplicate(true)
	candidate.surfaces.layer_ids = order.duplicate()
	var remapped: Array = []
	for cell in int(terrain.data.grid.width_cells) * int(terrain.data.grid.depth_cells):
		for id in order:
			remapped.append(terrain.data.surfaces.weights[cell * ids.size() + ids.find(id)])
	candidate.surfaces.weights = remapped
	return terrain.commit_structural("Reorder surface layers", candidate)


func replace_layer(index: int, surface_id: String) -> bool:
	var ids: Array = terrain.data.surfaces.layer_ids
	if index < 0 or index >= ids.size() or (surface_id in ids and ids[index] != surface_id):
		return false
	var candidate: Dictionary = terrain.data.duplicate(true)
	candidate.surfaces.layer_ids[index] = surface_id
	return terrain.commit_structural("Replace surface layer", candidate)


func remove_layer(index: int) -> bool:
	var ids: Array = terrain.data.surfaces.layer_ids
	if index <= 0 or index >= ids.size():
		return false
	var candidate: Dictionary = terrain.data.duplicate(true)
	candidate.surfaces.layer_ids.remove_at(index)
	var compacted: Array = []
	for cell in int(terrain.data.grid.width_cells) * int(terrain.data.grid.depth_cells):
		var removed := int(terrain.data.surfaces.weights[cell * ids.size() + index])
		for layer in ids.size():
			if layer == index:
				continue
			var value := int(terrain.data.surfaces.weights[cell * ids.size() + layer])
			compacted.append(value + removed if layer == 0 else value)
	candidate.surfaces.weights = compacted
	return terrain.commit_structural("Remove surface layer", candidate)


func layer_impact(index: int) -> Dictionary:
	var layers: int = terrain.data.surfaces.layer_ids.size()
	var cells := 0
	var weight := 0
	for cell in int(terrain.data.grid.width_cells) * int(terrain.data.grid.depth_cells):
		var value := int(terrain.data.surfaces.weights[cell * layers + index])
		if value > 0:
			cells += 1
			weight += value
	return {"cells": cells, "total_weight": weight}


func _stamp(world_point: Vector2) -> void:
	var grid: Dictionary = terrain.data.grid
	var cell_size := float(grid.cell_size_m)
	var center_x := (world_point.x - float(grid.origin_x_m)) / cell_size - 0.5
	var center_z := (world_point.y - float(grid.origin_z_m)) / cell_size - 0.5
	var sample_radius := radius_m / cell_size
	for z in range(maxi(0, floori(center_z - sample_radius)), mini(int(grid.depth_cells) - 1, ceili(center_z + sample_radius)) + 1):
		for x in range(maxi(0, floori(center_x - sample_radius)), mini(int(grid.width_cells) - 1, ceili(center_x + sample_radius)) + 1):
			var distance := Vector2(float(x) - center_x, float(z) - center_z).length() * cell_size
			if distance <= radius_m:
				_paint_cell(z * int(grid.width_cells) + x, roundi(255.0 * opacity * _influence(distance / radius_m)))


func _paint_cell(cell: int, amount: int) -> void:
	var layers: int = terrain.data.surfaces.layer_ids.size()
	var offset := cell * layers
	if erase:
		if selected_layer == 0:
			return
		var transfer := mini(amount, int(preview_weights[offset + selected_layer]))
		preview_weights[offset + selected_layer] -= transfer
		preview_weights[offset] += transfer
	else:
		var current := int(preview_weights[offset + selected_layer])
		var target := mini(255, current + amount)
		var take := target - current
		if take <= 0:
			return
		var available := 255 - current
		var removed := 0
		for layer in layers:
			if layer == selected_layer:
				continue
			var reduction := floori(float(take * int(preview_weights[offset + layer])) / float(available))
			preview_weights[offset + layer] -= reduction
			removed += reduction
		var remainder := take - removed
		for layer in layers:
			if layer != selected_layer and remainder > 0:
				var extra := mini(remainder, int(preview_weights[offset + layer]))
				preview_weights[offset + layer] -= extra
				remainder -= extra
		preview_weights[offset + selected_layer] = target
	changed_cells[cell] = true


func _influence(distance: float) -> float:
	var remaining := clampf(1.0 - distance, 0.0, 1.0)
	if falloff == "constant": return 1.0
	if falloff == "linear": return remaining
	return remaining * remaining * (3.0 - 2.0 * remaining)


func _spacing() -> float:
	return maxf(float(terrain.data.grid.cell_size_m) * 0.25, radius_m * 0.25)
