extends SceneTree

const SHELL := preload("res://src/app/editor_shell.tscn")
const TERRAIN := preload("res://src/domain/terrain_document.gd")

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture_path := _make_fixture()
	var host := SubViewport.new()
	host.size = Vector2i(1280, 720)
	host.gui_embed_subwindows = true
	root.add_child(host)
	var editor = SHELL.instantiate()
	host.add_child(editor)
	await process_frame
	await process_frame
	editor.open_package(fixture_path)
	await process_frame
	await process_frame

	_check_palette_shell(editor)
	await _check_viewport_workflow(editor)
	await _check_window_shortcuts(editor)
	await _check_preview_cancel_confirm(editor)
	_check_persistence(editor, fixture_path)

	print("T1_SUMMARY|checks=", checks, "|failures=", failures.size())
	for failure in failures: print("T1_FAIL|", failure)
	editor.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.remove_child(editor)
	editor.free()
	root.remove_child(host)
	host.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _make_fixture() -> String:
	var path := "/tmp/frontier-terrain-t1-%s" % Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(path)
	for filename in ["definitions.json", "world.json", "scenario.json"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path("res://worlds/crimsdale/" + filename), path.path_join(filename))
	var terrain = TERRAIN.new()
	terrain.create(8, 8, 1.0, 0, -4.0, -4.0)
	var candidate: Dictionary = terrain.data.duplicate(true)
	var width := int(candidate.grid.width_cells)
	for z in range(4, 6):
		for x in range(4, 6): candidate.grid.heights_cm[z * (width + 1) + x] = 100
	candidate.cliffs.levels[4 * width + 4] = 1
	candidate.pathing.movement[4 * width + 4] = "blocked"
	terrain.commit_structural("T1 fixture", candidate)
	terrain.save(path.path_join("terrain.json"))
	return path


func _check_palette_shell(editor) -> void:
	var world_before: Dictionary = editor.package.world.duplicate(true)
	var terrain_before: String = editor.package.terrain.serialize()
	var revisions := [editor.package.revision, editor.package.terrain.revision, editor.package.scenario.revision]
	var histories := [editor.package.history_depth(), editor.package.terrain.history_depth(), editor.package.scenario.history_depth()]
	var dirty_before: bool = editor.has_unsaved_changes()
	var original_side: String = editor.palette_side
	var original_width: int = editor.palette_width
	var original_collapsed: bool = editor.palette_collapsed
	var original_page: String = editor.palette_last_page
	editor._select_palette_page(0)
	editor._toggle_palette_side()
	var resize := InputEventMouseMotion.new(); resize.button_mask = MOUSE_BUTTON_MASK_LEFT; resize.relative = Vector2(24, 0)
	editor._on_palette_resize_input(resize)
	editor._toggle_palette_collapsed()
	editor._toggle_palette_collapsed()
	var pages: Array[String] = []
	for index in editor.palette_page.item_count: pages.append(editor.palette_page.get_item_text(index))
	var neutral: bool = editor.package.world == world_before and editor.package.terrain.serialize() == terrain_before and [editor.package.revision, editor.package.terrain.revision, editor.package.scenario.revision] == revisions and [editor.package.history_depth(), editor.package.terrain.history_depth(), editor.package.scenario.history_depth()] == histories and editor.has_unsaved_changes() == dirty_before
	_check(editor.palette_panel.get_parent() == editor.get_node("Workspace") and pages == ["Terrain", "Units", "Props", "Regions", "Mission"], "Creator palette stays inside the workspace with all five swappable pages")
	_check(editor.palette_width >= 180 and editor.palette_width <= 420 and editor.palette_collapse_button.accessibility_name != "" and editor.palette_resize_handle.accessibility_name != "", "Palette docking, resizing, collapse, and keyboard names remain available at 1280×720")
	_check(neutral, "Palette preferences never dirty canonical data or enter Undo/Redo history")
	editor.palette_side = original_side; editor.palette_width = original_width; editor.palette_collapsed = original_collapsed; editor.palette_last_page = original_page
	editor._apply_palette_layout(); editor._save_palette_preferences()


func _check_viewport_workflow(editor) -> void:
	editor.show_workflow_editor()
	await process_frame
	_check(editor.workflow_dialog.visible and not editor.workflow_dialog.exclusive and editor.workflow_confirm_button.disabled, "Terrain Workflow is non-modal and starts with Confirm disabled")
	var target := Vector3(0.5, 3.0, 0.5)
	var screen: Vector2 = editor.camera.unproject_position(target)
	var picked: Vector3 = editor.ground_position(screen)
	_check(editor.workflow.world_to_cell(picked) == Vector2i(4, 4) and picked.y > 2.5, "Viewport picking follows the displayed raised cliff top instead of Y=0; picked=%s cell=%s screen=%s viewport=%s container=%s camera=%s" % [picked, editor.workflow.world_to_cell(picked), screen, editor.viewport.size, editor.viewport_container.size, editor.camera.position])
	var flat: Dictionary = editor.package.terrain.data.duplicate(true)
	flat.grid.heights_cm.fill(0); flat.cliffs.levels.fill(0)
	editor.package.terrain.commit_structural("Flatten after elevated-picking probe", flat)
	editor.refresh_all()
	await process_frame

	var expected := Rect2i(2, 2, 4, 3)
	for pair in [[Vector2i(2, 2), Vector2i(5, 4)], [Vector2i(5, 2), Vector2i(2, 4)], [Vector2i(2, 4), Vector2i(5, 2)], [Vector2i(5, 4), Vector2i(2, 2)]]:
		editor._workflow_begin_selection()
		var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = _screen_for_cell(editor, pair[0])
		var release := InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_LEFT; release.pressed = false; release.position = _screen_for_cell(editor, pair[1])
		editor._handle_workflow_viewport_input(press)
		editor._handle_workflow_viewport_input(release)
		_check(editor.workflow.selection == expected, "Mouse drag selection is inclusive in every direction")
	editor._workflow_begin_selection()
	var cancelled_press := InputEventMouseButton.new(); cancelled_press.button_index = MOUSE_BUTTON_LEFT; cancelled_press.pressed = true; cancelled_press.position = _screen_for_cell(editor, Vector2i(0, 0))
	editor._handle_workflow_viewport_input(cancelled_press)
	editor._workflow_cancel()
	_check(editor.workflow.selection == expected and int(editor.workflow_fields.x.value) == expected.position.x and int(editor.workflow_fields.width.value) == expected.size.x, "Escape restores the prior source selection and synchronized numeric fallback during a drag")

	var yaw_before: float = editor.orbit_yaw
	var camera_drag := InputEventMouseMotion.new(); camera_drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE; camera_drag.relative = Vector2(8, 0)
	editor._on_viewport_input(camera_drag)
	var distance_before: float = editor.orbit_distance
	var wheel := InputEventMouseButton.new(); wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true
	editor._on_viewport_input(wheel)
	_check(editor.orbit_yaw != yaw_before and editor.orbit_distance < distance_before, "Middle-drag camera and wheel zoom remain usable during Workflow")

	editor._workflow_sample()
	var inspect := InputEventMouseButton.new(); inspect.button_index = MOUSE_BUTTON_LEFT; inspect.pressed = true; inspect.position = screen
	editor._handle_workflow_viewport_input(inspect)
	_check("Height authored" in editor.workflow_preview_label.text and "effective" in editor.workflow_preview_label.text and "surface_crimsdale_grass" in editor.workflow_preview_label.text and "Pathing" in editor.workflow_preview_label.text, "F-then-click inspection exposes authored/effective height, paired surfaces, water, pathing, and attachments")


func _check_window_shortcuts(editor) -> void:
	editor.workflow.select_cells(Vector2i(4, 4), Vector2i(4, 4)); editor._workflow_sync_source_fields(editor.workflow.selection)
	editor.workflow_cancel_button.grab_focus()
	await process_frame
	var button_focus_established: bool = editor.workflow_dialog.gui_get_focus_owner() == editor.workflow_cancel_button
	_push_window_key(editor, _key(KEY_S))
	await process_frame
	var button_select: bool = editor.workflow_select_armed
	_push_window_key(editor, _key(KEY_ESCAPE))
	await process_frame
	_push_window_key(editor, _key(KEY_F))
	await process_frame
	var button_sample: bool = editor.workflow_sampling
	editor.orbit_target = Vector3(99, 99, 99)
	var expected_center: Vector3 = editor.workflow.minimap_recenter(Vector2(0.5, 0.5))
	_push_window_key(editor, _key(KEY_M))
	await process_frame
	var button_recenter: bool = editor.orbit_target.is_equal_approx(expected_center)
	_push_window_key(editor, _key(KEY_ESCAPE))
	await process_frame
	var guard = editor.workflow_dialog.get_node("WorkflowInputGuard")
	_check(guard.dispatcher.is_valid() and button_focus_established and button_select and button_sample and button_recenter and editor.workflow_dialog.visible and not editor.workflow_select_armed and not editor.workflow_sampling, "Focused workflow Window routes S, F, M, and Escape through its input guard to the same states as mouse controls")

	editor.terrain_clipboard.clear()
	editor.workflow_fields.width.get_line_edit().grab_focus()
	var width_text: String = editor.workflow_fields.width.get_line_edit().text
	_push_window_key(editor, _key(KEY_C, true))
	await process_frame
	var text_copy_preserved: bool = editor.terrain_clipboard.is_empty() and editor.workflow_fields.width.get_line_edit().text == width_text
	_push_window_key(editor, _key(KEY_S))
	await process_frame
	var numeric_select_suppressed: bool = not editor.workflow_select_armed and editor.workflow_fields.width.get_line_edit().text == width_text
	_push_window_key(editor, _key(KEY_F))
	await process_frame
	var numeric_inspect_suppressed: bool = not editor.workflow_sampling
	editor.orbit_target = Vector3(99, 99, 99)
	_push_window_key(editor, _key(KEY_M))
	await process_frame
	_check(text_copy_preserved and numeric_select_suppressed and numeric_inspect_suppressed and is_equal_approx(editor.orbit_target.x, 99.0) and is_equal_approx(editor.orbit_target.z, 99.0), "Numeric LineEdit focus preserves editing by suppressing Ctrl+C, S, F, and M workflow shortcuts")

	editor.workflow_cancel_button.grab_focus()
	_push_window_key(editor, _key(KEY_C, true))
	await process_frame
	var copied: bool = not editor.terrain_clipboard.is_empty()
	_push_window_key(editor, _key(KEY_V, true))
	await process_frame
	var paste_ghost: bool = not editor.workflow_pending_preview.is_empty() and not editor.workflow_pending_preview.get("destination_settled", true)
	_push_window_key(editor, _key(KEY_ESCAPE))
	await process_frame
	_check(copied and paste_ghost and editor.workflow_pending_preview.is_empty() and editor.workflow_dialog.visible, "Button focus routes Ctrl+C, Ctrl+V, and Escape through immutable copy, live ghost, and non-mutating cancel")


func _check_preview_cancel_confirm(editor) -> void:
	editor.workflow.select_cells(Vector2i(4, 4), Vector2i(4, 4))
	editor._workflow_sync_source_fields(editor.workflow.selection)
	for domain in editor.workflow_domains: editor.workflow_domains[domain].button_pressed = domain == "pathing"
	editor.workflow_fields.paste_x.value = 6
	editor.workflow_fields.paste_z.value = 4
	editor._workflow_move()
	editor._workflow_update_preview("move", Vector2i(6, 4))
	var before_cancel := [editor.package.terrain.serialize(), editor.package.terrain.revision, editor.package.terrain.dirty, editor.package.terrain.history_depth(), editor.package.terrain.redo_history.size()]
	_check(editor.workflow_pending_preview.confirm_enabled and editor.workflow_pending_preview.changed_cells == 2 and "crimsdale_fountain_001" in editor.workflow_pending_preview.intersecting_authored_ids, "Live Move preview reports changed cells and intersecting authored IDs")
	var workflow_overlay: Node = editor.world_root.get_node_or_null("WorkflowOverlay")
	editor.pathing_overlay_visible = true; editor.pathing.reset_cancellation(); editor.pathing.rebuild_overlay("movement"); editor.refresh_pathing_overlay()
	var pathing_overlay: Node = editor.world_root.get_node_or_null("PathingOverlay")
	var region_overlay: Node = editor.world_root.get_node_or_null("ScenarioRegions")
	_check(workflow_overlay != null and workflow_overlay.get_meta("overlay_label") == "Terrain Workflow" and workflow_overlay.get_node_or_null("SourceLabel") != null and workflow_overlay.get_node_or_null("DestinationLabel") != null and pathing_overlay != null and pathing_overlay.get_meta("overlay_label") == "Pathing" and region_overlay != null and region_overlay.get_meta("overlay_label") == "Scenario Regions" and editor.world_root.get_node_or_null("WorkflowOverlay") == workflow_overlay, "Workflow, Pathing, and Scenario Regions remain independently labelled without hiding the source or ghost")
	var populated: Dictionary = editor.workflow_pending_preview.duplicate(true)
	populated.intersecting_authored_ids = ["crimsdale_fountain_001", "crimsdale_guard_patrol_north_001", "mission_encounter_boundary_northeast", "grounded_attachment_blacksmith_workshop"]
	populated.warnings = ["1 boundary ramp remains at the source", "A grounded authored target intersects the committed rectangle"]
	populated.ok = false; populated.confirm_enabled = false; populated.error = "Candidate validation failed after a representative authored-data change"; populated.recovery = "Return to the source selection, repair the named terrain edge, and validate this destination again."
	editor.workflow_preview_label.text = editor._workflow_preview_text(populated)
	await process_frame
	await process_frame
	var client_size := Vector2(620, 680) if DisplayServer.get_name() == "headless" else Vector2(editor.workflow_dialog.size)
	var client := Rect2(Vector2.ZERO, client_size)
	var confirm_rect: Rect2 = editor.workflow_confirm_button.get_global_rect()
	var cancel_rect: Rect2 = editor.workflow_cancel_button.get_global_rect()
	var preview_rect: Rect2 = editor.workflow_preview_label.get_global_rect()
	var screen_bottom := float(editor.workflow_dialog.position.y) + maxf(confirm_rect.end.y, cancel_rect.end.y)
	var layout_conditions := [client.encloses(confirm_rect), client.encloses(cancel_rect), client.encloses(preview_rect), screen_bottom <= 720.0, editor.workflow_preview_label.autowrap_mode != TextServer.AUTOWRAP_OFF]
	_check(not layout_conditions.has(false), "Populated warning/recovery preview remains wrapped and Confirm/Cancel stay mouse-visible inside the 1280×720 client; conditions=%s client=%s confirm=%s cancel=%s preview=%s screen_bottom=%s" % [layout_conditions, client, confirm_rect, cancel_rect, preview_rect, screen_bottom])
	editor.workflow_cancel_button.grab_focus()
	_push_window_key(editor, _key(KEY_ESCAPE))
	await process_frame
	var after_cancel := [editor.package.terrain.serialize(), editor.package.terrain.revision, editor.package.terrain.dirty, editor.package.terrain.history_depth(), editor.package.terrain.redo_history.size()]
	_check(after_cancel == before_cancel and editor.workflow.selection == Rect2i(4, 4, 1, 1), "Escape cancels preview without changing data, revision, dirty state, history, redo, or source selection")

	editor.workflow_fields.paste_x.value = 6; editor.workflow_fields.paste_z.value = 4
	editor._workflow_move()
	editor._workflow_update_preview("move", Vector2i(6, 4))
	var terrain_history_before: int = editor.package.terrain.history_depth()
	var global_history_before: int = editor.global_undo_domains.size()
	var state_before_move: String = editor.package.terrain.serialize()
	editor.workflow_confirm_button.grab_focus()
	_push_window_key(editor, _key(KEY_ENTER))
	await process_frame
	var moved_state: String = editor.package.terrain.serialize()
	_check(moved_state != state_before_move and editor.package.terrain.history_depth() == terrain_history_before + 1 and editor.global_undo_domains.size() == global_history_before + 1, "Confirm commits Move as one globally chronological terrain transaction")
	editor.perform_undo()
	_check(editor.package.terrain.serialize() == state_before_move, "One global Undo restores the complete Move")
	editor.perform_redo()
	_check(editor.package.terrain.serialize() == moved_state, "Global Redo restores the confirmed frozen Move")

	editor.show_workflow_editor()
	editor.workflow.select_cells(Vector2i(6, 4), Vector2i(6, 4)); editor._workflow_sync_source_fields(editor.workflow.selection)
	for domain in editor.workflow_domains: editor.workflow_domains[domain].button_pressed = domain == "pathing"
	editor._capture_workflow_clipboard()
	editor._workflow_update_preview("paste", Vector2i(7, 7))
	var pending_before_reset: bool = not editor.workflow_pending_preview.is_empty()
	editor._reset_terrain_session(false)
	_check(pending_before_reset and editor.workflow_pending_preview.is_empty() and editor.world_root.get_node_or_null("WorkflowOverlay") == null, "Package/session reset removes stale preview and ghost state")


func _check_persistence(editor, fixture_path: String) -> void:
	var expected: String = editor.package.terrain.serialize()
	_check(editor.package.save(), "Confirmed T1 result saves through the package transaction")
	editor.open_package(fixture_path)
	var preflight: Dictionary = editor.package.test_world_preflight({"renderer": "godot_4_7_1_forward_plus", "chunk_cells": 32})
	_check(editor.package.terrain.serialize() == expected and editor.package.validate().is_empty() and preflight.ok and preflight.cache.terrain_sha256 == expected.sha256_text(), "Save, Reopen, and Test World preflight preserve the canonical T1 result without schema or runtime changes")


func _screen_for_cell(editor, cell: Vector2i) -> Vector2:
	var grid: Dictionary = editor.package.terrain.data.grid
	var x := float(grid.origin_x_m) + (cell.x + 0.5) * float(grid.cell_size_m)
	var z := float(grid.origin_z_m) + (cell.y + 0.5) * float(grid.cell_size_m)
	return editor.camera.unproject_position(Vector3(x, editor.package.terrain.effective_height(x, z), z))


func _key(keycode: Key, control := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.ctrl_pressed = control
	return event


func _push_window_key(editor, event: InputEventKey) -> void:
	if DisplayServer.get_name() == "headless": editor._on_workflow_window_input(event)
	else: editor.workflow_dialog.push_input(event)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("T1_PASS|", message)
	else:
		failures.append(message)
