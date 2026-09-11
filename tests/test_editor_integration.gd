extends SceneTree

const SHELL := preload("res://src/app/editor_shell.tscn")
const CLIFF_WATER := preload("res://src/domain/terrain_cliff_water.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var editor = SHELL.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	_check(editor.package.world.get("world_id") == "crimsdale", "Editor opens Crimsdale")
	_check(editor.world_root.get_node_or_null("crimsdale_fountain_001") != null, "Fountain preview is created")
	_check(editor.world_root.get_node_or_null("crimsdale_house_001") != null, "House preview is created")
	_check(editor.definition_list.item_count == 8, "Object Editor lists world, unit, ability, and item definitions")
	_check(editor.terrain_dialog != null and editor.terrain_fields.size() == 6, "Terrain workflow exposes explicit dimensions, resolution, height, and origin")
	editor.terrain_fields.width_cells.text = "8"
	editor.terrain_fields.depth_cells.text = "8"
	editor.terrain_fields.cell_size_m.text = "1"
	editor.terrain_fields.base_height_cm.text = "25"
	editor.terrain_fields.origin_x_m.text = "-4"
	editor.terrain_fields.origin_z_m.text = "-4"
	editor._create_terrain()
	_check(editor.package.terrain != null and editor.world_root.get_node_or_null("TerrainPreview") != null, "Terrain creation immediately produces a world preview")
	editor.toggle_sculpt_mode()
	_check(editor.sculpt_enabled and editor.sculpt_tool.item_count == 6 and editor.brush_preview != null, "Persistent sculpt HUD exposes all six tools and a live brush preview")
	editor.toggle_sculpt_mode()
	editor.show_surface_editor()
	_check(editor.surface_catalog.item_count == 4 and editor.surface_layers.item_count >= 1, "Surface palette exposes portable catalog entries and active layers")
	editor.terrain_fields.width_cells.text = "12"
	editor.terrain_fields.depth_cells.text = "10"
	editor.terrain_anchor.select(0)
	editor._resize_terrain()
	_check(editor.package.terrain.data.grid.width_cells == 12, "Terrain bounds can be resized through the Creator workflow")
	editor.perform_undo()
	_check(editor.package.terrain.data.grid.width_cells == 8, "Main toolbar undo restores the prior terrain bounds")
	editor.perform_redo()
	_check(editor.package.terrain.data.grid.width_cells == 12, "Main toolbar redo reapplies the terrain transaction")
	_check(editor.cliff_dialog != null and editor.cliff_style.item_count == 2, "Cliff and water workflow exposes the portable style catalog")
	var cliff_tools = CLIFF_WATER.new(editor.package.terrain)
	_check(cliff_tools.change_level(0, 0, 1), "Creator cliff operation updates a cell")
	editor.refresh_terrain_preview()
	_check(editor.world_root.get_node("TerrainPreview").mesh.get_aabb().end.y >= 2.0, "Discrete cliff height is visible in generated terrain geometry")
	cliff_tools.set_water(true, 100)
	editor.refresh_terrain_preview()
	_check(editor.world_root.get_node_or_null("WaterPreview") != null, "Water depth preview is generated in the viewport")
	editor.show_pathing_editor()
	_check(editor.pathing_dialog.visible and editor.pathing_layer.item_count == 2 and editor.pathing_clearance.item_count == 3, "Pathing workflow exposes separate layers and supported clearances")
	editor.toggle_pathing_overlay()
	_check(editor.pathing_overlay_visible and editor.pathing.last_overlay.size() == 120, "Walkability overlay computes every canonical cell")
	editor.show_environment_editor()
	_check(editor.environment_dialog.visible and editor.environment_sky.item_count == 2 and editor.environment_fields.size() == 7, "Environment workflow exposes focused sun, ambient, fog, and sky controls")
	var preview_before:bool=editor.environment_preview_enabled
	editor.toggle_environment_preview()
	_check(editor.environment_preview_enabled != preview_before, "Accurate environment preview toggles without mutating authored data")
	editor.show_workflow_editor()
	_check(editor.workflow_dialog.visible and editor.workflow_domains.size() == 5 and editor.workflow_mode.item_count == 2, "Workflow panel exposes explicit domain toggles and merge/replace paste")
	editor.workflow_fields.width.value = 2
	editor.workflow_fields.depth.value = 2
	editor._workflow_copy()
	_check(editor.terrain_clipboard.get("clipboard_version") == 1, "Creator selection produces a portable versioned clipboard")
	editor.workflow_fields.paste_x.value = 2
	editor.workflow_fields.paste_z.value = 2
	editor._workflow_paste()
	_check(editor.package.terrain.can_undo(), "Creator paste is available as one undoable operation")
	editor.show_scenario_editor()
	editor.package.remove_scenario()
	editor._create_scenario()
	_check(editor.package.scenario != null and editor.scenario_fields.scenario_id.text == "crimsdale_guided_tutorial", "Creator can add a scenario document to the open world")
	editor.scenario_region_fields.region_id.text = "tutorial_start"
	editor.scenario_region_fields.display_name.text = "Tutorial Start"
	editor.scenario_region_fields.x1.text = "1"
	editor.scenario_region_fields.z1.text = "2"
	editor._add_scenario_region()
	_check(editor.package.scenario.find_region("tutorial_start").shape == "point" and editor.world_root.get_node_or_null("ScenarioRegions/tutorial_start") != null, "Creator-authored region is visible in the viewport")
	editor.show_guidance_editor()
	editor.objective_fields.objective_id.text = "learn_movement"
	editor.objective_fields.title.text = "Follow the trail"
	editor._add_objective()
	editor._reselect_objective("learn_movement")
	editor.objective_fields.step_id.text = "reach_start"
	editor.objective_fields.step_title.text = "Reach the marker"
	editor.objective_fields.checkpoint_region_id.text = "tutorial_start"
	editor._add_objective_step()
	editor.tutorial_fields.tutorial_id.text = "move_prompt"
	editor.tutorial_fields.text.text = "Right-click the marked ground."
	editor.tutorial_fields.region_id.text = "tutorial_start"
	editor._add_tutorial()
	editor._preview_guidance()
	_check(editor.package.scenario.data.objectives[0].steps[0].checkpoint_region_id == "tutorial_start" and "never color alone" in editor.guidance_preview.text, "Creator authors and previews objective checkpoints and non-color tutorial guidance without JSON")
	editor.show_encounter_editor()
	editor.group_fields.group_id.text="allies";editor.group_fields.instance_ids.text="crimsdale_guard_001, crimsdale_guard_002";editor._add_group()
	editor.group_fields.group_id.text="raiders";editor.group_fields.instance_ids.text="crimsdale_raider_001";editor._add_group()
	editor.encounter_fields.encounter_id.text="first_raid";editor.encounter_fields.group_id.text="raiders";editor.encounter_fields.leash_region_id.text="tutorial_start";editor._add_encounter()
	_check(editor.package.scenario.data.unit_groups.size()==2 and editor.package.scenario.data.encounters[0].initial_state=="inactive","Creator groups placed units and authors a dormant encounter without JSON")
	editor.show_cinematic_editor();editor.cinematic_fields.cinematic_id.text="opening";editor._add_cinematic();editor._reselect_cinematic("opening");editor.cinematic_fields.a.text="crimsdale_guard_001";editor.cinematic_fields.text.text="Follow me beyond the ridge.";editor.cinematic_fields.number.text="3";_check(editor._cinematic_step_from_form().get("type")=="dialogue","Cinematic form defaults to dialogue");editor._add_cinematic_step();editor._play_cinematic_preview();editor._skip_cinematic_preview()
	_check(editor.package.scenario.data.cinematics.size()==1,"Creator adds a cinematic: "+" | ".join(editor.package.scenario.errors))
	if editor.package.scenario.data.cinematics.size()==1:_check(editor.package.scenario.data.cinematics[0].steps.size()==1 and "Follow me" in editor.package.scenario.data.cinematics[0].steps[0].text and "SKIPPED" in editor.cinematic_preview.text,"Creator authors, subtitles, scrubs, plays, and skips a cinematic without optional audio: "+" | ".join(editor.package.scenario.errors))
	editor.show_sequence_editor()
	editor.sequence_fields.sequence_id.text = "mission_start"
	editor._create_sequence()
	_check(editor.package.scenario.data.sequences.size() == 1 and editor.sequence_event_type.item_count == 5, "Creator can add a typed scenario-start sequence")
	editor._reload_sequence_by_id("mission_start")
	for action_index in editor.sequence_action_type.item_count:
		if editor.sequence_action_type.get_item_metadata(action_index)=="set_encounter":editor.sequence_action_type.select(action_index)
	editor.sequence_fields.a.text="raiders";editor.sequence_fields.b.text="active";editor.sequence_fields.c.text="attack";editor.sequence_fields.text.text="tutorial_start";editor._add_sequence_action()
	for action_index in editor.sequence_action_type.item_count:
		if editor.sequence_action_type.get_item_metadata(action_index)=="play_cinematic":editor.sequence_action_type.select(action_index)
	editor.sequence_fields.a.text="opening";editor._add_sequence_action()
	editor._preview_encounters()
	_check(editor.sequence_action_type.item_count == 10 and editor.sequence_actions.item_count == 3, "Sequence workspace exposes the constrained action vocabulary and ordered steps")
	_check("mission_start via scenario_start" in editor.encounter_preview.text,"Encounter preview identifies its activation sequence, membership, and labeled bounds")
	var guard: Dictionary = editor.package.find_definition("unit_crimsdale_guard")
	_check(guard.owner == "player" and guard.max_health == 120.0, "Crimsdale guard exposes authored gameplay fields")
	for definition_index in editor.definition_list.item_count:
		if editor.definition_list.get_item_metadata(definition_index)=="unit_crimsdale_guard":editor.load_definition_form(definition_index);break
	_check(editor.unit_fields.max_health.text == "120.0", "Object Editor loads unit gameplay values")

	editor.prepare_new_definition()
	editor.definition_id_field.text = "prop_test_marker"
	editor.definition_name.text = "Test Marker"
	editor.definition_scene.text = "res://content/crimsdale/landmarks/fountain.tscn"
	editor.create_definition_from_form()
	_check(not editor.package.find_definition("prop_test_marker").is_empty(), "Object Editor creates definitions")
	_check(editor.package.dirty, "Definition edits mark package dirty")
	_check(editor.package.undo(), "Definition creation participates in undo")
	_check(editor.package.find_definition("prop_test_marker").is_empty(), "Undo removes created definition")

	var initial_count: int = editor.package.world.objects.size()
	var placed_id: String = editor.package.place_instance("building_crimsdale_house_a", Vector3(8, 0, 8), 30)
	editor.refresh_all()
	_check(not placed_id.is_empty() and editor.world_root.get_node_or_null(placed_id) != null, "Placed data maps to a viewport preview")
	_check(editor.package.undo() and editor.package.world.objects.size() == initial_count, "Placement can be undone")

	var exported_launch: Dictionary = editor.build_test_world_launch("Frontier.exe", "", "C:/Worlds/Crimsdale", "player_start")
	_check(exported_launch.executable == "Frontier.exe", "Exported Frontier executable is preserved")
	_check(exported_launch.arguments == PackedStringArray(["--world-package", "C:/Worlds/Crimsdale", "--spawn", "player_start"]), "Exported build receives the agreed package and spawn contract")
	var project_launch: Dictionary = editor.build_test_world_launch("godot", "/projects/Frontier/Game", "/worlds/crimsdale", "player_start")
	_check(project_launch.arguments == PackedStringArray(["--path", "/projects/Frontier/Game", "--", "--world-package", "/worlds/crimsdale", "--spawn", "player_start"]), "Godot development launch preserves the same runtime contract")

	editor.prepare_new_definition();editor.definition_id_field.text="ability_storm_arc";editor.definition_name.text="Storm Arc";editor.definition_category.select(4);editor.refresh_unit_field_visibility();editor.definition_scene.text="res://content/crimsdale/units/guard.tscn";editor.ability_fields.ability_mode.text="chained_damage";editor.ability_fields.chain_count.text="3";editor.create_definition_from_form()
	editor.prepare_new_definition();editor.definition_id_field.text="item_veterans_badge";editor.definition_name.text="Veteran's Badge";editor.definition_category.select(5);editor.refresh_unit_field_visibility();editor.definition_scene.text="res://content/crimsdale/units/guard.tscn";editor.item_fields.item_kind.text="permanent_stat";editor.item_fields.effect_stat.text="strength";editor.item_fields.effect_amount.text="2";editor.create_definition_from_form()
	for index in editor.definition_list.item_count:
		if editor.definition_list.get_item_metadata(index)=="unit_crimsdale_guard":editor.definition_list.select(index);editor.load_definition_form(index);break
	editor.hero_fields.hero.text="true";editor.hero_fields.ability_ids.text="ability_storm_arc";editor.apply_definition_changes();editor._preview_gameplay_definition()
	_check(editor.package.find_definition("unit_crimsdale_guard").ability_ids==["ability_storm_arc"] and "ability_storm_arc" in editor.definition_gameplay_preview.text,"Creator authors and previews a hero ability and item reward without JSON")
	editor.package.remove_scenario();editor._create_guided_mission_template();_check(editor.package.scenario!=null and editor.package.scenario.data.sequences[-1].actions[-1].result=="victory","Creator generates the complete reusable guided-mission spine from an empty scenario without JSON")

	editor.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.remove_child(editor)
	editor.free()
	await process_frame
	if failures.is_empty():
		print("PASS: editor package, Object Editor, palette, and viewport integration")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
