class_name WorldPackage
extends RefCounted

const TerrainDocumentScript = preload("res://src/domain/terrain_document.gd")
const ScenarioDocumentScript = preload("res://src/domain/scenario_document.gd")
const HistoryClock = preload("res://src/domain/history_clock.gd")
const FORMAT_VERSION := 1
const CATEGORIES := ["building", "prop", "landmark", "unit", "ability", "item"]
const ID_PATTERN := "^[a-z][a-z0-9_]*$"
const UNIT_FIELDS := ["owner", "max_health", "movement_speed", "selection_radius", "attack_damage", "attack_interval", "attack_range", "acquisition_range"]
const HERO_FIELDS := ["hero", "max_mana", "starting_level", "starting_experience", "strength", "agility", "intellect", "ability_ids", "inventory_limit", "pickup_behavior"]
const ABILITY_FIELDS := ["ability_mode", "damage", "cast_range", "cooldown_s", "mana_cost", "area_radius", "chain_count", "presentation"]
const ITEM_FIELDS := ["item_kind", "effect_stat", "effect_amount", "feedback_text"]
const OWNERS := ["player", "ally", "neutral", "hostile"]

var package_path := ""
var definitions: Array[Dictionary] = []
var world: Dictionary = {}
var errors: Array[String] = []
var dirty := false
var terrain
var scenario
var scenario_removed := false
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _undo_transaction_ids: Array[int] = []
var _redo_transaction_ids: Array[int] = []
var revision:=0
var saved_revision:=0
var _next_revision:=1


func load_from_directory(path: String) -> bool:
	if not _recover_transaction(path):
		return false
	var loaded_definitions = _read_json(path.path_join("definitions.json"))
	var loaded_world = _read_json(path.path_join("world.json"))
	if loaded_definitions == null or loaded_world == null:
		return false
	var candidate_definitions: Array[Dictionary] = []
	for entry in loaded_definitions.get("definitions", []):
		candidate_definitions.append(entry.duplicate(true))
	var candidate_world: Dictionary = loaded_world.duplicate(true)
	var candidate_terrain = null
	var terrain_path := path.path_join("terrain.json")
	if FileAccess.file_exists(terrain_path):
		candidate_terrain = TerrainDocumentScript.new()
		if not candidate_terrain.load_from_file(terrain_path):
			errors = candidate_terrain.errors.duplicate()
			return false
	var candidate_scenario = null
	var scenario_path := path.path_join("scenario.json")
	if FileAccess.file_exists(scenario_path):
		candidate_scenario = ScenarioDocumentScript.new()
		if not candidate_scenario.load_from_file(scenario_path, candidate_world):
			errors = candidate_scenario.errors.duplicate()
			return false
	var validation_errors := validate_data(loaded_definitions, candidate_world)
	if not validation_errors.is_empty():
		errors = validation_errors
		return false
	package_path = path
	definitions = candidate_definitions
	world = candidate_world
	terrain = candidate_terrain
	scenario = candidate_scenario
	scenario_removed = false
	errors.clear()
	dirty = false
	_undo.clear()
	_redo.clear()
	_undo_transaction_ids.clear()
	_redo_transaction_ids.clear()
	revision=0
	saved_revision=0
	_next_revision=1
	return true


func validate() -> Array[String]:
	var failures:=validate_data({"format_version": FORMAT_VERSION, "definitions": definitions}, world)
	if scenario!=null:failures.append_array(_scenario_definition_errors())
	return failures


func resource_errors() -> Array[String]:
	var failures: Array[String] = []
	for definition in definitions:
		var scene_path: String = definition.get("scene_path", "")
		if scene_path.begins_with("res://") and not ResourceLoader.exists(scene_path):
			failures.append("Definition '%s' cannot load scene_path '%s'" % [definition.definition_id, scene_path])
	if terrain != null:
		var catalog_path := "res://content/%s/terrain_surfaces.json" % world.get("world_id", "")
		var catalog_file := FileAccess.open(catalog_path, FileAccess.READ)
		if catalog_file == null:
			failures.append("Terrain surface catalog is missing: %s" % catalog_path)
		else:
			var catalog = JSON.parse_string(catalog_file.get_as_text())
			var known := {}
			if catalog is Dictionary:
				for surface in catalog.get("surfaces", []):
					var surface_id: String = surface.get("surface_id", "")
					var source_path: String = surface.get("editor_source_path", "")
					var expected_hash: String = surface.get("resource_sha256", "")
					if source_path.is_empty() or not FileAccess.file_exists(source_path):
						failures.append("Terrain surface '%s' source is missing: %s" % [surface_id, source_path])
					elif FileAccess.get_sha256(source_path) != expected_hash:
						failures.append("Terrain surface '%s' source hash does not match its catalog" % surface_id)
					else:
						known[surface_id] = true
			for surface_id in terrain.data.surfaces.layer_ids:
				if not known.has(surface_id):
					failures.append("Terrain surface '%s' is unresolved in %s" % [surface_id, catalog_path])
		var cliff_catalog_path := "res://content/%s/terrain_cliffs.json" % world.get("world_id", "")
		var cliff_catalog = JSON.parse_string(FileAccess.get_file_as_string(cliff_catalog_path))
		var known_cliffs := {}
		if cliff_catalog is Dictionary:
			for style in cliff_catalog.get("styles", []):
				known_cliffs[style.get("style_id", "")] = true
		if not known_cliffs.has(terrain.data.cliffs.style_id):
			failures.append("Terrain cliff style '%s' is unresolved in %s" % [terrain.data.cliffs.style_id, cliff_catalog_path])
		var sky_catalog_path := "res://content/%s/terrain_skies.json" % world.get("world_id", "")
		var sky_catalog = JSON.parse_string(FileAccess.get_file_as_string(sky_catalog_path))
		var known_skies := {}
		if sky_catalog is Dictionary:
			for sky in sky_catalog.get("skies", []):known_skies[sky.get("sky_id","")]=true
		if not known_skies.has(terrain.data.environment.sky_id):failures.append("Terrain sky '%s' is unresolved in %s"%[terrain.data.environment.sky_id,sky_catalog_path])
	return failures


func validate_data(definition_document: Variant, world_document: Variant) -> Array[String]:
	var failures: Array[String] = []
	if not definition_document is Dictionary:
		failures.append("definitions.json: root must be an object")
		return failures
	if not world_document is Dictionary:
		failures.append("world.json: root must be an object")
		return failures
	_validate_keys(definition_document, ["format_version", "definitions"], "definitions.json", failures)
	_validate_keys(world_document, ["format_version", "world_id", "display_name", "objects", "spawn_points"], "world.json", failures)
	if definition_document.get("format_version") != FORMAT_VERSION:
		failures.append("definitions.json: unsupported format_version '%s'" % definition_document.get("format_version"))
	if world_document.get("format_version") != FORMAT_VERSION:
		failures.append("world.json: unsupported format_version '%s'" % world_document.get("format_version"))
	if not definition_document.get("definitions") is Array:
		failures.append("definitions.json: definitions must be an array")
		return failures
	if not world_document.get("objects") is Array:
		failures.append("world.json: objects must be an array")
		return failures
	if not world_document.get("spawn_points") is Array:
		failures.append("world.json: spawn_points must be an array")
		return failures
	if not _valid_id(world_document.get("world_id", "")):
		failures.append("world.json: world_id is invalid")
	if not world_document.get("display_name") is String or world_document.get("display_name", "").is_empty():
		failures.append("world.json: display_name is required")

	var definition_ids := {}
	for index in definition_document.definitions.size():
		var definition: Variant = definition_document.definitions[index]
		var context := "definitions.json: definitions[%d]" % index
		if not definition is Dictionary:
			failures.append("%s must be an object" % context)
			continue
		var allowed_fields := ["definition_id", "display_name", "category", "scene_path"];var optional_fields:=[]
		if definition.get("category") == "unit":
			allowed_fields.append_array(UNIT_FIELDS)
			optional_fields.append_array(HERO_FIELDS)
		elif definition.get("category") == "ability":allowed_fields.append_array(ABILITY_FIELDS)
		elif definition.get("category") == "item":allowed_fields.append_array(ITEM_FIELDS)
		_validate_keys_optional(definition, allowed_fields, optional_fields, context, failures)
		var definition_id: String = definition.get("definition_id", "")
		if not _valid_id(definition_id):
			failures.append("%s.definition_id is invalid" % context)
		elif definition_ids.has(definition_id):
			failures.append("definitions.json: duplicate definition_id '%s'" % definition_id)
		else:
			definition_ids[definition_id] = true
		if not definition.get("display_name") is String or definition.get("display_name", "").is_empty():
			failures.append("%s.display_name is required" % context)
		if definition.get("category") not in CATEGORIES:
			failures.append("%s.category is unsupported" % context)
		if not definition.get("scene_path") is String or definition.get("scene_path", "").is_empty():
			failures.append("%s.scene_path is required" % context)
		if definition.get("category") == "unit":
			_validate_unit_definition(definition, context, failures)
		elif definition.get("category")=="ability":_validate_ability_definition(definition,context,failures)
		elif definition.get("category")=="item":_validate_item_definition(definition,context,failures)

	var definition_by_id:={};for definition in definition_document.definitions:
		if definition is Dictionary:definition_by_id[definition.get("definition_id","")]=definition
	for definition in definition_document.definitions:
		if not definition is Dictionary or definition.get("category")!="unit":continue
		for ability_id in definition.get("ability_ids",[]):
			if definition_by_id.get(ability_id,{}).get("category")!="ability":failures.append("definitions.json: unit '%s' references unknown ability '%s'"%[definition.get("definition_id"),ability_id])

	var instance_ids := {}
	for index in world_document.objects.size():
		var instance: Variant = world_document.objects[index]
		var context := "world.json: objects[%d]" % index
		if not instance is Dictionary:
			failures.append("%s must be an object" % context)
			continue
		_validate_keys(instance, ["instance_id", "definition_id", "position", "rotation_y"], context, failures)
		var instance_id: String = instance.get("instance_id", "")
		if not _valid_id(instance_id):
			failures.append("%s.instance_id is invalid" % context)
		elif instance_ids.has(instance_id):
			failures.append("world.json: duplicate instance_id '%s'" % instance_id)
		else:
			instance_ids[instance_id] = true
		var definition_id: String = instance.get("definition_id", "")
		if not definition_ids.has(definition_id):
			failures.append("%s '%s' references unknown definition_id '%s'" % [context, instance_id, definition_id])
		_validate_transform(instance, context, failures)

	var spawn_ids := {}
	for index in world_document.spawn_points.size():
		var spawn: Variant = world_document.spawn_points[index]
		var context := "world.json: spawn_points[%d]" % index
		if not spawn is Dictionary:
			failures.append("%s must be an object" % context)
			continue
		_validate_keys(spawn, ["spawn_id", "position", "rotation_y"], context, failures)
		var spawn_id: String = spawn.get("spawn_id", "")
		if not _valid_id(spawn_id):
			failures.append("%s.spawn_id is invalid" % context)
		elif spawn_ids.has(spawn_id):
			failures.append("world.json: duplicate spawn_id '%s'" % spawn_id)
		else:
			spawn_ids[spawn_id] = true
		_validate_transform(spawn, context, failures)
	return failures


func find_definition(definition_id: String) -> Dictionary:
	for definition in definitions:
		if definition.definition_id == definition_id:
			return definition
	return {}


func find_instance(instance_id: String) -> Dictionary:
	for instance in world.get("objects", []):
		if instance.instance_id == instance_id:
			return instance
	return {}


func create_definition(definition: Dictionary) -> bool:
	if not find_definition(definition.get("definition_id", "")).is_empty():
		errors = ["Definition ID '%s' already exists" % definition.get("definition_id")]
		return false
	_snapshot()
	definitions.append(definition.duplicate(true))
	return _accept_change()


func update_definition(definition_id: String, changes: Dictionary) -> bool:
	var definition := find_definition(definition_id)
	if definition.is_empty():
		errors = ["Unknown definition '%s'" % definition_id]
		return false
	_snapshot()
	for key in ["display_name", "category", "scene_path"] + UNIT_FIELDS + HERO_FIELDS + ABILITY_FIELDS + ITEM_FIELDS:
		if changes.has(key):
			definition[key] = changes[key]
	for key in UNIT_FIELDS:
		if definition.get("category") != "unit":
			definition.erase(key)
	for key in HERO_FIELDS:
		if definition.get("category")!="unit":definition.erase(key)
	for key in ABILITY_FIELDS:
		if definition.get("category")!="ability":definition.erase(key)
	for key in ITEM_FIELDS:
		if definition.get("category")!="item":definition.erase(key)
	return _accept_change()


func _validate_unit_definition(definition: Dictionary, context: String, failures: Array[String]) -> void:
	for field in UNIT_FIELDS:
		if not definition.has(field):
			failures.append("%s: missing required unit field '%s'" % [context, field])
	if definition.get("owner") not in OWNERS:
		failures.append("%s.owner must be player, ally, neutral, or hostile" % context)
	for field in ["max_health", "movement_speed", "selection_radius", "attack_interval", "attack_range", "acquisition_range"]:
		var value: Variant = definition.get(field)
		if (not value is int and not value is float) or float(value) <= 0.0:
			failures.append("%s.%s must be greater than zero" % [context, field])
	var damage: Variant = definition.get("attack_damage")
	if (not damage is int and not damage is float) or float(damage) < 0.0:
		failures.append("%s.attack_damage must be zero or greater" % context)
	if definition.get("attack_range") is int or definition.get("attack_range") is float:
		if definition.get("acquisition_range") is int or definition.get("acquisition_range") is float:
			if float(definition.acquisition_range) < float(definition.attack_range):
				failures.append("%s.acquisition_range must be at least attack_range" % context)
	if definition.has("hero"):
		for field in HERO_FIELDS:
			if not definition.has(field):failures.append("%s: hero unit missing '%s'"%[context,field])
		if definition.get("hero")!=true:failures.append("%s.hero must be true when hero fields are present"%context)
		for field in ["max_mana","starting_level","strength","agility","intellect","inventory_limit"]:
			if float(definition.get(field,0))<=0:failures.append("%s.%s must be greater than zero"%[context,field])
		if float(definition.get("starting_experience",-1))<0:failures.append("%s.starting_experience must be zero or greater"%context)
		if not definition.get("ability_ids") is Array:failures.append("%s.ability_ids must be an array"%context)
		if definition.get("pickup_behavior") not in ["automatic","manual"]:failures.append("%s.pickup_behavior is invalid"%context)


func _validate_ability_definition(definition:Dictionary,context:String,failures:Array[String])->void:
	for field in ABILITY_FIELDS:
		if not definition.has(field):failures.append("%s: missing ability field '%s'"%[context,field])
	if definition.get("ability_mode") not in ["targeted","area","chained_damage"]:failures.append("%s.ability_mode is invalid"%context)
	for field in ["damage","cast_range","cooldown_s","mana_cost","area_radius"]:
		if float(definition.get(field,-1))<0:failures.append("%s.%s must be zero or greater"%[context,field])
	if int(definition.get("chain_count",0))<1:failures.append("%s.chain_count must be at least one"%context)
	if not definition.get("presentation") is String or definition.get("presentation","").is_empty():failures.append("%s.presentation is required"%context)


func _validate_item_definition(definition:Dictionary,context:String,failures:Array[String])->void:
	for field in ITEM_FIELDS:
		if not definition.has(field):failures.append("%s: missing item field '%s'"%[context,field])
	if definition.get("item_kind") not in ["consumable","permanent_stat"]:failures.append("%s.item_kind is invalid"%context)
	if definition.get("effect_stat") not in ["health","mana","strength","agility","intellect"]:failures.append("%s.effect_stat is invalid"%context)
	if float(definition.get("effect_amount",0))<=0:failures.append("%s.effect_amount must be greater than zero"%context)
	if not definition.get("feedback_text") is String or definition.get("feedback_text","").is_empty():failures.append("%s.feedback_text is required"%context)


func _scenario_definition_errors()->Array[String]:
	var failures:Array[String]=[];var by_id:={};for definition in definitions:by_id[definition.definition_id]=definition
	for sequence in scenario.data.get("sequences",[]):
		for action in sequence.actions:
			if action.get("type")=="grant_reward" and by_id.get(action.get("reward_id"),{}).get("category")!="item":failures.append("scenario.json: sequence '%s' reward '%s' is not an item definition"%[sequence.sequence_id,action.get("reward_id")])
	return failures


func delete_definition(definition_id: String) -> bool:
	var count := 0
	for instance in world.objects:
		if instance.definition_id == definition_id:
			count += 1
	if count > 0:
		errors = ["Cannot delete '%s': referenced by %d placed instance(s)" % [definition_id, count]]
		return false
	_snapshot()
	definitions = definitions.filter(func(item): return item.definition_id != definition_id)
	return _accept_change()


func place_instance(definition_id: String, position: Vector3, rotation_y: float = 0.0) -> String:
	if find_definition(definition_id).is_empty():
		errors = ["Unknown definition '%s'" % definition_id]
		return ""
	_snapshot()
	var instance_id := _next_instance_id(definition_id)
	world.objects.append({
		"instance_id": instance_id,
		"definition_id": definition_id,
		"position": [position.x, position.y, position.z],
		"rotation_y": rotation_y,
	})
	_accept_change()
	return instance_id


func update_instance(instance_id: String, position: Vector3, rotation_y: float) -> bool:
	var instance := find_instance(instance_id)
	if instance.is_empty():
		errors = ["Unknown instance '%s'" % instance_id]
		return false
	_snapshot()
	instance.position = [position.x, position.y, position.z]
	instance.rotation_y = rotation_y
	return _accept_change()


func delete_instance(instance_id: String) -> bool:
	if find_instance(instance_id).is_empty():
		return false
	_snapshot()
	world.objects = world.objects.filter(func(item): return item.instance_id != instance_id)
	return _accept_change()


func set_player_start(position: Vector3, rotation_y: float) -> bool:
	_snapshot()
	var found := false
	for spawn in world.spawn_points:
		if spawn.spawn_id == "player_start":
			spawn.position = [position.x, position.y, position.z]
			spawn.rotation_y = rotation_y
			found = true
	if not found:
		world.spawn_points.append({"spawn_id": "player_start", "position": [position.x, position.y, position.z], "rotation_y": rotation_y})
	return _accept_change()


func undo() -> bool:
	if _undo.is_empty():
		return false
	var entry:Dictionary=_undo.pop_back()
	_redo.append({"state":_state(),"revision":revision})
	_redo_transaction_ids.append(_undo_transaction_ids.pop_back())
	_restore(entry.state)
	revision=int(entry.revision)
	dirty=revision!=saved_revision
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var entry:Dictionary=_redo.pop_back()
	_undo.append({"state":_state(),"revision":revision})
	_undo_transaction_ids.append(_redo_transaction_ids.pop_back())
	_restore(entry.state)
	revision=int(entry.revision)
	dirty=revision!=saved_revision
	return true


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func history_depth() -> int:
	return _undo.size()


func discard_redo_history() -> void:
	_redo.clear()
	_redo_transaction_ids.clear()


func undo_transaction_ids() -> Array[int]:
	return _undo_transaction_ids.duplicate()


func save(failure_after_install := -1) -> bool:
	errors = validate()
	errors.append_array(resource_errors())
	if not errors.is_empty():
		return false
	if package_path.is_empty():
		errors = ["No package path is open"]
		return false
	definitions.sort_custom(func(a, b): return a.definition_id < b.definition_id)
	world.objects.sort_custom(func(a, b): return a.instance_id < b.instance_id)
	world.spawn_points.sort_custom(func(a, b): return a.spawn_id < b.spawn_id)
	var definition_document := {"format_version": FORMAT_VERSION, "definitions": definitions}
	var definitions_path := package_path.path_join("definitions.json")
	var world_path := package_path.path_join("world.json")
	var paths := [definitions_path, world_path]
	var delete_paths: Array[String] = []
	if not _write_temporary(definitions_path, JSON.stringify(definition_document, "  ") + "\n"):
		return false
	if not _write_temporary(world_path, JSON.stringify(world, "  ") + "\n"):
		return false
	if terrain != null:
		var terrain_failures: Array[String] = terrain.validate(terrain.data)
		if not terrain_failures.is_empty():
			errors = terrain_failures
			return false
		var terrain_path := package_path.path_join("terrain.json")
		if not _write_temporary(terrain_path, terrain.serialize()):
			return false
		paths.append(terrain_path)
	if scenario != null:
		var scenario_failures: Array[String] = scenario.validate(scenario.data, world)
		if not scenario_failures.is_empty():
			errors = scenario_failures
			return false
		var scenario_path := package_path.path_join("scenario.json")
		if not _write_temporary(scenario_path, scenario.canonical_text()):
			return false
		paths.append(scenario_path)
	elif scenario_removed and FileAccess.file_exists(package_path.path_join("scenario.json")):
		delete_paths.append(package_path.path_join("scenario.json"))
	if not _replace_files(paths, failure_after_install, delete_paths):
		return false
	if terrain != null:
		terrain.mark_saved(package_path.path_join("terrain.json"))
	if scenario != null:
		scenario.mark_saved(package_path.path_join("scenario.json"))
	scenario_removed = false
	saved_revision=revision
	dirty = false
	return true


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors = ["%s: could not be opened" % path]
		return null
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		errors = ["%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()]]
		return null
	return json.data


func _write_temporary(path: String, content: String) -> bool:
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		errors = ["%s: temporary file could not be written" % path]
		return false
	file.store_string(content)
	file.close()
	return true


func _replace_files(paths: Array, failure_after_install := -1, delete_paths: Array[String] = []) -> bool:
	var transaction_path := package_path.path_join(".world-package-transaction.json")
	var transaction_paths: Array = paths + delete_paths
	var preexisting := []
	for path in transaction_paths: preexisting.append(FileAccess.file_exists(path))
	var marker := FileAccess.open(transaction_path, FileAccess.WRITE)
	if marker == null:
		errors = ["Save prepare stage: transaction marker could not be written"]
		return false
	marker.store_string(JSON.stringify({"version": 1, "paths": transaction_paths, "preexisting": preexisting}) + "\n")
	marker.close()
	for path in transaction_paths:
		var backup_path: String = path + ".bak"
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		if FileAccess.file_exists(path) and DirAccess.rename_absolute(path, backup_path) != OK:
			errors = ["%s: could not protect the previous valid file" % path]
			_restore_backups(transaction_paths, preexisting)
			return false
	for index in paths.size():
		var path: String = paths[index]
		if DirAccess.rename_absolute(path + ".tmp", path) != OK:
			errors = ["%s: could not install the validated temporary file" % path]
			_restore_backups(transaction_paths, preexisting)
			return false
		if failure_after_install == index + 1:
			errors = ["Save commit stage: injected failure after %d file(s); previous package restored" % (index + 1)]
			_restore_backups(paths, preexisting)
			return false
	for path in transaction_paths:
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
	DirAccess.remove_absolute(transaction_path)
	return true


func set_scenario(document)->bool:
	_snapshot()
	scenario=document
	scenario_removed=false
	return _accept_change()


func set_terrain(document)->bool:
	if terrain == document:
		return false
	_snapshot()
	terrain = document
	return _accept_change()


func remove_scenario() -> bool:
	if scenario==null:return false
	scenario.discard_redo_history()
	_snapshot()
	scenario = null
	scenario_removed = true
	return _accept_change()


func _restore_backups(paths: Array, preexisting: Array = []) -> void:
	for index in paths.size():
		var path: String = paths[index]
		var backup_path: String = path + ".bak"
		if FileAccess.file_exists(backup_path):
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
			DirAccess.rename_absolute(backup_path, path)
		elif index < preexisting.size() and not preexisting[index] and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		if FileAccess.file_exists(path + ".tmp"):
			DirAccess.remove_absolute(path + ".tmp")
	if not package_path.is_empty():
		DirAccess.remove_absolute(package_path.path_join(".world-package-transaction.json"))


func _recover_transaction(path: String) -> bool:
	var transaction_path := path.path_join(".world-package-transaction.json")
	if not FileAccess.file_exists(transaction_path):
		return true
	var marker = _read_json(transaction_path)
	if not marker is Dictionary or marker.get("version") != 1 or not marker.get("paths") is Array or not marker.get("preexisting") is Array:
		errors = ["Save recovery stage: invalid transaction marker; preserve the package and restore its .bak files manually"]
		return false
	package_path = path
	_restore_backups(marker.paths, marker.preexisting)
	return true


func terrain_build_identity(build_settings: Dictionary = {}) -> Dictionary:
	if terrain == null:
		return {}
	var resources := resource_errors()
	if not resources.is_empty():
		return {"error": "Build validation stage: %s" % " | ".join(resources)}
	var resource_hashes := _terrain_resource_hashes()
	var material: String = terrain.serialize() + JSON.stringify(build_settings) + JSON.stringify(resource_hashes) + str(terrain.data.terrain_format_version) + ":" + str(terrain.data.algorithm_version)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(material.to_utf8_buffer())
	return {"cache_key": context.finish().hex_encode(), "terrain_sha256": terrain.serialize().sha256_text(), "resource_hashes": resource_hashes, "schema_version": terrain.data.terrain_format_version, "algorithm_version": terrain.data.algorithm_version, "build_settings": build_settings.duplicate(true)}


func test_world_preflight(build_settings: Dictionary = {}) -> Dictionary:
	var validation := validate()
	if scenario != null:
		validation.append_array(scenario.validate(scenario.data, world))
	validation.append_array(resource_errors())
	if not validation.is_empty():
		return {"ok": false, "stage": "validate", "diagnostics": validation, "recovery": "Fix the named authored domain or resource, save, then retry Test World"}
	var identity := terrain_build_identity(build_settings)
	if identity.has("error"):
		return {"ok": false, "stage": "build", "diagnostics": [identity.error], "recovery": "Resolve the named terrain resource and rebuild"}
	return {"ok": true, "stage": "launch", "progress": 1.0, "cache": identity, "diagnostics": [], "recovery": ""}


func _terrain_resource_hashes() -> Dictionary:
	var hashes := {}
	for name in ["terrain_surfaces.json", "terrain_cliffs.json", "terrain_skies.json"]:
		var path := "res://content/%s/%s" % [world.get("world_id", ""), name]
		hashes[name] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return hashes


func _snapshot() -> void:
	_undo.append({"state":_state(),"revision":revision})
	_undo_transaction_ids.append(HistoryClock.claim())
	_redo.clear()
	_redo_transaction_ids.clear()
	revision=_next_revision
	_next_revision+=1


func _state() -> Dictionary:
	return {"definitions": definitions.duplicate(true), "world": world.duplicate(true), "terrain": terrain, "scenario": scenario}


func _restore(state: Dictionary) -> void:
	definitions = state.definitions.duplicate(true)
	world = state.world.duplicate(true)
	terrain = state.get("terrain")
	scenario=state.get("scenario")
	scenario_removed=scenario==null and not package_path.is_empty() and FileAccess.file_exists(package_path.path_join("scenario.json"))


func _accept_change() -> bool:
	errors = validate()
	if not errors.is_empty():
		var entry:Dictionary=_undo.pop_back()
		_restore(entry.state)
		revision=int(entry.revision)
		_undo_transaction_ids.pop_back()
		return false
	dirty=revision!=saved_revision
	return true


func _next_instance_id(definition_id: String) -> String:
	var prefix := definition_id + "_"
	var number := 1
	while not find_instance(prefix + "%03d" % number).is_empty():
		number += 1
	return prefix + "%03d" % number


func _valid_id(value: Variant) -> bool:
	if not value is String:
		return false
	var regex := RegEx.new()
	regex.compile(ID_PATTERN)
	return regex.search(value) != null


func _validate_keys(data: Dictionary, allowed: Array, context: String, failures: Array[String]) -> void:
	_validate_keys_optional(data,allowed,[],context,failures)


func _validate_keys_optional(data:Dictionary,required:Array,optional:Array,context:String,failures:Array[String])->void:
	for key in required:
		if not data.has(key):
			failures.append("%s: missing required field '%s'" % [context, key])
	for key in data.keys():
		if key not in required and key not in optional:
			failures.append("%s: unknown field '%s'" % [context, key])


func _validate_transform(data: Dictionary, context: String, failures: Array[String]) -> void:
	var position: Variant = data.get("position")
	if not position is Array or position.size() != 3:
		failures.append("%s.position must contain exactly three numbers" % context)
	else:
		for value in position:
			if not value is int and not value is float:
				failures.append("%s.position must contain only numbers" % context)
	if not data.get("rotation_y") is int and not data.get("rotation_y") is float:
		failures.append("%s.rotation_y must be a number" % context)
