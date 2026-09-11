extends SceneTree

const Shell:=preload("res://src/app/editor_shell.tscn")
var failures:Array[String]=[]


func _init()->void:call_deferred("_run")


func _run()->void:
	var editor=Shell.instantiate();root.add_child(editor);await process_frame;await process_frame
	var tools:Array=[editor.surface_dialog,editor.cliff_dialog,editor.pathing_dialog,editor.environment_dialog,editor.workflow_dialog,editor.scenario_dialog,editor.sequence_dialog,editor.guidance_dialog,editor.encounter_dialog,editor.cinematic_dialog,editor.object_dialog,editor.terrain_dialog]
	_check(tools.all(func(window):return not window.visible),"Editor startup leaves all twelve tool windows closed")
	editor.show_encounter_editor();editor.encounter_list.select(0);editor._load_encounter(0);var selected_id:String=editor.encounter_list.get_item_metadata(0);editor.encounter_fields.behavior.text="guard";editor.encounter_fields.reinforcement_group_ids.text="";editor._update_encounter();var updated:Dictionary=editor.package.scenario._find(editor.package.scenario.data.encounters,"encounter_id",selected_id)
	_check(updated.behavior=="guard" and updated.reinforcement_group_ids==[],"Encounter UI updates string and array fields without mixed-type comparison")
	editor.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.remove_child(editor);editor.free();await process_frame
	if failures.is_empty():print("PASS: QA checkpoint A editor startup and encounter editing");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)


func _check(condition:bool,message:String)->void:
	if not condition:failures.append(message)
