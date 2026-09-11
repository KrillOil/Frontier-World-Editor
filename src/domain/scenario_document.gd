class_name ScenarioDocument
extends RefCounted

const FORMAT_VERSION := 1
const ID_PATTERN := "^[a-z][a-z0-9_]*$"
const EVENTS := ["scenario_start", "unit_enters_region", "unit_died", "objective_changed", "sequence_completed"]
const CONDITIONS := ["objective_is", "group_alive", "group_owned_by", "sequence_has_run"]
const ACTIONS := ["show_message", "set_objective", "set_ownership", "order_group", "set_encounter", "grant_reward", "play_cinematic", "complete_scenario"]
const CINEMATIC_STEPS := ["dialogue", "camera", "unit_cue", "audio"]

var data: Dictionary = {}
var errors: Array[String] = []
var source_path := ""


func load_from_file(path: String, world: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _fail(["%s: could not be opened" % path])
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return _fail(["%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()]])
	if not json.data is Dictionary: return _fail(["scenario.json: root must be an object"])
	var failures := validate(json.data, world)
	if not failures.is_empty(): return _fail(failures)
	data = json.data.duplicate(true); source_path = path; errors.clear(); return true


func validate(candidate: Dictionary, world: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	_exact(candidate, ["scenario_format_version","scenario_id","title","description","player_faction_id","regions","unit_groups","objectives","cinematics","sequences"], "scenario.json", failures)
	if candidate.get("scenario_format_version") != FORMAT_VERSION: failures.append("scenario.json: unsupported scenario_format_version '%s'" % candidate.get("scenario_format_version"))
	for field in ["scenario_id", "player_faction_id"]:
		if not _valid_id(candidate.get(field)): failures.append("scenario.json.%s must be a stable ID" % field)
	if not candidate.get("title") is String or candidate.get("title", "").is_empty(): failures.append("scenario.json.title is required")
	if not candidate.get("description") is String: failures.append("scenario.json.description must be text")
	for collection in ["regions","unit_groups","objectives","cinematics","sequences"]:
		if not candidate.get(collection) is Array: failures.append("scenario.json.%s must be an array" % collection)
	if not failures.is_empty(): return failures
	var region_ids := _validate_regions(candidate.regions, failures)
	var group_ids := _validate_groups(candidate.unit_groups, world, failures)
	var objective_ids := _validate_objectives(candidate.objectives, failures)
	var cinematic_ids := _validate_cinematics(candidate.cinematics, region_ids, group_ids, world, failures)
	var sequence_ids := _ids(candidate.sequences, "sequence_id", "sequences", failures)
	_validate_sequences(candidate.sequences, region_ids, group_ids, objective_ids, cinematic_ids, sequence_ids, failures)
	_validate_sequence_cycles(candidate.sequences, sequence_ids, failures)
	return failures


func canonical_text() -> String:
	var normalized := data.duplicate(true)
	for pair in [["regions","region_id"],["unit_groups","group_id"],["objectives","objective_id"],["cinematics","cinematic_id"],["sequences","sequence_id"]]:
		normalized[pair[0]].sort_custom(func(a, b): return a[pair[1]] < b[pair[1]])
	return _canonical_json(normalized) + "\n"


func content_hash() -> String: return canonical_text().sha256_text()


func _validate_regions(values: Array, failures: Array[String]) -> Dictionary:
	var ids := _ids(values, "region_id", "regions", failures)
	for index in values.size():
		var value = values[index]; var context := "scenario.json.regions[%d]" % index
		if not value is Dictionary: continue
		_exact(value, ["region_id","display_name","shape","points"], context, failures)
		if value.get("shape") not in ["point","rectangle","path"]: failures.append("%s.shape is unsupported" % context)
		var points = value.get("points")
		if not points is Array: failures.append("%s.points must be an array" % context); continue
		var expected := 1 if value.get("shape") == "point" else 2
		if points.size() < expected or value.get("shape") != "path" and points.size() != expected: failures.append("%s.points count does not match its shape" % context)
		for point in points:
			if not _vector3(point): failures.append("%s.points must contain world-space Vector3 values" % context); break
	return ids


func _validate_groups(values: Array, world: Dictionary, failures: Array[String]) -> Dictionary:
	var ids := _ids(values, "group_id", "unit_groups", failures); var instances := {}
	for item in world.get("objects", []): instances[item.get("instance_id", "")] = true
	for index in values.size():
		var value = values[index]; var context := "scenario.json.unit_groups[%d]" % index
		if not value is Dictionary: continue
		_exact(value, ["group_id","instance_ids"], context, failures)
		if not value.get("instance_ids") is Array or value.get("instance_ids", []).is_empty(): failures.append("%s.instance_ids must not be empty" % context); continue
		var seen := {}
		for instance_id in value.instance_ids:
			if not _valid_id(instance_id) or seen.has(instance_id): failures.append("%s has an invalid or duplicate instance reference" % context)
			elif not instances.has(instance_id): failures.append("%s references unknown world instance '%s'" % [context, instance_id])
			seen[instance_id] = true
	return ids


func _validate_objectives(values: Array, failures: Array[String]) -> Dictionary:
	var ids := _ids(values, "objective_id", "objectives", failures)
	for index in values.size():
		var value = values[index]; var context := "scenario.json.objectives[%d]" % index
		if not value is Dictionary: continue
		_exact(value, ["objective_id","title","kind","initial_state"], context, failures)
		if value.get("kind") not in ["main","optional"] or value.get("initial_state") not in ["hidden","active"]: failures.append("%s has invalid kind or initial state" % context)
	return ids


func _validate_cinematics(values: Array, regions: Dictionary, groups: Dictionary, world: Dictionary, failures: Array[String]) -> Dictionary:
	var ids := _ids(values, "cinematic_id", "cinematics", failures); var instances := {}
	for item in world.get("objects", []): instances[item.get("instance_id", "")] = true
	for index in values.size():
		var value = values[index]; var context := "scenario.json.cinematics[%d]" % index
		if not value is Dictionary: continue
		_exact(value, ["cinematic_id","skippable","steps"], context, failures)
		if not value.get("skippable") is bool or not value.get("steps") is Array: failures.append("%s requires skippable and steps" % context); continue
		for step_index in value.steps.size():
			_validate_cinematic_step(value.steps[step_index], "%s.steps[%d]" % [context, step_index], regions, groups, instances, failures)
	return ids


func _validate_cinematic_step(step, context: String, regions: Dictionary, groups: Dictionary, instances: Dictionary, failures: Array[String]) -> void:
	if not step is Dictionary or step.get("type") not in CINEMATIC_STEPS: failures.append("%s has an unsupported cinematic step" % context); return
	match step.type:
		"dialogue":
			_exact_optional(step, ["type","speaker_instance_id","text","duration_s"], ["audio_id"], context, failures)
			if not instances.has(step.get("speaker_instance_id")) or float(step.get("duration_s", 0)) <= 0: failures.append("%s has invalid speaker or duration" % context)
		"camera":
			_exact(step, ["type","region_id","duration_s","blend_s"], context, failures)
			if not regions.has(step.get("region_id")) or float(step.get("duration_s", 0)) <= 0 or float(step.get("blend_s", -1)) < 0: failures.append("%s has invalid camera region or timing" % context)
		"unit_cue":
			_exact(step, ["type","group_id","cue","target_region_id"], context, failures)
			if not groups.has(step.get("group_id")) or not regions.has(step.get("target_region_id")) or step.get("cue") not in ["face","move","animate","show","hide","transform"]: failures.append("%s has invalid unit cue references" % context)
		"audio":
			_exact(step, ["type","audio_id","volume","policy"], context, failures)
			if not _valid_id(step.get("audio_id")) or float(step.get("volume", -1)) < 0 or step.get("policy") not in ["mix","replace","stop"]: failures.append("%s has invalid audio settings" % context)


func _validate_sequences(values: Array, regions: Dictionary, groups: Dictionary, objectives: Dictionary, cinematics: Dictionary, sequences: Dictionary, failures: Array[String]) -> void:
	for index in values.size():
		var value = values[index]; var context := "scenario.json.sequences[%d]" % index
		if not value is Dictionary: continue
		_exact(value, ["sequence_id","enabled","one_shot","event","conditions","actions"], context, failures)
		if not value.get("enabled") is bool or not value.get("one_shot") is bool or not value.get("conditions") is Array or not value.get("actions") is Array or value.get("actions", []).is_empty(): failures.append("%s has invalid execution fields" % context); continue
		_validate_event(value.get("event"), context + ".event", regions, groups, objectives, sequences, failures)
		for offset in value.conditions.size(): _validate_condition(value.conditions[offset], "%s.conditions[%d]" % [context, offset], groups, objectives, sequences, failures)
		for offset in value.actions.size(): _validate_action(value.actions[offset], "%s.actions[%d]" % [context, offset], regions, groups, objectives, cinematics, failures)


func _validate_event(value, context: String, regions: Dictionary, groups: Dictionary, objectives: Dictionary, sequences: Dictionary, failures: Array[String]) -> void:
	if not value is Dictionary or value.get("type") not in EVENTS: failures.append("%s has an unsupported event" % context); return
	var keys: Array = {"scenario_start":["type"],"unit_enters_region":["type","group_id","region_id"],"unit_died":["type","group_id"],"objective_changed":["type","objective_id","state"],"sequence_completed":["type","sequence_id"]}[value.type]
	_exact(value, keys, context, failures)
	if value.type == "unit_enters_region" and (not groups.has(value.get("group_id")) or not regions.has(value.get("region_id"))): failures.append("%s has unresolved group or region" % context)
	if value.type == "unit_died" and not groups.has(value.get("group_id")): failures.append("%s has unresolved group" % context)
	if value.type == "objective_changed" and (not objectives.has(value.get("objective_id")) or value.get("state") not in ["hidden","active","completed","failed"]): failures.append("%s has unresolved objective or state" % context)
	if value.type == "sequence_completed" and not sequences.has(value.get("sequence_id")): failures.append("%s has unresolved sequence" % context)


func _validate_condition(value, context: String, groups: Dictionary, objectives: Dictionary, sequences: Dictionary, failures: Array[String]) -> void:
	if not value is Dictionary or value.get("type") not in CONDITIONS: failures.append("%s has an unsupported condition" % context); return
	var keys: Array = {"objective_is":["type","objective_id","state"],"group_alive":["type","group_id","value"],"group_owned_by":["type","group_id","owner_id"],"sequence_has_run":["type","sequence_id","value"]}[value.type]
	_exact(value, keys, context, failures)
	if value.type == "objective_is" and (not objectives.has(value.get("objective_id")) or value.get("state") not in ["hidden","active","completed","failed"]): failures.append("%s has unresolved objective or state" % context)
	if value.type in ["group_alive","group_owned_by"] and not groups.has(value.get("group_id")): failures.append("%s has unresolved group" % context)
	if value.type == "sequence_has_run" and not sequences.has(value.get("sequence_id")): failures.append("%s has unresolved sequence" % context)
	if value.type in ["group_alive","sequence_has_run"] and not value.get("value") is bool: failures.append("%s.value must be boolean" % context)


func _validate_action(value, context: String, regions: Dictionary, groups: Dictionary, objectives: Dictionary, cinematics: Dictionary, failures: Array[String]) -> void:
	if not value is Dictionary or value.get("type") not in ACTIONS: failures.append("%s has an unsupported action" % context); return
	var keys: Array = {"show_message":["type","message_id","text","duration_s"],"set_objective":["type","objective_id","state"],"set_ownership":["type","group_id","owner_id"],"order_group":["type","group_id","order","target_region_id"],"set_encounter":["type","group_id","state","behavior","leash_region_id"],"grant_reward":["type","group_id","reward_id"],"play_cinematic":["type","cinematic_id"],"complete_scenario":["type","result"]}[value.type]
	_exact(value, keys, context, failures)
	if value.type == "show_message" and (not _valid_id(value.get("message_id")) or not value.get("text") is String or float(value.get("duration_s", 0)) <= 0): failures.append("%s has invalid message fields" % context)
	if value.type == "set_objective" and (not objectives.has(value.get("objective_id")) or value.get("state") not in ["hidden","active","completed","failed"]): failures.append("%s has unresolved objective or state" % context)
	if value.type in ["set_ownership","grant_reward"] and not groups.has(value.get("group_id")): failures.append("%s has unresolved group" % context)
	if value.type == "order_group" and (not groups.has(value.get("group_id")) or not regions.has(value.get("target_region_id")) or value.get("order") not in ["move","attack_move"]): failures.append("%s has invalid group order" % context)
	if value.type == "set_encounter" and (not groups.has(value.get("group_id")) or not regions.has(value.get("leash_region_id")) or value.get("state") not in ["inactive","active"] or value.get("behavior") not in ["guard","sleep","patrol","attack","leash"]): failures.append("%s has invalid encounter settings" % context)
	if value.type == "play_cinematic" and not cinematics.has(value.get("cinematic_id")): failures.append("%s has unresolved cinematic" % context)
	if value.type == "complete_scenario" and value.get("result") not in ["victory","failure"]: failures.append("%s has invalid result" % context)


func _validate_sequence_cycles(values: Array, sequence_ids: Dictionary, failures: Array[String]) -> void:
	var edges := {}; for id in sequence_ids: edges[id] = []
	for sequence in values:
		if sequence is Dictionary and sequence.get("event", {}).get("type") == "sequence_completed": edges[sequence.event.sequence_id].append(sequence.sequence_id)
	var visiting := {}; var visited := {}
	for id in edges:
		if _cycle(id, edges, visiting, visited): failures.append("scenario.json.sequences contains a sequence_completed cycle at '%s'" % id); return


func _cycle(id: String, edges: Dictionary, visiting: Dictionary, visited: Dictionary) -> bool:
	if visiting.has(id): return true
	if visited.has(id): return false
	visiting[id] = true
	for next in edges.get(id, []):
		if _cycle(next, edges, visiting, visited): return true
	visiting.erase(id); visited[id] = true; return false


func _ids(values: Array, field: String, collection: String, failures: Array[String]) -> Dictionary:
	var result := {}
	for index in values.size():
		if not values[index] is Dictionary: failures.append("scenario.json.%s[%d] must be an object" % [collection,index]); continue
		var id = values[index].get(field)
		if not _valid_id(id) or result.has(id): failures.append("scenario.json.%s has invalid or duplicate %s '%s'" % [collection, field, id])
		else: result[id] = true
	return result


func _exact(value: Dictionary, keys: Array, context: String, failures: Array[String]) -> void: _exact_optional(value, keys, [], context, failures)
func _exact_optional(value: Dictionary, required: Array, optional: Array, context: String, failures: Array[String]) -> void:
	for key in required:
		if not value.has(key): failures.append("%s: missing '%s'" % [context,key])
	for key in value:
		if key not in required and key not in optional: failures.append("%s: unknown field '%s'" % [context,key])


func _valid_id(value) -> bool:
	if not value is String: return false
	var regex := RegEx.new(); regex.compile(ID_PATTERN); return regex.search(value) != null
func _vector3(value) -> bool: return value is Array and value.size() == 3 and value.all(func(number): return number is int or number is float)
func _fail(messages: Array[String]) -> bool: errors = messages; return false
func _canonical_json(value) -> String:
	if value is Dictionary:
		var keys: Array = value.keys(); keys.sort(); var members: Array[String] = []
		for key in keys: members.append("%s:%s" % [JSON.stringify(str(key)), _canonical_json(value[key])])
		return "{%s}" % ",".join(members)
	if value is Array:
		var members: Array[String] = []; for item in value: members.append(_canonical_json(item))
		return "[%s]" % ",".join(members)
	if value is float and is_equal_approx(value, roundf(value)): return str(int(value))
	return JSON.stringify(value)
