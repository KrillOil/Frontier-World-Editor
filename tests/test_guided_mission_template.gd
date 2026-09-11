extends SceneTree

const PackageScript:=preload("res://src/domain/world_package.gd")
const ScenarioScript:=preload("res://src/domain/scenario_document.gd")
var failures:Array[String]=[]


func _init()->void:
	var package=PackageScript.new();_check(package.load_from_directory("res://worlds/crimsdale"),"Crimsdale package loads")
	var scenario=ScenarioScript.new();_check(scenario.create_guided_mission_template("template_proof",package.world,package.definitions),"One action creates a valid guided mission from placed role-compatible units: "+" | ".join(scenario.errors))
	if not scenario.data.is_empty():
		_check(scenario.validate(scenario.data,package.world).is_empty(),"Generated scenario passes the canonical contract")
		var authored_ids:Array=[scenario.data.scenario_id];for collection in [scenario.data.regions,scenario.data.unit_groups,scenario.data.objectives,scenario.data.tutorials,scenario.data.encounters,scenario.data.cinematics,scenario.data.sequences]:
			for value in collection:
				for key in ["region_id","group_id","objective_id","tutorial_id","encounter_id","cinematic_id","sequence_id"]:
					if value.has(key):authored_ids.append(value[key])
		_check(scenario.data.title=="Guided Mission" and authored_ids.all(func(value):return "lantern" not in value and "mara" not in value and "crimsdale" not in value),"Template-authored IDs contain no story- or world-specific names")
		_check(scenario.data.unit_groups.size()==4 and scenario.data.encounters.size()==2,"Template assigns leader, allies, and two staged hostile groups")
		_check(scenario.data.cinematics.size()==2 and scenario.data.sequences[-1].actions[-1].result=="victory","Template includes skippable bookends and an opening-to-victory sequence")
		_check(scenario.data.tutorials.any(func(value):return value.control=="ability"),"Hero capability automatically adds signature-ability guidance")
		var optional:Dictionary=scenario._find(scenario.data.objectives,"objective_id","claim_optional_reward");var reward_sequence:Dictionary=scenario._find(scenario.data.sequences,"sequence_id","claim_optional_reward")
		_check(optional.kind=="optional" and optional.initial_state=="hidden" and reward_sequence.actions.any(func(value):return value.type=="grant_reward" and value.reward_id=="item_river_charm"),"Template creates an optional permanent hero reward path")
		var first_bounds:Dictionary=scenario.find_region("encounter_one_bounds");var final_bounds:Dictionary=scenario.find_region("encounter_two_bounds");var goal:Dictionary=scenario.find_region("mission_goal");var route:Dictionary=scenario.find_region("guided_route");var first_center:=Vector2((float(first_bounds.points[0][0])+float(first_bounds.points[1][0]))*0.5,(float(first_bounds.points[0][2])+float(first_bounds.points[1][2]))*0.5);var final_center:=Vector2((float(final_bounds.points[0][0])+float(final_bounds.points[1][0]))*0.5,(float(final_bounds.points[0][2])+float(final_bounds.points[1][2]))*0.5);var goal_point:=Vector2(float(goal.points[0][0]),float(goal.points[0][2]))
		_check(goal_point.distance_to(first_center)>final_center.distance_to(first_center) and route.points[-1]==goal.points[0],"Generated route places mission_goal beyond the final encounter")
		var recruit_sequence:Dictionary=scenario._find(scenario.data.sequences,"sequence_id","recruit_allies");var approach_sequence:Dictionary=scenario._find(scenario.data.sequences,"sequence_id","approach_first_encounter")
		_check(recruit_sequence.actions.any(func(value):return value.get("tutorial_id")=="select_squad") and not recruit_sequence.actions.any(func(value):return value.get("tutorial_id")=="attack_encounter") and approach_sequence.actions.any(func(value):return value.get("tutorial_id")=="attack_encounter"),"Squad selection and attack guidance occur on separate deliberate beats")
		var save_path:="user://qa_i02_guided_template.json";var file:=FileAccess.open(save_path,FileAccess.WRITE);file.store_string(JSON.stringify(scenario.data));file.close();var reopened=ScenarioScript.new();var reopened_ok:=reopened.load_from_file(save_path,package.world);var reopened_reward:Dictionary=reopened._find(reopened.data.get("sequences",[]),"sequence_id","claim_optional_reward");_check(reopened_ok and reopened.find_region("guided_route").points[-1]==reopened.find_region("mission_goal").points[0] and reopened_reward.actions.any(func(value):return value.get("reward_id")=="item_river_charm"),"Generated optional path and route survive save and reopen")
	var insufficient=ScenarioScript.new();_check(not insufficient.create_guided_mission_template("cannot_build",{"objects":[]},[]),"Template reports missing placed roles instead of producing broken data")
	var no_reward_definitions:Array[Dictionary]=package.definitions.filter(func(value):return value.get("category")!="item");var no_reward=ScenarioScript.new();_check(not no_reward.create_guided_mission_template("cannot_reward",package.world,no_reward_definitions) and "permanent-stat item" in no_reward.errors[0],"Template reports how to recover when no optional reward definition exists")
	if failures.is_empty():print("PASS: reusable guided mission template from empty scenario state");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)


func _check(condition:bool,message:String)->void:
	if not condition:failures.append(message)
