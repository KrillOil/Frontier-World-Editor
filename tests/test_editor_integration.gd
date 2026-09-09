extends SceneTree

const SHELL := preload("res://src/app/editor_shell.tscn")

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
