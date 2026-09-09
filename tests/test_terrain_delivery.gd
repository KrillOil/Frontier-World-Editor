extends SceneTree

const TERRAIN := preload("res://src/domain/terrain_document.gd")
const PACKAGE := preload("res://src/domain/world_package.gd")
var failures: Array[String] = []


func _init() -> void:
	var timings := {}
	for spec in [["minimum", 8], ["target", 128], ["maximum", 512]]:
		var started := Time.get_ticks_msec()
		var terrain = TERRAIN.new()
		_check(terrain.create(spec[1], spec[1], 1.0, 0) and terrain.validate(terrain.data).is_empty(), "%s fixture creates and validates" % spec[0])
		timings[spec[0]] = Time.get_ticks_msec() - started
	var current = TERRAIN.new(); current.create(8, 8, 1.0, 0)
	var preview := current.migration_preview(current.data)
	_check(preview.supported and preview.changes.is_empty() and not preview.requires_backup, "Current v1 migration preview is deterministic and idempotent")
	var future: Dictionary = current.data.duplicate(true); future.terrain_format_version = 2
	_check(not current.migration_preview(future).supported, "Unregistered future terrain versions never overwrite on open")

	var directory := "user://terrain_delivery/crimsdale"
	DirAccess.make_dir_recursive_absolute(directory)
	_copy("res://worlds/crimsdale/definitions.json", directory.path_join("definitions.json"))
	_copy("res://worlds/crimsdale/world.json", directory.path_join("world.json"))
	_copy("res://worlds/crimsdale/terrain.json", directory.path_join("terrain.json"))
	var package = PACKAGE.new()
	_check(package.load_from_directory(directory), "Complete Crimsdale package opens")
	var identity_a := package.terrain_build_identity({"chunk_cells": 32})
	var identity_b := package.terrain_build_identity({"chunk_cells": 32})
	_check(identity_a.cache_key == identity_b.cache_key and identity_a.resource_hashes.size() == 3, "Cache identity covers deterministic payload, versions, resources, and build settings")
	var preflight := package.test_world_preflight({"chunk_cells": 32})
	_check(preflight.ok and preflight.stage == "launch" and preflight.progress == 1.0, "Test World preflight reports staged completion")
	var before := _package_bytes(directory)
	package.world.display_name = "Failure injection"
	_check(not package.save(1) and _package_bytes(directory) == before, "Injected multi-file commit failure restores the complete prior package")
	_check(package.load_from_directory(directory), "Recovered package reopens after interrupted transaction")
	_check(package.save(), "Complete package saves transactionally")
	var reopened = PACKAGE.new()
	_check(reopened.load_from_directory(directory) and reopened.terrain.serialize() == package.terrain.serialize(), "Every terrain domain semantically round-trips")
	print("Terrain fixture timings (informational ms): ", timings)
	if failures.is_empty(): print("PASS: terrain persistence, migration gate, recovery, cache, and Test World preflight"); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)


func _package_bytes(directory: String) -> Array[String]:
	return [FileAccess.get_file_as_string(directory.path_join("definitions.json")), FileAccess.get_file_as_string(directory.path_join("world.json")), FileAccess.get_file_as_string(directory.path_join("terrain.json"))]


func _copy(source: String, destination: String) -> void:
	var input := FileAccess.open(source, FileAccess.READ); var output := FileAccess.open(destination, FileAccess.WRITE)
	output.store_buffer(input.get_buffer(input.get_length())); output.close(); input.close()


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
