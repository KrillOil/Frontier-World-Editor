extends SceneTree

const ScenarioScript:=preload("res://src/domain/scenario_document.gd")
var failures:Array[String]=[]


func _init()->void:
	var world:={"objects":[{"instance_id":"hero_001"},{"instance_id":"ally_001"},{"instance_id":"ally_002"},{"instance_id":"ally_003"},{"instance_id":"enemy_001"},{"instance_id":"enemy_002"}]};var scenario=ScenarioScript.new();scenario.create("trial","Trial","","frontier_company",world)
	scenario.add_region("camp","Camp","rectangle",[[0,0,0],[8,0,8]],world);scenario.add_region("patrol","Patrol","path",[[1,0,1],[7,0,7]],world)
	_check(scenario.add_group("allies",["ally_001","ally_002","ally_003"],world),"Three allies form one stable recruitment group")
	_check(scenario.add_group("raiders",["enemy_001"],world) and scenario.add_group("reinforcements",["enemy_002"],world),"Encounter groups author from placed instances")
	var encounter:={"encounter_id":"camp_raid","group_id":"raiders","initial_state":"inactive","behavior":"sleep","leash_region_id":"camp","patrol_path_region_id":"patrol","completion":"all_defeated","reinforcement_group_ids":["reinforcements"]}
	_check(scenario.add_encounter(encounter,world),"Dormant staged encounter with reinforcements creates")
	_check(scenario.add_sequence("recruit",{"type":"unit_enters_region","group_id":"allies","region_id":"camp"},world),"Region activation sequence creates")
	_check(scenario.add_sequence_step("recruit","actions",{"type":"set_ownership","group_id":"allies","owner_id":"player"},world),"Recruitment is authored as ownership transfer")
	_check(scenario.add_sequence_step("recruit","actions",{"type":"set_encounter","group_id":"raiders","state":"active","behavior":"attack","leash_region_id":"camp"},world),"Dormant encounter activation is authored")
	_check(not scenario.delete_group("allies",world) and "recruit" in scenario.errors[0],"Referenced recruitment group deletion is blocked")
	_check(not scenario.delete_region("camp",world) and "encounter" in scenario.errors[0],"Encounter bounds protect region deletion")
	if failures.is_empty():print("PASS: group recruitment and staged encounter authoring");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)


func _check(condition:bool,message:String)->void:
	if not condition:failures.append(message)
