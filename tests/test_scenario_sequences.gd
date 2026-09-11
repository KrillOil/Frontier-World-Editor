extends SceneTree

const ScenarioScript:=preload("res://src/domain/scenario_document.gd")
var failures:Array[String]=[]


func _init()->void:
	var world:={"objects":[{"instance_id":"hero_001"}]};var scenario=ScenarioScript.new();scenario.create("guided","Guided","", "frontier_company",world)
	scenario.data.regions=[{"region_id":"beacon","display_name":"Beacon","shape":"point","points":[[1,0,1]]}]
	scenario.data.unit_groups=[{"group_id":"party","instance_ids":["hero_001"]}]
	scenario.data.objectives=[{"objective_id":"follow","title":"Follow","kind":"main","initial_state":"active"}]
	_check(scenario.add_sequence("begin",{"type":"scenario_start"},world),"Typed start sequence creates")
	_check(scenario.add_sequence_step("begin","conditions",{"type":"objective_is","objective_id":"follow","state":"active"},world),"Typed condition appends")
	_check(scenario.add_sequence_step("begin","actions",{"type":"set_objective","objective_id":"follow","state":"completed"},world),"Typed action appends")
	var begin:Dictionary=scenario._find(scenario.data.sequences,"sequence_id","begin");var last_type:String=begin.actions[-1].type
	_check(scenario.move_sequence_step("begin","actions",begin.actions.size()-1,-1,world) and scenario._find(scenario.data.sequences,"sequence_id","begin").actions[0].type==last_type,"Action order is authorable and meaningful")
	_check(scenario.duplicate_sequence("begin","begin_copy",world) and not scenario._find(scenario.data.sequences,"sequence_id","begin_copy").enabled,"Duplication creates a disabled review copy")
	_check(scenario.update_sequence("begin_copy",{"event":{"type":"sequence_completed","sequence_id":"begin"},"enabled":true},world),"Sequence-completed event references an earlier sequence")
	_check(not scenario.delete_sequence("begin",world) and "begin_copy" in scenario.errors[0],"Referenced sequence deletion names the blocker")
	_check(not scenario.update_sequence("begin",{"event":{"type":"sequence_completed","sequence_id":"begin_copy"}},world) and "cycle" in scenario.errors[0],"Completion cycles are rejected atomically")
	_check(scenario.flow_diagnostics().is_empty(),"Enabled reachable flow has no diagnostics")
	_check(scenario.update_sequence("begin_copy",{"enabled":false},world) and scenario.flow_diagnostics().any(func(message):return "disabled" in message),"Disabled flow is visible to the Creator")
	_check(scenario.undo() and scenario._find(scenario.data.sequences,"sequence_id","begin_copy").enabled,"Sequence edits participate in undo")
	var broken:Dictionary=scenario._find(scenario.data.sequences,"sequence_id","begin_copy");broken.event={"type":"sequence_completed","sequence_id":"missing_dependency"}
	_check(scenario.validate(scenario.data,world).any(func(message):return "unresolved sequence" in message),"Unresolved completion dependencies become validation findings")
	_check(scenario.flow_diagnostics().all(func(message):return "waits on a disabled sequence" not in message),"Flow diagnostics safely ignore a missing dependency already reported by validation")
	if failures.is_empty():print("PASS: typed scenario sequence lifecycle and flow validation");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)


func _check(condition:bool,message:String)->void:
	if not condition:failures.append(message)
