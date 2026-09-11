class_name ScenarioDocument
extends RefCounted

const TerrainPathingScript:=preload("res://src/domain/terrain_pathing.gd")

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
	var candidate := {"scenario_format_version":FORMAT_VERSION,"scenario_id":scenario_id,"title":title,"description":description,"player_faction_id":player_faction_id,"visibility":{"fog_enabled":true,"explored_radius_m":8.0,"hidden_by_default":true},"regions":[],"unit_groups":[],"objectives":[],"tutorials":[],"encounters":[],"cinematics":[],"sequences":[]}
	var failures := validate(candidate, world)
	if not failures.is_empty(): return _fail(failures)
	data = candidate; dirty = true; history.clear(); redo_history.clear(); errors.clear(); return true


func create_guided_mission_template(scenario_id:String,world:Dictionary,definitions:Array[Dictionary],terrain=null)->bool:
	var by_definition:={};for definition in definitions:by_definition[definition.definition_id]=definition
	var player:Array=[];var allies:Array=[];var hostiles:Array=[];var rewards:Array=[]
	for definition in definitions:
		if definition.get("category")=="item" and definition.get("item_kind")=="permanent_stat":rewards.append(definition)
	for object in world.get("objects",[]):
		var definition:Dictionary=by_definition.get(object.definition_id,{})
		if definition.get("category")!="unit":continue
		match definition.get("owner"):
			"player":player.append(object)
			"ally":allies.append(object)
			"hostile":hostiles.append(object)
	if player.is_empty() or allies.is_empty() or hostiles.size()<2:return _fail(["Guided Mission Template needs at least one player unit, one ally, and two hostile units placed in the world"])
	if rewards.is_empty():return _fail(["Guided Mission Template needs at least one permanent-stat item definition for its optional hero reward"])
	player.sort_custom(func(a,b):return int(not by_definition[a.definition_id].get("hero",false))<int(not by_definition[b.definition_id].get("hero",false)));rewards.sort_custom(func(a,b):return a.definition_id<b.definition_id)
	var hero:Dictionary=player[0];var hero_x:=float(hero.position[0]);var hero_z:=float(hero.position[2]);hostiles.sort_custom(func(a,b):var da:=Vector2(float(a.position[0])-hero_x,float(a.position[2])-hero_z).length_squared();var db:=Vector2(float(b.position[0])-hero_x,float(b.position[2])-hero_z).length_squared();return a.instance_id<b.instance_id if is_equal_approx(da,db) else da<db)
	var split:=maxi(1,hostiles.size()/2);var first:Array=hostiles.slice(0,split);var second:Array=hostiles.slice(split);if second.is_empty():second.append(first.pop_back())
	var recruit:Dictionary=allies[0]
	var point:=func(placed):return placed.position.duplicate()
	var center:=func(objects:Array):
		var result:=Vector2.ZERO
		for object in objects:result+=Vector2(float(object.position[0]),float(object.position[2]))
		result/=float(objects.size());return [result.x,0.0,result.y]
	var bounds:=func(objects:Array):
		var min_x:=float(objects[0].position[0])-3.0;var max_x:=min_x+6.0;var min_z:=float(objects[0].position[2])-3.0;var max_z:=min_z+6.0
		for object in objects:min_x=minf(min_x,float(object.position[0])-3);max_x=maxf(max_x,float(object.position[0])+3);min_z=minf(min_z,float(object.position[2])-3);max_z=maxf(max_z,float(object.position[2])+3)
		return [[min_x,0,min_z],[max_x,0,max_z]]
	var first_center:Array=center.call(first)
	var second_center:Array=center.call(second)
	var route_direction:=Vector2(float(second_center[0])-float(first_center[0]),float(second_center[2])-float(first_center[2]))
	if route_direction.length_squared()<0.01:
		route_direction=Vector2(float(second_center[0])-hero_x,float(second_center[2])-hero_z)
	if route_direction.length_squared()<0.01:
		route_direction=Vector2.RIGHT
	route_direction=route_direction.normalized()
	var second_bounds:Array=bounds.call(second);var farthest_projection:=-INF
	for corner in [[second_bounds[0][0],second_bounds[0][2]],[second_bounds[0][0],second_bounds[1][2]],[second_bounds[1][0],second_bounds[0][2]],[second_bounds[1][0],second_bounds[1][2]]]:farthest_projection=maxf(farthest_projection,Vector2(float(corner[0]),float(corner[1])).dot(route_direction))
	var second_center_2d:=Vector2(float(second_center[0]),float(second_center[2]));var goal_candidate:=second_center_2d+route_direction*(farthest_projection-second_center_2d.dot(route_direction)+8.0);var branch_midpoint:=Vector2((float(first_center[0])+float(second_center[0]))*0.5,(float(first_center[2])+float(second_center[2]))*0.5);var reward_candidate:=branch_midpoint+Vector2(-route_direction.y,route_direction.x)*6.0
	var goal_point:=[goal_candidate.x,0.0,goal_candidate.y];var reward_point:=[reward_candidate.x,0.0,reward_candidate.y]
	if terrain!=null:
		var pathing=TerrainPathingScript.new(terrain);var reachable:Dictionary=pathing._flood(pathing._world_cell(hero.position));goal_point=_project_to_reachable(goal_candidate,terrain,reachable,route_direction,farthest_projection+6.0);reward_point=_project_to_reachable(reward_candidate,terrain,reachable)
		if goal_point.is_empty() or reward_point.is_empty():return _fail(["Guided Mission Template could not place its goal and optional reward on reachable terrain; move the staged units away from blocked edges and try again"])
	var hero_definition:Dictionary=by_definition[hero.definition_id];var tutorials:Array=[{"tutorial_id":"move_to_allies","text":"Move to the waiting allies.","control":"move","indicator":"both","acknowledgement":"input","region_id":"recruit_checkpoint"},{"tutorial_id":"select_squad","text":"Select the recruited squad together.","control":"group","indicator":"viewport","acknowledgement":"input","highlight":"recruitable_allies"},{"tutorial_id":"attack_encounter","text":"Attack the awakened hostile group.","control":"attack","indicator":"both","acknowledgement":"input","region_id":"encounter_one_bounds"},{"tutorial_id":"claim_optional_reward","text":"Optional: take the side path to claim a permanent hero reward.","control":"move","indicator":"both","acknowledgement":"input","region_id":"reward_checkpoint"},{"tutorial_id":"attack_final_encounter","text":"Defeat the final hostile group, then continue to the mission goal.","control":"attack","indicator":"both","acknowledgement":"input","region_id":"encounter_two_bounds"},{"tutorial_id":"reach_mission_goal","text":"Move beyond the final encounter to the mission goal.","control":"move","indicator":"both","acknowledgement":"input","region_id":"mission_goal"}]
	if hero_definition.get("hero",false) and not hero_definition.get("ability_ids",[]).is_empty():tutorials.append({"tutorial_id":"use_signature_ability","text":"Use your leader's signature ability against grouped enemies.","control":"ability","indicator":"viewport","acknowledgement":"input","highlight":hero_definition.ability_ids[0]})
	var candidate:={"scenario_format_version":FORMAT_VERSION,"scenario_id":scenario_id,"title":"Guided Mission","description":"Recruit allies, clear staged encounters, claim an optional reward, and reach the goal.","player_faction_id":"frontier_company","visibility":{"fog_enabled":true,"explored_radius_m":9.0,"hidden_by_default":true},"regions":[{"region_id":"start_checkpoint","display_name":"Start","shape":"point","points":[point.call(hero)]},{"region_id":"recruit_checkpoint","display_name":"Recruit Allies","shape":"point","points":[point.call(recruit)]},{"region_id":"encounter_one_bounds","display_name":"First Encounter","shape":"rectangle","points":bounds.call(first)},{"region_id":"reward_checkpoint","display_name":"Optional Reward","shape":"point","points":[reward_point]},{"region_id":"encounter_two_bounds","display_name":"Final Encounter","shape":"rectangle","points":bounds.call(second)},{"region_id":"mission_goal","display_name":"Mission Goal","shape":"point","points":[goal_point]},{"region_id":"guided_route","display_name":"Guided Route","shape":"path","points":[point.call(hero),point.call(recruit),first_center,second_center,goal_point]},{"region_id":"opening_camera","display_name":"Opening Camera","shape":"point","points":[[float(hero.position[0])+5,8,float(hero.position[2])+8]]},{"region_id":"ending_camera","display_name":"Ending Camera","shape":"point","points":[[float(goal_point[0])+5,8,float(goal_point[2])+8]]}],"unit_groups":[{"group_id":"player_party","instance_ids":[hero.instance_id]},{"group_id":"recruitable_allies","instance_ids":allies.map(func(value):return value.instance_id)},{"group_id":"encounter_one","instance_ids":first.map(func(value):return value.instance_id)},{"group_id":"encounter_two","instance_ids":second.map(func(value):return value.instance_id)}],"objectives":[{"objective_id":"complete_route","title":"Reach the mission goal","kind":"main","initial_state":"active","steps":[{"step_id":"recruit_allies","title":"Recruit the waiting allies","checkpoint_region_id":"recruit_checkpoint"},{"step_id":"clear_encounters","title":"Clear both encounters","checkpoint_region_id":"encounter_two_bounds"},{"step_id":"reach_goal","title":"Reach the mission goal","checkpoint_region_id":"mission_goal"}]},{"objective_id":"claim_optional_reward","title":"Claim the permanent hero reward","kind":"optional","initial_state":"hidden","steps":[{"step_id":"reach_reward","title":"Take the side path","checkpoint_region_id":"reward_checkpoint"}]}],"tutorials":tutorials,"encounters":[{"encounter_id":"first_encounter","group_id":"encounter_one","initial_state":"inactive","behavior":"sleep","leash_region_id":"encounter_one_bounds","completion":"all_defeated","reinforcement_group_ids":[]},{"encounter_id":"final_encounter","group_id":"encounter_two","initial_state":"inactive","behavior":"guard","leash_region_id":"encounter_two_bounds","completion":"all_defeated","reinforcement_group_ids":[]}],"cinematics":[{"cinematic_id":"opening","skippable":true,"letterbox":true,"control_lock":true,"steps":[{"type":"camera","region_id":"opening_camera","duration_s":2.0,"blend_s":0.0},{"type":"dialogue","speaker_instance_id":hero.instance_id,"text":"We need to gather our allies and secure the route.","duration_s":3.0}]},{"cinematic_id":"ending","skippable":true,"letterbox":true,"control_lock":true,"steps":[{"type":"camera","region_id":"ending_camera","duration_s":2.0,"blend_s":0.5},{"type":"dialogue","speaker_instance_id":hero.instance_id,"text":"The route is secure.","duration_s":3.0}]}],"sequences":[]}
	candidate.regions=candidate.regions.filter(func(region):return region.region_id!="guided_route")
	candidate.sequences=[{"sequence_id":"mission_start","enabled":true,"one_shot":true,"event":{"type":"scenario_start"},"conditions":[],"actions":[{"type":"play_cinematic","cinematic_id":"opening"},{"type":"show_tutorial","tutorial_id":"move_to_allies"},{"type":"set_objective_step","objective_id":"complete_route","step_id":"recruit_allies","state":"active"}]},{"sequence_id":"recruit_allies","enabled":true,"one_shot":true,"event":{"type":"unit_enters_region","group_id":"player_party","region_id":"recruit_checkpoint"},"conditions":[],"actions":[{"type":"set_ownership","group_id":"recruitable_allies","owner_id":"player"},{"type":"set_objective_step","objective_id":"complete_route","step_id":"recruit_allies","state":"completed"},{"type":"set_objective_step","objective_id":"complete_route","step_id":"clear_encounters","state":"active"},{"type":"show_tutorial","tutorial_id":"select_squad"}]},{"sequence_id":"approach_first_encounter","enabled":true,"one_shot":true,"event":{"type":"unit_enters_region","group_id":"player_party","region_id":"encounter_one_bounds"},"conditions":[{"type":"sequence_has_run","sequence_id":"recruit_allies","value":true}],"actions":[{"type":"show_tutorial","tutorial_id":"attack_encounter"},{"type":"set_encounter","group_id":"encounter_one","state":"active","behavior":"attack","leash_region_id":"encounter_one_bounds"}]},{"sequence_id":"first_encounter_cleared","enabled":true,"one_shot":true,"event":{"type":"unit_died","group_id":"encounter_one"},"conditions":[{"type":"group_alive","group_id":"encounter_one","value":false}],"actions":[{"type":"set_encounter","group_id":"encounter_two","state":"active","behavior":"guard","leash_region_id":"encounter_two_bounds"},{"type":"set_objective","objective_id":"claim_optional_reward","state":"active"},{"type":"set_objective_step","objective_id":"claim_optional_reward","step_id":"reach_reward","state":"active"},{"type":"show_tutorial","tutorial_id":"claim_optional_reward"}]},{"sequence_id":"claim_optional_reward","enabled":true,"one_shot":true,"event":{"type":"unit_enters_region","group_id":"player_party","region_id":"reward_checkpoint"},"conditions":[{"type":"objective_is","objective_id":"claim_optional_reward","state":"active"}],"actions":[{"type":"set_objective_step","objective_id":"claim_optional_reward","step_id":"reach_reward","state":"completed"},{"type":"set_objective","objective_id":"claim_optional_reward","state":"completed"},{"type":"grant_reward","group_id":"player_party","reward_id":rewards[0].definition_id}]},{"sequence_id":"approach_final_encounter","enabled":true,"one_shot":true,"event":{"type":"unit_enters_region","group_id":"player_party","region_id":"encounter_two_bounds"},"conditions":[{"type":"sequence_has_run","sequence_id":"first_encounter_cleared","value":true}],"actions":[{"type":"show_tutorial","tutorial_id":"attack_final_encounter"}]},{"sequence_id":"final_encounter_cleared","enabled":true,"one_shot":true,"event":{"type":"unit_died","group_id":"encounter_two"},"conditions":[{"type":"group_alive","group_id":"encounter_two","value":false}],"actions":[{"type":"set_objective_step","objective_id":"complete_route","step_id":"clear_encounters","state":"completed"},{"type":"set_objective_step","objective_id":"complete_route","step_id":"reach_goal","state":"active"},{"type":"show_tutorial","tutorial_id":"reach_mission_goal"}]},{"sequence_id":"mission_victory","enabled":true,"one_shot":true,"event":{"type":"unit_enters_region","group_id":"player_party","region_id":"mission_goal"},"conditions":[{"type":"group_alive","group_id":"encounter_two","value":false}],"actions":[{"type":"set_objective_step","objective_id":"complete_route","step_id":"reach_goal","state":"completed"},{"type":"set_objective","objective_id":"complete_route","state":"completed"},{"type":"play_cinematic","cinematic_id":"ending"},{"type":"complete_scenario","result":"victory"}]}]
	if tutorials.any(func(value):return value.tutorial_id=="use_signature_ability"):_find(candidate.sequences,"sequence_id","approach_final_encounter").actions[0]={"type":"show_tutorial","tutorial_id":"use_signature_ability"}
	var failures:=validate(candidate,world);if not failures.is_empty():return _fail(failures)
	data=candidate;dirty=true;history.clear();redo_history.clear();errors.clear();return true


func _project_to_reachable(candidate:Vector2,terrain,reachable:Dictionary,direction:=Vector2.ZERO,minimum_projection:=-INF)->Array:
	var grid:Dictionary=terrain.data.grid;var cell_size:=float(grid.cell_size_m);var origin:=Vector2(float(grid.origin_x_m),float(grid.origin_z_m));var best:Array=[];var best_distance:=INF
	for cell in reachable:
		var point:=origin+Vector2(float(cell.x)+0.5,float(cell.y)+0.5)*cell_size
		if direction!=Vector2.ZERO and point.dot(direction)<float(minimum_projection):continue
		var distance:=point.distance_squared_to(candidate)
		if distance<best_distance:best_distance=distance;best=[point.x,0.0,point.y]
	return best


func update_metadata(title: String, description: String, player_faction_id: String, world: Dictionary) -> bool:
	var candidate: Dictionary = data.duplicate(true); candidate.title = title; candidate.description = description; candidate.player_faction_id = player_faction_id
	return _commit(candidate, world)


func update_visibility(fog_enabled:bool,explored_radius_m:float,hidden_by_default:bool,world:Dictionary)->bool:
	var candidate:Dictionary=data.duplicate(true);candidate.visibility={"fog_enabled":fog_enabled,"explored_radius_m":explored_radius_m,"hidden_by_default":hidden_by_default};return _commit(candidate,world)


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
		if not changes.has(key):continue
		var value=changes[key]
		if value is String and value.is_empty():encounter.erase(key)
		else:encounter[key]=value.duplicate() if value is Array else value
	return _commit(candidate,world)


func delete_encounter(encounter_id:String,world:Dictionary)->bool:
	var candidate:Dictionary=data.duplicate(true);var prior:int=candidate.get("encounters",[]).size();candidate.encounters=candidate.get("encounters",[]).filter(func(encounter):return encounter.encounter_id!=encounter_id)
	if candidate.encounters.size()==prior:return _fail(["Unknown encounter '%s'"%encounter_id])
	return _commit(candidate,world)


func add_cinematic(cinematic_id:String,skippable:bool,letterbox:bool,control_lock:bool,world:Dictionary)->bool:
	var candidate:Dictionary=data.duplicate(true);candidate.cinematics.append({"cinematic_id":cinematic_id,"skippable":skippable,"letterbox":letterbox,"control_lock":control_lock,"steps":[]});return _commit(candidate,world)


func update_cinematic(cinematic_id:String,changes:Dictionary,world:Dictionary)->bool:
	var candidate:Dictionary=data.duplicate(true);var cinematic:=_find(candidate.cinematics,"cinematic_id",cinematic_id)
	if cinematic.is_empty():return _fail(["Unknown cinematic '%s'"%cinematic_id])
	for key in ["skippable","letterbox","control_lock"]:
		if changes.has(key):cinematic[key]=changes[key]
	return _commit(candidate,world)


func delete_cinematic(cinematic_id:String,world:Dictionary)->bool:
	for sequence in data.get("sequences",[]):
		for action in sequence.actions:
			if action.get("type")=="play_cinematic" and action.get("cinematic_id")==cinematic_id:return _fail(["Cannot delete cinematic '%s'; referenced by sequence %s"%[cinematic_id,sequence.sequence_id]])
	var candidate:Dictionary=data.duplicate(true);var prior:int=candidate.cinematics.size();candidate.cinematics=candidate.cinematics.filter(func(cinematic):return cinematic.cinematic_id!=cinematic_id)
	if candidate.cinematics.size()==prior:return _fail(["Unknown cinematic '%s'"%cinematic_id])
	return _commit(candidate,world)


func add_cinematic_step(cinematic_id:String,step:Dictionary,world:Dictionary)->bool:
	var candidate:Dictionary=data.duplicate(true);var cinematic:=_find(candidate.cinematics,"cinematic_id",cinematic_id)
	if cinematic.is_empty():return _fail(["Unknown cinematic '%s'"%cinematic_id])
	cinematic.steps.append(step.duplicate(true));return _commit(candidate,world)


func move_cinematic_step(cinematic_id:String,index:int,direction:int,world:Dictionary)->bool:
	var candidate:Dictionary=data.duplicate(true);var cinematic:=_find(candidate.cinematics,"cinematic_id",cinematic_id);var destination:=index+direction
	if cinematic.is_empty() or index<0 or destination<0 or index>=cinematic.steps.size() or destination>=cinematic.steps.size():return _fail(["Cinematic step cannot move farther"])
	var step=cinematic.steps.pop_at(index);cinematic.steps.insert(destination,step);return _commit(candidate,world)


func delete_cinematic_step(cinematic_id:String,index:int,world:Dictionary)->bool:
	var candidate:Dictionary=data.duplicate(true);var cinematic:=_find(candidate.cinematics,"cinematic_id",cinematic_id)
	if cinematic.is_empty() or index<0 or index>=cinematic.steps.size():return _fail(["Unknown cinematic step"])
	cinematic.steps.remove_at(index);return _commit(candidate,world)


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
	_exact_optional(candidate, ["scenario_format_version","scenario_id","title","description","player_faction_id","regions","unit_groups","objectives","cinematics","sequences"], ["tutorials","encounters","visibility"], "scenario.json", failures)
	if candidate.get("scenario_format_version") != FORMAT_VERSION: failures.append("scenario.json: unsupported scenario_format_version '%s'" % candidate.get("scenario_format_version"))
	for field in ["scenario_id", "player_faction_id"]:
		if not _valid_id(candidate.get(field)): failures.append("scenario.json.%s must be a stable ID" % field)
	if not candidate.get("title") is String or candidate.get("title", "").is_empty(): failures.append("scenario.json.title is required")
	if not candidate.get("description") is String: failures.append("scenario.json.description must be text")
	for collection in ["regions","unit_groups","objectives","cinematics","sequences"]:
		if not candidate.get(collection) is Array: failures.append("scenario.json.%s must be an array" % collection)
	if not failures.is_empty(): return failures
	if candidate.has("visibility"):
		_exact(candidate.visibility,["fog_enabled","explored_radius_m","hidden_by_default"],"scenario.json.visibility",failures)
		if not candidate.visibility.get("fog_enabled") is bool or float(candidate.visibility.get("explored_radius_m",0))<=0 or not candidate.visibility.get("hidden_by_default") is bool:failures.append("scenario.json.visibility has invalid settings")
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
		_exact_optional(value, ["cinematic_id","skippable","steps"], ["letterbox","control_lock"], context, failures)
		if not value.get("skippable") is bool or not value.get("steps") is Array or value.has("letterbox") and not value.letterbox is bool or value.has("control_lock") and not value.control_lock is bool: failures.append("%s requires valid playback flags and steps" % context); continue
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
