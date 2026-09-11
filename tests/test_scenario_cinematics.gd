extends SceneTree

const ScenarioScript:=preload("res://src/domain/scenario_document.gd")
var failures:Array[String]=[]


func _init()->void:
	var world:={"objects":[{"instance_id":"hero_001"},{"instance_id":"guide_001"}]};var scenario=ScenarioScript.new();scenario.create("vision","Vision","","frontier_company",world)
	scenario.add_region("opening_shot","Opening Shot","point",[[2,2,5]],world);scenario.add_region("walk_target","Walk Target","point",[[8,0,8]],world);scenario.add_group("guides",["guide_001"],world)
	_check(scenario.update_visibility(true,9.0,true,world),"Fog and player vision defaults author")
	_check(scenario.add_cinematic("opening",true,true,true,world),"Skippable letterboxed control-lock cinematic creates")
	_check(scenario.add_cinematic_step("opening",{"type":"dialogue","speaker_instance_id":"guide_001","text":"Follow me beyond the ridge.","duration_s":3.0},world),"Subtitle dialogue works without optional audio")
	_check(scenario.add_cinematic_step("opening",{"type":"camera","region_id":"opening_shot","duration_s":2.5,"blend_s":0.5},world),"Camera shot and blend author")
	_check(scenario.add_cinematic_step("opening",{"type":"unit_cue","group_id":"guides","cue":"move","target_region_id":"walk_target"},world),"Unit movement cue authors")
	_check(scenario.add_cinematic_step("opening",{"type":"audio","audio_id":"opening_theme","volume":0.8,"policy":"replace"},world),"Music interruption policy authors")
	_check(scenario.move_cinematic_step("opening",3,-1,world) and scenario.data.cinematics[0].steps[2].type=="audio","Cinematic timeline can be reordered and scrubbed deterministically")
	_check(scenario.add_sequence("begin",{"type":"scenario_start"},world) and scenario.add_sequence_step("begin","actions",{"type":"play_cinematic","cinematic_id":"opening"},world),"Opening scene wires to typed sequence action")
	_check(not scenario.delete_cinematic("opening",world) and "begin" in scenario.errors[0],"Referenced cinematic deletion is blocked")
	if failures.is_empty():print("PASS: visibility and cinematic timeline authoring");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)


func _check(condition:bool,message:String)->void:
	if not condition:failures.append(message)
