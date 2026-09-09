extends SceneTree

const SHELL := preload("res://src/app/editor_shell.tscn")
const CLIFF_WATER := preload("res://src/domain/terrain_cliff_water.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var editor = SHELL.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	_check(editor.package.world.get("world_id") == "crimsdale", "Editor opens Crimsdale")
	_check(editor.world_root.get_node_or_null("crimsdale_fountain_001") != null, "Fountain preview is created")
	_check(editor.world_root.get_node_or_null("crimsdale_house_001") != null, "House preview is created")
	_check(editor.definition_list.item_count == 4, "Object Editor lists world and unit definitions")
	_check(editor.terrain_dialog != null and editor.terrain_fields.size() == 6, "Terrain workflow exposes explicit dimensions, resolution, height, and origin")
	editor.terrain_fields.width_cells.text = "8"
	editor.terrain_fields.depth_cells.text = "8"
	editor.terrain_fields.cell_size_m.text = "1"
	editor.terrain_fields.base_height_cm.text = "25"
	editor.terrain_fields.origin_x_m.text = "-4"
	editor.terrain_fields.origin_z_m.text = "-4"
	editor._create_terrain()
	_check(editor.package.terrain != null and editor.world_root.get_node_or_null("TerrainPreview") != null, "Terrain creation immediately produces a world preview")
	editor.toggle_sculpt_mode()
	_check(editor.sculpt_enabled and editor.sculpt_tool.item_count == 6 and editor.brush_preview != null, "Persistent sculpt HUD exposes all six tools and a live brush preview")
	editor.toggle_sculpt_mode()
	editor.show_surface_editor()
	_check(editor.surface_catalog.item_count == 4 and editor.surface_layers.item_count >= 1, "Surface palette exposes portable catalog entries and active layers")
	editor.terrain_fields.width_cells.text = "12"
	editor.terrain_fields.depth_cells.text = "10"
	editor.terrain_anchor.select(0)
	editor._resize_terrain()
	_check(editor.package.terrain.data.grid.width_cells == 12, "Terrain bounds can be resized through the Creator workflow")
	editor.perform_undo()
	_check(editor.package.terrain.data.grid.width_cells == 8, "Main toolbar undo restores the prior terrain bounds")
	editor.perform_redo()
	_check(editor.package.terrain.data.grid.width_cells == 12, "Main toolbar redo reapplies the terrain transaction")
	_check(editor.cliff_dialog != null and editor.cliff_style.item_count == 2, "Cliff and water workflow exposes the portable style catalog")
	var cliff_tools = CLIFF_WATER.new(editor.package.terrain)
	_check(cliff_tools.change_level(0, 0, 1), "Creator cliff operation updates a cell")
	editor.refresh_terrain_preview()
	_check(editor.world_root.get_node("TerrainPreview").mesh.get_aabb().end.y >= 2.0, "Discrete cliff height is visible in generated terrain geometry")
	cliff_tools.set_water(true, 100)
	editor.refresh_terrain_preview()
	_check(editor.world_root.get_node_or_null("WaterPreview") != null, "Water depth preview is generated in the viewport")
	editor.show_pathing_editor()
	_check(editor.pathing_dialog.visible and editor.pathing_layer.item_count == 2 and editor.pathing_clearance.item_count == 3, "Pathing workflow exposes separate layers and supported clearances")
	editor.toggle_pathing_overlay()
	_check(editor.pathing_overlay_visible and editor.pathing.last_overlay.size() == 120, "Walkability overlay computes every canonical cell")
	editor.show_environment_editor()
	_check(editor.environment_dialog.visible and editor.environment_sky.item_count == 2 and editor.environment_fields.size() == 7, "Environment workflow exposes focused sun, ambient, fog, and sky controls")
	var preview_before:bool=editor.environment_preview_enabled
	editor.toggle_environment_preview()
	_check(editor.environment_preview_enabled != preview_before, "Accurate environment preview toggles without mutating authored data")
	var guard: Dictionary = editor.package.find_definition("unit_crimsdale_guard")
	_check(guard.owner == "player" and guard.max_health == 120.0, "Crimsdale guard exposes authored gameplay fields")
	editor.load_definition_form(2 if editor.definition_list.get_item_metadata(2) == "unit_crimsdale_guard" else 3)
	_check(editor.unit_fields.max_health.text == "120.0", "Object Editor loads unit gameplay values")

	editor.prepare_new_definition()
	editor.definition_id_field.text = "prop_test_marker"
	editor.definition_name.text = "Test Marker"
	editor.definition_scene.text = "res://content/crimsdale/landmarks/fountain.tscn"
	editor.create_definition_from_form()
	_check(not editor.package.find_definition("prop_test_marker").is_empty(), "Object Editor creates definitions")
	_check(editor.package.dirty, "Definition edits mark package dirty")
	_check(editor.package.undo(), "Definition creation participates in undo")
	_check(editor.package.find_definition("prop_test_marker").is_empty(), "Undo removes created definition")

	var initial_count: int = editor.package.world.objects.size()
	var placed_id: String = editor.package.place_instance("building_crimsdale_house_a", Vector3(8, 0, 8), 30)
	editor.refresh_all()
	_check(not placed_id.is_empty() and editor.world_root.get_node_or_null(placed_id) != null, "Placed data maps to a viewport preview")
	_check(editor.package.undo() and editor.package.world.objects.size() == initial_count, "Placement can be undone")

	var exported_launch: Dictionary = editor.build_test_world_launch("Frontier.exe", "", "C:/Worlds/Crimsdale", "player_start")
	_check(exported_launch.executable == "Frontier.exe", "Exported Frontier executable is preserved")
	_check(exported_launch.arguments == PackedStringArray(["--world-package", "C:/Worlds/Crimsdale", "--spawn", "player_start"]), "Exported build receives the agreed package and spawn contract")
	var project_launch: Dictionary = editor.build_test_world_launch("godot", "/projects/Frontier/Game", "/worlds/crimsdale", "player_start")
	_check(project_launch.arguments == PackedStringArray(["--path", "/projects/Frontier/Game", "--", "--world-package", "/worlds/crimsdale", "--spawn", "player_start"]), "Godot development launch preserves the same runtime contract")

	editor.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.remove_child(editor)
	editor.free()
	await process_frame
	if failures.is_empty():
		print("PASS: editor package, Object Editor, palette, and viewport integration")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
