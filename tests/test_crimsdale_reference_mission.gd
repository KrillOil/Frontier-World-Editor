extends SceneTree

const PackageScript:=preload("res://src/domain/world_package.gd")
var failures:Array[String]=[]


func _init()->void:
	var package=PackageScript.new();_check(package.load_from_directory("res://worlds/crimsdale"),"Reference package loads: "+" | ".join(package.errors));if package.scenario==null:_finish();return
	_check(package.validate().is_empty(),"Definitions, composition, terrain, and scenario validate together: "+" | ".join(package.validate()))
	_check(package.terrain.data.environment.sky_id=="sky_crimsdale_dusk" and package.terrain.data.environment.fog_enabled,"Crimsdale route uses authored dusk and fog")
	var hero:=package.find_definition("unit_crimsdale_warden");_check(hero.hero and hero.ability_ids==["ability_warden_storm_arc"],"Reference hero has one signature chained ability")
	var allies:Dictionary=package.scenario._find(package.scenario.data.unit_groups,"group_id","trailguards");_check(allies.instance_ids.size()==3,"Exactly three allies form the recruitment group")
	_check(package.scenario.data.encounters.size()==3 and package.scenario.data.encounters.all(func(encounter):return encounter.initial_state=="inactive"),"All three combat stages begin dormant")
	_check(package.scenario.data.objectives.any(func(objective):return objective.kind=="optional") and package.world.objects.any(func(object):return object.definition_id=="item_river_charm"),"Optional branch offers a useful placed reward")
	var start:Dictionary=package.scenario._find(package.scenario.data.sequences,"sequence_id","mission_start");var victory:Dictionary=package.scenario._find(package.scenario.data.sequences,"sequence_id","mission_victory");_check(start.actions[0].type=="play_cinematic" and victory.actions[-1]=={"type":"complete_scenario","result":"victory"},"Scenario has an opening-to-victory authored spine")
	var original:String=package.scenario.canonical_text();var temporary:="user://crimsdale_reference_roundtrip";DirAccess.make_dir_recursive_absolute(temporary)
	for filename in ["definitions.json","world.json","terrain.json","scenario.json"]:var file:=FileAccess.open(temporary.path_join(filename),FileAccess.WRITE);file.store_string(FileAccess.get_file_as_string("res://worlds/crimsdale".path_join(filename)))
	var roundtrip=PackageScript.new();_check(roundtrip.load_from_directory(temporary),"Copied reference mission reopens")
	if roundtrip.scenario!=null:_check(roundtrip.save() and roundtrip.scenario.canonical_text()==original,"Save/reopen preserves deterministic scenario meaning")
	_finish()


func _finish()->void:
	if failures.is_empty():print("PASS: complete original Crimsdale guided tutorial reference mission");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)


func _check(condition:bool,message:String)->void:
	if not condition:failures.append(message)
