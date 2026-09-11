extends SceneTree

const WorldPackageScript = preload("res://src/domain/world_package.gd")

var failures: Array[String] = []


func _init() -> void:
	var temporary_package := "user://frontier_world_editor_tests/crimsdale"
	DirAccess.make_dir_recursive_absolute(temporary_package)
	copy_file("res://worlds/crimsdale/definitions.json", temporary_package.path_join("definitions.json"))
	copy_file("res://worlds/crimsdale/world.json", temporary_package.path_join("world.json"))
	copy_file("res://tests/fixtures/scenario_tiny/scenario.json", temporary_package.path_join("scenario.json"))
	var package = WorldPackageScript.new()
	_check(package.load_from_directory(temporary_package), "Crimsdale fixture loads")
	_check(package.validate().is_empty(), "Crimsdale fixture validates")
	_check(package.resource_errors().is_empty(), "Crimsdale preview resources resolve")
	_check(package.scenario != null and package.scenario.data.scenario_id == "tiny_guided_path", "Optional scenario document loads with its world references")
	var guard: Dictionary = package.find_definition("unit_crimsdale_guard")
	_check(guard.owner == "player" and guard.attack_damage == 14.0, "Unit gameplay definition loads")
	var invalid_guard := guard.duplicate(true)
	invalid_guard.max_health = 0.0
	var invalid_definitions: Array[Dictionary] = package.definitions.duplicate(true)
	invalid_definitions[invalid_definitions.find(guard)] = invalid_guard
	_check(package.validate_data({"format_version": 1, "definitions": invalid_definitions}, package.world).any(func(message): return "max_health" in message), "Invalid unit health is rejected")

	var duplicate_definitions := {"format_version": 1, "definitions": package.definitions.duplicate(true)}
	duplicate_definitions.definitions.append(package.definitions[0].duplicate(true))
	_check(_contains(package.validate_data(duplicate_definitions, package.world), "duplicate definition_id"), "Duplicate definitions fail")

	var unresolved_world: Dictionary = package.world.duplicate(true)
	unresolved_world.objects[0].definition_id = "missing_definition"
	_check(_contains(package.validate_data({"format_version": 1, "definitions": package.definitions}, unresolved_world), "unknown definition_id"), "Unresolved references fail")

	var unsupported_world: Dictionary = package.world.duplicate(true)
	unsupported_world.format_version = 99
	_check(_contains(package.validate_data({"format_version": 1, "definitions": package.definitions}, unsupported_world), "unsupported format_version"), "Unsupported versions fail")

	var object_count: int = package.world.objects.size()
	var instance_id: String = package.place_instance("building_crimsdale_house_a", Vector3(2, 0, 3), 45.0)
	_check(not instance_id.is_empty() and package.world.objects.size() == object_count + 1, "Placement changes canonical data")
	_check(package.undo() and package.world.objects.size() == object_count, "Undo restores prior state")
	_check(package.redo() and package.world.objects.size() == object_count + 1, "Redo reapplies state")
	_check(not package.delete_definition("building_crimsdale_house_a"), "Referenced definition deletion is blocked")
	var missing_resource: Dictionary = package.definitions[0].duplicate(true)
	missing_resource.definition_id = "building_missing_preview"
	missing_resource.scene_path = "res://content/missing_preview.tscn"
	_check(package.create_definition(missing_resource), "Missing preview resources remain inspectable")
	_check(_contains(package.resource_errors(), "building_missing_preview"), "Missing preview resource error identifies its definition")
	_check(package.undo(), "Missing preview fixture can be removed before save")
	_check(package.set_player_start(Vector3(5, 0, 6), 90), "Player start can be updated")
	var player_start: Dictionary = package.world.spawn_points[0]
	_check(player_start.position == [5.0, 0.0, 6.0] and player_start.rotation_y == 90, "Player start remains unique and stores its transform")
	_check(package.save(), "Valid authored package saves")
	var first_save := FileAccess.get_file_as_string(temporary_package.path_join("world.json"))
	_check(package.save(), "Unchanged authored package saves again")
	_check(first_save == FileAccess.get_file_as_string(temporary_package.path_join("world.json")), "Unchanged save is deterministic")
	var reopened = WorldPackageScript.new()
	_check(reopened.load_from_directory(temporary_package), "Saved package reopens")
	_check(reopened.world.objects.size() == object_count + 1, "Semantic round trip preserves instances")
	_check(reopened.scenario != null and reopened.scenario.canonical_text() == package.scenario.canonical_text(), "Scenario save and reopen preserves authored meaning")

	if failures.is_empty():
		print("PASS: authored package validation and commands")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _contains(messages: Array[String], fragment: String) -> bool:
	for message in messages:
		if fragment in message:
			return true
	return false


func copy_file(source: String, destination: String) -> void:
	var source_file := FileAccess.open(source, FileAccess.READ)
	var destination_file := FileAccess.open(destination, FileAccess.WRITE)
	destination_file.store_buffer(source_file.get_buffer(source_file.get_length()))
