extends SceneTree

const PackageScript:=preload("res://src/domain/world_package.gd")
const ScenarioScript:=preload("res://src/domain/scenario_document.gd")
const PathingScript:=preload("res://src/domain/terrain_pathing.gd")
var failures:Array[String]=[]


func _init()->void:
	var package=PackageScript.new();_check(package.load_from_directory("res://worlds/crimsdale"),"Crimsdale package loads")
	var scenario=ScenarioScript.new();_check(scenario.create_guided_mission_template("template_proof",package.world,package.definitions,package.terrain),"One action creates a valid guided mission from placed role-compatible units: "+" | ".join(scenario.errors))
	if not scenario.data.is_empty():
		_check(scenario.validate(scenario.data,package.world).is_empty(),"Generated scenario passes the canonical contract")
		var authored_ids:Array=[scenario.data.scenario_id];for collection in [scenario.data.regions,scenario.data.unit_groups,scenario.data.objectives,scenario.data.tutorials,scenario.data.encounters,scenario.data.cinematics,scenario.data.sequences]:
			for value in collection:
				for key in ["region_id","group_id","objective_id","tutorial_id","encounter_id","cinematic_id","sequence_id"]:
					if value.has(key):authored_ids.append(value[key])
		_check(scenario.data.title=="Guided Mission" and authored_ids.all(func(value):return "lantern" not in value and "mara" not in value and "crimsdale" not in value),"Template-authored IDs contain no story- or world-specific names")
		_check(scenario.data.unit_groups.size()==4 and scenario.data.encounters.size()==2,"Template assigns leader, allies, and two staged hostile groups")
		_check(scenario.data.cinematics.size()==2 and scenario._find(scenario.data.sequences,"sequence_id","mission_victory").actions[-1].result=="victory","Template includes skippable bookends and an opening-to-victory sequence")
		_check(scenario.data.tutorials.any(func(value):return value.control=="ability"),"Hero capability automatically adds signature-ability guidance")
		var optional:Dictionary=scenario._find(scenario.data.objectives,"objective_id","claim_optional_reward");var reward_sequence:Dictionary=scenario._find(scenario.data.sequences,"sequence_id","claim_optional_reward")
		_check(optional.kind=="optional" and optional.initial_state=="hidden" and reward_sequence.actions.any(func(value):return value.type=="grant_reward" and value.reward_id=="item_river_charm"),"Template creates an optional permanent hero reward path")
		var first_bounds:Dictionary=scenario.find_region("encounter_one_bounds");var final_bounds:Dictionary=scenario.find_region("encounter_two_bounds");var goal:Dictionary=scenario.find_region("mission_goal");var first_center:=_group_center(scenario,"encounter_one",package.world);var final_center:=_group_center(scenario,"encounter_two",package.world);var route_direction:=(final_center-first_center).normalized();var goal_point:=Vector2(float(goal.points[0][0]),float(goal.points[0][2]));var farthest_projection:=-INF
		for corner in [[final_bounds.points[0][0],final_bounds.points[0][2]],[final_bounds.points[0][0],final_bounds.points[1][2]],[final_bounds.points[1][0],final_bounds.points[0][2]],[final_bounds.points[1][0],final_bounds.points[1][2]]]:farthest_projection=maxf(farthest_projection,Vector2(float(corner[0]),float(corner[1])).dot(route_direction))
		var grid:Dictionary=package.terrain.data.grid;var min_x:=float(grid.origin_x_m);var min_z:=float(grid.origin_z_m);var max_x:=min_x+float(grid.width_cells)*float(grid.cell_size_m);var max_z:=min_z+float(grid.depth_cells)*float(grid.cell_size_m);var reward_point:=Vector2(float(scenario.find_region("reward_checkpoint").points[0][0]),float(scenario.find_region("reward_checkpoint").points[0][2]));var in_bounds:=func(value:Vector2):return value.x>=min_x and value.x<max_x and value.y>=min_z and value.y<max_z
		_check(goal_point.dot(route_direction)>=farthest_projection+6.0 and not _inside_rectangle(goal_point,final_bounds.points) and in_bounds.call(goal_point) and in_bounds.call(reward_point),"Generated goal is beyond the far edge of the final encounter and both generated points remain in Crimsdale bounds")
		var pathing=PathingScript.new(package.terrain);var start_point:Array=scenario.find_region("start_checkpoint").points[0];var reachable:Dictionary=pathing._flood(pathing._world_cell(start_point));_check(reachable.has(pathing._world_cell(goal.points[0])) and reachable.has(pathing._world_cell(scenario.find_region("reward_checkpoint").points[0])),"Generated goal and optional reward are traversable from the stock Crimsdale route start")
		var recruit_sequence:Dictionary=scenario._find(scenario.data.sequences,"sequence_id","recruit_allies");var approach_sequence:Dictionary=scenario._find(scenario.data.sequences,"sequence_id","approach_first_encounter")
		var start_sequence:Dictionary=scenario._find(scenario.data.sequences,"sequence_id","mission_start");_check(start_sequence.actions.any(func(value):return value.get("tutorial_id")=="move_to_allies") and scenario._find(scenario.data.tutorials,"tutorial_id","select_player_unit").is_empty() and scenario._find(scenario.data.sequences,"sequence_id","begin_route").is_empty() and recruit_sequence.actions.any(func(value):return value.get("tutorial_id")=="select_squad") and not recruit_sequence.actions.any(func(value):return value.get("tutorial_id")=="attack_encounter") and approach_sequence.actions.any(func(value):return value.get("tutorial_id")=="attack_encounter"),"Auto-selected leader movement, squad selection, and attack guidance occur on separate deliberate beats")
		var save_path:="user://qa_i02_guided_template.json";var file:=FileAccess.open(save_path,FileAccess.WRITE);file.store_string(JSON.stringify(scenario.data));file.close();var reopened=ScenarioScript.new();var reopened_ok:=reopened.load_from_file(save_path,package.world);var reopened_reward:Dictionary=reopened._find(reopened.data.get("sequences",[]),"sequence_id","claim_optional_reward");_check(reopened_ok and reopened.find_region("guided_route").is_empty() and reopened_reward.actions.any(func(value):return value.get("reward_id")=="item_river_charm"),"Generated optional checkpoint chain survives save and reopen without an unsupported editable path")
	var insufficient=ScenarioScript.new();_check(not insufficient.create_guided_mission_template("cannot_build",{"objects":[]},[]),"Template reports missing placed roles instead of producing broken data")
	var no_reward_definitions:Array[Dictionary]=package.definitions.filter(func(value):return value.get("category")!="item");var no_reward=ScenarioScript.new();_check(not no_reward.create_guided_mission_template("cannot_reward",package.world,no_reward_definitions) and "permanent-stat item" in no_reward.errors[0],"Template reports how to recover when no optional reward definition exists")
	if failures.is_empty():print("PASS: reusable guided mission template from empty scenario state");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)


func _check(condition:bool,message:String)->void:
	if not condition:failures.append(message)


func _group_center(scenario,group_id:String,world:Dictionary)->Vector2:
	var ids:Array=scenario._find(scenario.data.unit_groups,"group_id",group_id).instance_ids;var result:=Vector2.ZERO
	for instance_id in ids:
		var object:Dictionary=scenario._find(world.objects,"instance_id",instance_id);result+=Vector2(float(object.position[0]),float(object.position[2]))
	return result/float(ids.size())


func _inside_rectangle(point:Vector2,points:Array)->bool:return point.x>=minf(float(points[0][0]),float(points[1][0])) and point.x<=maxf(float(points[0][0]),float(points[1][0])) and point.y>=minf(float(points[0][2]),float(points[1][2])) and point.y<=maxf(float(points[0][2]),float(points[1][2]))
