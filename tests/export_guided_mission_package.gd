extends SceneTree

const Shell:=preload("res://src/app/editor_shell.tscn")


func _init()->void:call_deferred("_run")


func _run()->void:
	var output:=OS.get_environment("QA_GUIDED_PACKAGE_PATH")
	if output.is_empty():push_error("QA_GUIDED_PACKAGE_PATH is required");quit(1);return
	var screenshot_path:=OS.get_environment("QA_EDITOR_SCREENSHOT_PATH")
	var cinematic_screenshot_path:=OS.get_environment("QA_CINEMATIC_SCREENSHOT_PATH");var validation_screenshot_path:=OS.get_environment("QA_VALIDATION_SCREENSHOT_PATH");var setup_screenshot_path:=OS.get_environment("QA_TEST_SETUP_SCREENSHOT_PATH");var needs_capture:=not screenshot_path.is_empty() or not cinematic_screenshot_path.is_empty() or not validation_screenshot_path.is_empty() or not setup_screenshot_path.is_empty()
	DirAccess.make_dir_recursive_absolute(output)
	for filename in ["definitions.json","world.json","terrain.json"]:
		var source:=ProjectSettings.globalize_path("res://worlds/crimsdale/"+filename);var error:=DirAccess.copy_absolute(source,output.path_join(filename))
		if error!=OK:push_error("Could not prepare "+filename);quit(1);return
	var capture_viewport:Viewport=root;var editor=Shell.instantiate()
	if not needs_capture:root.add_child(editor)
	else:
		var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.gui_embed_subwindows=true;root.add_child(viewport);capture_viewport=viewport;viewport.add_child(editor)
	await process_frame;await process_frame;editor.open_package(output);editor.package.remove_scenario();editor._create_guided_mission_template()
	if editor.package.scenario==null:push_error("Editor UI could not create guided mission: "+" | ".join(editor.package.errors));quit(1);return
	if not editor.package.save():push_error("Editor UI could not save guided mission: "+" | ".join(editor.package.errors));quit(1);return
	if not screenshot_path.is_empty():
		editor.show_scenario_editor()
		for index in editor.scenario_region_list.item_count:
			if editor.scenario_region_list.get_item_metadata(index)=="reward_checkpoint":editor.scenario_region_list.select(index);editor._load_scenario_region(index);break
		await process_frame;editor.scenario_dialog.get_child(0).scroll_vertical=520
		if not await _capture(capture_viewport,screenshot_path):return
	if not cinematic_screenshot_path.is_empty():
		editor.scenario_dialog.hide();editor.show_cinematic_editor();editor._reselect_cinematic("opening");editor.cinematic_step_list.select(1);editor._scrub_cinematic(1)
		if not await _capture(capture_viewport,cinematic_screenshot_path):return
	if not validation_screenshot_path.is_empty():
		var opening:Dictionary=editor.package.scenario._find(editor.package.scenario.data.cinematics,"cinematic_id","opening");var speaker:String=opening.steps[1].speaker_instance_id;opening.steps[1].speaker_instance_id="missing_speaker";editor._validate_sequence_flow()
		if not await _capture(capture_viewport,validation_screenshot_path):return
		opening.steps[1].speaker_instance_id=speaker
	if not setup_screenshot_path.is_empty():
		editor.validation_dialog.hide();editor.cinematic_dialog.hide();editor.test_world_executable_field.text="/full/path/Godot_v4.7.1-stable_linux.x86_64";editor.test_world_project_field.text="/full/path/Frontier/Game";editor.show_test_world_setup();editor.status("Test World setup ready")
		if not await _capture(capture_viewport,setup_screenshot_path):return
	editor.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;var host:=editor.get_parent();host.remove_child(editor);editor.free()
	if host is SubViewport:root.remove_child(host);host.free()
	await process_frame
	print("PASS: editor UI exported guided mission package to "+output);quit(0)


func _capture(viewport:Viewport,path:String)->bool:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	if viewport.get_texture().get_image().save_png(path)!=OK:push_error("Could not save editor screenshot: "+path);quit(1);return false
	return true
