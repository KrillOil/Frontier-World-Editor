class_name ScenarioDocument
extends RefCounted

const FORMAT_VERSION := 1
const ID_PATTERN := "^[a-z][a-z0-9_]*$"
const EVENTS := ["scenario_start", "unit_enters_region", "unit_died", "objective_changed", "sequence_completed"]
const CONDITIONS := ["objective_is", "group_alive", "group_owned_by", "sequence_has_run"]
const ACTIONS := ["show_message", "show_tutorial", "set_objective", "set_objective_step", "set_ownership", "order_group", "set_encounter", "grant_reward", "play_cinematic", "complete_scenario"]
const CINEMATIC_STEPS := ["dialogue", "camera", "unit_cue", "audio"]

var data: Dictionary = {}
var errors: Array[String] = []
var source_path := ""
var dirty := false
var history: Array[Dictionary] = []
var redo_history: Array[Dictionary] = []


func load_from_file(path: String, world: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _fail(["%s: could not be opened" % path])
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return _fail(["%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()]])
	if not json.data is Dictionary: return _fail(["scenario.json: root must be an object"])
	var failures := validate(json.data, world)
	if not failures.is_empty(): return _fail(failures)
	data = json.data.duplicate(true); source_path = path; dirty = false; history.clear(); redo_history.clear(); errors.clear(); return true


func create(scenario_id: String, title: String, description: String, player_faction_id: String, world: Dictionary) -> bool:
	var candidate := {"scenario_format_version":FORMAT_VERSION,"scenario_id":scenario_id,"title":title,"description":description,"player_faction_id":player_faction_id,"regions":[],"unit_groups":[],"objectives":[],"tutorials":[],"encounters":[],"cinematics":[],"sequences":[]}
	var failures := validate(candidate, world)
	if not failures.is_empty(): return _fail(failures)
	data = candidate; dirty = true; history.clear(); redo_history.clear(); errors.clear(); return true


func update_metadata(title: String, description: String, player_faction_id: String, world: Dictionary) -> bool:
	var candidate: Dictionary = data.duplicate(true); candidate.title = title; candidate.description = description; candidate.player_faction_id = player_faction_id
	return _commit(candidate, world)


func add_region(region_id: String, display_name: String, shape: String, points: Array, world: Dictionary) -> bool:
	var candidate: Dictionary = data.duplicate(true)
	candidate.regions.append({"region_id":region_id,"display_name":display_name,"shape":shape,"points":points.duplicate(true)})
	return _commit(candidate, world)


func update_region(region_id: String, changes: Dictionary, world: Dictionary) -> bool:
	var candidate: Dictionary = data.duplicate(true); var region := _find(candidate.regions, "region_id", region_id)
	if region.is_empty(): return _fail(["Unknown scenario region '%s'" % region_id])
	for key in ["display_name","shape","points"]:
		if changes.has(key): region[key] = changes[key].duplicate(true) if changes[key] is Array else changes[key]
	return _commit(candidate, world)


func reverse_path(region_id: String, world: Dictionary) -> bool:
	var region := find_region(region_id)
	if region.is_empty() or region.shape != "path": return _fail(["Region '%s' is not a path" % region_id])
	var points: Array = region.points.duplicate(true); points.reverse()
	return update_region(region_id, {"points":points}, world)


func delete_region(region_id: String, world: Dictionary) -> bool:
	var references := region_references(region_id)
	if not references.is_empty(): return _fail(["Cannot delete region '%s'; referenced by %s" % [region_id, ", ".join(references)]])
	var candidate: Dictionary = data.duplicate(true); candidate.regions = candidate.regions.filter(func(region): return region.region_id != region_id)
	if candidate.regions.size() == data.regions.size(): return _fail(["Unknown scenario region '%s'" % region_id])
	return _commit(candidate, world)


func add_objective(objective_id: String, title: String, kind: String, initial_state: String, world: Dictionary) -> bool:
	var candidate: Dictionary = data.duplicate(true)
	candidate.objectives.append({"objective_id":objective_id,"title":title,"kind":kind,"initial_state":initial_state,"steps":[]})
	return _commit(candidate, world)


func update_objective(objective_id: String, changes: Dictionary, world: Dictionary) -> bool:
	var candidate: Dictionary = data.duplicate(true); var objective := _find(candidate.objectives, "objective_id", objective_id)
	if objective.is_empty(): return _fail(["Unknown objective '%s'" % objective_id])
	for key in ["title","kind","initial_state"]:
		if changes.has(key): objective[key] = changes[key]
	return _commit(candidate, world)


func delete_objective(objective_id: String, world: Dictionary) -> bool:
	var references: Array[String] = []
	for sequence in data.get("sequences", []):
		if sequence.event.get("objective_id") == objective_id: references.append("sequence %s event" % sequence.sequence_id)
		for condition in sequence.conditions:
			if condition.get("objective_id") == objective_id: references.append("sequence %s condition" % sequence.sequence_id)
		for action in sequence.actions:
			if action.get("objective_id") == objective_id: references.append("sequence %s action" % sequence.sequence_id)
	if not references.is_empty(): return _fail(["Cannot delete objective '%s'; referenced by %s" % [objective_id, ", ".join(references)]])
	var candidate: Dictionary = data.duplicate(true); candidate.objectives = candidate.objectives.filter(func(objective): return objective.objective_id != objective_id)
	if candidate.objectives.size() == data.objectives.size(): return _fail(["Unknown objective '%s'" % objective_id])
	return _commit(candidate, world)


func add_objective_step(objective_id: String, step_id: String, title: String, checkpoint_region_id: String, world: Dictionary) -> bool:
	var candidate: Dictionary = data.duplicate(true); var objective := _find(candidate.objectives, "objective_id", objective_id)
	if objective.is_empty(): return _fail(["Unknown objective '%s'" % objective_id])
	if not objective.has("steps"): objective.steps = []
	var step := {"step_id":step_id,"title":title}
	if not checkpoint_region_id.is_empty(): step.checkpoint_region_id = checkpoint_region_id
	objective.steps.append(step); return _commit(candidate, world)


func move_objective_step(objective_id: String, index: int, direction: int, world: Dictionary) -> bool:
	var candidate: Dictionary = data.duplicate(true); var objective := _find(candidate.objectives, "objective_id", objective_id)
	var destination := index + direction
	if objective.is_empty() or index < 0 or destination < 0 or index >= objective.get("steps", []).size() or destination >= objective.get("steps", []).size(): return _fail(["Objective step cannot move farther"])
	var step = objective.steps.pop_at(index); objective.steps.insert(destination, step); return _commit(candidate, world)


func delete_objective_step(objective_id: String, step_id: String, world: Dictionary) -> bool:
	for sequence in data.get("sequences", []):
		for action in sequence.actions:
			if action.get("type") == "set_objective_step" and action.get("objective_id") == objective_id and action.get("step_id") == step_id: return _fail(["Cannot delete objective step '%s'; referenced by sequence %s" % [step_id, sequence.sequence_id]])
	var candidate: Dictionary = data.duplicate(true); var objective := _find(candidate.objectives, "objective_id", objective_id)
	if objective.is_empty(): return _fail(["Unknown objective '%s'" % objective_id])
	var prior: int = objective.get("steps", []).size(); objective.steps = objective.get("steps", []).filter(func(step): return step.step_id != step_id)
	if objective.steps.size() == prior: return _fail(["Unknown objective step '%s'" % step_id])
	return _commit(candidate, world)


func add_tutorial(tutorial: Dictionary, world: Dictionary) -> bool:
	var candidate: Dictionary = data.duplicate(true)
	if not candidate.has("tutorials"): candidate.tutorials = []
	candidate.tutorials.append(tutorial.duplicate(true)); return _commit(candidate, world)


func update_tutorial(tutorial_id: String, changes: Dictionary, world: Dictionary) -> bool:
	var candidate: Dictionary = data.duplicate(true); var tutorial := _find(candidate.get("tutorials", []), "tutorial_id", tutorial_id)
	if tutorial.is_empty(): return _fail(["Unknown tutorial '%s'" % tutorial_id])
	for key in ["text","control","indicator","acknowledgement","region_id","highlight","gates_sequence_id"]:
		if changes.has(key) and changes[key] != "": tutorial[key] = changes[key]
		elif changes.has(key): tutorial.erase(key)
	return _commit(candidate, world)


func delete_tutorial(tutorial_id: String, world: Dictionary) -> bool:
	for sequence in data.get("sequences", []):
		for action in sequence.actions:
			if action.get("type") == "show_tutorial" and action.get("tutorial_id") == tutorial_id: return _fail(["Cannot delete tutorial '%s'; referenced by sequence %s" % [tutorial_id, sequence.sequence_id]])
	var candidate: Dictionary = data.duplicate(true); var prior: int = candidate.get("tutorials", []).size()
	candidate.tutorials = candidate.get("tutorials", []).filter(func(tutorial): return tutorial.tutorial_id != tutorial_id)
	if candidate.tutorials.size() == prior: return _fail(["Unknown tutorial '%s'" % tutorial_id])
	return _commit(candidate, world)


func add_group(group_id: String, instance_ids: Array, world: Dictionary) -> bool:
	var candidate:Dictionary=data.duplicate(true);candidate.unit_groups.append({"group_id":group_id,"instance_ids":instance_ids.duplicate()});return _commit(candidate,world)


func update_group(group_id:String,instance_ids:Array,world:Dictionary)->bool:
	var candidate:Dictionary=data.duplicate(true);var group:=_find(candidate.unit_groups,"group_id",group_id)
	if group.is_empty():return _fail(["Unknown unit group '%s'"%group_id])
	group.instance_ids=instance_ids.duplicate();return _commit(candidate,world)


func delete_group(group_id:String,world:Dictionary)->bool:
	var references:=group_references(group_id)
	if not references.is_empty():return _fail(["Cannot delete unit group '%s'; referenced by %s"%[group_id,", ".join(references)]])
	var candidate:Dictionary=data.duplicate(true);var prior:int=candidate.unit_groups.size();candidate.unit_groups=candidate.unit_groups.filter(func(group):return group.group_id!=group_id)
	if candidate.unit_groups.size()==prior:return _fail(["Unknown unit group '%s'"%group_id])
	return _commit(candidate,world)


func add_encounter(encounter:Dictionary,world:Dictionary)->bool:
	var candidate:Dictionary=data.duplicate(true);if not candidate.has("encounters"):candidate.encounters=[]
	candidate.encounters.append(encounter.duplicate(true));return _commit(candidate,world)


func update_encounter(encounter_id:String,changes:Dictionary,world:Dictionary)->bool:
	var candidate:Dictionary=data.duplicate(true);var encounter:=_find(candidate.get("encounters",[]),"encounter_id",encounter_id)
	if encounter.is_empty():return _fail(["Unknown encounter '%s'"%encounter_id])
	for key in ["group_id","initial_state","behavior","leash_region_id","patrol_path_region_id","completion","reinforcement_group_ids"]:
		if changes.has(key) and changes[key] != "":encounter[key]=changes[key].duplicate() if changes[key] is Array else changes[key]
		elif changes.has(key):encounter.erase(key)
	return _commit(candidate,world)


func delete_encounter(encounter_id:String,world:Dictionary)->bool:
	var candidate:Dictionary=data.duplicate(true);var prior:int=candidate.get("encounters",[]).size();candidate.encounters=candidate.get("encounters",[]).filter(func(encounter):return encounter.encounter_id!=encounter_id)
	if candidate.encounters.size()==prior:return _fail(["Unknown encounter '%s'"%encounter_id])
	return _commit(candidate,world)


func group_references(group_id:String)->Array[String]:
	var result:Array[String]=[]
	for encounter in data.get("encounters",[]):
		if encounter.get("group_id")==group_id or group_id in encounter.get("reinforcement_group_ids",[]):result.append("encounter %s"%encounter.encounter_id)
	for sequence in data.get("sequences",[]):
		if sequence.event.get("group_id")==group_id:result.append("sequence %s event"%sequence.sequence_id)
		for condition in sequence.conditions:
			if condition.get("group_id")==group_id:result.append("sequence %s condition"%sequence.sequence_id)
		for action in sequence.actions:
			if action.get("group_id")==group_id:result.append("sequence %s action"%sequence.sequence_id)
	return result


func add_sequence(sequence_id: String, event: Dictionary, world: Dictionary, enabled := true, one_shot := true) -> bool:
	var candidate: Dictionary = data.duplicate(true)
	candidate.sequences.append({"sequence_id":sequence_id,"enabled":enabled,"one_shot":one_shot,"event":event.duplicate(true),"conditions":[],"actions":[{"type":"show_message","message_id":sequence_id + "_message","text":"New sequence","duration_s":2.0}]})
	return _commit(candidate, world)


func update_sequence(sequence_id: String, changes: Dictionary, world: Dictionary) -> bool:
	var candidate: Dictionary = data.duplicate(true); var sequence := _find(candidate.sequences, "sequence_id", sequence_id)
	if sequence.is_empty(): return _fail(["Unknown scenario sequence '%s'" % sequence_id])
	for key in ["enabled","one_shot","event","conditions","actions"]:
		if changes.has(key): sequence[key] = changes[key].duplicate(true) if changes[key] is Array or changes[key] is Dictionary else changes[key]
	return _commit(candidate, world)


func duplicate_sequence(sequence_id: String, new_id: String, world: Dictionary) -> bool:
	var source := _find(data.get("sequences", []), "sequence_id", sequence_id)
	if source.is_empty(): return _fail(["Unknown scenario sequence '%s'" % sequence_id])
	var candidate: Dictionary = data.duplicate(true); var copy: Dictionary = source.duplicate(true); copy.sequence_id = new_id; copy.enabled = false; candidate.sequences.append(copy)
	return _commit(candidate, world)


func delete_sequence(sequence_id: String, world: Dictionary) -> bool:
	var references: Array[String] = []
	for sequence in data.get("sequences", []):
		if sequence.sequence_id != sequence_id and sequence.event.get("type") == "sequence_completed" and sequence.event.get("sequence_id") == sequence_id: references.append(sequence.sequence_id)
		for condition in sequence.conditions:
			if condition.get("type") == "sequence_has_run" and condition.get("sequence_id") == sequence_id: references.append(sequence.sequence_id)
	if not references.is_empty(): return _fail(["Cannot delete sequence '%s'; referenced by %s" % [sequence_id, ", ".join(references)]])
	var candidate: Dictionary = data.duplicate(true); candidate.sequences = candidate.sequences.filter(func(sequence): return sequence.sequence_id != sequence_id)
	if candidate.sequences.size() == data.sequences.size(): return _fail(["Unknown scenario sequence '%s'" % sequence_id])
	return _commit(candidate, world)


func add_sequence_step(sequence_id: String, collection: String, step: Dictionary, world: Dictionary) -> bool:
	if collection not in ["conditions","actions"]: return _fail(["Sequence steps must be conditions or actions"])
	var candidate: Dictionary = data.duplicate(true); var sequence := _find(candidate.sequences, "sequence_id", sequence_id)
	if sequence.is_empty(): return _fail(["Unknown scenario sequence '%s'" % sequence_id])
	sequence[collection].append(step.duplicate(true)); return _commit(candidate, world)


func move_sequence_step(sequence_id: String, collection: String, index: int, direction: int, world: Dictionary) -> bool:
	var candidate: Dictionary = data.duplicate(true); var sequence := _find(candidate.sequences, "sequence_id", sequence_id)
	if sequence.is_empty() or collection not in ["conditions","actions"]: return _fail(["Unknown sequence step collection"])
	var destination := index + direction
	if index < 0 or destination < 0 or index >= sequence[collection].size() or destination >= sequence[collection].size(): return _fail(["Sequence step cannot move farther"])
	var step = sequence[collection].pop_at(index); sequence[collection].insert(destination, step); return _commit(candidate, world)


func delete_sequence_step(sequence_id: String, collection: String, index: int, world: Dictionary) -> bool:
	var candidate: Dictionary = data.duplicate(true); var sequence := _find(candidate.sequences, "sequence_id", sequence_id)
	if sequence.is_empty() or collection not in ["conditions","actions"] or index < 0 or index >= sequence[collection].size(): return _fail(["Unknown sequence step"])
	sequence[collection].remove_at(index); return _commit(candidate, world)


func flow_diagnostics() -> Array[String]:
	var messages: Array[String] = []
	for sequence in data.get("sequences", []):
		if not sequence.enabled: messages.append("Sequence '%s' is disabled" % sequence.sequence_id)
		if sequence.event.get("type") == "sequence_completed" and not _find(data.sequences, "sequence_id", sequence.event.get("sequence_id", "")).enabled: messages.append("Sequence '%s' waits on a disabled sequence" % sequence.sequence_id)
	return messages


func find_region(region_id: String) -> Dictionary: return _find(data.get("regions", []), "region_id", region_id)


func region_references(region_id: String) -> Array[String]:
	var result: Array[String] = []
	for objective in data.get("objectives", []):
		for step in objective.get("steps", []):
			if step.get("checkpoint_region_id") == region_id: result.append("objective %s step %s" % [objective.objective_id, step.step_id])
	for tutorial in data.get("tutorials", []):
		if tutorial.get("region_id") == region_id: result.append("tutorial %s" % tutorial.tutorial_id)
	for encounter in data.get("encounters",[]):
		if encounter.get("leash_region_id")==region_id or encounter.get("patrol_path_region_id")==region_id:result.append("encounter %s"%encounter.encounter_id)
	for cinematic in data.get("cinematics", []):
		for step_index in cinematic.steps.size():
			if cinematic.steps[step_index].get("region_id") == region_id or cinematic.steps[step_index].get("target_region_id") == region_id: result.append("cinematic %s step %d" % [cinematic.cinematic_id,step_index])
	for sequence in data.get("sequences", []):
		if sequence.event.get("region_id") == region_id: result.append("sequence %s event" % sequence.sequence_id)
		for action_index in sequence.actions.size():
			var action: Dictionary = sequence.actions[action_index]
			if action.get("region_id") == region_id or action.get("target_region_id") == region_id or action.get("leash_region_id") == region_id: result.append("sequence %s action %d" % [sequence.sequence_id,action_index])
	return result


func undo() -> bool:
	if history.is_empty(): return false
	redo_history.append(data.duplicate(true)); data = history.pop_back(); dirty = true; return true
func redo() -> bool:
	if redo_history.is_empty(): return false
	history.append(data.duplicate(true)); data = redo_history.pop_back(); dirty = true; return true
func can_undo() -> bool: return not history.is_empty()
func can_redo() -> bool: return not redo_history.is_empty()
func mark_saved(path: String) -> void: source_path = path; dirty = false


func validate(candidate: Dictionary, world: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	_exact_optional(candidate, ["scenario_format_version","scenario_id","title","description","player_faction_id","regions","unit_groups","objectives","cinematics","sequences"], ["tutorials","encounters"], "scenario.json", failures)
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
	var objective_ids := _validate_objectives(candidate.objectives, region_ids, failures)
	var tutorial_ids := _validate_tutorials(candidate.get("tutorials", []), region_ids, failures)
	_validate_encounters(candidate.get("encounters",[]),region_ids,group_ids,failures)
	var cinematic_ids := _validate_cinematics(candidate.cinematics, region_ids, group_ids, world, failures)
	var sequence_ids := _ids(candidate.sequences, "sequence_id", "sequences", failures)
	for tutorial in candidate.get("tutorials", []):
		if tutorial is Dictionary and tutorial.has("gates_sequence_id") and not sequence_ids.has(tutorial.gates_sequence_id): failures.append("scenario.json tutorial references unknown gated sequence")
	_validate_sequences(candidate.sequences, region_ids, group_ids, objective_ids, _objective_steps(candidate.objectives), tutorial_ids, cinematic_ids, sequence_ids, failures)
	_validate_sequence_cycles(candidate.sequences, sequence_ids, failures)
	return failures


func canonical_text() -> String:
	var normalized := data.duplicate(true)
	for pair in [["regions","region_id"],["unit_groups","group_id"],["objectives","objective_id"],["tutorials","tutorial_id"],["encounters","encounter_id"],["cinematics","cinematic_id"],["sequences","sequence_id"]]:
		if not normalized.has(pair[0]): continue
		normalized[pair[0]].sort_custom(func(a, b): return a[pair[1]] < b[pair[1]])
	return _canonical_json(normalized) + "\n"


func content_hash() -> String: return canonical_text().sha256_text()


func _commit(candidate: Dictionary, world: Dictionary) -> bool:
	var failures := validate(candidate, world)
	if not failures.is_empty(): return _fail(failures)
	history.append(data.duplicate(true)); redo_history.clear(); data = candidate; dirty = true; errors.clear(); return true


func _find(values: Array, field: String, id: String) -> Dictionary:
	for value in values:
		if value.get(field) == id: return value
	return {}


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


func _validate_objectives(values: Array, regions: Dictionary, failures: Array[String]) -> Dictionary:
	var ids := _ids(values, "objective_id", "objectives", failures)
	for index in values.size():
		var value = values[index]; var context := "scenario.json.objectives[%d]" % index
		if not value is Dictionary: continue
		_exact_optional(value, ["objective_id","title","kind","initial_state"], ["steps"], context, failures)
		if value.get("kind") not in ["main","optional"] or value.get("initial_state") not in ["hidden","active"]: failures.append("%s has invalid kind or initial state" % context)
		var step_ids := {}
		for step in value.get("steps", []):
			if not step is Dictionary: failures.append("%s.steps must contain objects" % context); continue
			_exact_optional(step,["step_id","title"],["checkpoint_region_id"],context+".steps",failures)
			if not _valid_id(step.get("step_id")) or step_ids.has(step.get("step_id")): failures.append("%s has invalid or duplicate step ID" % context)
			if step.has("checkpoint_region_id") and not regions.has(step.checkpoint_region_id): failures.append("%s step references unknown checkpoint region" % context)
			step_ids[step.get("step_id")]=true
	return ids


func _validate_tutorials(values: Array, regions: Dictionary, failures: Array[String]) -> Dictionary:
	var ids:=_ids(values,"tutorial_id","tutorials",failures)
	for index in values.size():
		var value=values[index];var context:="scenario.json.tutorials[%d]"%index
		if not value is Dictionary:continue
		_exact_optional(value,["tutorial_id","text","control","indicator","acknowledgement"],["region_id","highlight","gates_sequence_id"],context,failures)
		if value.get("control") not in ["select","move","camera","group","attack","ability"] or value.get("indicator") not in ["viewport","world","both"] or value.get("acknowledgement") not in ["automatic","input"]:failures.append("%s has invalid guidance settings"%context)
		if value.has("region_id") and not regions.has(value.region_id):failures.append("%s references unknown region"%context)
	return ids


func _validate_encounters(values:Array,regions:Dictionary,groups:Dictionary,failures:Array[String])->Dictionary:
	var ids:=_ids(values,"encounter_id","encounters",failures)
	for index in values.size():
		var value=values[index];var context:="scenario.json.encounters[%d]"%index
		if not value is Dictionary:continue
		_exact_optional(value,["encounter_id","group_id","initial_state","behavior","leash_region_id","completion","reinforcement_group_ids"],["patrol_path_region_id"],context,failures)
		if not groups.has(value.get("group_id")) or value.get("initial_state") not in ["inactive","active"] or value.get("behavior") not in ["guard","sleep","patrol","attack","leash"] or not regions.has(value.get("leash_region_id")) or value.get("completion")!="all_defeated":failures.append("%s has invalid encounter settings"%context)
		if value.has("patrol_path_region_id") and not regions.has(value.patrol_path_region_id):failures.append("%s has unresolved patrol path"%context)
		if not value.get("reinforcement_group_ids") is Array:failures.append("%s reinforcements must be an array"%context)
		else:
			for group_id in value.reinforcement_group_ids:
				if not groups.has(group_id):failures.append("%s has unresolved reinforcement group"%context)
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


func _validate_sequences(values: Array, regions: Dictionary, groups: Dictionary, objectives: Dictionary, objective_steps: Dictionary, tutorials: Dictionary, cinematics: Dictionary, sequences: Dictionary, failures: Array[String]) -> void:
	for index in values.size():
		var value = values[index]; var context := "scenario.json.sequences[%d]" % index
		if not value is Dictionary: continue
		_exact(value, ["sequence_id","enabled","one_shot","event","conditions","actions"], context, failures)
		if not value.get("enabled") is bool or not value.get("one_shot") is bool or not value.get("conditions") is Array or not value.get("actions") is Array or value.get("actions", []).is_empty(): failures.append("%s has invalid execution fields" % context); continue
		_validate_event(value.get("event"), context + ".event", regions, groups, objectives, sequences, failures)
		for offset in value.conditions.size(): _validate_condition(value.conditions[offset], "%s.conditions[%d]" % [context, offset], groups, objectives, sequences, failures)
		for offset in value.actions.size(): _validate_action(value.actions[offset], "%s.actions[%d]" % [context, offset], regions, groups, objectives, objective_steps, tutorials, cinematics, failures)


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


func _validate_action(value, context: String, regions: Dictionary, groups: Dictionary, objectives: Dictionary, objective_steps: Dictionary, tutorials: Dictionary, cinematics: Dictionary, failures: Array[String]) -> void:
	if not value is Dictionary or value.get("type") not in ACTIONS: failures.append("%s has an unsupported action" % context); return
	var keys: Array = {"show_message":["type","message_id","text","duration_s"],"show_tutorial":["type","tutorial_id"],"set_objective":["type","objective_id","state"],"set_objective_step":["type","objective_id","step_id","state"],"set_ownership":["type","group_id","owner_id"],"order_group":["type","group_id","order","target_region_id"],"set_encounter":["type","group_id","state","behavior","leash_region_id"],"grant_reward":["type","group_id","reward_id"],"play_cinematic":["type","cinematic_id"],"complete_scenario":["type","result"]}[value.type]
	_exact(value, keys, context, failures)
	if value.type == "show_message" and (not _valid_id(value.get("message_id")) or not value.get("text") is String or float(value.get("duration_s", 0)) <= 0): failures.append("%s has invalid message fields" % context)
	if value.type == "show_tutorial" and not tutorials.has(value.get("tutorial_id")):failures.append("%s has unresolved tutorial"%context)
	if value.type == "set_objective" and (not objectives.has(value.get("objective_id")) or value.get("state") not in ["hidden","active","completed","failed"]): failures.append("%s has unresolved objective or state" % context)
	if value.type == "set_objective_step":
		if not objective_steps.get(value.get("objective_id"), {}).has(value.get("step_id")) or value.get("state") not in ["active","completed"]: failures.append("%s has unresolved objective step or state" % context)
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


func _objective_steps(values: Array) -> Dictionary:
	var result := {}
	for objective in values:
		if not objective is Dictionary: continue
		var steps := {}
		for step in objective.get("steps", []):
			if step is Dictionary: steps[step.get("step_id")] = true
		result[objective.get("objective_id")] = steps
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
