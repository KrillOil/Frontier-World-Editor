extends SceneTree

const TerrainScript = preload("res://src/domain/terrain_document.gd")
const PainterScript = preload("res://src/domain/terrain_surface_painter.gd")

var failures: Array[String] = []


func _init() -> void:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://content/crimsdale/terrain_surfaces.json"))
	_check(catalog.catalog_format_version == 1 and catalog.surfaces.size() == 4, "Versioned Crimsdale surface catalog loads")
	for surface in catalog.surfaces:
		_check(surface.resource_sha256.length() == 64 and surface.source_color_space == "srgb" and float(surface.uv_scale_m) > 0.0, "Catalog entry carries portable resource and material metadata")
	var terrain = TerrainScript.new()
	terrain.create(8, 8, 1.0, 0)
	var painter = PainterScript.new(terrain)
	_check(painter.add_layer("surface_crimsdale_dirt"), "A second stable surface layer can be added")
	_check(terrain.data.surfaces.weights.size() == 128, "Adding a layer expands cell-major weights")
	painter.begin(1, Vector2(4.5, 4.5), {"radius_m": 2.0, "opacity": 0.5, "falloff": "constant"})
	_check(painter.commit(), "Surface stroke commits")
	var painted: Array = terrain.data.surfaces.weights.duplicate()
	_check(_all_cells_normalized(terrain), "Paint normalizes every cell to exactly 255")
	_check(terrain.history.back().kind == "tiles", "Paint uses exact tile-delta history")
	terrain.undo()
	_check(terrain.data.surfaces.weights[4 * 8 * 2 + 4 * 2 + 1] == 0, "Paint undo restores exact weights")
	terrain.redo()
	_check(terrain.data.surfaces.weights == painted, "Paint redo is deterministic")

	painter = PainterScript.new(terrain)
	painter.begin(1, Vector2(4.5, 4.5), {"radius_m": 1.0, "opacity": 0.25, "falloff": "constant", "erase": true})
	painter.commit()
	_check(_all_cells_normalized(terrain), "Erase transfers weight to the base layer")
	var impact := painter.layer_impact(1)
	_check(impact.cells > 0 and impact.total_weight > 0, "Layer lifecycle impact reports affected cells and weight")
	_check(painter.replace_layer(1, "surface_crimsdale_stone"), "Replace preserves weights under a new stable identity")
	_check(terrain.data.surfaces.weights == terrain.history.back().after.surfaces.weights, "Replace does not alter painted weights")
	_check(painter.add_layer("surface_crimsdale_dry_grass"), "Third layer adds")
	_check(painter.reorder_layers(["surface_crimsdale_stone", "surface_crimsdale_grass", "surface_crimsdale_dry_grass"]), "Reorder remaps weights with identities")
	_check(_all_cells_normalized(terrain), "Reorder preserves normalization")
	_check(painter.remove_layer(2), "Non-base layer removes safely")
	_check(_all_cells_normalized(terrain), "Remove transfers its weights to the base")
	_check(not painter.remove_layer(0), "Base layer cannot be removed")
	_check(painter.add_layer("surface_crimsdale_dirt") and painter.add_layer("surface_crimsdale_dry_grass"), "Catalog layers fill remaining slots")
	_check(not painter.add_layer("surface_extra"), "Fifth layer is rejected")
	var save_path := "user://terrain_surfaces/terrain.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))
	_check(terrain.save(save_path), "Painted surfaces save")
	var saved_bytes := FileAccess.get_file_as_string(save_path)
	var reopened = TerrainScript.new()
	_check(reopened.load_from_file(save_path) and reopened.save(), "Painted surfaces reopen and resave")
	_check(FileAccess.get_file_as_string(save_path) == saved_bytes, "Painted surface save/reopen is byte deterministic")
	_finish()


func _all_cells_normalized(terrain) -> bool:
	var layers: int = terrain.data.surfaces.layer_ids.size()
	for cell in int(terrain.data.grid.width_cells) * int(terrain.data.grid.depth_cells):
		var total := 0
		for layer in layers:
			total += int(terrain.data.surfaces.weights[cell * layers + layer])
		if total != 255:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PASS: deterministic surface painting and layer lifecycle")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
