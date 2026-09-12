extends SceneTree

const SHELL := preload("res://src/app/editor_shell.tscn")
const PACKAGE := preload("res://src/domain/world_package.gd")
const CLIFF_WATER := preload("res://src/domain/terrain_cliff_water.gd")
const SURFACE_PAINTER:=preload("res://src/domain/terrain_surface_painter.gd")

var failures: Array[String] = []
var checks := 0
var pairwise_completed:=false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := SubViewport.new()
	host.size = Vector2i(1280, 720)
	host.gui_embed_subwindows = true
	root.add_child(host)
	var editor = SHELL.instantiate()
	host.add_child(editor)
	await process_frame
	await process_frame

	await _check_control_reachability(editor)
	await _check_pairwise_tool_transitions(editor)
	_check(pairwise_completed,"pairwise Selection/Workflow matrix reached its terminal assertion")
	await _check_world_and_escape_recovery(editor)
	await _check_ramp_surface_parity(editor)
	await _check_terrain_lifecycle_history(editor)
	await _check_package_rebinding(editor)
	await _check_chronological_history(editor)
	await _check_saved_history_and_scenario_lifecycle(editor)
	await _check_history_branch_clear(editor)
	await _check_failed_open_preserves_session(editor)
	_check(checks==22,"all planned T0 phases reached completion")

	print("T0_SUMMARY|checks=", checks, "|failures=", failures.size())
	for failure in failures:
		print("T0_FAIL|", failure)
	editor.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.remove_child(editor)
	editor.free()
	root.remove_child(host)
	host.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _check_control_reachability(editor) -> void:
	editor.show_terrain_editor()
	await process_frame
	var terrain_controls: Array[Control] = []
	for field in editor.terrain_fields.values(): terrain_controls.append(field)
	terrain_controls.append(editor.terrain_anchor)
	terrain_controls.append_array(_action_buttons(editor.terrain_dialog))
	_check_window_controls("Terrain", editor.terrain_dialog, terrain_controls)
	editor.terrain_dialog.hide()

	editor.show_workflow_editor()
	await process_frame
	var workflow_controls: Array[Control] = []
	for field in editor.workflow_fields.values(): workflow_controls.append(field)
	for field in editor.workflow_domains.values(): workflow_controls.append(field)
	workflow_controls.append(editor.workflow_mode)
	workflow_controls.append_array(_action_buttons(editor.workflow_dialog))
	_check_window_controls("Workflow", editor.workflow_dialog, workflow_controls)
	editor.workflow_dialog.hide()


func _check_window_controls(label: String, window: Window, controls: Array[Control]) -> void:
	var client := Rect2(Vector2.ZERO, window.size)
	var unreachable: Array[String] = []
	for control in controls:
		var rect := control.get_global_rect()
		var reachable := control.is_visible_in_tree() and client.encloses(rect) and control.mouse_filter != Control.MOUSE_FILTER_IGNORE
		if not reachable:
			unreachable.append("%s %s" % [_control_name(control), rect])
	_check(unreachable.is_empty(), "%s controls mouse-reachable at 1280x720; window=%s unreachable=%s" % [label, window.size, unreachable])


func _check_pairwise_tool_transitions(editor) -> void:
	if editor.package.terrain.data.pathing.movement[0] == "inherit": editor.package.terrain.data.pathing.movement[0] = "blocked"
	var modes := ["selection", "placement", "move", "sculpt", "surface", "cliff", "pathing", "workflow"]
	var bad_pairs: Array[String] = []
	var bad_labels:Array[String]=[]
	for source in modes:
		for destination in modes:
			if source == destination: continue
			_force_neutral(editor)
			_activate(editor, source)
			_activate(editor, destination)
			var active := _active_modes(editor)
			var expected:Array[String]=[]
			if destination!="selection":expected.append(destination)
			if active != expected:
				bad_pairs.append("%s→%s leaves %s" % [source, destination, active])
			var expected_label:String="Mode: "+str({"selection":"Selection","placement":"Placement","move":"Move","sculpt":"Sculpt","surface":"Surface Paint","cliff":"Raise Cliff","pathing":"Pathing Paint","workflow":"Workflow"}[destination])
			if editor.terrain_mode_label.text!=expected_label:bad_labels.append("%s→%s labels '%s'"%[source,destination,editor.terrain_mode_label.text])
		await process_frame
	_check(bad_pairs.is_empty(), "every pairwise viewport-tool transition leaves only its destination active; failures=" + str(bad_pairs))
	_check(bad_labels.is_empty(),"every pairwise transition exposes the destination mode; failures="+str(bad_labels))
	pairwise_completed=true
	_force_neutral(editor)


func _check_world_and_escape_recovery(editor) -> void:
	var modes := ["selection", "placement", "move", "sculpt", "surface", "cliff", "pathing", "workflow"]
	var world_failures: Array[String] = []
	var world_button: Button
	for child in editor.get_node("Toolbar").get_children():
		if child is Button and child.text == "World": world_button = child
	for mode in modes:
		_force_neutral(editor)
		_activate(editor, mode)
		world_button.pressed.emit()
		var active := _active_modes(editor)
		if not active.is_empty(): world_failures.append("%s leaves %s" % [mode, active])
	_check(world_failures.is_empty(), "World returns every viewport mode to neutral; failures=" + str(world_failures))

	var escape_failures: Array[String] = []
	for mode in modes:
		_force_neutral(editor)
		_activate(editor, mode)
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = true
		if mode=="workflow":
			editor.workflow_fields.width.get_line_edit().grab_focus()
			editor.workflow_dialog.push_input(event)
			await process_frame
		else:editor._on_viewport_input(event)
		var active := _active_modes(editor)
		if not active.is_empty(): escape_failures.append("%s leaves %s" % [mode, active])
	_check(escape_failures.is_empty(), "Escape returns every idle viewport mode to neutral; failures=" + str(escape_failures))
	_force_neutral(editor)


func _check_ramp_surface_parity(editor)->void:
	var package_path:="/tmp/frontier-terrain-t0-ramp-%s"%Time.get_ticks_msec();DirAccess.make_dir_recursive_absolute(package_path)
	for filename in ["definitions.json","world.json","terrain.json","scenario.json"]:
		var source:=ProjectSettings.globalize_path("res://worlds/crimsdale/"+filename)
		if FileAccess.file_exists(source):DirAccess.copy_absolute(source,package_path.path_join(filename))
	editor.open_package(package_path);var terrain=editor.package.terrain;var width:=int(terrain.data.grid.width_cells);var depth:=int(terrain.data.grid.depth_cells)
	for z in depth+1:
		for x in width+1:terrain.data.grid.heights_cm[z*(width+1)+x]=x*50
	terrain.data.cliffs.levels.fill(0);terrain.data.cliffs.levels[4*width+4]=1;terrain.data.cliffs.ramps=[{"x":3.0,"z":4.0,"direction":"east"},{"x":4.0,"z":4.0,"direction":"west"}]
	_check(editor.package.save(),"Serialized-float ramp fixture saves")
	editor.open_package(package_path);terrain=editor.package.terrain;var cliff_tools=CLIFF_WATER.new(terrain);var normalized:=cliff_tools.edge_has_ramp(3,4,"east") and cliff_tools.edge_has_ramp(4,4,"west");var lower_corners:Array[float]=terrain.cell_corner_heights(3,4);var upper_corners:Array[float]=terrain.cell_corner_heights(4,4);var corners_match:=_all_close(lower_corners,[1.5,1.5,4.0,4.0]) and _all_close(upper_corners,[4.0,4.0,4.5,4.5])
	editor.refresh_terrain_preview();var grid:Dictionary=terrain.data.grid;var z_center:=float(grid.origin_z_m)+4.5*float(grid.cell_size_m);var lower:=Vector2(float(grid.origin_x_m)+3.5*float(grid.cell_size_m),z_center);var upper:=Vector2(float(grid.origin_x_m)+4.5*float(grid.cell_size_m),z_center);var edge:=Vector2(float(grid.origin_x_m)+4.0*float(grid.cell_size_m),z_center);var mesh=editor.world_root.get_node("TerrainPreview").mesh;var lower_mesh:=_mesh_heights_at([mesh],lower);var upper_mesh:=_mesh_heights_at([mesh],upper);var edge_mesh:=_mesh_heights_at([mesh],edge);var lower_effective:float=terrain.effective_height(lower.x,lower.y);var upper_effective:float=terrain.effective_height(upper.x,upper.y);var edge_effective:float=terrain.effective_height(edge.x,edge.y);var preview_matches:=_all_values_close(lower_mesh,lower_effective) and _all_values_close(upper_mesh,upper_effective) and _all_values_close(edge_mesh,edge_effective)
	var original:Dictionary=terrain.data.duplicate(true);terrain.data.grid.heights_cm.fill(0);terrain.data.cliffs.levels.fill(0);terrain.data.cliffs.levels[4*width+4]=1;terrain.data.cliffs.ramps=[{"x":3,"z":4,"direction":"east"}];terrain.data.water={"enabled":true,"level_cm":100};cliff_tools=CLIFF_WATER.new(terrain);var water_contract:bool=cliff_tools.water_class_at_cell(3,4)=="shallow" and {"direction":"east","x":3,"z":4} in cliff_tools.derived_shores();editor.refresh_terrain_preview();var isolated_mesh=editor.world_root.get_node("TerrainPreview").mesh;var wall_contract:bool=_mesh_has_vertical_wall([isolated_mesh],"z",float(grid.origin_z_m)+4.0*float(grid.cell_size_m),float(grid.origin_x_m)+3.0*float(grid.cell_size_m),float(grid.origin_x_m)+4.0*float(grid.cell_size_m));terrain.data=original;editor.refresh_terrain_preview()
	_check(normalized and corners_match and preview_matches and water_contract and wall_contract and is_equal_approx(lower_effective,2.75) and is_equal_approx(upper_effective,4.25) and is_equal_approx(edge_effective,4.0),"saved/reopened ramp coordinates, closed endpoint walls, preview, and ramp-independent water classification match the canonical contract; normalized=%s lower=%s upper=%s edge=%s"%[normalized,lower_mesh,upper_mesh,edge_mesh])


func _check_terrain_lifecycle_history(editor)->void:
	var package_path:="/tmp/frontier-terrain-t0-lifecycle-%s"%Time.get_ticks_msec();DirAccess.make_dir_recursive_absolute(package_path)
	for filename in ["definitions.json","world.json","scenario.json"]:
		var source:=ProjectSettings.globalize_path("res://worlds/crimsdale/"+filename)
		if FileAccess.file_exists(source):DirAccess.copy_absolute(source,package_path.path_join(filename))
	editor.open_package(package_path);editor.show_terrain_editor();editor.terrain_fields.width_cells.text="8";editor.terrain_fields.depth_cells.text="8";editor.terrain_fields.cell_size_m.text="1";editor.terrain_fields.base_height_cm.text="0";editor.terrain_fields.origin_x_m.text="-4";editor.terrain_fields.origin_z_m.text="-4";editor._create_terrain()
	var created=editor.package.terrain;var create_dirty:bool=created!=null and editor.package.dirty;editor.perform_undo();var undo_clean:bool=editor.package.terrain==null and not editor.package.dirty;editor.perform_redo();var redo_dirty:bool=editor.package.terrain==created and editor.package.dirty
	_check(create_dirty and undo_clean and redo_dirty,"absent terrain → Create → Undo → Redo is one global lifecycle transaction with exact pre-save dirtiness")
	var saved:bool=editor.package.save();editor.perform_undo();var saved_undo_dirty:bool=editor.package.terrain==null and editor.package.dirty;editor.perform_redo();var saved_redo_clean:bool=editor.package.terrain==created and not editor.package.dirty and not created.dirty
	_check(saved and saved_undo_dirty and saved_redo_clean,"saved terrain lifecycle Undo is dirty and Redo returns to the exact clean saved state")


func _check_package_rebinding(editor) -> void:
	editor.open_package("res://worlds/crimsdale")
	var package_a_terrain = editor.package.terrain
	package_a_terrain.data.pathing.movement[0] = "blocked"
	editor.sculptor = null
	editor.surface_painter = null
	editor.pathing = null
	editor.workflow = null

	editor.toggle_sculpt_mode()
	editor.enable_surface_paint()
	editor.show_pathing_editor()
	editor.enable_pathing_paint()
	editor.show_workflow_editor()
	editor.workflow_fields.width.value = 2
	editor.workflow_fields.depth.value = 2
	editor._workflow_copy()
	editor.toggle_pathing_overlay()
	if not editor.pathing_overlay_visible: editor.toggle_pathing_overlay()
	_check(SURFACE_PAINTER.new(package_a_terrain).add_layer("surface_crimsdale_dry_grass"),"package A stale-confirmation fixture has a removable second surface")
	var package_a_revision: int = int(package_a_terrain.revision)

	var package_b_path := "/tmp/frontier-terrain-t0-package-b-%s" % Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(package_b_path)
	for filename in ["definitions.json", "world.json", "terrain.json", "scenario.json"]:
		var source := ProjectSettings.globalize_path("res://worlds/crimsdale/" + filename)
		if FileAccess.file_exists(source): DirAccess.copy_absolute(source, package_b_path.path_join(filename))
	var package_b = PACKAGE.new()
	if not package_b.load_from_directory(package_b_path):
		_check(false, "package B fixture loads: %s" % package_b.errors)
		return
	package_b.terrain.reset(777)
	SURFACE_PAINTER.new(package_b.terrain).add_layer("surface_crimsdale_dry_grass")
	CLIFF_WATER.new(package_b.terrain).set_water(true,321)
	if not package_b.save():
		_check(false, "package B fixture saves: %s" % package_b.errors)
		return
	var a_layers:Array=package_a_terrain.data.surfaces.layer_ids.duplicate();editor.show_surface_editor();editor.surface_layers.select(1);editor.request_remove_surface_layer();await process_frame;var stale_confirmation_armed:bool=editor.surface_confirmation.visible and not editor.surface_confirmation.confirmed.get_connections().is_empty();editor.surface_confirmation.hide()
	editor.show_scenario_editor();editor.request_remove_scenario();await process_frame;var stale_scenario_armed:bool=editor.scenario_remove_armed and editor.scenario_remove_confirmation.visible
	editor.show_cliff_water_editor();await process_frame;var stale_water_values:bool=not editor.cliff_water_enabled.button_pressed and int(editor.cliff_water_level.value)==0

	editor.open_package(package_b_path)
	var package_b_terrain = editor.package.terrain
	var package_b_scenario=editor.package.scenario;var b_layers:Array=package_b_terrain.data.surfaces.layer_ids.duplicate();editor.surface_confirmation.confirmed.emit();editor.scenario_remove_confirmation.confirmed.emit();editor.apply_water();var package_dialogs_closed:=true
	for dialog in [editor.terrain_dialog,editor.surface_dialog,editor.cliff_dialog,editor.pathing_dialog,editor.environment_dialog,editor.workflow_dialog,editor.object_dialog,editor.scenario_dialog,editor.sequence_dialog,editor.guidance_dialog,editor.encounter_dialog,editor.cinematic_dialog]:package_dialogs_closed=package_dialogs_closed and not dialog.visible
	var stale_confirmation_safe:bool=stale_confirmation_armed and stale_scenario_armed and stale_water_values and package_dialogs_closed and not editor.surface_confirmation.visible and editor.surface_confirmation.confirmed.get_connections().is_empty() and not editor.scenario_remove_armed and not editor.scenario_remove_confirmation.visible and package_a_terrain.data.surfaces.layer_ids==a_layers and package_b_terrain.data.surfaces.layer_ids==b_layers and editor.package.scenario==package_b_scenario and bool(package_b_terrain.data.water.enabled) and int(package_b_terrain.data.water.level_cm)==321
	var helpers_rebound: bool = (
		editor.sculptor == null or editor.sculptor.terrain == package_b_terrain
	) and (
		editor.surface_painter == null or editor.surface_painter.terrain == package_b_terrain
	) and (
		editor.pathing == null or editor.pathing.terrain == package_b_terrain
	) and (
		editor.workflow == null or editor.workflow.terrain == package_b_terrain
	)
	var clean_session: bool = _active_modes(editor).is_empty() and editor.terrain_clipboard.is_empty() and editor.world_root.get_node_or_null("PathingOverlay") == null
	_check(helpers_rebound and clean_session and stale_confirmation_safe, "A→B clears/rebinds helpers, mode, clipboard, overlays, and stale confirmations; rebound=%s active=%s clipboard_empty=%s pathing_overlay=%s stale=(armed=%s visible=%s connections=%d A=%s B=%s)" % [helpers_rebound, _active_modes(editor), editor.terrain_clipboard.is_empty(), editor.world_root.get_node_or_null("PathingOverlay") != null,stale_confirmation_armed,editor.surface_confirmation.visible,editor.surface_confirmation.confirmed.get_connections().size(),package_a_terrain.data.surfaces.layer_ids==a_layers,package_b_terrain.data.surfaces.layer_ids==b_layers])

	var b_revision_before: int = int(package_b_terrain.revision)
	if editor.pathing != null:
		var old_grid: Dictionary = editor.pathing.terrain.data.grid
		var open_index: int = int(editor.pathing.terrain.data.pathing.movement.find("inherit"))
		var open_x: int = open_index % int(old_grid.width_cells)
		var open_z: int = open_index / int(old_grid.width_cells)
		var center := Vector2(float(old_grid.origin_x_m) + (open_x + 0.5) * float(old_grid.cell_size_m), float(old_grid.origin_z_m) + (open_z + 0.5) * float(old_grid.cell_size_m))
		editor.pathing.paint("movement", true, center, float(old_grid.cell_size_m) * 0.5)
	var stale_mutation: bool = int(package_a_terrain.revision) != package_a_revision and int(package_b_terrain.revision) == b_revision_before
	_check(not stale_mutation, "post-open terrain actions cannot mutate package A through a stale helper; A revision %d→%d, B revision %d→%d" % [package_a_revision, package_a_terrain.revision, b_revision_before, package_b_terrain.revision])
	_force_neutral(editor)


func _check_chronological_history(editor) -> void:
	editor.open_package("res://worlds/crimsdale")
	for dialog in [editor.scenario_dialog, editor.guidance_dialog, editor.sequence_dialog, editor.encounter_dialog, editor.cinematic_dialog]: dialog.hide()
	var terrain = editor.package.terrain
	var scenario = editor.package.scenario
	var cliff_before := int(terrain.data.cliffs.levels[0])
	var objects_before: int = editor.package.world.objects.size()
	var title_before := str(scenario.data.title)
	CLIFF_WATER.new(terrain).change_level(0, 0, 1) # A
	editor.package.place_instance("building_crimsdale_house_a", Vector3(1, 0, 1), 0.0) # B
	scenario.update_metadata(title_before + " Chronology", str(scenario.data.description), str(scenario.data.player_faction_id), editor.package.world) # C
	editor.show_scenario_editor()

	editor.perform_undo()
	var first_ok: bool = str(scenario.data.title) == title_before and editor.package.world.objects.size() == objects_before + 1 and int(terrain.data.cliffs.levels[0]) == cliff_before + 1
	editor.perform_undo()
	var second_ok: bool = str(scenario.data.title) == title_before and editor.package.world.objects.size() == objects_before and int(terrain.data.cliffs.levels[0]) == cliff_before + 1
	editor.perform_undo()
	var third_ok: bool = str(scenario.data.title) == title_before and editor.package.world.objects.size() == objects_before and int(terrain.data.cliffs.levels[0]) == cliff_before
	_check(first_ok and second_ok and third_ok, "Undo reverses C scenario → B object → A terrain regardless of dialog; after1=%s after2=%s after3=%s current(title_changed=%s objects=%d cliff=%d)" % [first_ok, second_ok, third_ok, str(scenario.data.title) != title_before, editor.package.world.objects.size(), int(terrain.data.cliffs.levels[0])])

	editor.perform_redo()
	var redo_first: bool = int(terrain.data.cliffs.levels[0]) == cliff_before + 1 and editor.package.world.objects.size() == objects_before and str(scenario.data.title) == title_before
	editor.perform_redo()
	var redo_second: bool = int(terrain.data.cliffs.levels[0]) == cliff_before + 1 and editor.package.world.objects.size() == objects_before + 1 and str(scenario.data.title) == title_before
	editor.perform_redo()
	var redo_third: bool = int(terrain.data.cliffs.levels[0]) == cliff_before + 1 and editor.package.world.objects.size() == objects_before + 1 and str(scenario.data.title) == title_before + " Chronology"
	_check(redo_first and redo_second and redo_third, "Redo reapplies A terrain → B object → C scenario regardless of dialog; after1=%s after2=%s after3=%s" % [redo_first, redo_second, redo_third])
	editor.scenario_dialog.hide()


func _check_saved_history_and_scenario_lifecycle(editor)->void:
	var package_path:="/tmp/frontier-terrain-t0-history-%s"%Time.get_ticks_msec();DirAccess.make_dir_recursive_absolute(package_path)
	for filename in ["definitions.json","world.json","terrain.json","scenario.json"]:
		var source:=ProjectSettings.globalize_path("res://worlds/crimsdale/"+filename)
		if FileAccess.file_exists(source):DirAccess.copy_absolute(source,package_path.path_join(filename))
	editor.open_package(package_path);var scenario=editor.package.scenario;var title_before:=str(scenario.data.title);editor.package.place_instance("building_crimsdale_house_a",Vector3(3,0,3),0.0);scenario.update_metadata(title_before+" Saved",str(scenario.data.description),str(scenario.data.player_faction_id),editor.package.world);editor.refresh_all();_check(editor.package.save(),"mixed World/Scenario history fixture saves")
	var saved_world:Dictionary=editor.package.world.duplicate(true);var saved_scenario:Dictionary=scenario.data.duplicate(true);editor.perform_undo();var undo_dirty:bool=scenario.dirty and not editor.package.dirty;editor.perform_redo();var returned_clean:bool=editor.package.world==saved_world and scenario.data==saved_scenario and not editor.package.dirty and not scenario.dirty
	_check(undo_dirty and returned_clean,"Save→Undo→Redo returns exact World/Scenario content to a clean saved state")
	var object_count:int=editor.package.world.objects.size();editor._remove_scenario();editor.perform_undo();var removal_undo:bool=editor.package.scenario==scenario and editor.package.scenario.data==saved_scenario and editor.package.world.objects.size()==object_count and not editor.package.dirty;editor.perform_redo();var removal_redo:bool=editor.package.scenario==null and editor.package.world.objects.size()==object_count and editor.package.dirty;editor.perform_undo()
	_check(removal_undo and removal_redo,"scenario removal is a globally ordered transaction that does not reverse older World edits")
	editor._remove_scenario();editor._create_scenario();var created=editor.package.scenario;editor.perform_undo();var creation_undo:bool=editor.package.scenario==null;editor.perform_undo();var original_restored:bool=editor.package.scenario==scenario and editor.package.scenario.data==saved_scenario and editor.package.world.objects.size()==object_count
	_check(created!=null and creation_undo and original_restored,"scenario creation/removal can be undone in chronological order back to the original saved scenario")


func _check_history_branch_clear(editor) -> void:
	editor.open_package("res://worlds/crimsdale")
	var terrain = editor.package.terrain
	var scenario = editor.package.scenario
	var cliff_before := int(terrain.data.cliffs.levels[1])
	var objects_before: int = editor.package.world.objects.size()
	var title_before := str(scenario.data.title)
	CLIFF_WATER.new(terrain).change_level(1, 0, 1) # A
	editor.package.place_instance("building_crimsdale_house_a", Vector3(2, 0, 2), 0.0) # B
	editor.refresh_all()
	editor.perform_undo() # abandon B
	scenario.update_metadata(title_before + " Branch", str(scenario.data.description), str(scenario.data.player_faction_id), editor.package.world) # C
	editor.refresh_all()
	var redos_cleared: bool = editor.global_redo_domains.is_empty() and not editor.package.can_redo() and not terrain.can_redo() and not scenario.can_redo()
	editor.perform_redo()
	var state_preserved: bool = int(terrain.data.cliffs.levels[1]) == cliff_before + 1 and editor.package.world.objects.size() == objects_before and str(scenario.data.title) == title_before + " Branch"
	_check(redos_cleared and state_preserved, "a new edit after Undo clears every abandoned redo branch and Redo cannot resurrect it; cleared=%s state_preserved=%s" % [redos_cleared, state_preserved])


func _check_failed_open_preserves_session(editor) -> void:
	editor.open_package("res://worlds/crimsdale")
	editor.enable_surface_paint()
	editor.show_workflow_editor()
	editor.workflow_fields.width.value = 1
	editor.workflow_fields.depth.value = 1
	editor._workflow_copy()
	var terrain_before = editor.package.terrain
	var clipboard_before: Dictionary = editor.terrain_clipboard.duplicate(true)
	editor.open_package("/tmp/frontier-terrain-t0-package-does-not-exist")
	var preserved: bool = editor.package.terrain == terrain_before and editor.terrain_tool_mode=="workflow" and editor.workflow_dialog.visible and editor.workflow != null and editor.workflow.terrain == terrain_before and editor.terrain_clipboard == clipboard_before
	_check(preserved, "a failed Open leaves the current package and recoverable editing session intact; workflow=%s clipboard=%s" % [editor.workflow_dialog.visible, not editor.terrain_clipboard.is_empty()])
	_force_neutral(editor)


func _activate(editor, mode: String) -> void:
	match mode:
		"selection":editor.return_to_world_selection()
		"placement": editor.start_placement("building_crimsdale_house_a")
		"move":
			editor.selected_instance_id = "crimsdale_house_001"
			var event := InputEventKey.new(); event.keycode = KEY_G; event.pressed = true
			editor._on_viewport_input(event)
		"sculpt": editor.toggle_sculpt_mode()
		"surface": editor.enable_surface_paint()
		"cliff":editor.show_cliff_water_editor();editor.set_cliff_mode("raise")
		"pathing":
			editor.show_pathing_editor()
			editor.enable_pathing_paint()
		"workflow":editor.show_workflow_editor()


func _active_modes(editor) -> Array[String]:
	var active: Array[String] = []
	if not editor.placement_definition_id.is_empty() or editor.placement_ghost != null: active.append("placement")
	if editor.moving_instance: active.append("move")
	if editor.sculpt_enabled or editor.get_node("Workspace/Viewport/Content/SculptHUD").visible: active.append("sculpt")
	if editor.surface_enabled or editor.get_node("Workspace/Viewport/Content/SurfaceHUD").visible: active.append("surface")
	if not editor.cliff_mode.is_empty(): active.append("cliff")
	if editor.pathing_enabled or editor.get_node("Workspace/Viewport/Content/PathingHUD").visible: active.append("pathing")
	if editor.terrain_tool_mode=="workflow" or editor.workflow_dialog.visible:active.append("workflow")
	return active


func _force_neutral(editor) -> void:
	if editor.sculptor != null and editor.sculptor.active: editor.sculptor.cancel()
	if editor.surface_painter != null and editor.surface_painter.active: editor.surface_painter.cancel()
	if editor.pathing != null and editor.pathing.painting: editor.pathing.cancel_paint()
	editor.sculpt_enabled = false
	editor.surface_enabled = false
	editor.pathing_enabled = false
	editor.cliff_mode = ""
	editor.moving_instance = false
	editor.placement_definition_id = ""
	editor.terrain_tool_mode="selection"
	editor.terrain_mode_label.text="Mode: Selection"
	editor.workflow_dialog.hide()
	for hud_name in ["SculptHUD", "SurfaceHUD", "PathingHUD"]:
		editor.get_node("Workspace/Viewport/Content/" + hud_name).visible = false
	if editor.placement_ghost != null:
		editor.placement_ghost.free()
		editor.placement_ghost = null
	if editor.brush_preview != null:
		editor.brush_preview.free()
		editor.brush_preview = null


func _action_buttons(window: Window) -> Array[Control]:
	var result: Array[Control] = []
	for node in window.find_children("*", "Button", true, false):
		if node.get_class() == "Button" and node.get_parent() is VBoxContainer: result.append(node)
	return result


func _control_name(control: Control) -> String:
	if control is CheckBox: return "CheckBox[%s]" % control.text
	if control is OptionButton: return "OptionButton[%s]" % control.text
	if control is Button: return "Button[%s]" % control.text
	return control.get_class()


func _mesh_heights_at(meshes:Array,point:Vector2)->Array[float]:
	var heights:Array[float]=[]
	for mesh in meshes:
		for surface in mesh.get_surface_count():
			var arrays:Array=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for index in range(0,indices.size(),3):
				var a:Vector3=vertices[indices[index]];var b:Vector3=vertices[indices[index+1]];var c:Vector3=vertices[indices[index+2]];var denominator:float=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
				if absf(denominator)<0.000001:continue
				var wa:float=((b.z-c.z)*(point.x-c.x)+(c.x-b.x)*(point.y-c.z))/denominator;var wb:float=((c.z-a.z)*(point.x-c.x)+(a.x-c.x)*(point.y-c.z))/denominator;var wc:=1.0-wa-wb
				if wa>=-0.0001 and wb>=-0.0001 and wc>=-0.0001:heights.append(wa*a.y+wb*b.y+wc*c.y)
	return heights


func _all_close(values:Array[float],expected:Array)->bool:
	if values.size()!=expected.size():return false
	for index in values.size():
		if not is_equal_approx(values[index],float(expected[index])):return false
	return true


func _all_values_close(values:Array[float],expected:float)->bool:
	if values.is_empty():return false
	for value in values:
		if absf(value-expected)>0.001:return false
	return true


func _mesh_has_vertical_wall(meshes:Array,axis:String,coordinate:float,span_min:float,span_max:float)->bool:
	for mesh in meshes:
		for surface in mesh.get_surface_count():
			var arrays:Array=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for index in range(0,indices.size(),3):
				var points:Array[Vector3]=[vertices[indices[index]],vertices[indices[index+1]],vertices[indices[index+2]]];var plane_values:Array=[points[0].x,points[1].x,points[2].x] if axis=="x" else [points[0].z,points[1].z,points[2].z];var spans:Array=[points[0].z,points[1].z,points[2].z] if axis=="x" else [points[0].x,points[1].x,points[2].x];var heights:Array=[points[0].y,points[1].y,points[2].y]
				if plane_values.all(func(value):return absf(value-coordinate)<0.001) and float(spans.max())>=span_max-0.001 and float(spans.min())<=span_min+0.001 and float(heights.max())-float(heights.min())>0.1:return true
	return false


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("T0_PASS|", message)
	else:
		failures.append(message)
