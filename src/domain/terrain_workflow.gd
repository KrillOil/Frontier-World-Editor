class_name TerrainWorkflow
extends RefCounted

const TerrainPathingScript = preload("res://src/domain/terrain_pathing.gd")
const TerrainCliffWaterScript = preload("res://src/domain/terrain_cliff_water.gd")

const CLIPBOARD_VERSION := 1
const DEFAULT_DOMAINS := {"height": true, "surface": true, "cliff": true, "water": true, "pathing": true}

var terrain
var selection := Rect2i()
var height_snap_cm := 25
var grid_snap_cells := 1
var last_error := ""
var history_budget_bytes := 256 * 1024 * 1024


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
		"source_document_id": terrain.get_instance_id(),
		"source_revision": terrain.revision,
		"source_position": [selection.position.x, selection.position.y],
	}
	payload.mask.resize(selection.size.x * selection.size.y)
	payload.mask.fill(true)
	if domains.get("height", false): payload.heights_cm = _copy_heights(selection)
	if domains.get("surface", false): payload.surface_weights = _copy_cells(terrain.data.surfaces.weights, layers.size())
	if domains.get("cliff", false):
		payload.cliff_levels = _copy_cells(terrain.data.cliffs.levels)
		payload.ramps = _copy_ramps()
		payload.boundary_ramps = _boundary_ramps()
	if domains.get("water", false): payload.water = terrain.data.water.duplicate(true)
	if domains.get("pathing", false):
		payload.movement = _copy_cells(terrain.data.pathing.movement)
		payload.placement = _copy_cells(terrain.data.pathing.placement)
	last_error = ""
	return payload


func preview_paste(clipboard: Dictionary, destination: Vector2i) -> Dictionary:
	return preview_operation(clipboard, destination, "paste", "replace")


func preview_destination(clipboard: Dictionary, destination: Vector2i, operation := "paste", mode := "replace", intersecting_authored_ids: Array = []) -> Dictionary:
	var result := _preview_base(clipboard, destination, operation, mode)
	result.changed_cells = -1
	result.changed_vertices = -1
	result.intersecting_authored_ids = intersecting_authored_ids.duplicate()
	result.destination_settled = false
	result.confirm_enabled = false
	if result.ok:
		result.recovery = "Click the destination or press Enter to validate the exact candidate."
	return result


func preview_operation(clipboard: Dictionary, destination: Vector2i, operation := "paste", mode := "replace", intersecting_authored_ids: Array = []) -> Dictionary:
	var result := _preview_base(clipboard, destination, operation, mode)
	if not result.confirm_enabled:
		return result
	var candidate: Dictionary = terrain.data.duplicate(true)
	if operation == "move":
		_neutralize_source(candidate, clipboard)
	_apply_clipboard(candidate, clipboard, destination, mode)
	var label := "%s terrain (%s)" % [operation.capitalize(), mode]
	var preflight: Dictionary = terrain.structural_preflight(label, candidate, history_budget_bytes)
	result.candidate = candidate
	result.changed_cells = _changed_cell_count(terrain.data, candidate)
	result.changed_vertices = _changed_vertex_count(terrain.data, candidate)
	result.intersecting_authored_ids = intersecting_authored_ids.duplicate()
	result.history_bytes = preflight.bytes
	result.would_evict_history = preflight.would_evict_history
	result.destination_settled = true
	if not preflight.ok:
		result.confirm_enabled = false
		result.ok = false
		result.error = " | ".join(preflight.errors)
		result.recovery = "Adjust the destination or enabled domains, then preview again."
	return result


func confirm_operation(preview: Dictionary) -> bool:
	if not preview.get("confirm_enabled", false) or not preview.get("candidate") is Dictionary:
		last_error = preview.get("error", "Preview is not confirmable")
		return false
	if int(preview.get("document_id", -1)) != terrain.get_instance_id():
		last_error = "Terrain document changed; copy and preview again"
		return false
	if int(preview.get("revision", -1)) != int(terrain.revision):
		last_error = "Terrain changed after preview; preview again"
		return false
	var label := "%s terrain (%s)" % [str(preview.operation).capitalize(), str(preview.mode)]
	var failures: Array[String] = terrain.validate(preview.candidate)
	if not failures.is_empty():
		last_error = "Confirm rejected before mutation: %s" % " | ".join(failures)
		return false
	if int(preview.get("history_bytes", history_budget_bytes + 1)) > history_budget_bytes:
		last_error = "Confirm rejected before mutation: terrain history budget changed"
		return false
	if not terrain.commit_structural(label, preview.candidate):
		last_error = "Confirm rejected atomically: %s" % " | ".join(terrain.errors)
		return false
	last_error = ""
	return true


func paste(clipboard: Dictionary, destination: Vector2i, mode := "replace") -> bool:
	return confirm_operation(preview_operation(clipboard, destination, "paste", mode))


func move(clipboard: Dictionary, destination: Vector2i, mode := "replace") -> bool:
	return confirm_operation(preview_operation(clipboard, destination, "move", mode))


func snapped_cell(cell: Vector2i) -> Vector2i:
	var snap := maxi(1, grid_snap_cells)
	return Vector2i(snappedi(cell.x, snap), snappedi(cell.y, snap))


func snapped_height_cm(value: int) -> int:
	return snappedi(value, height_snap_cm)


func world_to_cell(world_position: Vector3, bounded := true) -> Vector2i:
	var grid: Dictionary = terrain.data.grid
	var cell := Vector2i(
		floori((world_position.x - float(grid.origin_x_m)) / float(grid.cell_size_m)),
		floori((world_position.z - float(grid.origin_z_m)) / float(grid.cell_size_m))
	)
	cell = snapped_cell(cell)
	if bounded:
		cell.x = clampi(cell.x, 0, int(grid.width_cells) - 1)
		cell.y = clampi(cell.y, 0, int(grid.depth_cells) - 1)
	return cell


func sample(cell: Vector2i, authored_positions: Dictionary = {}) -> Dictionary:
	var x := clampi(cell.x, 0, int(terrain.data.grid.width_cells) - 1)
	var z := clampi(cell.y, 0, int(terrain.data.grid.depth_cells) - 1)
	var index: int = terrain.cell_index(x, z)
	var layers: Array = terrain.data.surfaces.layer_ids
	var weights: Array = []
	var surfaces: Array[Dictionary] = []
	for layer in layers.size():
		var weight := int(terrain.data.surfaces.weights[index * layers.size() + layer])
		weights.append(weight)
		surfaces.append({"surface_id": layers[layer], "weight": weight, "percent": float(weight) * 100.0 / 255.0})
	var grid: Dictionary = terrain.data.grid
	var center_x := float(grid.origin_x_m) + (float(x) + 0.5) * float(grid.cell_size_m)
	var center_z := float(grid.origin_z_m) + (float(z) + 0.5) * float(grid.cell_size_m)
	var authored_height_cm := int(grid.heights_cm[z * (int(grid.width_cells) + 1) + x])
	var effective_height_cm := roundi(terrain.effective_height(center_x, center_z) * 100.0)
	var cliff_level := int(terrain.data.cliffs.levels[index])
	var water_depth_cm := int(terrain.data.water.level_cm) - roundi(terrain.sample_height(center_x, center_z) * 100.0) - cliff_level * 200 if terrain.data.water.enabled else 0
	var pathing = TerrainPathingScript.new(terrain)
	return {
		"cell": Vector2i(x, z),
		"world": Vector3(center_x, float(effective_height_cm) / 100.0, center_z),
		"height_cm": authored_height_cm,
		"authored_height_cm": authored_height_cm,
		"effective_height_cm": effective_height_cm,
		"surface_weights": weights,
		"surfaces": surfaces,
		"cliff_level": cliff_level,
		"cliff_style_id": terrain.data.cliffs.style_id,
		"water": terrain.data.water.duplicate(true),
		"water_depth_cm": maxi(0, water_depth_cm),
		"water_class": TerrainCliffWaterScript.new(terrain).water_class_at_cell(x, z),
		"movement": terrain.data.pathing.movement[index],
		"placement": terrain.data.pathing.placement[index],
		"movement_reasons": pathing.reasons(x, z, "movement"),
		"placement_reasons": pathing.reasons(x, z, "placement"),
		"attachments": _attachments_at_cell(Vector2i(x, z), authored_positions),
	}


func minimap_recenter(normalized: Vector2) -> Vector3:
	var grid: Dictionary = terrain.data.grid
	var x := float(grid.origin_x_m) + clampf(normalized.x, 0.0, 1.0) * int(grid.width_cells) * float(grid.cell_size_m)
	var z := float(grid.origin_z_m) + clampf(normalized.y, 0.0, 1.0) * int(grid.depth_cells) * float(grid.cell_size_m)
	return Vector3(x, terrain.sample_height(x, z), z)


func _compatibility_error(clipboard: Dictionary) -> String:
	if clipboard.get("clipboard_version") != CLIPBOARD_VERSION: return "Unsupported terrain clipboard version"
	if clipboard.get("anchor") != "north_west": return "Unsupported terrain clipboard anchor"
	if clipboard.get("cell_size_m") != terrain.data.grid.cell_size_m: return "Clipboard and destination cell sizes differ"
	if not clipboard.get("domains") is Dictionary: return "Clipboard domains are invalid"
	if clipboard.get("domains", {}).get("surface", false) and clipboard.get("surface_layer_ids") != terrain.data.surfaces.layer_ids: return "Clipboard surface layers differ from destination"
	if clipboard.get("domains", {}).get("cliff", false) and clipboard.get("cliff_style_id") != terrain.data.cliffs.style_id: return "Clipboard cliff style differs from destination"
	if not clipboard.get("size_cells") is Array or clipboard.size_cells.size() != 2: return "Clipboard size is invalid"
	var width := int(clipboard.size_cells[0])
	var depth := int(clipboard.size_cells[1])
	if width <= 0 or depth <= 0: return "Clipboard size is invalid"
	if not clipboard.get("mask") is Array or clipboard.mask.size() != width * depth: return "Clipboard cell mask is invalid"
	if clipboard.domains.get("height", false) and (not clipboard.get("heights_cm") is Array or clipboard.heights_cm.size() != (width + 1) * (depth + 1)): return "Clipboard height footprint is invalid"
	if clipboard.domains.get("surface", false) and (not clipboard.get("surface_weights") is Array or clipboard.surface_weights.size() != width * depth * terrain.data.surfaces.layer_ids.size()): return "Clipboard surface footprint is invalid"
	if clipboard.domains.get("cliff", false) and (not clipboard.get("cliff_levels") is Array or clipboard.cliff_levels.size() != width * depth or not clipboard.get("ramps", []) is Array): return "Clipboard cliff footprint is invalid"
	if clipboard.domains.get("water", false) and not clipboard.get("water") is Dictionary: return "Clipboard water value is invalid"
	if clipboard.domains.get("pathing", false):
		for field in ["movement", "placement"]:
			if not clipboard.get(field) is Array or clipboard[field].size() != width * depth: return "Clipboard %s pathing footprint is invalid" % field
	return ""


func _preview_base(clipboard: Dictionary, destination: Vector2i, operation: String, mode: String) -> Dictionary:
	var size := Vector2i.ZERO
	if clipboard.get("size_cells") is Array and clipboard.size_cells.size() == 2:
		size = Vector2i(int(clipboard.size_cells[0]), int(clipboard.size_cells[1]))
	var requested := Rect2i(destination, size)
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(int(terrain.data.grid.width_cells), int(terrain.data.grid.depth_cells)))
	var committed := requested.intersection(bounds)
	var result := {
		"ok": true,
		"confirm_enabled": true,
		"operation": operation,
		"mode": mode,
		"source": _clipboard_source_rect(clipboard),
		"requested": requested,
		"destination": committed,
		"dimensions": size,
		"clipped_cells": requested.get_area() - committed.get_area(),
		"overlap_cells": 0,
		"domains": clipboard.get("domains", {}).duplicate(true),
		"boundary_ramps": clipboard.get("boundary_ramps", []).duplicate(true),
		"warnings": [],
		"atomic": true,
		"document_id": terrain.get_instance_id(),
		"revision": terrain.revision,
		"recovery": "",
	}
	var error := _compatibility_error(clipboard)
	if operation not in ["paste", "move"]:
		error = "Operation must be paste or move"
	elif mode not in ["merge", "replace"]:
		error = "Paste mode must be merge or replace"
	elif committed.get_area() <= 0:
		error = "Destination is outside terrain bounds"
	elif operation == "move" and mode != "replace":
		error = "Move always replaces enabled destination values"
	elif operation == "move" and _clipboard_source_rect(clipboard).get_area() <= 0:
		error = "Move source bounds are invalid"
	elif operation == "move" and clipboard.get("domains", {}).get("water", false):
		error = "Move cannot include water because terrain v1 water is a global plane"
	elif operation == "move" and int(clipboard.get("source_document_id", -1)) != terrain.get_instance_id():
		error = "Move source belongs to a different terrain document"
	elif operation == "move" and int(clipboard.get("source_revision", -1)) != int(terrain.revision):
		error = "Move source is stale; copy the selection again"
	elif operation == "move" and result.source == requested:
		error = "Move destination is unchanged"
	elif operation == "move" and result.clipped_cells > 0:
		error = "Move would clip %d cell(s); choose an in-bounds destination" % result.clipped_cells
	if result.source is Rect2i:
		result.overlap_cells = (result.source as Rect2i).intersection(committed).get_area()
	if not result.boundary_ramps.is_empty():
		result.warnings.append("%d boundary ramp(s) remain at the source" % result.boundary_ramps.size())
	if not error.is_empty():
		result.ok = false
		result.confirm_enabled = false
		result.error = error
		result.recovery = "Copy again or choose a compatible, in-bounds destination."
	return result


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
		if selection.has_point(point) and selection.has_point(_ramp_neighbor(point, ramp.direction)):
			output.append({"x": point.x - selection.position.x, "z": point.y - selection.position.y, "direction": ramp.direction})
	return output


func _boundary_ramps() -> Array:
	var output: Array = []
	for ramp in terrain.data.cliffs.ramps:
		var point := Vector2i(ramp.x, ramp.z)
		var neighbor := _ramp_neighbor(point, ramp.direction)
		if selection.has_point(point) != selection.has_point(neighbor):
			output.append(ramp.duplicate(true))
	return output


func _ramp_neighbor(point: Vector2i, direction: String) -> Vector2i:
	return point + {"north": Vector2i.UP, "east": Vector2i.RIGHT, "south": Vector2i.DOWN, "west": Vector2i.LEFT}.get(direction, Vector2i.ZERO)


func _clipboard_source_rect(clipboard: Dictionary) -> Rect2i:
	var position = clipboard.get("source_position")
	var size = clipboard.get("size_cells")
	if position is Array and position.size() == 2 and size is Array and size.size() == 2:
		return Rect2i(int(position[0]), int(position[1]), int(size[0]), int(size[1]))
	return Rect2i()


func _neutralize_source(candidate: Dictionary, clipboard: Dictionary) -> void:
	var rect: Rect2i = _clipboard_source_rect(clipboard)
	var width := int(candidate.grid.width_cells)
	var layers := int(candidate.surfaces.layer_ids.size())
	for z in rect.size.y:
		for x in rect.size.x:
			var cell := (rect.position.y + z) * width + rect.position.x + x
			if clipboard.domains.get("surface", false):
				for layer in layers: candidate.surfaces.weights[cell * layers + layer] = 255 if layer == 0 else 0
			if clipboard.domains.get("cliff", false): candidate.cliffs.levels[cell] = 0
			if clipboard.domains.get("pathing", false):
				candidate.pathing.movement[cell] = "inherit"
				candidate.pathing.placement[cell] = "inherit"
	if clipboard.domains.get("height", false):
		var sample_width := width + 1
		for z in rect.size.y + 1:
			for x in rect.size.x + 1: candidate.grid.heights_cm[(rect.position.y + z) * sample_width + rect.position.x + x] = 0
	if clipboard.domains.get("cliff", false):
		candidate.cliffs.ramps = candidate.cliffs.ramps.filter(func(ramp):
			var point := Vector2i(ramp.x, ramp.z)
			return not (rect.has_point(point) and rect.has_point(_ramp_neighbor(point, ramp.direction)))
		)


func _apply_clipboard(candidate: Dictionary, clipboard: Dictionary, destination: Vector2i, mode: String) -> void:
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
	if clipboard.domains.get("cliff", false): _paste_ramps(candidate, clipboard, destination, size, mode)


func _paste_heights(candidate: Dictionary, clipboard: Dictionary, destination: Vector2i, size: Vector2i) -> void:
	var target_width := int(candidate.grid.width_cells) + 1
	for z in size.y + 1:
		for x in size.x + 1:
			var target := destination + Vector2i(x, z)
			if target.x >= 0 and target.y >= 0 and target.x <= int(candidate.grid.width_cells) and target.y <= int(candidate.grid.depth_cells): candidate.grid.heights_cm[target.y * target_width + target.x] = clipboard.heights_cm[z * (size.x + 1) + x]


func _paste_ramps(candidate: Dictionary, clipboard: Dictionary, destination: Vector2i, size: Vector2i, mode: String) -> void:
	var region := Rect2i(destination, size)
	if mode == "replace":
		candidate.cliffs.ramps = candidate.cliffs.ramps.filter(func(ramp):
			var point := Vector2i(ramp.x, ramp.z)
			return not (region.has_point(point) and region.has_point(_ramp_neighbor(point, ramp.direction)))
		)
	for ramp in clipboard.get("ramps", []):
		var point := destination + Vector2i(ramp.x, ramp.z)
		var neighbor := _ramp_neighbor(point, ramp.direction)
		var duplicate: bool = candidate.cliffs.ramps.any(func(existing): return int(existing.x) == point.x and int(existing.z) == point.y and str(existing.direction) == str(ramp.direction))
		if not duplicate and point.x >= 0 and point.y >= 0 and point.x < int(candidate.grid.width_cells) and point.y < int(candidate.grid.depth_cells) and neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < int(candidate.grid.width_cells) and neighbor.y < int(candidate.grid.depth_cells):
			candidate.cliffs.ramps.append({"x": point.x, "z": point.y, "direction": ramp.direction})
	candidate.cliffs.ramps.sort_custom(func(a, b): return [a.z, a.x, a.direction] < [b.z, b.x, b.direction])


func _changed_cell_count(before: Dictionary, after: Dictionary) -> int:
	var cells := int(before.grid.width_cells) * int(before.grid.depth_cells)
	if before.water != after.water: return cells
	var layers := int(before.surfaces.layer_ids.size())
	var changed_cells := {}
	for cell in cells:
		var changed: bool = before.cliffs.levels[cell] != after.cliffs.levels[cell] or before.pathing.movement[cell] != after.pathing.movement[cell] or before.pathing.placement[cell] != after.pathing.placement[cell]
		if not changed:
			for layer in layers:
				if before.surfaces.weights[cell * layers + layer] != after.surfaces.weights[cell * layers + layer]:
					changed = true
					break
		if changed: changed_cells[cell] = true
	if before.cliffs.ramps != after.cliffs.ramps:
		for ramp in before.cliffs.ramps + after.cliffs.ramps:
			var point := Vector2i(ramp.x, ramp.z)
			var neighbor := _ramp_neighbor(point, ramp.direction)
			for ramp_cell in [point, neighbor]:
				if ramp_cell.x >= 0 and ramp_cell.y >= 0 and ramp_cell.x < int(before.grid.width_cells) and ramp_cell.y < int(before.grid.depth_cells): changed_cells[ramp_cell.y * int(before.grid.width_cells) + ramp_cell.x] = true
	return changed_cells.size()


func _changed_vertex_count(before: Dictionary, after: Dictionary) -> int:
	var count := 0
	for index in before.grid.heights_cm.size():
		if before.grid.heights_cm[index] != after.grid.heights_cm[index]: count += 1
	return count


func _attachments_at_cell(cell: Vector2i, authored_positions: Dictionary) -> Array:
	var result: Array = []
	for attachment in terrain.data.get("attachments", []):
		if not attachment is Dictionary: continue
		var attachment_cell := Vector2i(-1, -1)
		if attachment.get("cell") is Array and attachment.cell.size() == 2:
			attachment_cell = Vector2i(int(attachment.cell[0]), int(attachment.cell[1]))
		elif attachment.get("position") is Array and attachment.position.size() >= 3:
			var grid: Dictionary = terrain.data.grid
			attachment_cell = Vector2i(floori((float(attachment.position[0]) - float(grid.origin_x_m)) / float(grid.cell_size_m)), floori((float(attachment.position[2]) - float(grid.origin_z_m)) / float(grid.cell_size_m)))
		else:
			var target_id := str(attachment.get("target_id", attachment.get("instance_id", attachment.get("spawn_id", ""))))
			if authored_positions.get(target_id) is Array and authored_positions[target_id].size() >= 3:
				var position: Array = authored_positions[target_id]
				var grid: Dictionary = terrain.data.grid
				attachment_cell = Vector2i(floori((float(position[0]) - float(grid.origin_x_m)) / float(grid.cell_size_m)), floori((float(position[2]) - float(grid.origin_z_m)) / float(grid.cell_size_m)))
		if attachment_cell == cell:
			result.append(attachment.duplicate(true))
	return result
