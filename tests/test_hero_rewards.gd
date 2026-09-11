extends SceneTree

const PackageScript:=preload("res://src/domain/world_package.gd")
const ScenarioScript:=preload("res://src/domain/scenario_document.gd")
var failures:Array[String]=[]


func _init()->void:
	var package=PackageScript.new();_check(package.load_from_directory("res://worlds/crimsdale"),"Crimsdale loads: "+" | ".join(package.errors))
	var scene:="res://content/crimsdale/units/guard.tscn"
	var ability:={"definition_id":"ability_storm_arc","display_name":"Storm Arc","category":"ability","scene_path":scene,"ability_mode":"chained_damage","damage":30.0,"cast_range":8.0,"cooldown_s":7.0,"mana_cost":25.0,"area_radius":0.0,"chain_count":3,"presentation":"Blue arc links each struck target."}
	var item:={"definition_id":"item_veterans_badge","display_name":"Veteran's Badge","category":"item","scene_path":scene,"item_kind":"permanent_stat","effect_stat":"strength","effect_amount":2.0,"feedback_text":"Strength permanently increased by 2."}
	_check(package.create_definition(ability) and package.create_definition(item),"Ability and item definitions create")
	var hero_changes:={"hero":true,"max_mana":120.0,"starting_level":1,"starting_experience":0,"strength":18.0,"agility":12.0,"intellect":15.0,"ability_ids":["ability_storm_arc"],"inventory_limit":6,"pickup_behavior":"automatic"}
	_check(package.update_definition("unit_crimsdale_guard",hero_changes),"Reference unit becomes an authored hero")
	_check(not package.place_instance("item_veterans_badge",Vector3(3,0,3)).is_empty(),"Item reward places through ordinary world composition")
	var scenario=ScenarioScript.new();scenario.create("reward_trial","Reward Trial","","frontier_company",package.world);scenario.add_group("reward_source",["crimsdale_raider_001"],package.world);scenario.add_sequence("reward",{"type":"unit_died","group_id":"reward_source"},package.world);scenario.add_sequence_step("reward","actions",{"type":"grant_reward","group_id":"reward_source","reward_id":"item_veterans_badge"},package.world);package.scenario=scenario
	_check(package.validate().is_empty(),"Scenario reward resolves to an item definition")
	var invalid:Dictionary=package.find_definition("unit_crimsdale_guard");invalid.ability_ids=["missing_ability"]
	_check(package.validate().any(func(message):return "missing_ability" in message),"Missing ability references fail actionably")
	if failures.is_empty():print("PASS: hero, ability, item, placement, and reward references");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)


func _check(condition:bool,message:String)->void:
	if not condition:failures.append(message)
