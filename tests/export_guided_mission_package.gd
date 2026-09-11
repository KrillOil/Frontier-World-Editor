extends SceneTree

const Shell:=preload("res://src/app/editor_shell.tscn")


func _init()->void:call_deferred("_run")


func _run()->void:
	var output:=OS.get_environment("QA_GUIDED_PACKAGE_PATH")
	if output.is_empty():push_error("QA_GUIDED_PACKAGE_PATH is required");quit(1);return
	var screenshot_path:=OS.get_environment("QA_EDITOR_SCREENSHOT_PATH")
	DirAccess.make_dir_recursive_absolute(output)
	for filename in ["definitions.json","world.json","terrain.json"]:
		var source:=ProjectSettings.globalize_path("res://worlds/crimsdale/"+filename);var error:=DirAccess.copy_absolute(source,output.path_join(filename))
		if error!=OK:push_error("Could not prepare "+filename);quit(1);return
	var capture_viewport:Viewport=root;var editor=Shell.instantiate()
	if screenshot_path.is_empty():root.add_child(editor)
	else:
		var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.gui_embed_subwindows=true;root.add_child(viewport);capture_viewport=viewport;viewport.add_child(editor)
	await process_frame;await process_frame;editor.open_package(output);editor.package.remove_scenario();editor._create_guided_mission_template()
	if editor.package.scenario==null:push_error("Editor UI could not create guided mission: "+" | ".join(editor.package.errors));quit(1);return
	if not editor.package.save():push_error("Editor UI could not save guided mission: "+" | ".join(editor.package.errors));quit(1);return
	if not screenshot_path.is_empty():
		editor.show_scenario_editor()
		for index in editor.scenario_region_list.item_count:
			if editor.scenario_region_list.get_item_metadata(index)=="reward_checkpoint":editor.scenario_region_list.select(index);editor._load_scenario_region(index);break
		await process_frame;editor.scenario_dialog.get_child(0).scroll_vertical=520;await process_frame;await RenderingServer.frame_post_draw
		var image:=capture_viewport.get_texture().get_image();var screenshot_error:=image.save_png(screenshot_path)
		if screenshot_error!=OK:push_error("Could not save editor screenshot");quit(1);return
	print("PASS: editor UI exported guided mission package to "+output);quit(0)
