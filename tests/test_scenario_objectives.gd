extends SceneTree

const ScenarioScript:=preload("res://src/domain/scenario_document.gd")
var failures:Array[String]=[]


func _init()->void:
	var world:={"objects":[]};var scenario=ScenarioScript.new();_check(scenario.create("guided","Guided","","frontier_company",world),"Scenario creates")
	_check(scenario.add_region("ridge","Ridge","point",[[4,0,9]],world),"Checkpoint region creates")
	_check(scenario.add_objective("follow_guide","Follow the guide","main","active",world),"Objective creates without JSON")
	_check(scenario.add_objective_step("follow_guide","reach_ridge","Reach the ridge","ridge",world),"Ordered checkpoint step creates")
	_check(scenario.add_objective_step("follow_guide","meet_squad","Meet the squad","",world),"Non-spatial step creates")
	_check(scenario.move_objective_step("follow_guide",1,-1,world) and scenario.data.objectives[0].steps[0].step_id=="meet_squad","Step order is authorable")
	var tutorial:={"tutorial_id":"move_prompt","text":"Right-click the marked ground.","control":"move","indicator":"both","acknowledgement":"input","region_id":"ridge"}
	_check(scenario.add_tutorial(tutorial,world),"Reusable tutorial creates")
	_check(scenario.add_sequence("teach_move",{"type":"scenario_start"},world),"Sequence creates")
	_check(scenario.add_sequence_step("teach_move","actions",{"type":"show_tutorial","tutorial_id":"move_prompt"},world),"Tutorial action resolves")
	_check(scenario.add_sequence_step("teach_move","actions",{"type":"set_objective_step","objective_id":"follow_guide","step_id":"reach_ridge","state":"active"},world),"Objective-step action resolves")
	_check(not scenario.delete_tutorial("move_prompt",world) and "teach_move" in scenario.errors[0],"Referenced tutorial deletion is blocked")
	_check(not scenario.delete_objective_step("follow_guide","reach_ridge",world) and "teach_move" in scenario.errors[0],"Referenced objective step deletion is blocked")
	var invalid:Dictionary=scenario.data.duplicate(true);invalid.sequences[0].actions.append({"type":"set_objective_step","objective_id":"follow_guide","step_id":"missing","state":"active"})
	_check(not scenario.validate(invalid,world).is_empty(),"Candidate validation does not consult stale document state")
	_check(scenario.undo(),"Guidance edits participate in undo")
	if failures.is_empty():print("PASS: objectives, checkpoints, and tutorial guidance authoring");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)


func _check(condition:bool,message:String)->void:
	if not condition:failures.append(message)
