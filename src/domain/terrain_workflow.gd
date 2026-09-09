class_name TerrainWorkflow
extends RefCounted

const CLIPBOARD_VERSION := 1
const DEFAULT_DOMAINS := {"height": true, "surface": true, "cliff": true, "water": true, "pathing": true}

var terrain
var selection := Rect2i()
var height_snap_cm := 25
var grid_snap_cells := 1
var last_error := ""


func _init(document) -> void:
	terrain = document


func select_cells(first: Vector2i, last: Vector2i) -> Rect2i:
	var width := int(terrain.data.grid.width_cells)
	var depth := int(terrain.data.grid.depth_cells)
	var start := Vector2i(clampi(mini(first.x, last.x), 0, width - 1), clampi(mini(first.y, last.y), 0, depth - 1))
	var end := Vector2i(clampi(maxi(first.x, last.x), 0, width - 1), clampi(maxi(first.y, last.y), 0, depth - 1))
	selection = Rect2i(start, end - start + Vector2i.ONE)
	return selection


func copy_selection(domains: Dictionary = DEFAULT_DOMAINS) -> Dictionary:
	if selection.size.x <= 0 or selection.size.y <= 0:
		last_error = "Select a bounded terrain area before copying"
		return {}
	var grid: Dictionary = terrain.data.grid
	var layers: Array = terrain.data.surfaces.layer_ids
	var payload := {
		"clipboard_version": CLIPBOARD_VERSION,
		"anchor": "north_west",
		"cell_size_m": grid.cell_size_m,
		"size_cells": [selection.size.x, selection.size.y],
		"domains": domains.duplicate(true),
		"mask": [],
		"surface_layer_ids": layers.duplicate(),
		"cliff_style_id": terrain.data.cliffs.style_id,
	}
	payload.mask.resize(selection.size.x * selection.size.y)
	payload.mask.fill(true)
	if domains.get("height", false): payload.heights_cm = _copy_heights(selection)
	if domains.get("surface", false): payload.surface_weights = _copy_cells(terrain.data.surfaces.weights, layers.size())
	if domains.get("cliff", false):
		payload.cliff_levels = _copy_cells(terrain.data.cliffs.levels)
		payload.ramps = _copy_ramps()
	if domains.get("water", false): payload.water = terrain.data.water.duplicate(true)
	if domains.get("pathing", false):
		payload.movement = _copy_cells(terrain.data.pathing.movement)
		payload.placement = _copy_cells(terrain.data.pathing.placement)
	last_error = ""
	return payload


func preview_paste(clipboard: Dictionary, destination: Vector2i) -> Dictionary:
	var error := _compatibility_error(clipboard)
	if not error.is_empty(): return {"ok": false, "error": error}
	var size := Vector2i(int(clipboard.size_cells[0]), int(clipboard.size_cells[1]))
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(int(terrain.data.grid.width_cells), int(terrain.data.grid.depth_cells)))
	var requested := Rect2i(destination, size)
	var clipped := requested.intersection(bounds)
	return {"ok": clipped.size.x > 0 and clipped.size.y > 0, "requested": requested, "destination": clipped, "clipped_cells": requested.get_area() - clipped.get_area(), "atomic": true}


func paste(clipboard: Dictionary, destination: Vector2i, mode := "replace") -> bool:
	var preview := preview_paste(clipboard, destination)
	if not preview.get("ok", false):
		last_error = preview.get("error", "Paste destination is outside terrain bounds")
		return false
	if mode not in ["merge", "replace"]:
		last_error = "Paste mode must be merge or replace"
		return false
	var candidate: Dictionary = terrain.data.duplicate(true)
	var size := Vector2i(int(clipboard.size_cells[0]), int(clipboard.size_cells[1]))
	var layers: int = candidate.surfaces.layer_ids.size()
	for local_z in size.y:
		for local_x in size.x:
			var source_cell := local_z * size.x + local_x
			if not clipboard.mask[source_cell]: continue
			var x := destination.x + local_x
			var z := destination.y + local_z
			if x < 0 or z < 0 or x >= int(candidate.grid.width_cells) or z >= int(candidate.grid.depth_cells): continue
			var target_cell := z * int(candidate.grid.width_cells) + x
			if clipboard.domains.get("surface", false):
				for layer in layers: candidate.surfaces.weights[target_cell * layers + layer] = clipboard.surface_weights[source_cell * layers + layer]
			if clipboard.domains.get("cliff", false) and (mode == "replace" or int(clipboard.cliff_levels[source_cell]) != 0): candidate.cliffs.levels[target_cell] = clipboard.cliff_levels[source_cell]
			for field in ["movement", "placement"]:
				if clipboard.domains.get("pathing", false) and (mode == "replace" or clipboard[field][source_cell] != "inherit"): candidate.pathing[field][target_cell] = clipboard[field][source_cell]
	if clipboard.domains.get("height", false): _paste_heights(candidate, clipboard, destination, size)
	if clipboard.domains.get("water", false): candidate.water = clipboard.water.duplicate(true)
	if clipboard.domains.get("cliff", false): _paste_ramps(candidate, clipboard, destination, size)
	if not terrain.commit_structural("Paste terrain (%s)" % mode, candidate):
		last_error = "Paste rejected atomically: %s" % " | ".join(terrain.errors)
		return false
	last_error = ""
	return true


func snapped_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(snappedi(cell.x, grid_snap_cells), snappedi(cell.y, grid_snap_cells))


func snapped_height_cm(value: int) -> int:
	return snappedi(value, height_snap_cm)


func sample(cell: Vector2i) -> Dictionary:
	var x := clampi(cell.x, 0, int(terrain.data.grid.width_cells) - 1)
	var z := clampi(cell.y, 0, int(terrain.data.grid.depth_cells) - 1)
	var index: int = terrain.cell_index(x, z)
	var layers: Array = terrain.data.surfaces.layer_ids
	var weights: Array = []
	for layer in layers.size(): weights.append(terrain.data.surfaces.weights[index * layers.size() + layer])
	return {"cell": Vector2i(x, z), "height_cm": terrain.data.grid.heights_cm[z * (int(terrain.data.grid.width_cells) + 1) + x], "surface_weights": weights, "cliff_level": terrain.data.cliffs.levels[index], "cliff_style_id": terrain.data.cliffs.style_id, "water": terrain.data.water.duplicate(true), "movement": terrain.data.pathing.movement[index], "placement": terrain.data.pathing.placement[index]}


func minimap_recenter(normalized: Vector2) -> Vector3:
	var grid: Dictionary = terrain.data.grid
	var x := float(grid.origin_x_m) + clampf(normalized.x, 0.0, 1.0) * int(grid.width_cells) * float(grid.cell_size_m)
	var z := float(grid.origin_z_m) + clampf(normalized.y, 0.0, 1.0) * int(grid.depth_cells) * float(grid.cell_size_m)
	return Vector3(x, terrain.sample_height(x, z), z)


func _compatibility_error(clipboard: Dictionary) -> String:
	if clipboard.get("clipboard_version") != CLIPBOARD_VERSION: return "Unsupported terrain clipboard version"
	if clipboard.get("anchor") != "north_west": return "Unsupported terrain clipboard anchor"
	if clipboard.get("cell_size_m") != terrain.data.grid.cell_size_m: return "Clipboard and destination cell sizes differ"
	if clipboard.get("domains", {}).get("surface", false) and clipboard.get("surface_layer_ids") != terrain.data.surfaces.layer_ids: return "Clipboard surface layers differ from destination"
	if clipboard.get("domains", {}).get("cliff", false) and clipboard.get("cliff_style_id") != terrain.data.cliffs.style_id: return "Clipboard cliff style differs from destination"
	if not clipboard.get("size_cells") is Array or clipboard.size_cells.size() != 2: return "Clipboard size is invalid"
	return ""


func _copy_cells(source: Array, stride := 1) -> Array:
	var output: Array = []
	for z in selection.size.y:
		for x in selection.size.x:
			var cell := (selection.position.y + z) * int(terrain.data.grid.width_cells) + selection.position.x + x
			for offset in stride: output.append(source[cell * stride + offset])
	return output


func _copy_heights(rect: Rect2i) -> Array:
	var output: Array = []
	var width := int(terrain.data.grid.width_cells) + 1
	for z in rect.size.y + 1:
		for x in rect.size.x + 1: output.append(terrain.data.grid.heights_cm[(rect.position.y + z) * width + rect.position.x + x])
	return output


func _copy_ramps() -> Array:
	var output: Array = []
	for ramp in terrain.data.cliffs.ramps:
		var point := Vector2i(ramp.x, ramp.z)
		if selection.has_point(point): output.append({"x": point.x - selection.position.x, "z": point.y - selection.position.y, "direction": ramp.direction})
	return output


func _paste_heights(candidate: Dictionary, clipboard: Dictionary, destination: Vector2i, size: Vector2i) -> void:
	var target_width := int(candidate.grid.width_cells) + 1
	for z in size.y + 1:
		for x in size.x + 1:
			var target := destination + Vector2i(x, z)
			if target.x >= 0 and target.y >= 0 and target.x <= int(candidate.grid.width_cells) and target.y <= int(candidate.grid.depth_cells): candidate.grid.heights_cm[target.y * target_width + target.x] = clipboard.heights_cm[z * (size.x + 1) + x]


func _paste_ramps(candidate: Dictionary, clipboard: Dictionary, destination: Vector2i, size: Vector2i) -> void:
	var region := Rect2i(destination, size)
	candidate.cliffs.ramps = candidate.cliffs.ramps.filter(func(ramp): return not region.has_point(Vector2i(ramp.x, ramp.z)))
	for ramp in clipboard.get("ramps", []):
		var point := destination + Vector2i(ramp.x, ramp.z)
		if point.x >= 0 and point.y >= 0 and point.x < int(candidate.grid.width_cells) and point.y < int(candidate.grid.depth_cells): candidate.cliffs.ramps.append({"x": point.x, "z": point.y, "direction": ramp.direction})
