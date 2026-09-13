extends Control

const WorldPackageScript = preload("res://src/domain/world_package.gd")
const TerrainSculptorScript = preload("res://src/domain/terrain_sculptor.gd")
const TerrainSurfacePainterScript = preload("res://src/domain/terrain_surface_painter.gd")
const TerrainCliffWaterScript = preload("res://src/domain/terrain_cliff_water.gd")
const TerrainPathingScript = preload("res://src/domain/terrain_pathing.gd")
const TerrainEnvironmentScript = preload("res://src/domain/terrain_environment.gd")
const TerrainWorkflowScript = preload("res://src/domain/terrain_workflow.gd")
const WorkflowInputGuardScript=preload("res://src/app/workflow_input_guard.gd")
const ScenarioDocumentScript = preload("res://src/domain/scenario_document.gd")
const DEFAULT_PACKAGE := "res://worlds/crimsdale"

var package = WorldPackageScript.new()
var selected_instance_id := ""
var placement_definition_id := ""
var placement_rotation := 0.0
var camera: Camera3D
var world_root: Node3D
var viewport: SubViewport
var viewport_container: SubViewportContainer
var status_label: Label
var dirty_label: Label
var terrain_mode_label: Label
var inspector_content: VBoxContainer
var palette_content: VBoxContainer
var palette_panel: PanelContainer
var palette_page: OptionButton
var palette_summary: Label
var palette_body: VBoxContainer
var palette_collapse_button: Button
var palette_dock_button: Button
var palette_resize_handle: Button
var palette_side := "left"
var palette_width := 240
var palette_collapsed := false
var palette_last_page := "Units"
var placement_ghost: MeshInstance3D
var object_dialog: Window
var unsaved_dialog: ConfirmationDialog
var package_dialog: FileDialog
var error_dialog: AcceptDialog
var terrain_dialog: Window
var terrain_confirmation: ConfirmationDialog
var terrain_fields: Dictionary = {}
var terrain_anchor: OptionButton
var pending_terrain_action: Callable
var sculptor
var sculpt_enabled := false
var sculpt_tool: OptionButton
var sculpt_radius: SpinBox
var sculpt_strength: SpinBox
var sculpt_falloff: OptionButton
var sculpt_target: SpinBox
var sculpt_seed: SpinBox
var sculpt_sample_target: CheckBox
var brush_preview: MeshInstance3D
var surface_dialog: Window
var surface_confirmation: ConfirmationDialog
var surface_catalog: OptionButton
var surface_layers: OptionButton
var surface_enabled := false
var surface_painter
var surface_radius: SpinBox
var surface_opacity: SpinBox
var surface_falloff: OptionButton
var surface_erase: CheckBox
var cliff_dialog: Window
var cliff_style: OptionButton
var cliff_water_enabled: CheckBox
var cliff_water_level: SpinBox
var cliff_mode := ""
var cliff_ramp_direction: OptionButton
var cliff_dialog_terrain
var pathing_dialog: Window
var pathing_layer: OptionButton
var pathing_radius: SpinBox
var pathing_blocked: CheckBox
var pathing_clearance: OptionButton
var pathing_enabled:=false
var pathing_overlay_visible:=false
var pathing
var environment_dialog:Window
var environment_fields:Dictionary={}
var environment_colors:Dictionary={}
var environment_sky:OptionButton
var environment_fog_enabled:CheckBox
var environment_preview_enabled:=true
var workflow_dialog: Window
var workflow_fields: Dictionary = {}
var workflow_domains: Dictionary = {}
var workflow_mode: OptionButton
var workflow_preview_label: RichTextLabel
var workflow_confirm_button: Button
var workflow_cancel_button: Button
var workflow
var terrain_clipboard: Dictionary = {}
var workflow_pending_preview: Dictionary = {}
var workflow_select_armed := false
var workflow_dragging := false
var workflow_drag_start := Vector2i.ZERO
var workflow_selection_before_gesture := Rect2i()
var workflow_sampling := false
var workflow_syncing_fields := false
var terrain_tool_mode := "selection"
var global_undo_domains: Array[Dictionary] = []
var global_redo_domains: Array[Dictionary] = []
var tracked_history_depths: Dictionary = {}
var known_history_transaction_ids:Dictionary={}
var history_tracking_ready := false
var history_tracking_suspended := false
var scenario_dialog: Window
var scenario_fields: Dictionary = {}
var scenario_region_list: ItemList
var scenario_region_shape: OptionButton
var scenario_region_fields: Dictionary = {}
var scenario_remove_confirmation: ConfirmationDialog
var scenario_remove_armed := false
var sequence_dialog: Window
var sequence_list: ItemList
var sequence_fields: Dictionary = {}
var sequence_event_type: OptionButton
var sequence_condition_type: OptionButton
var sequence_action_type: OptionButton
var sequence_conditions: ItemList
var sequence_actions: ItemList
var sequence_signature: Label
var guidance_dialog: Window
var objective_list: ItemList
var objective_step_list: ItemList
var objective_fields: Dictionary = {}
var tutorial_list: ItemList
var tutorial_fields: Dictionary = {}
var guidance_preview: RichTextLabel
var encounter_dialog:Window
var group_list:ItemList
var group_fields:Dictionary={}
var encounter_list:ItemList
var encounter_fields:Dictionary={}
var encounter_preview:RichTextLabel
var cinematic_dialog:Window
var cinematic_list:ItemList
var cinematic_step_list:ItemList
var cinematic_fields:Dictionary={}
var cinematic_field_rows:Dictionary={}
var cinematic_field_labels:Dictionary={}
var cinematic_step_type:OptionButton
var cinematic_preview:RichTextLabel
var validation_dialog:Window
var validation_summary:Label
var validation_list:ItemList
var test_world_setup_dialog:Window
var test_world_executable_field:LineEdit
var test_world_project_field:LineEdit
var test_world_executable_dialog:FileDialog
var test_world_project_dialog:FileDialog
var test_world_use_values_button:Button
var cinematic_update_step_button:Button
var cinematic_play_preview_button:Button
var pending_after_save: Callable
var definition_list: ItemList
var definition_id_field: LineEdit
var definition_name: LineEdit
var definition_category: OptionButton
var definition_scene: LineEdit
var definition_owner: OptionButton
var unit_fields: Dictionary = {}
var unit_section_controls: Array[Control] = []
var hero_fields:Dictionary={}
var hero_section_controls:Array[Control]=[]
var ability_fields:Dictionary={}
var ability_section_controls:Array[Control]=[]
var item_fields:Dictionary={}
var item_section_controls:Array[Control]=[]
var definition_gameplay_preview:RichTextLabel
var mouse_position := Vector2.ZERO
var creating_definition := false
var moving_instance := false
var orbit_yaw := 0.65
var orbit_pitch := -0.75
var orbit_distance := 26.0
var orbit_target := Vector3.ZERO


func _ready() -> void:
	_build_toolbar()
	_build_status_bar()
	_build_palette_shell()
	inspector_content = $Workspace/Inspector/Content
	_build_viewport()
	_build_sculpt_hud()
	_build_surface_editor()
	_build_cliff_water_editor()
	_build_pathing_editor()
	_build_environment_editor()
	_build_workflow_editor()
	_build_scenario_editor()
	_build_sequence_editor()
	_build_guidance_editor()
	_build_encounter_editor()
	_build_cinematic_editor()
	_build_validation_results()
	_build_test_world_setup()
	_build_object_editor()
	_build_terrain_editor()
	_build_package_dialogs()
	if not package.load_from_directory(DEFAULT_PACKAGE):
		show_errors()
	else:
		_reset_terrain_session(true)
		var resource_failures: Array[String] = package.resource_errors()
		status("Opened Crimsdale" if resource_failures.is_empty() else " | ".join(resource_failures))
	refresh_all()


func _build_palette_shell() -> void:
	palette_panel = $Workspace/Palette
	var root_content: VBoxContainer = $Workspace/Palette/Content
	for child in root_content.get_children():
		child.free()
	var title := Label.new()
	title.name = "Title"
	title.text = "CREATOR PALETTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	root_content.add_child(title)
	var header := HBoxContainer.new()
	header.name = "PaletteHeader"
	root_content.add_child(header)
	palette_page = OptionButton.new()
	palette_page.name = "Page"
	palette_page.accessibility_name = "Creator palette page"
	palette_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for page_name in ["Terrain", "Units", "Props", "Regions", "Mission"]:
		palette_page.add_item(page_name)
	header.add_child(palette_page)
	palette_dock_button = _add_button(header, "Dock ⇄", _toggle_palette_side)
	palette_dock_button.accessibility_name = "Dock Creator palette on the opposite side"
	palette_collapse_button = _add_button(header, "Collapse", _toggle_palette_collapsed)
	palette_collapse_button.accessibility_name = "Collapse Creator palette"
	palette_summary = Label.new()
	palette_summary.name = "ActiveSummary"
	palette_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	palette_summary.accessibility_name = "Active Creator tool summary"
	root_content.add_child(palette_summary)
	palette_body = VBoxContainer.new()
	palette_body.name = "PageContent"
	palette_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_content.add_child(palette_body)
	palette_content = palette_body
	palette_resize_handle = Button.new()
	palette_resize_handle.name = "ResizeHandle"
	palette_resize_handle.text = "↔ Drag to resize"
	palette_resize_handle.flat = true
	palette_resize_handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	palette_resize_handle.accessibility_name = "Resize Creator palette"
	palette_resize_handle.gui_input.connect(_on_palette_resize_input)
	root_content.add_child(palette_resize_handle)
	_load_palette_preferences()
	palette_page.select(maxi(0, ["Terrain", "Units", "Props", "Regions", "Mission"].find(palette_last_page)))
	palette_page.item_selected.connect(_select_palette_page)
	_apply_palette_layout()


func _load_palette_preferences() -> void:
	var config := ConfigFile.new()
	if config.load("user://frontier_world_editor_ui.cfg") != OK:
		return
	palette_side = str(config.get_value("palette", "side", "left"))
	if palette_side not in ["left", "right"]: palette_side = "left"
	palette_width = clampi(int(config.get_value("palette", "width", 240)), 180, 420)
	palette_collapsed = bool(config.get_value("palette", "collapsed", false))
	palette_last_page = str(config.get_value("palette", "last_page", "Units"))
	if palette_last_page not in ["Terrain", "Units", "Props", "Regions", "Mission"]: palette_last_page = "Units"


func _save_palette_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("palette", "side", palette_side)
	config.set_value("palette", "width", palette_width)
	config.set_value("palette", "collapsed", palette_collapsed)
	config.set_value("palette", "last_page", palette_last_page)
	config.save("user://frontier_world_editor_ui.cfg")


func _apply_palette_layout() -> void:
	var workspace := get_node("Workspace")
	workspace.move_child(palette_panel, 0 if palette_side == "left" else workspace.get_child_count() - 1)
	palette_panel.custom_minimum_size.x = 42 if palette_collapsed else palette_width
	palette_page.visible = not palette_collapsed
	palette_dock_button.visible = not palette_collapsed
	palette_summary.visible = not palette_collapsed
	palette_body.visible = not palette_collapsed
	palette_resize_handle.visible = not palette_collapsed
	palette_collapse_button.text = "Expand" if palette_collapsed else "Collapse"
	palette_collapse_button.accessibility_name = "%s Creator palette" % ("Expand" if palette_collapsed else "Collapse")
	refresh_palette()


func _toggle_palette_side() -> void:
	palette_side = "right" if palette_side == "left" else "left"
	_apply_palette_layout()
	_save_palette_preferences()
	status("Creator palette docked %s" % palette_side)


func _toggle_palette_collapsed() -> void:
	palette_collapsed = not palette_collapsed
	_apply_palette_layout()
	_save_palette_preferences()
	status("Creator palette %s" % ("collapsed" if palette_collapsed else "expanded"))


func _on_palette_resize_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		palette_width = clampi(palette_width + roundi(event.relative.x) * (1 if palette_side == "left" else -1), 180, 420)
		palette_panel.custom_minimum_size.x = palette_width
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_save_palette_preferences()
		status("Creator palette width: %d px" % palette_width)


func _select_palette_page(index: int) -> void:
	palette_last_page = palette_page.get_item_text(index)
	_save_palette_preferences()
	refresh_palette()
	status("Creator palette: %s" % palette_last_page)


func refresh_palette_summary() -> void:
	if palette_summary == null:
		return
	var texture := "logical surface"
	if surface_layers != null and surface_layers.item_count > 0:
		texture = surface_layers.get_item_text(maxi(0, surface_layers.selected))
	var brush := "none"
	if sculpt_enabled and sculpt_radius != null: brush = "circle, %.1f m" % sculpt_radius.value
	elif surface_enabled and surface_radius != null: brush = "circle, %.1f m" % surface_radius.value
	elif pathing_enabled and pathing_radius != null: brush = "circle, %.1f m" % pathing_radius.value
	elif terrain_tool_mode == "workflow" and workflow != null and workflow.selection.get_area() > 0: brush = "%d × %d cells" % [workflow.selection.size.x, workflow.selection.size.y]
	palette_summary.text = "Page: %s\nTool: %s\nTexture: %s\nBrush/shape: %s" % [palette_last_page, _terrain_tool_display_name(terrain_tool_mode), texture, brush]


func _build_toolbar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "Toolbar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 12
	bar.offset_top = 10
	bar.offset_right = -12
	bar.offset_bottom = 46
	bar.add_theme_constant_override("separation",1)
	add_child(bar)
	_add_button(bar, "World", return_to_world_selection)
	_add_button(bar, "Open", request_open_package)
	_add_button(bar, "Object Editor", show_object_editor)
	_add_button(bar, "Terrain", show_terrain_editor)
	_add_button(bar, "Sculpt", toggle_sculpt_mode)
	_add_button(bar, "Surfaces", show_surface_editor)
	_add_button(bar, "Cliffs & Water", show_cliff_water_editor)
	_add_button(bar, "Pathing", show_pathing_editor)
	_add_button(bar, "Environment", show_environment_editor)
	_add_button(bar, "Workflow", show_workflow_editor)
	_add_button(bar, "Scenario", show_scenario_editor)
	bar.add_spacer(false)
	_add_button(bar, "Undo", perform_undo)
	_add_button(bar, "Redo", perform_redo)
	_add_button(bar, "Save", save_package)
	_add_button(bar, "Test Setup…", show_test_world_setup)
	_add_button(bar, "Test World ▶", test_world)


func _build_status_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "StatusBar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 12
	bar.offset_top = -32
	bar.offset_right = -12
	bar.offset_bottom = -8
	add_child(bar)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(status_label)
	terrain_mode_label = Label.new()
	terrain_mode_label.text = "Mode: Selection"
	terrain_mode_label.accessibility_name = "Active editor mode"
	bar.add_child(terrain_mode_label)
	dirty_label = Label.new()
	bar.add_child(dirty_label)


func _build_viewport() -> void:
	var content: VBoxContainer = $Workspace/Viewport/Content
	content.get_node("EmptyState").queue_free()
	viewport_container = SubViewportContainer.new()
	viewport_container.name = "WorldView"
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	viewport_container.focus_mode = Control.FOCUS_ALL
	viewport_container.gui_input.connect(_on_viewport_input)
	content.add_child(viewport_container)
	viewport = SubViewport.new()
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	world_root = Node3D.new()
	world_root.name = "AuthoredWorld"
	viewport.add_child(world_root)
	if DisplayServer.get_name() == "headless":
		camera = Camera3D.new()
		world_root.add_child(camera)
		update_camera()
		return
	var environment := WorldEnvironment.new()
	environment.name = "EnvironmentPreview"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("222936")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a5b1c2")
	env.ambient_light_energy = 0.55
	environment.environment = env
	environment.set_meta("preview_environment",env)
	world_root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.name = "SunPreview"
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.shadow_enabled = true
	world_root.add_child(light)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 2
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100, 100)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("354238")
	ground_material.roughness = 1.0
	plane.material = ground_material
	ground_mesh.mesh = plane
	ground.add_child(ground_mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 0.1, 100)
	shape.shape = box
	shape.position.y = -0.05
	ground.add_child(shape)
	world_root.add_child(ground)
	camera = Camera3D.new()
	camera.current = true
	world_root.add_child(camera)
	update_camera()


func _build_sculpt_hud() -> void:
	var hud := HFlowContainer.new()
	hud.name = "SculptHUD"
	hud.visible = false
	$Workspace/Viewport/Content.add_child(hud)
	$Workspace/Viewport/Content.move_child(hud, 0)
	var label := Label.new()
	label.text = "SCULPT"
	hud.add_child(label)
	sculpt_tool = OptionButton.new()
	for name in TerrainSculptorScript.TOOLS:
		sculpt_tool.add_item(name.capitalize())
		sculpt_tool.set_item_metadata(sculpt_tool.item_count - 1, name)
	hud.add_child(sculpt_tool)
	sculpt_radius = _hud_spin(hud, "Radius m", 1.0, 64.0, 3.0, 0.5)
	sculpt_strength = _hud_spin(hud, "Strength", 0.0, 1000.0, 20.0, 1.0)
	sculpt_falloff = OptionButton.new()
	for name in TerrainSculptorScript.FALLOFFS:
		sculpt_falloff.add_item(name.capitalize())
		sculpt_falloff.set_item_metadata(sculpt_falloff.item_count - 1, name)
	sculpt_falloff.select(2)
	hud.add_child(sculpt_falloff)
	sculpt_target = _hud_spin(hud, "Target cm", -32768.0, 32767.0, 0.0, 1.0)
	sculpt_sample_target = CheckBox.new()
	sculpt_sample_target.text = "Sample target"
	hud.add_child(sculpt_sample_target)
	sculpt_seed = _hud_spin(hud, "Seed", -2147483648.0, 2147483647.0, 1.0, 1.0)
	var help := Label.new()
	help.text = "1–6 tools · drag to sculpt · Esc cancels"
	hud.add_child(help)


func _hud_spin(parent: Control, title: String, minimum: float, maximum: float, initial: float, step: float) -> SpinBox:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = initial
	spin.custom_minimum_size.x = 80
	parent.add_child(spin)
	return spin


func toggle_sculpt_mode() -> void:
	if package.terrain == null:
		show_blocking_error("Create terrain before sculpting it.")
		return
	if sculpt_enabled:
		_set_terrain_tool("selection", "Selection tool")
	else:
		_set_terrain_tool("sculpt", "Sculpt mode: drag on terrain; keys 1–6 select tools; Escape returns to Selection")


func _make_brush_preview() -> void:
	brush_preview = MeshInstance3D.new()
	brush_preview.name = "TerrainBrushPreview"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.025
	disc.radial_segments = 48
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.85, 0.45, 0.28)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material = material
	brush_preview.mesh = disc
	world_root.add_child(brush_preview)
	_update_brush_preview(mouse_position)


func _update_brush_preview(screen_position: Vector2) -> void:
	if brush_preview == null:
		return
	var point := ground_position(screen_position)
	point.y = package.terrain.effective_height(point.x, point.z) + 0.03
	brush_preview.position = point
	var radius := surface_radius.value if surface_enabled else sculpt_radius.value
	brush_preview.scale = Vector3(radius, 1.0, radius)


func _sculpt_parameters() -> Dictionary:
	var parameters := {"radius_m": sculpt_radius.value, "strength": sculpt_strength.value, "falloff": sculpt_falloff.get_item_metadata(sculpt_falloff.selected), "noise_seed": roundi(sculpt_seed.value)}
	if not sculpt_sample_target.button_pressed:
		parameters.target_height_cm = roundi(sculpt_target.value)
	return parameters


func cancel_sculpt_stroke() -> void:
	if sculptor != null and sculptor.active:
		sculptor.cancel()
		refresh_terrain_preview()
		status("Sculpt stroke cancelled")


func return_to_world_selection() -> void:
	moving_instance = false
	_set_terrain_tool("selection", "World workspace — Selection tool")


func _set_terrain_tool(mode: String, message := "") -> void:
	if sculptor != null and sculptor.active:
		sculptor.cancel()
		refresh_terrain_preview()
	if surface_painter != null and surface_painter.active:
		surface_painter.cancel()
		refresh_terrain_preview()
	if pathing != null and pathing.painting:
		pathing.cancel_paint()
	cancel_placement()
	moving_instance = false
	if workflow_dialog != null and mode != "workflow":
		workflow_dialog.hide()
		_clear_workflow_gesture(true)
	terrain_tool_mode = mode
	sculpt_enabled = mode == "sculpt"
	surface_enabled = mode == "surface"
	pathing_enabled = mode == "pathing"
	cliff_mode = mode.trim_prefix("cliff_") if mode.begins_with("cliff_") else ""
	$Workspace/Viewport/Content/SculptHUD.visible = sculpt_enabled
	$Workspace/Viewport/Content/SurfaceHUD.visible = surface_enabled
	$Workspace/Viewport/Content/PathingHUD.visible = pathing_enabled
	if sculpt_enabled:
		sculptor = TerrainSculptorScript.new(package.terrain)
	elif surface_enabled:
		surface_painter = TerrainSurfacePainterScript.new(package.terrain)
	if sculpt_enabled or surface_enabled:
		if brush_preview == null:
			_make_brush_preview()
	elif brush_preview != null:
		brush_preview.queue_free()
		brush_preview = null
	if pathing_enabled:
		if pathing == null:
			pathing = TerrainPathingScript.new(package.terrain)
		pathing_overlay_visible = true
		pathing.reset_cancellation()
		pathing.rebuild_overlay(pathing_layer.get_item_metadata(pathing_layer.selected))
	else:
		pathing_overlay_visible = false
	refresh_pathing_overlay()
	if terrain_mode_label != null:
		terrain_mode_label.text = "Mode: %s" % _terrain_tool_display_name(mode)
	if not message.is_empty():
		status(message)
	refresh_palette_summary()


func _terrain_tool_display_name(mode: String) -> String:
	match mode:
		"sculpt": return "Sculpt"
		"surface": return "Surface Paint"
		"pathing": return "Pathing Paint"
		"workflow": return "Workflow"
		"placement": return "Placement"
		"move": return "Move"
		"cliff_raise": return "Raise Cliff"
		"cliff_lower": return "Lower Cliff"
		"cliff_ramp": return "Author Ramp"
		_: return "Selection"


func _reset_terrain_session(reset_history: bool, close_package_dialogs := false) -> void:
	moving_instance = false
	_cancel_pending_terrain_actions()
	_set_terrain_tool("selection", "Selection tool")
	terrain_clipboard.clear()
	_clear_workflow_gesture(true)
	sculptor = TerrainSculptorScript.new(package.terrain) if package.terrain != null else null
	surface_painter = TerrainSurfacePainterScript.new(package.terrain) if package.terrain != null else null
	pathing = TerrainPathingScript.new(package.terrain) if package.terrain != null else null
	workflow = TerrainWorkflowScript.new(package.terrain) if package.terrain != null else null
	cliff_dialog_terrain = null
	pathing_overlay_visible = false
	refresh_pathing_overlay()
	pending_terrain_action = Callable()
	if reset_history:
		_reset_global_history_tracking()
	if close_package_dialogs:
		_close_package_bound_dialogs()


func _cancel_pending_terrain_actions()->void:
	pending_terrain_action=Callable()
	if terrain_confirmation!=null:terrain_confirmation.hide()
	if surface_confirmation!=null:
		surface_confirmation.hide()
		for connection in surface_confirmation.confirmed.get_connections():
			surface_confirmation.confirmed.disconnect(connection.callable)
	scenario_remove_armed = false
	if scenario_remove_confirmation != null: scenario_remove_confirmation.hide()
	for dialog in [terrain_dialog, surface_dialog, cliff_dialog, pathing_dialog, environment_dialog, workflow_dialog]:
		if dialog != null: dialog.hide()


func _close_package_bound_dialogs() -> void:
	for dialog in [object_dialog, scenario_dialog, sequence_dialog, guidance_dialog, encounter_dialog, cinematic_dialog, validation_dialog]:
		if dialog != null: dialog.hide()


func _build_surface_editor() -> void:
	var hud := HFlowContainer.new()
	hud.name = "SurfaceHUD"
	hud.visible = false
	$Workspace/Viewport/Content.add_child(hud)
	$Workspace/Viewport/Content.move_child(hud, 1)
	var title := Label.new()
	title.text = "SURFACE PAINT"
	hud.add_child(title)
	surface_radius = _hud_spin(hud, "Radius m", 1.0, 64.0, 3.0, 0.5)
	surface_opacity = _hud_spin(hud, "Opacity", 0.0, 1.0, 0.25, 0.05)
	surface_falloff = OptionButton.new()
	for name in TerrainSurfacePainterScript.FALLOFFS:
		surface_falloff.add_item(name.capitalize())
		surface_falloff.set_item_metadata(surface_falloff.item_count - 1, name)
	surface_falloff.select(2)
	hud.add_child(surface_falloff)
	surface_erase = CheckBox.new()
	surface_erase.text = "Erase to base"
	hud.add_child(surface_erase)

	surface_dialog = Window.new()
	surface_dialog.title = "Terrain Surfaces"
	surface_dialog.size = Vector2i(520, 430)
	surface_dialog.close_requested.connect(surface_dialog.hide)
	surface_dialog.visible = false
	add_child(surface_dialog)
	var form := VBoxContainer.new()
	form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	form.offset_left = 18
	form.offset_top = 18
	form.offset_right = -18
	form.offset_bottom = -18
	surface_dialog.add_child(form)
	var help := Label.new()
	help.text = "Logical surface IDs remain portable between the editor and Frontier. Layer order controls shader order; every cell always totals 255."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(help)
	surface_catalog = OptionButton.new()
	for entry in _load_surface_catalog():
		var icon = load(entry.editor_source_path) if ResourceLoader.exists(entry.editor_source_path) else null
		if icon != null:
			surface_catalog.add_icon_item(icon, "%s — %s" % [entry.display_name, entry.surface_id])
		else:
			surface_catalog.add_item("Missing: %s — %s" % [entry.display_name, entry.surface_id])
		surface_catalog.set_item_metadata(surface_catalog.item_count - 1, entry.surface_id)
	form.add_child(surface_catalog)
	surface_layers = OptionButton.new()
	form.add_child(surface_layers)
	_add_button(form, "Add Catalog Surface", add_surface_layer)
	_add_button(form, "Replace Selected Layer", request_replace_surface_layer)
	_add_button(form, "Move Selected Up", move_surface_layer.bind(-1))
	_add_button(form, "Move Selected Down", move_surface_layer.bind(1))
	_add_button(form, "Remove Selected Layer", request_remove_surface_layer)
	_add_button(form, "Paint Selected Layer", enable_surface_paint)
	surface_confirmation = ConfirmationDialog.new()
	surface_confirmation.title = "Confirm Surface Layer Change"
	add_child(surface_confirmation)


func _load_surface_catalog() -> Array:
	var file := FileAccess.open("res://content/crimsdale/terrain_surfaces.json", FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed.get("surfaces", []) if parsed is Dictionary else []


func show_surface_editor() -> void:
	if package.terrain == null:
		show_blocking_error("Create terrain before editing surfaces.")
		return
	refresh_surface_layers()
	surface_dialog.popup_centered()


func refresh_surface_layers() -> void:
	var selected := surface_layers.selected
	surface_layers.clear()
	for id in package.terrain.data.surfaces.layer_ids:
		surface_layers.add_item(id)
		surface_layers.set_item_metadata(surface_layers.item_count - 1, id)
	if surface_layers.item_count > 0:
		surface_layers.select(clampi(selected, 0, surface_layers.item_count - 1))


func add_surface_layer() -> void:
	var id: String = surface_catalog.get_item_metadata(surface_catalog.selected)
	var painter = TerrainSurfacePainterScript.new(package.terrain)
	if painter.add_layer(id):
		refresh_surface_layers()
		refresh_all()
		status("Added surface layer '%s'" % id)
	else:
		show_blocking_error("That surface is already active or the four-layer limit is reached.")


func request_replace_surface_layer() -> void:
	var index := surface_layers.selected
	var impact = TerrainSurfacePainterScript.new(package.terrain).layer_impact(index)
	surface_confirmation.dialog_text = "Replace '%s'? Its identity changes across %d painted cells; weights are preserved." % [surface_layers.get_item_text(index), impact.cells]
	for connection in surface_confirmation.confirmed.get_connections():
		surface_confirmation.confirmed.disconnect(connection.callable)
	surface_confirmation.confirmed.connect(replace_surface_layer.bind(index), CONNECT_ONE_SHOT)
	surface_confirmation.popup_centered()


func replace_surface_layer(index: int) -> void:
	var id: String = surface_catalog.get_item_metadata(surface_catalog.selected)
	if TerrainSurfacePainterScript.new(package.terrain).replace_layer(index, id):
		refresh_surface_layers()
		refresh_all()


func request_remove_surface_layer() -> void:
	var index := surface_layers.selected
	if index == 0:
		show_blocking_error("The base surface cannot be removed.")
		return
	var impact = TerrainSurfacePainterScript.new(package.terrain).layer_impact(index)
	surface_confirmation.dialog_text = "Remove '%s'? %d painted cells (%d total byte-weight) transfer to the base layer." % [surface_layers.get_item_text(index), impact.cells, impact.total_weight]
	for connection in surface_confirmation.confirmed.get_connections():
		surface_confirmation.confirmed.disconnect(connection.callable)
	surface_confirmation.confirmed.connect(remove_surface_layer.bind(index), CONNECT_ONE_SHOT)
	surface_confirmation.popup_centered()


func remove_surface_layer(index: int) -> void:
	if TerrainSurfacePainterScript.new(package.terrain).remove_layer(index):
		refresh_surface_layers()
		refresh_all()


func move_surface_layer(direction: int) -> void:
	var from := surface_layers.selected
	var to := clampi(from + direction, 0, surface_layers.item_count - 1)
	if from == to:
		return
	var order: Array = package.terrain.data.surfaces.layer_ids.duplicate()
	var id = order.pop_at(from)
	order.insert(to, id)
	if TerrainSurfacePainterScript.new(package.terrain).reorder_layers(order):
		refresh_surface_layers()
		surface_layers.select(to)
		refresh_all()


func enable_surface_paint() -> void:
	_set_terrain_tool("surface", "Surface paint: drag to paint; Escape returns to Selection")
	surface_dialog.hide()


func _build_cliff_water_editor() -> void:
	cliff_dialog = Window.new()
	cliff_dialog.title = "Cliffs & Water"
	cliff_dialog.size = Vector2i(500, 500)
	cliff_dialog.close_requested.connect(cliff_dialog.hide)
	cliff_dialog.visible = false
	add_child(cliff_dialog)
	var form := VBoxContainer.new()
	form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	form.offset_left = 18
	form.offset_top = 18
	form.offset_right = -18
	form.offset_bottom = -18
	cliff_dialog.add_child(form)
	var help := Label.new()
	help.text = "Cliffs change in 2 metre levels. Choose a click tool, then click terrain cells. Ramps explicitly mark traversable cliff edges."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(help)
	cliff_style = OptionButton.new()
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://content/crimsdale/terrain_cliffs.json"))
	for style in catalog.get("styles", []):
		cliff_style.add_item("%s — %s" % [style.display_name, style.style_id])
		cliff_style.set_item_metadata(cliff_style.item_count - 1, style.style_id)
	form.add_child(cliff_style)
	_add_button(form, "Apply Cliff Style", apply_cliff_style)
	_add_button(form, "Raise Cliff Cell", set_cliff_mode.bind("raise"))
	_add_button(form, "Lower Cliff Cell", set_cliff_mode.bind("lower"))
	cliff_ramp_direction = OptionButton.new()
	for direction in ["north", "east", "south", "west"]:
		cliff_ramp_direction.add_item(direction.capitalize())
		cliff_ramp_direction.set_item_metadata(cliff_ramp_direction.item_count - 1, direction)
	form.add_child(cliff_ramp_direction)
	_add_button(form, "Author Traversable Ramp", set_cliff_mode.bind("ramp"))
	cliff_water_enabled = CheckBox.new()
	cliff_water_enabled.text = "Enable global water"
	form.add_child(cliff_water_enabled)
	cliff_water_level = _hud_spin(form, "Water level cm", -32768, 32767, 0, 1)
	_add_button(form, "Apply & Preview Water", apply_water)


func show_cliff_water_editor() -> void:
	if package.terrain == null:
		show_blocking_error("Create terrain before editing cliffs or water.")
		return
	cliff_dialog_terrain = package.terrain
	cliff_water_enabled.button_pressed = package.terrain.data.water.enabled
	cliff_water_level.value = package.terrain.data.water.level_cm
	var style_index := -1
	for index in cliff_style.item_count:
		if cliff_style.get_item_metadata(index) == package.terrain.data.cliffs.style_id:
			style_index = index
	if style_index >= 0: cliff_style.select(style_index)
	cliff_dialog.popup_centered()


func apply_cliff_style() -> void:
	if not _cliff_form_is_current(): return
	if TerrainCliffWaterScript.new(package.terrain).set_style(cliff_style.get_item_metadata(cliff_style.selected)):
		refresh_all()
		status("Cliff style replaced without changing topology")


func set_cliff_mode(mode: String) -> void:
	if not _cliff_form_is_current(): return
	_set_terrain_tool("cliff_" + mode, "%s: click a terrain cell; Escape returns to Selection" % mode.capitalize())
	cliff_dialog.hide()


func apply_water() -> void:
	if not _cliff_form_is_current(): return
	if TerrainCliffWaterScript.new(package.terrain).set_water(cliff_water_enabled.button_pressed, roundi(cliff_water_level.value)):
		refresh_all()
		status("Water preview updated")


func _cliff_form_is_current() -> bool:
	if cliff_dialog_terrain == null or cliff_dialog_terrain != package.terrain or not cliff_dialog.visible:
		status("Cliffs & Water was closed because the world changed; reopen it to edit the current terrain")
		return false
	return true


func apply_cliff_at(screen_position: Vector2) -> void:
	var point := ground_position(screen_position)
	var grid: Dictionary = package.terrain.data.grid
	var x := floori((point.x - float(grid.origin_x_m)) / float(grid.cell_size_m))
	var z := floori((point.z - float(grid.origin_z_m)) / float(grid.cell_size_m))
	var tools = TerrainCliffWaterScript.new(package.terrain)
	var changed := false
	if cliff_mode == "raise": changed = tools.change_level(x, z, 1)
	elif cliff_mode == "lower": changed = tools.change_level(x, z, -1)
	elif cliff_mode == "ramp": changed = tools.add_ramp(x, z, cliff_ramp_direction.get_item_metadata(cliff_ramp_direction.selected))
	if changed:
		refresh_all()
		status("%s applied at cell %d, %d" % [cliff_mode.capitalize(), x, z])
	else:
		package.errors = package.terrain.errors
		show_errors()


func _build_pathing_editor()->void:
	var hud:=HFlowContainer.new();hud.name="PathingHUD";hud.visible=false
	$Workspace/Viewport/Content.add_child(hud);$Workspace/Viewport/Content.move_child(hud,2)
	var title:=Label.new();title.text="PATHING PAINT";hud.add_child(title)
	pathing_layer=OptionButton.new()
	for layer in ["movement","placement"]:pathing_layer.add_item(layer.capitalize());pathing_layer.set_item_metadata(pathing_layer.item_count-1,layer)
	hud.add_child(pathing_layer)
	pathing_radius=_hud_spin(hud,"Radius m",0.5,16,1,0.5)
	pathing_blocked=CheckBox.new();pathing_blocked.text="Block (off = erase to inherit)";pathing_blocked.button_pressed=true;hud.add_child(pathing_blocked)
	pathing_clearance=OptionButton.new()
	for radius in TerrainPathingScript.CLEARANCE_RADII_M:pathing_clearance.add_item("Clearance %.1f m"%radius);pathing_clearance.set_item_metadata(pathing_clearance.item_count-1,radius)
	hud.add_child(pathing_clearance)
	var legend:=Label.new();legend.text="Red authored · orange terrain · blue deep water · hatched = no clearance";hud.add_child(legend)
	pathing_dialog=Window.new();pathing_dialog.title="Pathing";pathing_dialog.size=Vector2i(500,360);pathing_dialog.close_requested.connect(pathing_dialog.hide);pathing_dialog.visible=false;add_child(pathing_dialog)
	var form:=VBoxContainer.new();form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);form.offset_left=18;form.offset_top=18;form.offset_right=-18;form.offset_bottom=-18;pathing_dialog.add_child(form)
	var help:=Label.new();help.text="Movement and building placement are separate. Manual paint only adds restrictions; derived slope, cliff, water, and bounds rules remain authoritative.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;form.add_child(help)
	_add_button(form,"Toggle Walkability Overlay",toggle_pathing_overlay)
	_add_button(form,"Paint / Erase Pathing",enable_pathing_paint)
	_add_button(form,"Validate Starts & Islands",validate_pathing)


func show_pathing_editor()->void:
	if package.terrain==null:show_blocking_error("Create terrain before editing pathing.");return
	if pathing==null:pathing=TerrainPathingScript.new(package.terrain)
	pathing_dialog.popup_centered()


func toggle_pathing_overlay()->void:
	pathing_overlay_visible=not pathing_overlay_visible
	if pathing_overlay_visible:pathing.reset_cancellation();pathing.rebuild_overlay(pathing_layer.get_item_metadata(pathing_layer.selected))
	refresh_pathing_overlay()
	status("Walkability overlay visible" if pathing_overlay_visible else "Walkability overlay hidden")


func enable_pathing_paint()->void:
	_set_terrain_tool("pathing", "Pathing paint: drag cells; Escape returns to Selection")
	pathing_dialog.hide()


func validate_pathing()->void:
	var messages:Array=pathing.validate_connectivity(package.world)
	if messages.is_empty():status("Pathing validation passed: all starts are connected");return
	var lines:Array[String]=[]
	for message in messages:lines.append("%s %s — %d cell(s)"%[message.severity.to_upper(),message.code,message.cells.size()])
	error_dialog.dialog_text="\n".join(lines);error_dialog.popup_centered()


func refresh_pathing_overlay()->void:
	var existing:=world_root.get_node_or_null("PathingOverlay")
	if existing!=null:existing.free()
	if not pathing_overlay_visible or pathing==null:return
	if pathing.stale:pathing.rebuild_overlay(pathing_layer.get_item_metadata(pathing_layer.selected))
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid:Dictionary=package.terrain.data.grid;var radius:float=pathing_clearance.get_item_metadata(pathing_clearance.selected)
	for cell in pathing.last_overlay:
		var reasons:Array=cell.reasons;var clear: bool=pathing.has_clearance(cell.x,cell.z,radius,pathing_layer.get_item_metadata(pathing_layer.selected))
		if reasons.is_empty() and clear:continue
		var color:=Color(0.9,0.15,0.2,0.48) if "authored_block" in reasons else Color(0.15,0.45,0.95,0.46) if "deep_water" in reasons else Color(0.95,0.55,0.1,0.44)
		if not clear and (cell.x+cell.z)%2==0:color.a=0.7
		var x0: float=float(grid.origin_x_m)+cell.x*float(grid.cell_size_m);var z0: float=float(grid.origin_z_m)+cell.z*float(grid.cell_size_m);var size: float=float(grid.cell_size_m);var y: float=package.terrain.effective_height(x0+size/2,z0+size/2)+0.06
		for vertex in [Vector3(x0,y,z0),Vector3(x0,y,z0+size),Vector3(x0+size,y,z0),Vector3(x0+size,y,z0),Vector3(x0,y,z0+size),Vector3(x0+size,y,z0+size)]:mesh.surface_set_color(color);mesh.surface_add_vertex(vertex)
	mesh.surface_end();var preview:=MeshInstance3D.new();preview.name="PathingOverlay";preview.mesh=mesh
	preview.set_meta("overlay_label", "Pathing")
	var material:=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.vertex_color_use_as_albedo=true;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;preview.material_override=material;world_root.add_child(preview)


func _build_environment_editor()->void:
	environment_dialog=Window.new();environment_dialog.title="World Environment";environment_dialog.size=Vector2i(620,650);environment_dialog.close_requested.connect(environment_dialog.hide);environment_dialog.visible=false;add_child(environment_dialog)
	var scroll:=ScrollContainer.new();scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);scroll.offset_left=18;scroll.offset_top=18;scroll.offset_right=-18;scroll.offset_bottom=-18;environment_dialog.add_child(scroll)
	var form:=VBoxContainer.new();form.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(form)
	var help:=Label.new();help.text="Godot 4.7.1 parity preview uses identical authored values. Tone mapping, GPU precision, and display calibration may still differ from the target Windows display.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;form.add_child(help)
	for spec in [["sun_azimuth_deg","Sun azimuth °",-360,360,1],["sun_elevation_deg","Sun elevation °",-90,90,1],["sun_energy","Sun intensity",0,16,0.05],["ambient_energy","Ambient intensity",0,16,0.05],["fog_density","Fog density",0,1,0.001],["fog_start_m","Fog start m",0,10000,1],["fog_end_m","Fog end m",0.01,10000,1]]:
		environment_fields[spec[0]]=_hud_spin(form,spec[1],spec[2],spec[3],0,spec[4])
	for item in [["sun_color_linear","Sun color (linear)"],["ambient_color_linear","Ambient color (linear)"],["fog_color_linear","Fog color (linear)"]]:
		var label:=Label.new();label.text=item[1];form.add_child(label);var picker:=ColorPickerButton.new();picker.edit_alpha=false;form.add_child(picker);environment_colors[item[0]]=picker
	environment_fog_enabled=CheckBox.new();environment_fog_enabled.text="Enable depth fog";form.add_child(environment_fog_enabled)
	environment_sky=OptionButton.new();var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://content/crimsdale/terrain_skies.json"))
	for sky in catalog.get("skies",[]):environment_sky.add_item("%s — %s"%[sky.display_name,sky.sky_id]);environment_sky.set_item_metadata(environment_sky.item_count-1,sky.sky_id)
	form.add_child(environment_sky)
	_add_button(form,"Apply Environment",apply_environment_changes)
	_add_button(form,"Toggle Accurate Preview",toggle_environment_preview)


func show_environment_editor()->void:
	if package.terrain==null:show_blocking_error("Create terrain before editing the environment.");return
	var data:Dictionary=package.terrain.data.environment
	for key in environment_fields:environment_fields[key].value=data[key]
	for key in environment_colors:
		var color:Array=data[key];environment_colors[key].color=Color(float(color[0]),float(color[1]),float(color[2]))
	environment_fog_enabled.button_pressed=data.fog_enabled
	for index in environment_sky.item_count:
		if environment_sky.get_item_metadata(index)==data.sky_id:environment_sky.select(index)
	environment_dialog.popup_centered()


func apply_environment_changes()->void:
	var values:Dictionary={"fog_enabled":environment_fog_enabled.button_pressed,"sky_id":environment_sky.get_item_metadata(environment_sky.selected)}
	for key in environment_fields:values[key]=environment_fields[key].value
	for key in environment_colors:
		var color:Color=environment_colors[key].color;values[key]=[color.r,color.g,color.b]
	if TerrainEnvironmentScript.new(package.terrain).apply(values):apply_environment_preview();refresh_all();status("Environment applied as one undoable change")
	else:package.errors=package.terrain.errors;show_errors()


func toggle_environment_preview()->void:
	environment_preview_enabled=not environment_preview_enabled;apply_environment_preview();status("Accurate environment preview %s"%("on" if environment_preview_enabled else "off"))


func _build_workflow_editor() -> void:
	workflow_dialog = Window.new()
	workflow_dialog.title = "Terrain Workflow — Viewport Direct Manipulation"
	workflow_dialog.size = Vector2i(620, 680)
	workflow_dialog.exclusive = false
	workflow_dialog.transient = false
	workflow_dialog.close_requested.connect(close_workflow_editor)
	workflow_dialog.visible = false
	add_child(workflow_dialog)
	var input_guard=WorkflowInputGuardScript.new();input_guard.name="WorkflowInputGuard";input_guard.dispatcher=_on_workflow_window_input;workflow_dialog.add_child(input_guard)
	var form := VBoxContainer.new()
	form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	form.offset_left = 18; form.offset_top = 18; form.offset_right = -18; form.offset_bottom = -18
	form.add_theme_constant_override("separation", 2)
	workflow_dialog.add_child(form)
	var help := Label.new()
	help.text = "S drag-select · Ctrl+C copy · Ctrl+V paste ghost · Move starts a move ghost · Enter confirm · Escape cancel\nF then click inspect · M recenter · Middle-drag camera · Wheel zoom"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(help)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	form.add_child(columns)
	var coordinates := VBoxContainer.new()
	coordinates.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coordinates.add_theme_constant_override("separation", 2)
	columns.add_child(coordinates)
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 2)
	columns.add_child(options)
	for spec in [["x", "Selection X", 0, 511], ["z", "Selection Z", 0, 511], ["width", "Width", 1, 512], ["depth", "Depth", 1, 512], ["paste_x", "Paste X", 0, 511], ["paste_z", "Paste Z", 0, 511]]:
		workflow_fields[spec[0]] = _hud_spin(coordinates, spec[1], spec[2], spec[3], 1, 1)
	for spec in [["grid_snap", "Grid snap (cells)", 1, 32], ["height_snap", "Height snap (cm)", 1, 1000]]:
		workflow_fields[spec[0]] = _hud_spin(options, spec[1], spec[2], spec[3], 1, 1)
	workflow_fields.width.value = 1; workflow_fields.depth.value = 1
	workflow_fields.grid_snap.value = 1; workflow_fields.height_snap.value = 25
	var domains_label := Label.new(); domains_label.text = "Clipboard domains"; options.add_child(domains_label)
	for domain in ["height", "surface", "cliff", "water", "pathing"]:
		var toggle := CheckBox.new(); toggle.text = domain.capitalize(); toggle.button_pressed = true; toggle.accessibility_name = "Include %s terrain domain" % domain; options.add_child(toggle); workflow_domains[domain] = toggle
	workflow_mode = OptionButton.new(); workflow_mode.add_item("Replace enabled values"); workflow_mode.add_item("Merge non-default cliff/pathing values"); options.add_child(workflow_mode)
	var actions := HFlowContainer.new(); actions.add_theme_constant_override("h_separation", 4); form.add_child(actions)
	_add_button(actions, "Select Area  S", _workflow_begin_selection)
	_add_button(actions, "Copy  Ctrl+C", _workflow_copy)
	_add_button(actions, "Preview Paste  Ctrl+V", _workflow_paste)
	_add_button(actions, "Preview Move", _workflow_move)
	_add_button(actions, "Validate Fields", _workflow_validate_fields)
	_add_button(actions, "Inspect  F", _workflow_sample)
	_add_button(actions, "Recenter  M", _workflow_recenter)
	workflow_preview_label = RichTextLabel.new()
	workflow_preview_label.name = "PreviewDetails"
	workflow_preview_label.custom_minimum_size.y = 105
	workflow_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workflow_preview_label.fit_content = false
	workflow_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workflow_preview_label.scroll_active = true
	workflow_preview_label.accessibility_name = "Terrain operation preview details"
	workflow_preview_label.text = "No pending operation. Select terrain in the viewport or use the numeric fallback."
	form.add_child(workflow_preview_label)
	var confirmation := HBoxContainer.new(); form.add_child(confirmation)
	workflow_confirm_button = _add_button(confirmation, "Confirm  Enter", _workflow_confirm)
	workflow_confirm_button.accessibility_name = "Confirm terrain operation"
	workflow_confirm_button.disabled = true
	workflow_cancel_button = _add_button(confirmation, "Cancel  Escape", _workflow_cancel)
	workflow_cancel_button.accessibility_name = "Cancel terrain gesture"
	for field_name in ["paste_x", "paste_z"]:
		workflow_fields[field_name].value_changed.connect(_workflow_destination_field_changed)


func show_workflow_editor() -> void:
	if package.terrain == null: show_blocking_error("Create terrain before using terrain workflow tools."); return
	_set_terrain_tool("workflow")
	if workflow == null or workflow.terrain != package.terrain: workflow = TerrainWorkflowScript.new(package.terrain)
	var panel_position := Vector2i(maxi(12, int(size.x) - workflow_dialog.size.x - 12), 32)
	workflow_dialog.popup(Rect2i(panel_position, workflow_dialog.size))
	if workflow.selection.get_area() <= 0: _workflow_select()
	refresh_workflow_overlay()
	status("Terrain workflow ready — press S and drag a source area")


func close_workflow_editor() -> void:
	_clear_workflow_gesture(true)
	workflow_domains.water.disabled = false
	workflow_dialog.hide()
	_set_terrain_tool("selection", "Selection tool")


func _on_workflow_window_input(event:InputEvent)->bool:
	if not event is InputEventKey or not event.pressed or event.echo: return false
	var handled := true
	if event.keycode == KEY_ESCAPE: _workflow_cancel()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]: _workflow_confirm()
	elif event.ctrl_pressed and event.keycode == KEY_C:
		if _workflow_focus_is_editing_text(): handled = false
		else: _workflow_copy()
	elif event.ctrl_pressed and event.keycode == KEY_V:
		if _workflow_focus_is_editing_text(): handled = false
		else: _workflow_paste()
	elif not event.ctrl_pressed and not event.alt_pressed and event.keycode == KEY_S:
		if _workflow_focus_is_editing_text(): handled = false
		else: _workflow_begin_selection()
	elif not event.ctrl_pressed and not event.alt_pressed and event.keycode == KEY_F:
		if _workflow_focus_is_editing_text(): handled = false
		else: _workflow_sample()
	elif not event.ctrl_pressed and not event.alt_pressed and event.keycode == KEY_M:
		if _workflow_focus_is_editing_text(): handled = false
		else: _workflow_recenter()
	else: handled = false
	if handled: workflow_dialog.set_input_as_handled()
	return handled


func _workflow_focus_is_editing_text() -> bool:
	var focus := workflow_dialog.gui_get_focus_owner()
	if focus == null: focus = get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit or focus is SpinBox


func _workflow_begin_selection() -> void:
	_clear_workflow_gesture(false)
	workflow_selection_before_gesture = workflow.selection
	workflow_select_armed = true
	status("Select Area: drag across terrain; every drag direction is inclusive")


func _workflow_select() -> void:
	if workflow == null: workflow = TerrainWorkflowScript.new(package.terrain)
	workflow.grid_snap_cells = int(workflow_fields.grid_snap.value); workflow.height_snap_cm = int(workflow_fields.height_snap.value)
	var first := Vector2i(int(workflow_fields.x.value), int(workflow_fields.z.value))
	var last := first + Vector2i(int(workflow_fields.width.value), int(workflow_fields.depth.value)) - Vector2i.ONE
	var rect: Rect2i = workflow.select_cells(first, last)
	_workflow_sync_source_fields(rect)
	refresh_workflow_overlay()
	refresh_palette_summary()
	status("Selected %d × %d cells at %d, %d | snap %d cells / %d cm" % [rect.size.x, rect.size.y, rect.position.x, rect.position.y, workflow.grid_snap_cells, workflow.height_snap_cm])


func _workflow_copy() -> void:
	_workflow_select()
	_capture_workflow_clipboard()
	status("Copied %d terrain cells without mutation (clipboard v1, north-west anchor)" % workflow.selection.get_area())


func _capture_workflow_clipboard() -> void:
	var domains := {}
	for key in workflow_domains: domains[key] = workflow_domains[key].button_pressed
	terrain_clipboard = workflow.copy_selection(domains)


func _workflow_paste() -> void:
	if terrain_clipboard.is_empty(): status("Copy a terrain selection before pasting"); return
	workflow_domains.water.disabled = false
	_workflow_update_live_destination("paste", Vector2i(int(workflow_fields.paste_x.value), int(workflow_fields.paste_z.value)))


func _workflow_move() -> void:
	_workflow_select()
	workflow_domains.water.button_pressed = false
	workflow_domains.water.disabled = true
	_capture_workflow_clipboard()
	_workflow_update_live_destination("move", Vector2i(int(workflow_fields.paste_x.value), int(workflow_fields.paste_z.value)))


func _workflow_update_live_destination(operation: String, destination: Vector2i) -> void:
	if terrain_clipboard.is_empty(): return
	workflow.grid_snap_cells = int(workflow_fields.grid_snap.value)
	var snapped: Vector2i = workflow.snapped_cell(destination)
	_workflow_sync_destination_fields(snapped)
	var operation_mode := "replace" if operation == "move" or workflow_mode.selected == 0 else "merge"
	var source := Rect2i(Vector2i(terrain_clipboard.source_position[0], terrain_clipboard.source_position[1]), Vector2i(terrain_clipboard.size_cells[0], terrain_clipboard.size_cells[1]))
	workflow_pending_preview = workflow.preview_destination(terrain_clipboard, snapped, operation, operation_mode, _workflow_intersecting_ids(source, Rect2i(snapped, Vector2i(terrain_clipboard.size_cells[0], terrain_clipboard.size_cells[1]))))
	workflow_confirm_button.disabled = true
	workflow_preview_label.text = _workflow_preview_text(workflow_pending_preview)
	refresh_workflow_overlay()
	status("%s ghost active — click a destination for exact validation" % operation.capitalize())


func _workflow_update_preview(operation: String, destination: Vector2i) -> void:
	if terrain_clipboard.is_empty(): return
	workflow.grid_snap_cells = int(workflow_fields.grid_snap.value)
	var snapped: Vector2i = workflow.snapped_cell(destination)
	_workflow_sync_destination_fields(snapped)
	var operation_mode := "replace" if operation == "move" or workflow_mode.selected == 0 else "merge"
	var source := Rect2i(Vector2i(terrain_clipboard.source_position[0], terrain_clipboard.source_position[1]), Vector2i(terrain_clipboard.size_cells[0], terrain_clipboard.size_cells[1]))
	workflow_pending_preview = workflow.preview_operation(terrain_clipboard, snapped, operation, operation_mode, _workflow_intersecting_ids(source, Rect2i(snapped, Vector2i(terrain_clipboard.size_cells[0], terrain_clipboard.size_cells[1]))))
	workflow_confirm_button.disabled = not workflow_pending_preview.get("confirm_enabled", false)
	workflow_preview_label.text = _workflow_preview_text(workflow_pending_preview)
	refresh_workflow_overlay()
	status("%s" % ("%s preview ready — Enter or Confirm commits one transaction" % operation.capitalize() if workflow_pending_preview.get("confirm_enabled", false) else workflow_pending_preview.get("error", "Preview unavailable")))


func _workflow_validate_fields() -> void:
	if workflow_pending_preview.is_empty():
		status("Start a Paste or Move preview before validating its destination")
		return
	_workflow_update_preview(str(workflow_pending_preview.operation), Vector2i(int(workflow_fields.paste_x.value), int(workflow_fields.paste_z.value)))


func _workflow_confirm() -> void:
	if workflow_pending_preview.is_empty():
		status("Start a Paste or Move preview before confirming")
		return
	if not workflow_pending_preview.has("candidate"):
		_workflow_update_preview(str(workflow_pending_preview.operation), workflow_pending_preview.requested.position)
		if not workflow_pending_preview.get("confirm_enabled", false): return
	if workflow.confirm_operation(workflow_pending_preview):
		var operation := str(workflow_pending_preview.operation).capitalize()
		var committed: Rect2i = workflow_pending_preview.destination
		workflow.selection = committed
		_workflow_sync_source_fields(committed)
		_clear_workflow_gesture(false)
		refresh_all()
		refresh_workflow_overlay()
		status("%s committed as one Undo entry" % operation)
	else:
		workflow_pending_preview.confirm_enabled = false
		workflow_pending_preview.error = workflow.last_error
		workflow_pending_preview.recovery = "Preview the operation again from the current terrain."
		workflow_confirm_button.disabled = true
		workflow_preview_label.text = _workflow_preview_text(workflow_pending_preview)
		status(workflow.last_error)


func _workflow_cancel() -> void:
	if workflow_dragging or workflow_select_armed or workflow_sampling or not workflow_pending_preview.is_empty():
		_clear_workflow_gesture(false)
		status("Terrain gesture cancelled; source selection and authored data are unchanged")
	else:
		close_workflow_editor()


func _clear_workflow_gesture(remove_overlay: bool) -> void:
	if (workflow_dragging or workflow_select_armed) and workflow != null and workflow_selection_before_gesture.get_area() > 0:
		workflow.selection = workflow_selection_before_gesture
		if not workflow_fields.is_empty(): _workflow_sync_source_fields(workflow.selection)
	workflow_pending_preview.clear()
	workflow_dragging = false
	workflow_select_armed = false
	workflow_selection_before_gesture = Rect2i()
	workflow_sampling = false
	if workflow_domains.has("water"): workflow_domains.water.disabled = false
	if workflow_confirm_button != null: workflow_confirm_button.disabled = true
	if workflow_preview_label != null: workflow_preview_label.text = "No pending operation. Source selection remains available."
	if remove_overlay:
		var overlay := world_root.get_node_or_null("WorkflowOverlay") if world_root != null else null
		if overlay != null: overlay.free()
	else:
		refresh_workflow_overlay()


func _workflow_sample() -> void:
	workflow_sampling = true
	workflow_select_armed = false
	workflow_dragging = false
	status("Inspect Terrain: click the displayed terrain")


func _workflow_sample_cell(cell: Vector2i) -> void:
	var sample: Dictionary = workflow.sample(cell, _authored_position_map())
	var surfaces: Array[String] = []
	for surface in sample.surfaces: surfaces.append("%s %d (%0.1f%%)" % [surface.surface_id, surface.weight, surface.percent])
	var attachments: Array[String] = []
	for attachment in sample.attachments: attachments.append(str(attachment.get("target_id", attachment.get("id", "attachment"))))
	workflow_preview_label.text = "INSPECT cell %s | world (%0.2f, %0.2f, %0.2f)\nHeight authored %d cm / effective %d cm | surfaces %s\nCliff %d %s | water %s depth %d cm\nPathing movement %s → %s | placement %s → %s | attachments %s" % [sample.cell, sample.world.x, sample.world.y, sample.world.z, sample.authored_height_cm, sample.effective_height_cm, ", ".join(surfaces), sample.cliff_level, sample.cliff_style_id, sample.water_class, sample.water_depth_cm, sample.movement, sample.movement_reasons, sample.placement, sample.placement_reasons, attachments]
	workflow_sampling = false
	status("Inspected terrain cell %s" % sample.cell)


func _workflow_recenter() -> void:
	if workflow == null: workflow = TerrainWorkflowScript.new(package.terrain)
	orbit_target = workflow.minimap_recenter(Vector2(0.5, 0.5)); update_camera()
	status("Minimap recentered at %0.1f, %0.1f" % [orbit_target.x, orbit_target.z])


func _workflow_destination_field_changed(_value: float) -> void:
	if workflow_syncing_fields or workflow_pending_preview.is_empty(): return
	_workflow_update_preview(str(workflow_pending_preview.operation), Vector2i(int(workflow_fields.paste_x.value), int(workflow_fields.paste_z.value)))


func _workflow_sync_source_fields(rect: Rect2i) -> void:
	workflow_syncing_fields = true
	workflow_fields.x.value = rect.position.x; workflow_fields.z.value = rect.position.y
	workflow_fields.width.value = rect.size.x; workflow_fields.depth.value = rect.size.y
	workflow_syncing_fields = false


func _workflow_sync_destination_fields(destination: Vector2i) -> void:
	workflow_syncing_fields = true
	workflow_fields.paste_x.value = destination.x; workflow_fields.paste_z.value = destination.y
	workflow_syncing_fields = false


func _workflow_preview_text(preview: Dictionary) -> String:
	var domains: Array[String] = []
	for key in preview.get("domains", {}):
		if preview.domains[key]: domains.append(str(key))
	var changed := "pending destination validation" if int(preview.get("changed_cells", -1)) < 0 else "%d cells / %d vertices" % [int(preview.get("changed_cells", 0)), int(preview.get("changed_vertices", 0))]
	var intersections: Array[String] = []
	for id in preview.get("intersecting_authored_ids", []): intersections.append(str(id))
	var text := "%s | source %s → requested %s | committed %s\n%d × %d cells | changed %s | clipped %d | overlap %d\nDomains: %s | authored intersections: %s" % [str(preview.get("operation", "operation")).to_upper(), preview.get("source", Rect2i()), preview.get("requested", Rect2i()), preview.get("destination", Rect2i()), int(preview.get("dimensions", Vector2i.ZERO).x), int(preview.get("dimensions", Vector2i.ZERO).y), changed, int(preview.get("clipped_cells", 0)), int(preview.get("overlap_cells", 0)), ", ".join(domains), ", ".join(intersections) if not intersections.is_empty() else "none"]
	if not preview.get("warnings", []).is_empty(): text += "\nWarning: %s" % " | ".join(preview.warnings)
	if not preview.get("confirm_enabled", false):
		text += "\n%s: %s" % ["BLOCKED" if not preview.get("ok", false) else "NEXT", preview.get("error", preview.get("recovery", "Preview again."))]
	return text


func _workflow_intersecting_ids(source: Rect2i, destination: Rect2i) -> Array:
	var ids: Array = []
	for entry in package.world.get("objects", []) + package.world.get("spawn_points", []):
		if not entry.get("position") is Array: continue
		var cell: Vector2i = workflow.world_to_cell(array_to_vector(entry.position), false)
		if source.has_point(cell) or destination.has_point(cell): ids.append(entry.get("instance_id", entry.get("spawn_id", "authored")))
	if package.scenario != null:
		for region in package.scenario.data.get("regions", []):
			if _workflow_region_intersects(region, source) or _workflow_region_intersects(region, destination): ids.append(region.region_id)
	ids.sort()
	return ids


func _authored_position_map() -> Dictionary:
	var result := {}
	for entry in package.world.get("objects", []) + package.world.get("spawn_points", []):
		var id := str(entry.get("instance_id", entry.get("spawn_id", "")))
		if not id.is_empty() and entry.get("position") is Array: result[id] = entry.position
	return result


func _workflow_region_intersects(region: Dictionary, cells: Rect2i) -> bool:
	if cells.get_area() <= 0: return false
	var grid: Dictionary = package.terrain.data.grid
	var cell_size := float(grid.cell_size_m)
	var bounds := Rect2(float(grid.origin_x_m) + cells.position.x * cell_size, float(grid.origin_z_m) + cells.position.y * cell_size, cells.size.x * cell_size, cells.size.y * cell_size)
	var points: Array[Vector2] = []
	for value in region.get("points", []):
		if value is Array and value.size() >= 3: points.append(Vector2(float(value[0]), float(value[2])))
	if points.is_empty(): return false
	if region.get("shape") == "rectangle" and points.size() >= 2:
		var region_bounds := Rect2(Vector2(minf(points[0].x, points[1].x), minf(points[0].y, points[1].y)), Vector2(absf(points[1].x - points[0].x), absf(points[1].y - points[0].y)))
		return bounds.intersects(region_bounds, true)
	for point in points:
		if bounds.has_point(point): return true
	if region.get("shape") == "path":
		var corners := [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]
		for index in points.size() - 1:
			for edge in 4:
				if Geometry2D.segment_intersects_segment(points[index], points[index + 1], corners[edge], corners[(edge + 1) % 4]) != null: return true
	return false


func refresh_workflow_overlay() -> void:
	if world_root == null: return
	var existing := world_root.get_node_or_null("WorkflowOverlay")
	if existing != null: existing.free()
	if terrain_tool_mode != "workflow" or workflow == null or workflow.selection.get_area() <= 0 or package.terrain == null: return
	var root_3d := Node3D.new()
	root_3d.name = "WorkflowOverlay"
	root_3d.set_meta("overlay_label", "Terrain Workflow")
	root_3d.set_meta("source_rect", workflow.selection)
	world_root.add_child(root_3d)
	_add_workflow_rect_overlay(root_3d, workflow.selection, "SOURCE %d × %d" % [workflow.selection.size.x, workflow.selection.size.y], Color(1.0, 0.82, 0.18, 1.0), false)
	if not workflow_pending_preview.is_empty():
		var destination: Rect2i = workflow_pending_preview.get("destination", Rect2i())
		if destination.get_area() > 0:
			var suffix := " — BLOCKED" if not workflow_pending_preview.get("ok", false) else " — SET DESTINATION" if not workflow_pending_preview.get("destination_settled", true) else ""
			var label := "%s GHOST%s" % [str(workflow_pending_preview.operation).to_upper(), suffix]
			_add_workflow_rect_overlay(root_3d, destination, label, Color(0.15, 0.9, 1.0, 0.75) if workflow_pending_preview.get("confirm_enabled", false) else Color(1.0, 0.25, 0.25, 0.75), true)


func _add_workflow_rect_overlay(parent: Node3D, rect: Rect2i, label_text: String, color: Color, ghost: bool) -> void:
	var grid: Dictionary = package.terrain.data.grid
	var cell_size := float(grid.cell_size_m)
	var x0 := float(grid.origin_x_m) + rect.position.x * cell_size
	var z0 := float(grid.origin_z_m) + rect.position.y * cell_size
	var x1 := x0 + rect.size.x * cell_size
	var z1 := z0 + rect.size.y * cell_size
	var points: Array[Vector3] = []
	for point in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1), Vector2(x0, z0)]:
		points.append(Vector3(point.x, package.terrain.effective_height(point.x, point.y) + (0.16 if ghost else 0.12), point.y))
	var line := ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in points:
		line.surface_set_color(color)
		line.surface_add_vertex(point)
	line.surface_end()
	var outline := MeshInstance3D.new()
	outline.name = "DestinationOutline" if ghost else "SourceOutline"
	outline.mesh = line
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.vertex_color_use_as_albedo = true
	outline.material_override = line_material
	parent.add_child(outline)
	var center := Vector3((x0 + x1) * 0.5, package.terrain.effective_height((x0 + x1) * 0.5, (z0 + z1) * 0.5) + 0.2, (z0 + z1) * 0.5)
	if ghost:
		var fill := MeshInstance3D.new()
		fill.name = "DestinationGhost"
		var box := BoxMesh.new()
		box.size = Vector3(rect.size.x * cell_size, 0.04, rect.size.y * cell_size)
		var fill_material := StandardMaterial3D.new()
		fill_material.albedo_color = color * Color(1, 1, 1, 0.32)
		fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box.material = fill_material
		fill.mesh = box
		fill.position = center
		parent.add_child(fill)
	var label := Label3D.new()
	label.name = "DestinationLabel" if ghost else "SourceLabel"
	label.text = label_text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.position = center + Vector3.UP * 0.35
	parent.add_child(label)


func _build_scenario_editor() -> void:
	scenario_dialog = Window.new(); scenario_dialog.title = "Scenario Editor — Regions"; scenario_dialog.size = Vector2i(680, 680); scenario_dialog.close_requested.connect(scenario_dialog.hide); scenario_dialog.visible=false; add_child(scenario_dialog)
	var scroll := ScrollContainer.new(); scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scroll.offset_left = 18; scroll.offset_top = 18; scroll.offset_right = -18; scroll.offset_bottom = -18; scenario_dialog.add_child(scroll)
	var form := VBoxContainer.new(); form.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(form)
	var help := Label.new(); help.text = "Scenario data is portable and saved with the world. Regions use world metres: point (one position), rectangle (opposite corners), or path (ordered endpoints in this increment). IDs become stable references."; help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; form.add_child(help)
	for field in ["scenario_id","title","description","player_faction_id"]: scenario_fields[field] = _add_labeled_field(form, field.replace("_", " ").capitalize())
	for field in ["fog_enabled","explored_radius_m","hidden_by_default"]:scenario_fields[field]=_add_labeled_field(form,field.replace("_"," ").capitalize())
	scenario_fields.scenario_id.editable = false
	_add_button(form, "Create Scenario", _create_scenario)
	_add_button(form, "Create Guided Mission Template", _create_guided_mission_template)
	_add_button(form, "Apply Scenario Details", _apply_scenario_metadata)
	_add_button(form, "Open Objectives & Guidance…", show_guidance_editor)
	_add_button(form, "Open Groups & Encounters…", show_encounter_editor)
	_add_button(form, "Open Cinematics…", show_cinematic_editor)
	_add_button(form, "Open Sequences…", show_sequence_editor)
	_add_button(form, "Remove Scenario…", request_remove_scenario)
	var divider := HSeparator.new(); form.add_child(divider)
	scenario_region_list = ItemList.new();scenario_region_list.accessibility_name="Scenario regions, alphabetized by stable ID";scenario_region_list.custom_minimum_size.y = 150; scenario_region_list.item_selected.connect(_load_scenario_region); form.add_child(scenario_region_list)
	for field in ["region_id","display_name"]: scenario_region_fields[field] = _add_labeled_field(form, field.replace("_", " ").capitalize())
	scenario_region_shape = OptionButton.new()
	for shape in ["point","rectangle","path"]: scenario_region_shape.add_item(shape.capitalize()); scenario_region_shape.set_item_metadata(scenario_region_shape.item_count - 1, shape)
	_label_control(form,"Region shape",scenario_region_shape);form.add_child(scenario_region_shape)
	for field in ["x1","z1","x2","z2"]: scenario_region_fields[field] = _add_labeled_field(form, {"x1":"First point X (metres)","z1":"First point Z (metres)","x2":"Second point X (metres)","z2":"Second point Z (metres)"}[field])
	_add_button(form, "Add Region", _add_scenario_region)
	_add_button(form, "Update Selected Region", _update_scenario_region)
	_add_button(form, "Reverse Selected Path", _reverse_scenario_path)
	_add_button(form, "Delete Selected Region", _delete_scenario_region)
	scenario_remove_confirmation = ConfirmationDialog.new(); scenario_remove_confirmation.title = "Remove Scenario"; scenario_remove_confirmation.dialog_text = "Remove scenario.json from this world on the next save? Terrain, definitions, and placed objects remain."; scenario_remove_confirmation.confirmed.connect(_confirm_remove_scenario); add_child(scenario_remove_confirmation)


func _build_sequence_editor() -> void:
	sequence_dialog = Window.new(); sequence_dialog.title = "Scenario Editor — Sequences"; sequence_dialog.size = Vector2i(760,680); sequence_dialog.close_requested.connect(sequence_dialog.hide); sequence_dialog.visible=false; add_child(sequence_dialog)
	var scroll := ScrollContainer.new(); scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scroll.offset_left=18; scroll.offset_top=18; scroll.offset_right=-18; scroll.offset_bottom=-18; sequence_dialog.add_child(scroll)
	var form := VBoxContainer.new(); form.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(form)
	var help := Label.new(); help.text="Create typed event-condition-action sequences. Equal-frame sequences run by stable ID; actions run top to bottom. A duplicated sequence starts disabled for safe review."; help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; form.add_child(help)
	sequence_list=ItemList.new();sequence_list.accessibility_name="Scenario sequences";sequence_list.custom_minimum_size.y=130; sequence_list.item_selected.connect(_load_sequence); form.add_child(sequence_list)
	for field in ["sequence_id","a","b","c","text","number"]: sequence_fields[field]=_add_labeled_field(form, {"sequence_id":"Sequence ID","a":"Reference A","b":"Reference / value B","c":"Reference / value C","text":"Message text","number":"Duration / number"}[field])
	sequence_fields.number.text="2"
	var flags:=HBoxContainer.new(); form.add_child(flags)
	var enabled:=CheckBox.new(); enabled.text="Enabled"; enabled.button_pressed=true; flags.add_child(enabled); sequence_fields.enabled=enabled
	var one_shot:=CheckBox.new(); one_shot.text="One shot"; one_shot.button_pressed=true; flags.add_child(one_shot); sequence_fields.one_shot=one_shot
	sequence_event_type=OptionButton.new()
	for type in ScenarioDocumentScript.EVENTS: sequence_event_type.add_item(type.replace("_"," ").capitalize()); sequence_event_type.set_item_metadata(sequence_event_type.item_count-1,type)
	sequence_event_type.item_selected.connect(func(_index): _update_sequence_signature("event"));_label_control(form,"Event type",sequence_event_type);form.add_child(sequence_event_type)
	_add_button(form,"Create Sequence",_create_sequence); _add_button(form,"Apply Event / Flags",_apply_sequence_event); _add_button(form,"Duplicate Selected",_duplicate_sequence); _add_button(form,"Delete Selected",_delete_sequence)
	sequence_signature=Label.new(); sequence_signature.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; form.add_child(sequence_signature)
	var split:=HBoxContainer.new(); form.add_child(split)
	var conditions_box:=VBoxContainer.new(); conditions_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; split.add_child(conditions_box)
	var conditions_label:=Label.new(); conditions_label.text="Conditions"; conditions_box.add_child(conditions_label)
	sequence_condition_type=OptionButton.new()
	for type in ScenarioDocumentScript.CONDITIONS: sequence_condition_type.add_item(type.replace("_"," ").capitalize()); sequence_condition_type.set_item_metadata(sequence_condition_type.item_count-1,type)
	sequence_condition_type.item_selected.connect(func(_index): _update_sequence_signature("condition"));_label_control(conditions_box,"Condition type",sequence_condition_type);conditions_box.add_child(sequence_condition_type)
	sequence_conditions=ItemList.new(); sequence_conditions.custom_minimum_size=Vector2(330,120); conditions_box.add_child(sequence_conditions)
	_add_button(conditions_box,"Add Condition",_add_sequence_condition); _add_button(conditions_box,"Remove Condition",_remove_sequence_condition)
	var actions_box:=VBoxContainer.new(); actions_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; split.add_child(actions_box)
	var actions_label:=Label.new(); actions_label.text="Actions"; actions_box.add_child(actions_label)
	sequence_action_type=OptionButton.new()
	for type in ScenarioDocumentScript.ACTIONS: sequence_action_type.add_item(type.replace("_"," ").capitalize()); sequence_action_type.set_item_metadata(sequence_action_type.item_count-1,type)
	sequence_action_type.item_selected.connect(func(_index): _update_sequence_signature("action"));_label_control(actions_box,"Action type",sequence_action_type);actions_box.add_child(sequence_action_type)
	sequence_actions=ItemList.new(); sequence_actions.custom_minimum_size=Vector2(330,120); actions_box.add_child(sequence_actions)
	_add_button(actions_box,"Add Action",_add_sequence_action); _add_button(actions_box,"Move Action Up",func():_move_sequence_action(-1)); _add_button(actions_box,"Move Action Down",func():_move_sequence_action(1)); _add_button(actions_box,"Remove Action",_remove_sequence_action)
	_add_button(form,"Validate Flow",_validate_sequence_flow)
	_update_sequence_signature("event")


func _build_validation_results()->void:
	validation_dialog=Window.new();validation_dialog.title="Scenario Validation";validation_dialog.size=Vector2i(680,520);validation_dialog.close_requested.connect(validation_dialog.hide);validation_dialog.visible=false;add_child(validation_dialog)
	var form:=VBoxContainer.new();form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);form.offset_left=18;form.offset_top=18;form.offset_right=-18;form.offset_bottom=-18;validation_dialog.add_child(form)
	validation_summary=Label.new();validation_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;form.add_child(validation_summary)
	validation_list=ItemList.new();validation_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;validation_list.item_activated.connect(func(_index):_open_selected_validation_finding());form.add_child(validation_list)
	_add_button(form,"Open Selected Finding",_open_selected_validation_finding)


func _build_test_world_setup()->void:
	test_world_setup_dialog=Window.new();test_world_setup_dialog.title="Test World Setup";test_world_setup_dialog.size=Vector2i(720,560);test_world_setup_dialog.close_requested.connect(test_world_setup_dialog.hide);test_world_setup_dialog.visible=false;add_child(test_world_setup_dialog)
	test_world_executable_dialog=FileDialog.new();test_world_executable_dialog.title="Choose Frontier or Godot 4.7.1 executable";test_world_executable_dialog.access=FileDialog.ACCESS_FILESYSTEM;test_world_executable_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;test_world_executable_dialog.file_selected.connect(func(path):test_world_executable_field.text=path);add_child(test_world_executable_dialog)
	test_world_project_dialog=FileDialog.new();test_world_project_dialog.title="Choose Frontier Game project folder";test_world_project_dialog.access=FileDialog.ACCESS_FILESYSTEM;test_world_project_dialog.file_mode=FileDialog.FILE_MODE_OPEN_DIR;test_world_project_dialog.dir_selected.connect(func(path):test_world_project_field.text=path);add_child(test_world_project_dialog)
	var form:=VBoxContainer.new();form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);form.offset_left=18;form.offset_top=18;form.offset_right=-18;form.offset_bottom=-18;test_world_setup_dialog.add_child(form)
	var help:=Label.new();help.text="Choose one launch mode. Source review: select the Godot 4.7.1 executable and Frontier's Game folder. Exported build: select Frontier.exe and leave the project folder empty. These values apply to this editor session; FRONTIER_EXECUTABLE and FRONTIER_PROJECT_PATH remain supported defaults.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;form.add_child(help)
	test_world_executable_field=_add_labeled_path_field(form,"Frontier executable or Godot 4.7.1 executable","Browse…",func():test_world_executable_dialog.popup_centered_ratio(0.8))
	test_world_project_field=_add_labeled_path_field(form,"Frontier project folder (source review only, ending in Frontier/Game)","Browse…",func():test_world_project_dialog.popup_centered_ratio(0.8))
	test_world_executable_field.text=OS.get_environment("FRONTIER_EXECUTABLE");test_world_project_field.text=OS.get_environment("FRONTIER_PROJECT_PATH")
	var example:=Label.new();example.text="Source example\nExecutable: /full/path/Godot_v4.7.1-stable_linux.x86_64\nProject folder: /full/path/Frontier/Game\n\nExported example\nExecutable: C:\\Games\\Frontier\\Frontier.exe\nProject folder: leave empty";example.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;form.add_child(example)
	var buttons:=HBoxContainer.new();form.add_child(buttons);test_world_use_values_button=_add_button(buttons,"Use These Values",_accept_test_world_setup);_add_button(buttons,"Launch Test World",_launch_from_test_world_setup)


func show_test_world_setup(message:="")->void:
	if not str(message).is_empty():status(str(message))
	test_world_setup_dialog.popup_centered()


func _test_world_setup_error(executable:String,project_path:String)->String:
	if executable.is_empty():return "Choose a Frontier executable or the Godot 4.7.1 executable."
	if not FileAccess.file_exists(executable):return "The selected executable does not exist. Choose it again in Test Setup."
	var source_mode:=not project_path.is_empty() or executable.get_file().to_lower().begins_with("godot")
	if not source_mode:return ""
	if project_path.is_empty():return "Source review with Godot also needs Frontier's Game project folder."
	if not DirAccess.dir_exists_absolute(project_path):return "The selected Frontier project folder does not exist. Choose Frontier/Game in Test Setup."
	if not FileAccess.file_exists(project_path.path_join("project.godot")):return "The selected Frontier project folder has no project.godot. Choose the Frontier/Game folder."
	if not executable.get_file().to_lower().begins_with("godot"):return "Source review requires the Godot 4.7.1 executable. Choose it in Test Setup."
	var version_output:Array=[];var version_result:=OS.execute(executable,PackedStringArray(["--version"]),version_output,true)
	var version_text:=" ".join(version_output).strip_edges()
	if version_result!=0 or not version_text.begins_with("4.7.1."):return "Source review requires Godot 4.7.1. Choose the correct executable in Test Setup."
	var project_config:=ConfigFile.new();var project_error:=project_config.load(project_path.path_join("project.godot"));var frontier_autoload:=str(project_config.get_value("autoload","AuthoredWorldLaunch",""))
	if project_error!=OK or str(project_config.get_value("application","config/name",""))!="Frontier" or frontier_autoload!="*res://scripts/authored_world_launch.gd" or not FileAccess.file_exists(project_path.path_join("scripts/authored_world_launch.gd")):return "The selected Godot project is not Frontier. Choose the Frontier/Game folder in Test Setup."
	return ""


func _accept_test_world_setup()->void:
	var error:=_test_world_setup_error(test_world_executable_field.text.strip_edges(),test_world_project_field.text.strip_edges())
	if not error.is_empty():show_test_world_setup(error);return
	test_world_setup_dialog.hide();status("Test World setup validated for this editor session")


func _launch_from_test_world_setup()->void:
	var error:=_test_world_setup_error(test_world_executable_field.text.strip_edges(),test_world_project_field.text.strip_edges())
	if not error.is_empty():show_test_world_setup(error);return
	test_world_setup_dialog.hide();test_world()


func _build_guidance_editor() -> void:
	guidance_dialog=Window.new();guidance_dialog.title="Scenario Editor — Objectives & Guidance";guidance_dialog.size=Vector2i(760,680);guidance_dialog.close_requested.connect(guidance_dialog.hide);guidance_dialog.visible=false;add_child(guidance_dialog)
	var scroll:=ScrollContainer.new();scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);scroll.offset_left=18;scroll.offset_top=18;scroll.offset_right=-18;scroll.offset_bottom=-18;guidance_dialog.add_child(scroll)
	var form:=VBoxContainer.new();form.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(form)
	var help:=Label.new();help.text="Build the mission path as ordered objective steps. A step may point to a checkpoint region. Reusable tutorial prompts can mark the world or viewport and are shown by typed sequence actions.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;form.add_child(help)
	var heading:=Label.new();heading.text="Objectives";form.add_child(heading)
	objective_list=ItemList.new();objective_list.accessibility_name="Mission objectives";objective_list.custom_minimum_size.y=115;objective_list.item_selected.connect(_load_objective);form.add_child(objective_list)
	for field in ["objective_id","title","kind","initial_state","step_id","step_title","checkpoint_region_id"]:objective_fields[field]=_add_labeled_field(form,field.replace("_"," ").capitalize())
	objective_fields.kind.text="main";objective_fields.initial_state.text="active"
	_add_button(form,"Add Objective",_add_objective);_add_button(form,"Update Selected Objective",_update_objective);_add_button(form,"Delete Selected Objective",_delete_objective)
	objective_step_list=ItemList.new();objective_step_list.accessibility_name="Selected objective steps";objective_step_list.custom_minimum_size.y=105;form.add_child(objective_step_list)
	_add_button(form,"Add Step",_add_objective_step);_add_button(form,"Move Step Up",func():_move_objective_step(-1));_add_button(form,"Move Step Down",func():_move_objective_step(1));_add_button(form,"Delete Selected Step",_delete_objective_step)
	form.add_child(HSeparator.new());heading=Label.new();heading.text="Tutorial guidance";form.add_child(heading)
	tutorial_list=ItemList.new();tutorial_list.accessibility_name="Mission guidance prompts";tutorial_list.custom_minimum_size.y=115;tutorial_list.item_selected.connect(_load_tutorial);form.add_child(tutorial_list)
	for field in ["tutorial_id","text","control","indicator","acknowledgement","region_id","highlight","gates_sequence_id"]:tutorial_fields[field]=_add_labeled_field(form,field.replace("_"," ").capitalize())
	tutorial_fields.control.text="move";tutorial_fields.indicator.text="both";tutorial_fields.acknowledgement.text="input"
	_add_button(form,"Add Tutorial",_add_tutorial);_add_button(form,"Update Selected Tutorial",_update_tutorial);_add_button(form,"Delete Selected Tutorial",_delete_tutorial)
	_add_button(form,"Preview Mission Guidance",_preview_guidance)
	guidance_preview=RichTextLabel.new();guidance_preview.fit_content=true;guidance_preview.custom_minimum_size.y=110;guidance_preview.bbcode_enabled=false;form.add_child(guidance_preview)


func _build_encounter_editor()->void:
	encounter_dialog=Window.new();encounter_dialog.title="Scenario Editor — Groups & Encounters";encounter_dialog.size=Vector2i(760,680);encounter_dialog.close_requested.connect(encounter_dialog.hide);encounter_dialog.visible=false;add_child(encounter_dialog)
	var scroll:=ScrollContainer.new();scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);scroll.offset_left=18;scroll.offset_top=18;scroll.offset_right=-18;scroll.offset_bottom=-18;encounter_dialog.add_child(scroll)
	var form:=VBoxContainer.new();form.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(form)
	var help:=Label.new();help.text="Groups reference placed unit Instance IDs. Recruit allies with Set Ownership in Sequences. Encounters stay dormant until a region-entry or prior-completion sequence applies Set Encounter.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;form.add_child(help)
	var heading:=Label.new();heading.text="Unit groups";form.add_child(heading);group_list=ItemList.new();group_list.accessibility_name="Scenario unit groups";group_list.custom_minimum_size.y=110;group_list.item_selected.connect(_load_group);form.add_child(group_list)
	group_fields.group_id=_add_labeled_field(form,"Group ID");group_fields.instance_ids=_add_labeled_field(form,"Placed Instance IDs (comma separated)")
	_add_button(form,"Add Group",_add_group);_add_button(form,"Update Selected Group",_update_group);_add_button(form,"Delete Selected Group",_delete_group)
	form.add_child(HSeparator.new());heading=Label.new();heading.text="Staged encounters";form.add_child(heading);encounter_list=ItemList.new();encounter_list.accessibility_name="Staged encounters";encounter_list.custom_minimum_size.y=110;encounter_list.item_selected.connect(_load_encounter);form.add_child(encounter_list)
	for field in ["encounter_id","group_id","initial_state","behavior","leash_region_id","patrol_path_region_id","completion","reinforcement_group_ids"]:encounter_fields[field]=_add_labeled_field(form,field.replace("_"," ").capitalize())
	encounter_fields.initial_state.text="inactive";encounter_fields.behavior.text="sleep";encounter_fields.completion.text="all_defeated"
	_add_button(form,"Add Encounter",_add_encounter);_add_button(form,"Update Selected Encounter",_update_encounter);_add_button(form,"Delete Selected Encounter",_delete_encounter);_add_button(form,"Preview Staging",_preview_encounters)
	encounter_preview=RichTextLabel.new();encounter_preview.fit_content=true;encounter_preview.custom_minimum_size.y=120;form.add_child(encounter_preview)


func _build_cinematic_editor()->void:
	cinematic_dialog=Window.new();cinematic_dialog.title="Scenario Editor — Cinematics";cinematic_dialog.size=Vector2i(880,680);cinematic_dialog.close_requested.connect(cinematic_dialog.hide);cinematic_dialog.visible=false;add_child(cinematic_dialog)
	var scroll:=ScrollContainer.new();scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);scroll.offset_left=18;scroll.offset_top=18;scroll.offset_right=-18;scroll.offset_bottom=-18;cinematic_dialog.add_child(scroll)
	var form:=VBoxContainer.new();form.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(form)
	var help:=Label.new();help.text="Choose an opening or ending, then add or update its ordered shots. Dialogue always includes a subtitle; audio is optional. Select a timeline row to edit it or preview that beat.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;form.add_child(help)
	cinematic_list=ItemList.new();cinematic_list.accessibility_name="Cinematics";cinematic_list.custom_minimum_size.y=72;cinematic_list.item_selected.connect(_load_cinematic);form.add_child(cinematic_list)
	var id_label:=Label.new();id_label.text="Cinematic stable ID";form.add_child(id_label);cinematic_fields.cinematic_id=_add_field(form,"opening");cinematic_fields.cinematic_id.accessibility_name="Cinematic stable ID"
	var flags:=HBoxContainer.new();form.add_child(flags)
	for field in ["skippable","letterbox","control_lock"]:
		var toggle:=CheckBox.new();toggle.text={"skippable":"Escape can skip","letterbox":"Show letterbox","control_lock":"Lock gameplay controls"}[field];toggle.button_pressed=true;flags.add_child(toggle);cinematic_fields[field]=toggle
	var cinematic_buttons:=HBoxContainer.new();form.add_child(cinematic_buttons);_add_button(cinematic_buttons,"Add Cinematic",_add_cinematic);_add_button(cinematic_buttons,"Update Playback Flags",_update_cinematic);_add_button(cinematic_buttons,"Delete Cinematic",_delete_cinematic)
	var step_heading:=Label.new();step_heading.text="Timeline step type";form.add_child(step_heading)
	cinematic_step_type=OptionButton.new()
	cinematic_step_type.accessibility_name="Timeline step type"
	for type in ScenarioDocumentScript.CINEMATIC_STEPS:
		cinematic_step_type.add_item(type.replace("_"," ").capitalize());cinematic_step_type.set_item_metadata(cinematic_step_type.item_count-1,type)
	form.add_child(cinematic_step_type)
	cinematic_step_type.item_selected.connect(func(_index):_refresh_cinematic_step_fields());cinematic_step_type.select(0)
	for field in ["a","b","c","text","number","number_2"]:
		var row:=HBoxContainer.new();row.size_flags_horizontal=Control.SIZE_EXPAND_FILL;form.add_child(row);cinematic_field_rows[field]=row
		var label:=Label.new();label.custom_minimum_size.x=160;row.add_child(label);cinematic_field_labels[field]=label
		var input:=LineEdit.new();input.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(input);cinematic_fields[field]=input
	cinematic_fields.number.text="3";cinematic_fields.number_2.text="0.5";_refresh_cinematic_step_fields()
	cinematic_step_list=ItemList.new();cinematic_step_list.accessibility_name="Selected cinematic timeline";cinematic_step_list.custom_minimum_size.y=100;cinematic_step_list.item_selected.connect(_scrub_cinematic);form.add_child(cinematic_step_list)
	var step_buttons:=HBoxContainer.new();form.add_child(step_buttons);_add_button(step_buttons,"Add Step",_add_cinematic_step);cinematic_update_step_button=_add_button(step_buttons,"Update Selected Step",_update_cinematic_step);_add_button(step_buttons,"Move Up",func():_move_cinematic_step(-1));_add_button(step_buttons,"Move Down",func():_move_cinematic_step(1));_add_button(step_buttons,"Delete Step",_delete_cinematic_step)
	var playback:=HBoxContainer.new();form.add_child(playback);_add_button(playback,"Play Preview",_play_cinematic_preview);_add_button(playback,"Skip Preview",_skip_cinematic_preview);_add_button(playback,"Validate",_validate_cinematic_preview)
	cinematic_play_preview_button=playback.get_child(0);cinematic_preview=RichTextLabel.new();cinematic_preview.fit_content=true;cinematic_preview.custom_minimum_size.y=64;form.add_child(cinematic_preview)


func show_cinematic_editor()->void:
	if package.scenario==null:status("Create a scenario before authoring cinematics");return
	_refresh_cinematics();cinematic_dialog.popup_centered();status("Cinematic timeline workspace")


func _refresh_cinematics()->void:
	cinematic_list.clear();cinematic_step_list.clear();var seen_ids:={}
	for index in package.scenario.data.cinematics.size():
		var cinematic=package.scenario.data.cinematics[index]
		var stable_id:=str(cinematic.get("cinematic_id","")) if cinematic is Dictionary else "";var valid_id:bool=package.scenario._valid_id(stable_id);var invalid:bool=not cinematic is Dictionary or not valid_id or seen_ids.has(stable_id) or not cinematic.get("steps") is Array or not cinematic.get("skippable") is bool or cinematic.has("letterbox") and not cinematic.get("letterbox") is bool or cinematic.has("control_lock") and not cinematic.get("control_lock") is bool
		if valid_id:seen_ids[stable_id]=true
		var metadata:={"entity_index":index,"stable_id":stable_id,"invalid":invalid}
		if invalid:cinematic_list.add_item("Invalid cinematic%s (entry %d) — select Delete Cinematic to remove"%[" '%s'"%stable_id if not stable_id.is_empty() else "",index+1]);cinematic_list.set_item_metadata(cinematic_list.item_count-1,metadata);continue
		cinematic_list.add_item("%s  [%s]"%[stable_id,"skippable" if cinematic.get("skippable",false) else "locked"]);cinematic_list.set_item_metadata(cinematic_list.item_count-1,metadata)


func _selected_cinematic_id()->String:
	var selected:=cinematic_list.get_selected_items()
	if selected.is_empty():return ""
	var metadata=cinematic_list.get_item_metadata(selected[0]);return str(metadata.get("stable_id","")) if metadata is Dictionary else str(metadata)


func _load_cinematic(index:int)->void:
	var metadata=cinematic_list.get_item_metadata(index);cinematic_step_list.clear()
	if metadata is Dictionary and metadata.get("invalid",false):
		cinematic_fields.cinematic_id.text=str(metadata.get("stable_id",""));cinematic_fields.cinematic_id.editable=false;cinematic_preview.text="This cinematic entry is malformed. Select Delete Cinematic to remove it, then recreate it.";status("Invalid cinematic entry selected — Delete Cinematic is available");return
	var cinematic:Dictionary=package.scenario._find(package.scenario.data.cinematics,"cinematic_id",str(metadata.get("stable_id","")) if metadata is Dictionary else str(metadata))
	if cinematic.is_empty():status("Cinematic entry could not be loaded");return
	cinematic_fields.cinematic_id.text=cinematic.get("cinematic_id","");cinematic_fields.cinematic_id.editable=false;cinematic_fields.skippable.button_pressed=cinematic.get("skippable",false);cinematic_fields.letterbox.button_pressed=cinematic.get("letterbox",false);cinematic_fields.control_lock.button_pressed=cinematic.get("control_lock",false)
	for step in cinematic.get("steps",[]):
		var summary:=_cinematic_step_summary(step);cinematic_step_list.add_item(summary);cinematic_step_list.set_item_tooltip(cinematic_step_list.item_count-1,summary)


func _add_cinematic()->void:
	if package.scenario.add_cinematic(cinematic_fields.cinematic_id.text,cinematic_fields.skippable.button_pressed,cinematic_fields.letterbox.button_pressed,cinematic_fields.control_lock.button_pressed,package.world):cinematic_fields.cinematic_id.editable=true;_refresh_cinematics();refresh_all();status("Cinematic added")
	else:package.errors=package.scenario.errors;show_errors()


func _update_cinematic()->void:
	var id:=_selected_cinematic_id();if id.is_empty():status("Select a cinematic");return
	if package.scenario.update_cinematic(id,{"skippable":cinematic_fields.skippable.button_pressed,"letterbox":cinematic_fields.letterbox.button_pressed,"control_lock":cinematic_fields.control_lock.button_pressed},package.world):_refresh_cinematics();refresh_all();status("Cinematic flags updated")
	else:package.errors=package.scenario.errors;show_errors()


func _delete_cinematic()->void:
	var selected:=cinematic_list.get_selected_items();if selected.is_empty():status("Select a cinematic");return
	var metadata=cinematic_list.get_item_metadata(selected[0])
	if metadata is Dictionary and metadata.get("invalid",false):
		if package.scenario.remove_invalid_collection_entry("cinematics",int(metadata.entity_index),package.world):_refresh_cinematics();refresh_all();status("Invalid cinematic entry removed")
		else:package.errors=package.scenario.errors;show_errors()
		return
	var id:=_selected_cinematic_id();if id.is_empty():status("Select a cinematic");return
	if package.scenario.delete_cinematic(id,package.world):cinematic_fields.cinematic_id.editable=true;_refresh_cinematics();refresh_all();status("Cinematic deleted")
	else:package.errors=package.scenario.errors;show_errors()


func _cinematic_step_from_form()->Dictionary:
	var type:String=ScenarioDocumentScript.CINEMATIC_STEPS[cinematic_step_type.selected] if cinematic_step_type.selected>=0 and cinematic_step_type.selected<ScenarioDocumentScript.CINEMATIC_STEPS.size() else ""
	match type:
		"dialogue":
			var step:={"type":type,"speaker_instance_id":cinematic_fields.a.text,"text":cinematic_fields.text.text,"duration_s":float(cinematic_fields.number.text)}
			if not cinematic_fields.b.text.is_empty():step.audio_id=cinematic_fields.b.text
			return step
		"camera":return {"type":type,"region_id":cinematic_fields.a.text,"duration_s":float(cinematic_fields.number.text),"blend_s":float(cinematic_fields.number_2.text)}
		"unit_cue":return {"type":type,"group_id":cinematic_fields.a.text,"cue":cinematic_fields.b.text,"target_region_id":cinematic_fields.c.text}
		_:return {"type":type,"audio_id":cinematic_fields.a.text,"volume":float(cinematic_fields.number.text),"policy":cinematic_fields.b.text}
	return {}


func _refresh_cinematic_step_fields()->void:
	var type:String=cinematic_step_type.get_item_metadata(cinematic_step_type.selected)
	var specs:Dictionary={
		"dialogue":{"a":"Speaker instance ID","b":"Optional audio ID","text":"Subtitle","number":"Duration (seconds)"},
		"camera":{"a":"Camera region ID","number":"Duration (seconds)","number_2":"Blend time (seconds)"},
		"unit_cue":{"a":"Unit group ID","b":"Cue (face, move, animate, show, hide, transform)","c":"Target region ID"},
		"audio":{"a":"Audio ID","b":"Playback policy (mix, replace, stop)","number":"Volume"}
	}[type]
	for key in cinematic_field_rows:
		cinematic_field_rows[key].visible=specs.has(key)
		if specs.has(key):cinematic_field_labels[key].text=specs[key];cinematic_fields[key].placeholder_text=specs[key];cinematic_fields[key].accessibility_name=specs[key]


func _cinematic_step_summary(step)->String:
	if not step is Dictionary:return "Invalid timeline step — delete and recreate this step"
	match step.get("type",""):
		"dialogue":return "Dialogue — %s: %s (%ss)"%[step.get("speaker_instance_id","missing speaker"),step.get("text",""),step.get("duration_s",0)]
		"camera":return "Camera — %s (%ss, %ss blend)"%[step.get("region_id","missing region"),step.get("duration_s",0),step.get("blend_s",0)]
		"unit_cue":return "Unit cue — %s: %s → %s"%[step.get("group_id","missing group"),step.get("cue","missing cue"),step.get("target_region_id","missing region")]
		"audio":return "Audio — %s (%s, volume %s)"%[step.get("audio_id","missing audio"),step.get("policy","missing policy"),step.get("volume",0)]
	return "Unsupported timeline step"


func _load_cinematic_step_form(step:Dictionary)->void:
	for index in cinematic_step_type.item_count:
		if cinematic_step_type.get_item_metadata(index)==step.get("type"):
			cinematic_step_type.select(index);break
	for key in ["a","b","c","text","number","number_2"]:cinematic_fields[key].text=""
	match step.get("type",""):
		"dialogue":cinematic_fields.a.text=step.get("speaker_instance_id","");cinematic_fields.b.text=step.get("audio_id","");cinematic_fields.text.text=step.get("text","");cinematic_fields.number.text=str(step.get("duration_s",3))
		"camera":cinematic_fields.a.text=step.get("region_id","");cinematic_fields.number.text=str(step.get("duration_s",2));cinematic_fields.number_2.text=str(step.get("blend_s",0.5))
		"unit_cue":cinematic_fields.a.text=step.get("group_id","");cinematic_fields.b.text=step.get("cue","");cinematic_fields.c.text=step.get("target_region_id","")
		"audio":cinematic_fields.a.text=step.get("audio_id","");cinematic_fields.b.text=step.get("policy","");cinematic_fields.number.text=str(step.get("volume",1))
	_refresh_cinematic_step_fields()


func _add_cinematic_step()->void:
	var id:=_selected_cinematic_id();if id.is_empty():status("Select a cinematic");return
	if package.scenario.add_cinematic_step(id,_cinematic_step_from_form(),package.world):_refresh_cinematics();_reselect_cinematic(id);refresh_all();status("Timeline step added")
	else:package.errors=package.scenario.errors;show_errors()


func _update_cinematic_step()->void:
	var id:=_selected_cinematic_id();var selected:=cinematic_step_list.get_selected_items();if id.is_empty() or selected.is_empty():status("Select a timeline step");return
	if package.scenario.update_cinematic_step(id,selected[0],_cinematic_step_from_form(),package.world):_refresh_cinematics();_reselect_cinematic(id);cinematic_step_list.select(selected[0]);_scrub_cinematic(selected[0]);refresh_all();status("Timeline step updated")
	else:package.errors=package.scenario.errors;show_errors()


func _reselect_cinematic(id:String)->void:
	for index in cinematic_list.item_count:
		var metadata=cinematic_list.get_item_metadata(index);var item_id:=str(metadata.get("stable_id","")) if metadata is Dictionary else str(metadata)
		if item_id==id:cinematic_list.deselect_all();cinematic_list.select(index);_load_cinematic(index);return


func _move_cinematic_step(direction:int)->void:
	var id:=_selected_cinematic_id();var selected:=cinematic_step_list.get_selected_items();if id.is_empty() or selected.is_empty():status("Select a timeline step");return
	if package.scenario.move_cinematic_step(id,selected[0],direction,package.world):_refresh_cinematics();_reselect_cinematic(id);cinematic_step_list.select(clampi(selected[0]+direction,0,cinematic_step_list.item_count-1));refresh_all()
	else:status("Timeline step is already at that edge")


func _delete_cinematic_step()->void:
	var id:=_selected_cinematic_id();var selected:=cinematic_step_list.get_selected_items();if id.is_empty() or selected.is_empty():status("Select a timeline step");return
	if package.scenario.delete_cinematic_step(id,selected[0],package.world):_refresh_cinematics();_reselect_cinematic(id);refresh_all();status("Timeline step deleted")
	else:package.errors=package.scenario.errors;show_errors()


func _scrub_cinematic(index:int)->void:
	var cinematic:Dictionary=package.scenario._find(package.scenario.data.cinematics,"cinematic_id",_selected_cinematic_id());var steps=cinematic.get("steps",[])
	if not steps is Array or index<0 or index>=steps.size():status("Timeline step could not be loaded");return
	var step=steps[index]
	if not step is Dictionary:cinematic_preview.text="STEP %d/%d — INVALID\nSelect Delete Step to remove this malformed step, then recreate it."%[index+1,steps.size()];status("Invalid timeline step selected — Delete Step is available");return
	_load_cinematic_step_form(step);cinematic_preview.text="STEP %d/%d — %s\n%s"%[index+1,steps.size(),str(step.get("type","unsupported")).to_upper(),_cinematic_step_summary(step)];status("Loaded timeline step %d for editing"%(index+1))


func _play_cinematic_preview()->void:
	if cinematic_step_list.item_count==0:status("Add a timeline step first");return
	cinematic_step_list.select(0);_scrub_cinematic(0)


func _skip_cinematic_preview()->void:
	var cinematic:Dictionary=package.scenario._find(package.scenario.data.cinematics,"cinematic_id",_selected_cinematic_id());if cinematic.is_empty() or not cinematic.skippable:status("This cinematic is not skippable");return
	cinematic_preview.text="SKIPPED — gameplay control restored";status("Cinematic preview skipped")


func _validate_cinematic_preview()->void:
	var failures:Array[String]=package.scenario.validate(package.scenario.data,package.world);status("Cinematic valid; subtitles remain available without audio" if failures.is_empty() else " | ".join(failures))


func show_encounter_editor()->void:
	if package.scenario==null:status("Create a scenario before authoring groups");return
	_refresh_encounters();encounter_dialog.popup_centered();status("Group recruitment and staged encounter workspace")


func _csv_ids(text:String)->Array:
	var result:Array=[]
	for value in text.split(",",false):
		var clean:=value.strip_edges();if not clean.is_empty():result.append(clean)
	return result


func _refresh_encounters()->void:
	group_list.clear();encounter_list.clear()
	for group in package.scenario.data.unit_groups:group_list.add_item("%s  (%d units)"%[group.group_id,group.instance_ids.size()]);group_list.set_item_metadata(group_list.item_count-1,group.group_id)
	for encounter in package.scenario.data.get("encounters",[]):encounter_list.add_item("%s  [%s / %s]"%[encounter.encounter_id,encounter.initial_state,encounter.behavior]);encounter_list.set_item_metadata(encounter_list.item_count-1,encounter.encounter_id)


func _load_group(index:int)->void:
	var group:Dictionary=package.scenario._find(package.scenario.data.unit_groups,"group_id",group_list.get_item_metadata(index));group_fields.group_id.text=group.group_id;group_fields.group_id.editable=false;group_fields.instance_ids.text=", ".join(group.instance_ids)


func _selected_group_id()->String:
	var selected:=group_list.get_selected_items();return "" if selected.is_empty() else group_list.get_item_metadata(selected[0])


func _add_group()->void:
	if package.scenario.add_group(group_fields.group_id.text,_csv_ids(group_fields.instance_ids.text),package.world):group_fields.group_id.editable=true;_refresh_encounters();refresh_all();status("Unit group added")
	else:package.errors=package.scenario.errors;show_errors()


func _update_group()->void:
	var id:=_selected_group_id();if id.is_empty():status("Select a group");return
	if package.scenario.update_group(id,_csv_ids(group_fields.instance_ids.text),package.world):_refresh_encounters();refresh_all();status("Unit group updated")
	else:package.errors=package.scenario.errors;show_errors()


func _delete_group()->void:
	var id:=_selected_group_id();if id.is_empty():status("Select a group");return
	if package.scenario.delete_group(id,package.world):group_fields.group_id.editable=true;_refresh_encounters();refresh_all();status("Unit group deleted")
	else:package.errors=package.scenario.errors;show_errors()


func _encounter_from_form()->Dictionary:
	var value:={"encounter_id":encounter_fields.encounter_id.text,"group_id":encounter_fields.group_id.text,"initial_state":encounter_fields.initial_state.text,"behavior":encounter_fields.behavior.text,"leash_region_id":encounter_fields.leash_region_id.text,"completion":encounter_fields.completion.text,"reinforcement_group_ids":_csv_ids(encounter_fields.reinforcement_group_ids.text)}
	if not encounter_fields.patrol_path_region_id.text.is_empty():value.patrol_path_region_id=encounter_fields.patrol_path_region_id.text
	return value


func _add_encounter()->void:
	if package.scenario.add_encounter(_encounter_from_form(),package.world):encounter_fields.encounter_id.editable=true;_refresh_encounters();refresh_all();status("Staged encounter added")
	else:package.errors=package.scenario.errors;show_errors()


func _load_encounter(index:int)->void:
	var encounter:Dictionary=package.scenario._find(package.scenario.data.get("encounters",[]),"encounter_id",encounter_list.get_item_metadata(index));encounter_fields.encounter_id.text=encounter.encounter_id;encounter_fields.encounter_id.editable=false
	for field in ["group_id","initial_state","behavior","leash_region_id","patrol_path_region_id","completion"]:encounter_fields[field].text=str(encounter.get(field,""))
	encounter_fields.reinforcement_group_ids.text=", ".join(encounter.reinforcement_group_ids)


func _update_encounter()->void:
	var selected:=encounter_list.get_selected_items();if selected.is_empty():status("Select an encounter");return
	var id:String=encounter_list.get_item_metadata(selected[0]);var changes:=_encounter_from_form();changes.erase("encounter_id")
	if package.scenario.update_encounter(id,changes,package.world):_refresh_encounters();refresh_all();status("Encounter updated")
	else:package.errors=package.scenario.errors;show_errors()


func _delete_encounter()->void:
	var selected:=encounter_list.get_selected_items();if selected.is_empty():status("Select an encounter");return
	var id:String=encounter_list.get_item_metadata(selected[0])
	if package.scenario.delete_encounter(id,package.world):encounter_fields.encounter_id.editable=true;_refresh_encounters();refresh_all();status("Encounter deleted")
	else:package.errors=package.scenario.errors;show_errors()


func _preview_encounters()->void:
	var lines:Array[String]=["STAGING PREVIEW (IDs and labels accompany every world shape)"]
	for group in package.scenario.data.unit_groups:lines.append("GROUP %s: %s"%[group.group_id,", ".join(group.instance_ids)])
	for encounter in package.scenario.data.get("encounters",[]):
		var activators:Array[String]=[]
		for sequence in package.scenario.data.sequences:
			for action in sequence.actions:
				if action.get("type")=="set_encounter" and action.get("group_id")==encounter.group_id:activators.append(sequence.sequence_id+" via "+sequence.event.type)
		lines.append("ENCOUNTER %s: %s / %s; leash=%s; patrol=%s; activate=%s; reinforcements=%s"%[encounter.encounter_id,encounter.initial_state,encounter.behavior,encounter.leash_region_id,encounter.get("patrol_path_region_id","none"),", ".join(activators) if not activators.is_empty() else "not wired",", ".join(encounter.reinforcement_group_ids)])
	encounter_preview.text="\n".join(lines);status("Encounter staging preview refreshed")


func show_guidance_editor()->void:
	if package.scenario==null:status("Create a scenario before authoring objectives");return
	_refresh_guidance();guidance_dialog.popup_centered();status("Objectives and tutorial guidance workspace")


func _refresh_guidance()->void:
	objective_list.clear();objective_step_list.clear();tutorial_list.clear()
	if package.scenario==null:return
	for objective in package.scenario.data.objectives:
		objective_list.add_item("%s  [%s, %s]"%[objective.title,objective.kind,objective.initial_state]);objective_list.set_item_metadata(objective_list.item_count-1,objective.objective_id)
	for tutorial in package.scenario.data.get("tutorials",[]):
		tutorial_list.add_item("%s  [%s → %s]"%[tutorial.tutorial_id,tutorial.control,tutorial.indicator]);tutorial_list.set_item_metadata(tutorial_list.item_count-1,tutorial.tutorial_id)


func _selected_objective_id()->String:
	var selected:=objective_list.get_selected_items();return "" if selected.is_empty() else objective_list.get_item_metadata(selected[0])


func _load_objective(index:int)->void:
	var objective:Dictionary=package.scenario._find(package.scenario.data.objectives,"objective_id",objective_list.get_item_metadata(index));objective_fields.objective_id.text=objective.objective_id;objective_fields.objective_id.editable=false;objective_fields.title.text=objective.title;objective_fields.kind.text=objective.kind;objective_fields.initial_state.text=objective.initial_state;objective_step_list.clear()
	for step in objective.get("steps",[]):objective_step_list.add_item("%s  %s%s"%[step.step_id,step.title,"  @ "+step.checkpoint_region_id if step.has("checkpoint_region_id") else ""]);objective_step_list.set_item_metadata(objective_step_list.item_count-1,step.step_id)


func _add_objective()->void:
	if package.scenario.add_objective(objective_fields.objective_id.text,objective_fields.title.text,objective_fields.kind.text,objective_fields.initial_state.text,package.world):objective_fields.objective_id.editable=true;_refresh_guidance();refresh_all();status("Objective added")
	else:package.errors=package.scenario.errors;show_errors()


func _update_objective()->void:
	var id:=_selected_objective_id();if id.is_empty():status("Select an objective");return
	if package.scenario.update_objective(id,{"title":objective_fields.title.text,"kind":objective_fields.kind.text,"initial_state":objective_fields.initial_state.text},package.world):_refresh_guidance();refresh_all();status("Objective updated")
	else:package.errors=package.scenario.errors;show_errors()


func _delete_objective()->void:
	var id:=_selected_objective_id();if id.is_empty():status("Select an objective");return
	if package.scenario.delete_objective(id,package.world):objective_fields.objective_id.editable=true;_refresh_guidance();refresh_all();status("Objective deleted")
	else:package.errors=package.scenario.errors;show_errors()


func _add_objective_step()->void:
	var id:=_selected_objective_id();if id.is_empty():status("Select an objective");return
	if package.scenario.add_objective_step(id,objective_fields.step_id.text,objective_fields.step_title.text,objective_fields.checkpoint_region_id.text,package.world):_refresh_guidance();_reselect_objective(id);refresh_all();status("Objective step added")
	else:package.errors=package.scenario.errors;show_errors()


func _move_objective_step(direction:int)->void:
	var id:=_selected_objective_id();var selected:=objective_step_list.get_selected_items();if id.is_empty() or selected.is_empty():status("Select an objective step");return
	if package.scenario.move_objective_step(id,selected[0],direction,package.world):_refresh_guidance();_reselect_objective(id);objective_step_list.select(clampi(selected[0]+direction,0,objective_step_list.item_count-1));refresh_all()
	else:status("Step is already at that edge")


func _delete_objective_step()->void:
	var id:=_selected_objective_id();var selected:=objective_step_list.get_selected_items();if id.is_empty() or selected.is_empty():status("Select an objective step");return
	var step_id:String=objective_step_list.get_item_metadata(selected[0])
	if package.scenario.delete_objective_step(id,step_id,package.world):_refresh_guidance();_reselect_objective(id);refresh_all();status("Objective step deleted")
	else:package.errors=package.scenario.errors;show_errors()


func _reselect_objective(id:String)->void:
	for index in objective_list.item_count:
		if objective_list.get_item_metadata(index)==id:objective_list.select(index);_load_objective(index);return


func _tutorial_from_form()->Dictionary:
	var value:={"tutorial_id":tutorial_fields.tutorial_id.text,"text":tutorial_fields.text.text,"control":tutorial_fields.control.text,"indicator":tutorial_fields.indicator.text,"acknowledgement":tutorial_fields.acknowledgement.text}
	for key in ["region_id","highlight","gates_sequence_id"]:
		if not tutorial_fields[key].text.is_empty():value[key]=tutorial_fields[key].text
	return value


func _add_tutorial()->void:
	if package.scenario.add_tutorial(_tutorial_from_form(),package.world):tutorial_fields.tutorial_id.editable=true;_refresh_guidance();refresh_all();status("Tutorial guidance added")
	else:package.errors=package.scenario.errors;show_errors()


func _load_tutorial(index:int)->void:
	var tutorial:Dictionary=package.scenario._find(package.scenario.data.get("tutorials",[]),"tutorial_id",tutorial_list.get_item_metadata(index));tutorial_fields.tutorial_id.text=tutorial.tutorial_id;tutorial_fields.tutorial_id.editable=false
	for key in ["text","control","indicator","acknowledgement","region_id","highlight","gates_sequence_id"]:tutorial_fields[key].text=str(tutorial.get(key,""))


func _update_tutorial()->void:
	var selected:=tutorial_list.get_selected_items();if selected.is_empty():status("Select tutorial guidance");return
	var id:String=tutorial_list.get_item_metadata(selected[0]);var changes:=_tutorial_from_form();changes.erase("tutorial_id")
	if package.scenario.update_tutorial(id,changes,package.world):_refresh_guidance();refresh_all();status("Tutorial guidance updated")
	else:package.errors=package.scenario.errors;show_errors()


func _delete_tutorial()->void:
	var selected:=tutorial_list.get_selected_items();if selected.is_empty():status("Select tutorial guidance");return
	var id:String=tutorial_list.get_item_metadata(selected[0])
	if package.scenario.delete_tutorial(id,package.world):tutorial_fields.tutorial_id.editable=true;_refresh_guidance();refresh_all();status("Tutorial guidance deleted")
	else:package.errors=package.scenario.errors;show_errors()


func _preview_guidance()->void:
	var lines:Array[String]=["OBJECTIVE FLOW (ordered; ↑/↓ buttons are keyboard-focusable)"]
	for objective in package.scenario.data.objectives:
		lines.append("%s [%s / %s]"%[objective.title,objective.kind.to_upper(),objective.initial_state.to_upper()])
		for index in objective.get("steps",[]).size():
			var step:Dictionary=objective.steps[index];lines.append("  %d. %s%s"%[index+1,step.title," → "+step.checkpoint_region_id if step.has("checkpoint_region_id") else ""])
	lines.append("TUTORIAL CUES (text and shape/location labels; never color alone)")
	for tutorial in package.scenario.data.get("tutorials",[]):lines.append("[%s] %s — %s; acknowledge=%s%s"%[tutorial.indicator.to_upper(),tutorial.text,tutorial.control,tutorial.acknowledgement,"; region="+tutorial.region_id if tutorial.has("region_id") else ""])
	guidance_preview.text="\n".join(lines);status("Guidance preview refreshed with non-color labels")


func show_sequence_editor() -> void:
	if package.scenario==null: status("Create a scenario before authoring sequences"); return
	_refresh_sequence_list(); sequence_dialog.popup_centered(); status("Sequence workspace — typed events, conditions, and actions")


func _refresh_sequence_list() -> void:
	sequence_list.clear()
	if package.scenario==null:return
	var sequences:Array=[];var seen_ids:={}
	for index in package.scenario.data.sequences.size():
		var value=package.scenario.data.sequences[index];var stable_id:=str(value.get("sequence_id","")) if value is Dictionary else "";var valid_id:bool=package.scenario._valid_id(stable_id);var invalid:bool=not value is Dictionary or not valid_id or seen_ids.has(stable_id) or not value.get("event") is Dictionary or not value.get("conditions") is Array or not value.get("actions") is Array or not value.get("enabled") is bool or not value.get("one_shot") is bool
		if valid_id:seen_ids[stable_id]=true
		sequences.append({"index":index,"value":value,"stable_id":stable_id,"invalid":invalid})
	sequences.sort_custom(func(a,b):
		if a.value is Dictionary and not b.value is Dictionary:return true
		if not a.value is Dictionary:return false
		return str(a.value.get("sequence_id",""))<str(b.value.get("sequence_id","")))
	for entry in sequences:
		var sequence=entry.value
		var metadata:={"entity_index":entry.index,"stable_id":entry.stable_id,"invalid":entry.invalid}
		if entry.invalid:sequence_list.add_item("Invalid sequence%s (entry %d) — select Delete Selected Sequence to remove"%[" '%s'"%entry.stable_id if not entry.stable_id.is_empty() else "",entry.index+1]);sequence_list.set_item_metadata(sequence_list.item_count-1,metadata);continue
		sequence_list.add_item("%s  [%s%s]"%[entry.stable_id,"on" if sequence.get("enabled",false) else "off",", once" if sequence.get("one_shot",false) else ""]);sequence_list.set_item_metadata(sequence_list.item_count-1,metadata)


func _selected_sequence_id()->String:
	var selected:=sequence_list.get_selected_items()
	if selected.is_empty():return ""
	var metadata=sequence_list.get_item_metadata(selected[0]);return str(metadata.get("stable_id","")) if metadata is Dictionary else str(metadata)


func _load_sequence(index:int)->void:
	var metadata=sequence_list.get_item_metadata(index);sequence_conditions.clear();sequence_actions.clear()
	if metadata is Dictionary and metadata.get("invalid",false):
		sequence_fields.sequence_id.text=str(metadata.get("stable_id",""));sequence_fields.sequence_id.editable=false;status("Invalid sequence entry selected — Delete Selected Sequence is available");return
	var id:String=str(metadata.get("stable_id","")) if metadata is Dictionary else str(metadata);var sequence:Dictionary=package.scenario._find(package.scenario.data.sequences,"sequence_id",id)
	if sequence.is_empty():status("Sequence entry could not be loaded");return
	sequence_fields.sequence_id.text=id;sequence_fields.sequence_id.editable=false;sequence_fields.enabled.button_pressed=sequence.get("enabled",false);sequence_fields.one_shot.button_pressed=sequence.get("one_shot",false)
	for item in sequence_event_type.item_count:
		if sequence_event_type.get_item_metadata(item)==sequence.get("event",{}).get("type",""):sequence_event_type.select(item)
	_load_typed_references(sequence.get("event",{}))
	for condition in sequence.get("conditions",[]):sequence_conditions.add_item(_typed_summary(condition))
	for action in sequence.get("actions",[]):sequence_actions.add_item(_typed_summary(action))
	_update_sequence_signature("event");status("Selected sequence '%s'"%id)


func _create_sequence()->void:
	if package.scenario==null:return
	var id:String=sequence_fields.sequence_id.text;var event:Dictionary=_event_from_form()
	if package.scenario.add_sequence(id,event,package.world,sequence_fields.enabled.button_pressed,sequence_fields.one_shot.button_pressed):_refresh_sequence_list();refresh_all();status("Created sequence '%s'"%id)
	else:package.errors=package.scenario.errors;show_errors()


func _apply_sequence_event()->void:
	var id:String=_selected_sequence_id();if id.is_empty():status("Select a sequence");return
	if package.scenario.update_sequence(id,{"enabled":sequence_fields.enabled.button_pressed,"one_shot":sequence_fields.one_shot.button_pressed,"event":_event_from_form()},package.world):_refresh_sequence_list();refresh_all();status("Updated sequence event and flags")
	else:package.errors=package.scenario.errors;show_errors()


func _duplicate_sequence()->void:
	var id:String=_selected_sequence_id();if id.is_empty():status("Select a sequence");return
	var new_id:String=id+"_copy";var suffix:=2
	while not package.scenario._find(package.scenario.data.sequences,"sequence_id",new_id).is_empty():new_id="%s_copy_%d"%[id,suffix];suffix+=1
	if package.scenario.duplicate_sequence(id,new_id,package.world):_refresh_sequence_list();refresh_all();status("Duplicated as disabled sequence '%s'"%new_id)
	else:package.errors=package.scenario.errors;show_errors()


func _delete_sequence()->void:
	var selected:=sequence_list.get_selected_items();if selected.is_empty():status("Select a sequence");return
	var metadata=sequence_list.get_item_metadata(selected[0])
	if metadata is Dictionary and metadata.get("invalid",false):
		if package.scenario.remove_invalid_collection_entry("sequences",int(metadata.entity_index),package.world):_refresh_sequence_list();refresh_all();status("Invalid sequence entry removed")
		else:package.errors=package.scenario.errors;show_errors()
		return
	var id:String=_selected_sequence_id();if id.is_empty():status("Select a sequence");return
	if package.scenario.delete_sequence(id,package.world):_refresh_sequence_list();refresh_all();status("Deleted sequence '%s'"%id)
	else:package.errors=package.scenario.errors;show_errors()


func _add_sequence_condition()->void:
	var id:String=_selected_sequence_id();if id.is_empty():status("Select a sequence");return
	if package.scenario.add_sequence_step(id,"conditions",_condition_from_form(),package.world):_reload_sequence_by_id(id);refresh_all();status("Condition added")
	else:package.errors=package.scenario.errors;show_errors()


func _add_sequence_action()->void:
	var id:String=_selected_sequence_id();if id.is_empty():status("Select a sequence");return
	if package.scenario.add_sequence_step(id,"actions",_action_from_form(),package.world):_reload_sequence_by_id(id);refresh_all();status("Action appended")
	else:package.errors=package.scenario.errors;show_errors()


func _remove_sequence_condition()->void:
	var id:String=_selected_sequence_id();var selected:=sequence_conditions.get_selected_items();if id.is_empty() or selected.is_empty():status("Select a condition");return
	if package.scenario.delete_sequence_step(id,"conditions",selected[0],package.world):_reload_sequence_by_id(id);refresh_all()
	else:package.errors=package.scenario.errors;show_errors()


func _remove_sequence_action()->void:
	var id:String=_selected_sequence_id();var selected:=sequence_actions.get_selected_items();if id.is_empty() or selected.is_empty():status("Select an action");return
	if package.scenario.delete_sequence_step(id,"actions",selected[0],package.world):_reload_sequence_by_id(id);refresh_all()
	else:package.errors=package.scenario.errors;show_errors()


func _move_sequence_action(direction:int)->void:
	var id:String=_selected_sequence_id();var selected:=sequence_actions.get_selected_items();if id.is_empty() or selected.is_empty():status("Select an action");return
	if package.scenario.move_sequence_step(id,"actions",selected[0],direction,package.world):_reload_sequence_by_id(id);sequence_actions.select(clampi(selected[0]+direction,0,sequence_actions.item_count-1));refresh_all()
	else:status("Action is already at that edge")


func _reload_sequence_by_id(id:String)->void:
	_refresh_sequence_list()
	for index in sequence_list.item_count:
		var metadata=sequence_list.get_item_metadata(index);var item_id:=str(metadata.get("stable_id","")) if metadata is Dictionary else str(metadata)
		if item_id==id:sequence_list.deselect_all();sequence_list.select(index);_load_sequence(index);return


func _event_from_form()->Dictionary:
	var type:String=sequence_event_type.get_item_metadata(sequence_event_type.selected)
	match type:
		"scenario_start":return {"type":type}
		"unit_enters_region":return {"type":type,"group_id":sequence_fields.a.text,"region_id":sequence_fields.b.text}
		"unit_died":return {"type":type,"group_id":sequence_fields.a.text}
		"objective_changed":return {"type":type,"objective_id":sequence_fields.a.text,"state":sequence_fields.b.text}
		_:return {"type":type,"sequence_id":sequence_fields.a.text}


func _condition_from_form()->Dictionary:
	var type:String=sequence_condition_type.get_item_metadata(sequence_condition_type.selected)
	match type:
		"objective_is":return {"type":type,"objective_id":sequence_fields.a.text,"state":sequence_fields.b.text}
		"group_alive":return {"type":type,"group_id":sequence_fields.a.text,"value":sequence_fields.b.text.to_lower()!="false"}
		"group_owned_by":return {"type":type,"group_id":sequence_fields.a.text,"owner_id":sequence_fields.b.text}
		_:return {"type":type,"sequence_id":sequence_fields.a.text,"value":sequence_fields.b.text.to_lower()!="false"}


func _action_from_form()->Dictionary:
	var type:String=sequence_action_type.get_item_metadata(sequence_action_type.selected)
	match type:
		"show_message":return {"type":type,"message_id":sequence_fields.a.text,"text":sequence_fields.text.text,"duration_s":maxf(0.1,float(sequence_fields.number.text))}
		"show_tutorial":return {"type":type,"tutorial_id":sequence_fields.a.text}
		"set_objective":return {"type":type,"objective_id":sequence_fields.a.text,"state":sequence_fields.b.text}
		"set_objective_step":return {"type":type,"objective_id":sequence_fields.a.text,"step_id":sequence_fields.b.text,"state":sequence_fields.c.text}
		"set_ownership":return {"type":type,"group_id":sequence_fields.a.text,"owner_id":sequence_fields.b.text}
		"order_group":return {"type":type,"group_id":sequence_fields.a.text,"order":sequence_fields.b.text,"target_region_id":sequence_fields.c.text}
		"set_encounter":return {"type":type,"group_id":sequence_fields.a.text,"state":sequence_fields.b.text,"behavior":sequence_fields.c.text,"leash_region_id":sequence_fields.text.text}
		"grant_reward":return {"type":type,"group_id":sequence_fields.a.text,"reward_id":sequence_fields.b.text}
		"play_cinematic":return {"type":type,"cinematic_id":sequence_fields.a.text}
		_:return {"type":type,"result":sequence_fields.a.text}


func _load_typed_references(value:Dictionary)->void:
	var ordered:=[]
	for key in ["group_id","objective_id","tutorial_id","sequence_id","message_id","cinematic_id","result"]:
		if value.has(key):ordered.append(str(value[key]))
	for key in ["step_id","region_id","state","owner_id","reward_id","order"]:
		if value.has(key):ordered.append(str(value[key]))
	for index in 3:sequence_fields[["a","b","c"][index]].text=ordered[index] if index<ordered.size() else ""
	if value.has("text"):sequence_fields.text.text=value.text
	if value.has("duration_s"):sequence_fields.number.text=str(value.duration_s)


func _typed_summary(value)->String:
	if not value is Dictionary:return "Invalid step — delete and recreate this step"
	var details:Array[String]=[]
	for key in value:
		if key!="type":details.append("%s=%s"%[key,value[key]])
	return "%s  %s"%[str(value.type).replace("_"," "),", ".join(details)]


func _update_sequence_signature(kind:String)->void:
	if sequence_signature==null:return
	var signatures:={"event":{"scenario_start":"no references","unit_enters_region":"A=group, B=region","unit_died":"A=group","objective_changed":"A=objective, B=state","sequence_completed":"A=sequence"},"condition":{"objective_is":"A=objective, B=state","group_alive":"A=group, B=true/false","group_owned_by":"A=group, B=owner","sequence_has_run":"A=sequence, B=true/false"},"action":{"show_message":"A=message ID, Text, Number=duration","show_tutorial":"A=tutorial guidance","set_objective":"A=objective, B=state","set_objective_step":"A=objective, B=step, C=active/completed","set_ownership":"A=group, B=owner","order_group":"A=group, B=move/attack_move, C=region","set_encounter":"A=group, B=inactive/active, C=behavior, Text=leash region","grant_reward":"A=group, B=reward","play_cinematic":"A=cinematic","complete_scenario":"A=victory/failure"}}
	var control:OptionButton={"event":sequence_event_type,"condition":sequence_condition_type,"action":sequence_action_type}[kind];var type:String=control.get_item_metadata(control.selected);sequence_signature.text="%s: %s"%[type,signatures[kind][type]]


func _validate_sequence_flow()->void:
	var failures:Array[String]=package.scenario.validate(package.scenario.data,package.world);var notices:Array[String]=package.scenario.flow_diagnostics();validation_list.clear()
	if failures.is_empty() and notices.is_empty():
		validation_summary.text="Ready for Test World — schema, references, and flow checks passed.";validation_list.add_item("PASS — No scenario errors or notices")
	else:
		validation_summary.text="%d error(s), %d notice(s). Select a finding to see where it belongs, then open that workspace."%[failures.size(),notices.size()]
		for message in failures:_add_validation_finding("ERROR",message)
		for message in notices:_add_validation_finding("NOTICE",message)
	validation_dialog.popup_centered();status("Scenario validation passed" if failures.is_empty() and notices.is_empty() else "Scenario validation found items to review")


func _add_validation_finding(severity:String,message:String)->void:
	var workspace:=_validation_workspace(message);var finding:=_validation_route(message,workspace);finding.severity=severity;finding.message=message
	var summary:="%s — %s — %s"%[severity,workspace,_validation_human_message(message,finding)];validation_list.add_item(summary);validation_list.set_item_tooltip(validation_list.item_count-1,"%s\nTechnical detail: %s"%[summary,message]);validation_list.set_item_metadata(validation_list.item_count-1,finding)


func _validation_workspace(message:String)->String:
	var lower:=message.to_lower()
	if "scenario.json.sequences" in lower:return "Sequences"
	if "scenario.json.cinematics" in lower:return "Cinematics"
	if "cinematic" in lower:return "Cinematics"
	if "sequence" in lower:return "Sequences"
	if "tutorial" in lower or "objective" in lower:return "Objectives & Guidance"
	if "encounter" in lower or "unit_groups" in lower or "group" in lower:return "Groups & Encounters"
	return "Scenario & Regions"


func _validation_collection_index(message:String,collection:String)->int:
	var regex:=RegEx.new();regex.compile("\\.%s\\[(\\d+)\\]"%collection);var result:=regex.search(message)
	return -1 if result==null else int(result.get_string(1))


func _validation_route(message:String,workspace:String)->Dictionary:
	var route:={"workspace":workspace}
	if workspace=="Cinematics":
		var index:=_validation_collection_index(message,"cinematics")
		if index>=0:
			route.entity_index=index
			if index<package.scenario.data.cinematics.size():
				var cinematic=package.scenario.data.cinematics[index]
				if cinematic is Dictionary and cinematic.has("cinematic_id"):route.cinematic_id=cinematic.cinematic_id
		var step_index:=_validation_collection_index(message,"steps");if step_index>=0:route.step_index=step_index
	if workspace=="Sequences":
		var index:=_validation_collection_index(message,"sequences")
		if index>=0:
			route.entity_index=index
			if index<package.scenario.data.sequences.size():
				var sequence=package.scenario.data.sequences[index]
				if sequence is Dictionary and sequence.has("sequence_id"):route.sequence_id=sequence.sequence_id
		if not route.has("sequence_id"):
			var named:=RegEx.new();named.compile("[Ss]equence '([^']+)'");var named_match:=named.search(message)
			if named_match!=null:route.sequence_id=named_match.get_string(1)
		if not route.has("sequence_id"):
			var cycle:=RegEx.new();cycle.compile("cycle at '([^']+)'");var cycle_match:=cycle.search(message)
			if cycle_match!=null:route.sequence_id=cycle_match.get_string(1)
		for collection in ["conditions","actions"]:
			var step_index:=_validation_collection_index(message,collection)
			if step_index>=0:route.sequence_collection=collection;route.step_index=step_index
	return route


func _validation_human_message(message:String,finding:Dictionary)->String:
	var location:=""
	if finding.has("cinematic_id"):location="Cinematic '%s'"%finding.cinematic_id
	if finding.has("sequence_id"):location="Sequence '%s'"%finding.sequence_id
	if location.is_empty() and finding.has("entity_index"):location="%s entry %d"%["Cinematic" if finding.workspace=="Cinematics" else "Sequence",int(finding.entity_index)+1]
	if finding.has("step_index"):location+=" — %s %d"%["timeline step" if finding.workspace=="Cinematics" else str(finding.get("sequence_collection","step")).trim_suffix("s"),int(finding.step_index)+1]
	var marker:=message.find(" has ");var detail:=message.substr(marker+5) if marker>=0 else message
	if not location.is_empty() and message.begins_with(location):return message
	return detail if location.is_empty() else "%s: %s"%[location,detail]


func _open_selected_validation_finding()->void:
	var selected:=validation_list.get_selected_items();if selected.is_empty():status("Select a validation finding");return
	var finding=validation_list.get_item_metadata(selected[0]);if not finding is Dictionary:return
	validation_dialog.hide();var message:String=finding.message
	match finding.workspace:
		"Cinematics":
			show_cinematic_editor()
			var row:=_select_validation_entity(cinematic_list,int(finding.get("entity_index",-1))) if finding.has("entity_index") else -1
			if row>=0:_load_cinematic(row)
			elif finding.has("cinematic_id"):_reselect_cinematic(finding.cinematic_id)
			var step_index:=int(finding.get("step_index",-1));var selected_cinematic:=cinematic_list.get_selected_items()
			if step_index>=0 and not selected_cinematic.is_empty() and not cinematic_list.get_item_metadata(selected_cinematic[0]).get("invalid",false) and step_index<cinematic_step_list.item_count:cinematic_step_list.select(step_index);_scrub_cinematic(step_index)
		"Sequences":
			show_sequence_editor()
			var row:=_select_validation_entity(sequence_list,int(finding.get("entity_index",-1))) if finding.has("entity_index") else -1
			if row>=0:_load_sequence(row)
			elif finding.has("sequence_id"):_reload_sequence_by_id(finding.sequence_id)
			var step_index:=int(finding.get("step_index",-1));var collection:=str(finding.get("sequence_collection",""));var selected_sequence:=sequence_list.get_selected_items()
			if not selected_sequence.is_empty() and not sequence_list.get_item_metadata(selected_sequence[0]).get("invalid",false):
				if step_index>=0 and collection=="conditions" and step_index<sequence_conditions.item_count:sequence_conditions.select(step_index)
				if step_index>=0 and collection=="actions" and step_index<sequence_actions.item_count:sequence_actions.select(step_index)
		"Objectives & Guidance":show_guidance_editor()
		"Groups & Encounters":show_encounter_editor()
		_:show_scenario_editor()
	status("Opened %s for: %s"%[finding.workspace,message])


func _select_validation_entity(list:ItemList,entity_index:int)->int:
	for item_index in list.item_count:
		var metadata=list.get_item_metadata(item_index)
		if metadata is Dictionary and metadata.get("entity_index",-1)==entity_index:list.deselect_all();list.select(item_index);return item_index
	return -1


func show_scenario_editor() -> void:
	_refresh_scenario_form(); scenario_dialog.popup_centered(); status("Scenario workspace — details and world-space regions")


func _refresh_scenario_form() -> void:
	scenario_region_list.clear()
	var scenario = package.scenario
	if scenario == null:
		scenario_fields.scenario_id.text = ""
		scenario_fields.title.text = ""
		scenario_fields.description.text = ""
		scenario_fields.player_faction_id.text = "frontier_company"
		scenario_fields.fog_enabled.text="true";scenario_fields.explored_radius_m.text="8";scenario_fields.hidden_by_default.text="true"
		return
	scenario_fields.scenario_id.text = scenario.data.scenario_id; scenario_fields.title.text = scenario.data.title; scenario_fields.description.text = scenario.data.description; scenario_fields.player_faction_id.text = scenario.data.player_faction_id
	var visibility:Dictionary=scenario.data.get("visibility",{"fog_enabled":true,"explored_radius_m":8,"hidden_by_default":true});scenario_fields.fog_enabled.text=str(visibility.fog_enabled);scenario_fields.explored_radius_m.text=str(visibility.explored_radius_m);scenario_fields.hidden_by_default.text=str(visibility.hidden_by_default)
	var regions: Array = scenario.data.regions.duplicate(); regions.sort_custom(func(a,b): return a.region_id < b.region_id)
	for region in regions:
		scenario_region_list.add_item("%s  [%s]  %s" % [region.display_name, region.shape, region.region_id]); scenario_region_list.set_item_metadata(scenario_region_list.item_count - 1, region.region_id)


func _create_scenario() -> void:
	if package.scenario != null: status("This world already has a scenario document"); return
	var scenario = ScenarioDocumentScript.new(); var scenario_id := str(package.world.get("world_id", "world")) + "_guided_tutorial"
	if scenario.create(scenario_id, "Crimsdale Guided Tutorial", "A guided hero-and-squad journey through Crimsdale.", "frontier_company", package.world):
		package.set_scenario(scenario);_refresh_scenario_form();refresh_all();status("Created scenario '%s'"%scenario_id)
	else: package.errors = scenario.errors; show_errors()


func _create_guided_mission_template()->void:
	if package.scenario!=null:status("Remove the existing scenario before applying a guided mission template");return
	var scenario=ScenarioDocumentScript.new();var scenario_id:=str(package.world.get("world_id","world"))+"_guided_mission"
	if scenario.create_guided_mission_template(scenario_id,package.world,package.definitions,package.terrain):package.set_scenario(scenario);_refresh_scenario_form();refresh_all();status("Guided mission template created — review its generic roles and checkpoints")
	else:package.errors=scenario.errors;show_errors()


func _apply_scenario_metadata() -> void:
	if package.scenario == null: status("Create a scenario first"); return
	if package.scenario.update_metadata(scenario_fields.title.text, scenario_fields.description.text, scenario_fields.player_faction_id.text, package.world) and package.scenario.update_visibility(scenario_fields.fog_enabled.text.to_lower()=="true",float(scenario_fields.explored_radius_m.text),scenario_fields.hidden_by_default.text.to_lower()=="true",package.world): refresh_all(); status("Scenario details and visibility updated")
	else: package.errors = package.scenario.errors; show_errors()


func _remove_scenario() -> void:
	if package.remove_scenario():_refresh_scenario_form();refresh_all();status("Scenario removed; save to commit removal")


func request_remove_scenario() -> void:
	scenario_remove_armed = package.scenario != null
	if scenario_remove_armed: scenario_remove_confirmation.popup_centered()


func _confirm_remove_scenario() -> void:
	if not scenario_remove_armed:
		return
	scenario_remove_armed = false
	_remove_scenario()


func _scenario_points() -> Array:
	var first := Vector3(float(scenario_region_fields.x1.text), 0, float(scenario_region_fields.z1.text)); var second := Vector3(float(scenario_region_fields.x2.text), 0, float(scenario_region_fields.z2.text))
	if package.terrain != null:
		first.y = package.terrain.sample_height(first.x, first.z); second.y = package.terrain.sample_height(second.x, second.z)
	var shape: String = scenario_region_shape.get_item_metadata(scenario_region_shape.selected)
	return [[first.x,first.y,first.z]] if shape == "point" else [[first.x,first.y,first.z],[second.x,second.y,second.z]]


func _add_scenario_region() -> void:
	if package.scenario == null: status("Create a scenario first"); return
	var shape: String = scenario_region_shape.get_item_metadata(scenario_region_shape.selected)
	if package.scenario.add_region(scenario_region_fields.region_id.text, scenario_region_fields.display_name.text, shape, _scenario_points(), package.world): _refresh_scenario_form(); refresh_all(); status("Added %s region '%s'" % [shape,scenario_region_fields.region_id.text])
	else: package.errors = package.scenario.errors; show_errors()


func _selected_scenario_region_id() -> String:
	var selected := scenario_region_list.get_selected_items(); return "" if selected.is_empty() else scenario_region_list.get_item_metadata(selected[0])


func _load_scenario_region(index: int) -> void:
	var region: Dictionary = package.scenario.find_region(scenario_region_list.get_item_metadata(index)); scenario_region_fields.region_id.text = region.region_id; scenario_region_fields.region_id.editable = false; scenario_region_fields.display_name.text = region.display_name
	for shape_index in scenario_region_shape.item_count:
		if scenario_region_shape.get_item_metadata(shape_index) == region.shape: scenario_region_shape.select(shape_index)
	scenario_region_fields.x1.text = str(region.points[0][0]); scenario_region_fields.z1.text = str(region.points[0][2]); var last: Array = region.points[-1]; scenario_region_fields.x2.text = str(last[0]); scenario_region_fields.z2.text = str(last[2])
	status("Selected %s region '%s'" % [region.shape,region.region_id])


func _update_scenario_region() -> void:
	var id := _selected_scenario_region_id(); if id.is_empty(): status("Select a region to update"); return
	var shape: String = scenario_region_shape.get_item_metadata(scenario_region_shape.selected)
	if package.scenario.update_region(id, {"display_name":scenario_region_fields.display_name.text,"shape":shape,"points":_scenario_points()}, package.world): _refresh_scenario_form(); refresh_all(); status("Updated region '%s'" % id)
	else: package.errors = package.scenario.errors; show_errors()


func _reverse_scenario_path() -> void:
	var id := _selected_scenario_region_id(); if id.is_empty(): status("Select a path region"); return
	if package.scenario.reverse_path(id, package.world): _refresh_scenario_form(); refresh_all(); status("Reversed path '%s'" % id)
	else: package.errors = package.scenario.errors; show_errors()


func _delete_scenario_region() -> void:
	var id := _selected_scenario_region_id(); if id.is_empty(): status("Select a region to delete"); return
	if package.scenario.delete_region(id, package.world): _refresh_scenario_form(); refresh_all(); status("Deleted region '%s'" % id)
	else: package.errors = package.scenario.errors; show_errors()


func apply_environment_preview()->void:
	if DisplayServer.get_name()=="headless" or package.terrain==null:return
	var world_environment:WorldEnvironment=world_root.get_node("EnvironmentPreview");var sun:DirectionalLight3D=world_root.get_node("SunPreview")
	if not environment_preview_enabled:world_environment.environment=null;sun.visible=false;return
	world_environment.environment=world_environment.get_meta("preview_environment");sun.visible=true
	var probe:Dictionary=TerrainEnvironmentScript.new(package.terrain).parity_probe();var env:Environment=world_environment.environment
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=probe.ambient_color;env.ambient_light_energy=probe.ambient_energy
	env.fog_enabled=probe.fog_enabled;env.fog_light_color=probe.fog_color;env.fog_density=probe.fog_density;env.fog_depth_begin=probe.fog_start_m;env.fog_depth_end=probe.fog_end_m
	var sky_entry:Dictionary={}
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://content/crimsdale/terrain_skies.json"))
	for item in catalog.get("skies",[]):
		if item.sky_id==probe.sky_id:sky_entry=item
	if not sky_entry.is_empty():env.background_color=Color(float(sky_entry.sky_color_linear[0]),float(sky_entry.sky_color_linear[1]),float(sky_entry.sky_color_linear[2]))
	sun.rotation_degrees=probe.sun_rotation_degrees;sun.light_color=probe.sun_color;sun.light_energy=probe.sun_energy


func refresh_all() -> void:
	_track_history_changes()
	refresh_palette()
	refresh_world()
	refresh_inspector()
	refresh_definition_list()
	refresh_terrain_preview()
	refresh_scenario_regions()
	apply_environment_preview()
	dirty_label.text = "Unsaved changes" if package.dirty or package.scenario_removed or (package.terrain != null and package.terrain.dirty) or (package.scenario != null and package.scenario.dirty) else "Saved"


func refresh_scenario_regions() -> void:
	var existing := world_root.get_node_or_null("ScenarioRegions")
	if existing != null: existing.free()
	if package.scenario == null: return
	var root_3d := Node3D.new(); root_3d.name = "ScenarioRegions"; root_3d.set_meta("overlay_label", "Scenario Regions"); world_root.add_child(root_3d)
	for region in package.scenario.data.regions:
		var marker := MeshInstance3D.new(); marker.name = region.region_id
		var material := StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; material.albedo_color = Color(0.2,0.85,1.0,0.45)
		if region.shape == "point":
			var sphere := SphereMesh.new(); sphere.radius = 0.45; sphere.height = 0.9; marker.mesh = sphere; marker.position = array_to_vector(region.points[0]) + Vector3.UP * 0.5
		elif region.shape == "rectangle":
			var first := array_to_vector(region.points[0]); var second := array_to_vector(region.points[1]); var box := BoxMesh.new(); box.size = Vector3(maxf(absf(second.x-first.x),0.2),0.12,maxf(absf(second.z-first.z),0.2)); marker.mesh = box; marker.position = (first+second)/2.0 + Vector3.UP*0.08
		else:
			var line := ImmediateMesh.new(); line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for point in region.points: line.surface_add_vertex(array_to_vector(point)+Vector3.UP*0.15)
			line.surface_end(); marker.mesh = line
		marker.material_override = material; root_3d.add_child(marker)
		var label := Label3D.new(); label.text = "%s\n[%s]" % [region.display_name,region.shape]; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test = true; label.position = array_to_vector(region.points[0]) + Vector3.UP; root_3d.add_child(label)


func refresh_terrain_preview() -> void:
	var existing := world_root.get_node_or_null("TerrainPreview")
	if existing != null:
		existing.free()
	var ground := world_root.get_node_or_null("Ground")
	if ground != null:
		ground.visible = package.terrain == null
	if package.terrain == null:
		return
	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "TerrainPreview"
	terrain_mesh.set_meta("terrain_preview", true)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var colors := PackedColorArray()
	var grid: Dictionary = package.terrain.data.grid
	var surface_colors := {}
	for entry in _load_surface_catalog():
		surface_colors[entry.surface_id] = Color(entry.preview_color_srgb)
	var layer_ids: Array = package.terrain.data.surfaces.layer_ids
	var weights: Array = surface_painter.preview_weights if surface_painter != null and surface_painter.active else package.terrain.data.surfaces.weights
	var cliff_tools = TerrainCliffWaterScript.new(package.terrain)
	for z in int(grid.depth_cells):
		for x in int(grid.width_cells):
			var cell_index := z * int(grid.width_cells) + x
			var blended := Color(0, 0, 0, 1)
			for layer in layer_ids.size():
				blended += surface_colors.get(layer_ids[layer], Color.MAGENTA) * (float(weights[cell_index * layer_ids.size() + layer]) / 255.0)
			blended.a = 1.0
			var x0 := float(grid.origin_x_m) + x * float(grid.cell_size_m)
			var x1 := x0 + float(grid.cell_size_m)
			var z0 := float(grid.origin_z_m) + z * float(grid.cell_size_m)
			var z1 := z0 + float(grid.cell_size_m)
			var surface_heights:Array[float]=_terrain_preview_corner_heights(x,z)
			var corners: Array[Vector3] = []
			for corner in 4:
				var px := x0 if corner < 2 else x1
				var pz := z0 if corner % 2 == 0 else z1
				corners.append(Vector3(px,surface_heights[corner],pz))
			_append_mesh_quad(vertices, colors, indices, corners[0], corners[1], corners[2], corners[3], blended)
			if x + 1 < int(grid.width_cells) and not cliff_tools.edge_has_ramp(x, z, "east"):
				var east_heights:Array[float]=_terrain_preview_corner_heights(x+1,z)
				if not is_equal_approx(corners[2].y,east_heights[0]) or not is_equal_approx(corners[3].y,east_heights[1]):
					_append_mesh_quad(vertices,colors,indices,corners[2],corners[3],Vector3(corners[2].x,east_heights[0],corners[2].z),Vector3(corners[3].x,east_heights[1],corners[3].z),Color("686761"))
			if z + 1 < int(grid.depth_cells) and not cliff_tools.edge_has_ramp(x, z, "south"):
				var south_heights:Array[float]=_terrain_preview_corner_heights(x,z+1)
				if not is_equal_approx(corners[1].y,south_heights[0]) or not is_equal_approx(corners[3].y,south_heights[2]):
					_append_mesh_quad(vertices,colors,indices,corners[1],corners[3],Vector3(corners[1].x,south_heights[0],corners[1].z),Vector3(corners[3].x,south_heights[2],corners[3].z),Color("686761"))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	terrain_mesh.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	terrain_mesh.material_override = material
	world_root.add_child(terrain_mesh)
	refresh_water_preview()
	refresh_workflow_overlay()


func _terrain_preview_corner_heights(x:int,z:int)->Array[float]:
	var grid:Dictionary=package.terrain.data.grid;var sample_width:=int(grid.width_cells)+1;var height_indices:=[z*sample_width+x,(z+1)*sample_width+x,z*sample_width+x+1,(z+1)*sample_width+x+1];var preview_heights_cm:Array=[]
	for height_index in height_indices:
		preview_heights_cm.append(sculptor.preview_height_cm(height_index) if sculptor!=null and sculptor.active else int(grid.heights_cm[height_index]))
	return package.terrain.cell_corner_heights(x,z,preview_heights_cm)


func _append_mesh_quad(vertices: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, north_west: Vector3, south_west: Vector3, north_east: Vector3, south_east: Vector3, color: Color) -> void:
	var start := vertices.size()
	vertices.append_array([north_west, south_west, north_east, south_east])
	for ignored in 4: colors.append(color)
	indices.append_array([start, start + 1, start + 2, start + 2, start + 1, start + 3])


func refresh_water_preview() -> void:
	var existing := world_root.get_node_or_null("WaterPreview")
	if existing != null: existing.free()
	if package.terrain == null or not package.terrain.data.water.enabled:
		return
	var tools = TerrainCliffWaterScript.new(package.terrain)
	var grid: Dictionary = package.terrain.data.grid
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var y := float(package.terrain.data.water.level_cm) / 100.0 + 0.02
	for z in int(grid.depth_cells):
		for x in int(grid.width_cells):
			var water_class := tools.water_class_at_cell(x, z)
			if water_class == "dry": continue
			var start := vertices.size()
			var x0 := float(grid.origin_x_m) + x * float(grid.cell_size_m)
			var z0 := float(grid.origin_z_m) + z * float(grid.cell_size_m)
			var x1 := x0 + float(grid.cell_size_m)
			var z1 := z0 + float(grid.cell_size_m)
			vertices.append_array([Vector3(x0,y,z0), Vector3(x0,y,z1), Vector3(x1,y,z0), Vector3(x1,y,z1)])
			var color := Color(0.20,0.65,0.82,0.48) if water_class == "shallow" else Color(0.08,0.25,0.55,0.62)
			for ignored in 4: colors.append(color)
			indices.append_array([start,start+1,start+2,start+2,start+1,start+3])
	if vertices.is_empty(): return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var preview := MeshInstance3D.new()
	preview.name = "WaterPreview"
	preview.mesh = mesh
	preview.set_meta("shore_count", tools.derived_shores().size())
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview.material_override = material
	world_root.add_child(preview)


func refresh_palette() -> void:
	for child in palette_content.get_children():
		child.free()
	refresh_palette_summary()
	if palette_collapsed:
		return
	match palette_last_page:
		"Terrain":
			_add_button(palette_content, "Select / Copy / Move / Paste", show_workflow_editor)
			_add_button(palette_content, "Terrain Grid", show_terrain_editor)
			_add_button(palette_content, "Sculpt", toggle_sculpt_mode)
			_add_button(palette_content, "Surface Layers", show_surface_editor)
			_add_button(palette_content, "Cliffs & Water", show_cliff_water_editor)
			_add_button(palette_content, "Pathing", show_pathing_editor)
			var note := Label.new()
			note.text = "T1 previews logical surface weights; textured terrain rendering arrives in T2."
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			palette_content.add_child(note)
			return
		"Regions":
			_add_button(palette_content, "Open Region Authoring", show_scenario_editor)
			var note := Label.new()
			note.text = "Region data stays visible as an independently labelled viewport overlay."
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			palette_content.add_child(note)
			return
		"Mission":
			_add_button(palette_content, "Open Mission Authoring", show_scenario_editor)
			_add_button(palette_content, "Test World ▶", test_world)
			var note := Label.new()
			note.text = "Mission tools use authored definitions and world data; the palette does not create runtime coupling."
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			palette_content.add_child(note)
			return
	var search := LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "Search %s" % palette_last_page.to_lower()
	search.accessibility_name = search.placeholder_text
	palette_content.add_child(search)
	var list := VBoxContainer.new()
	list.name = "Definitions"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_content.add_child(list)
	for category in WorldPackageScript.CATEGORIES:
		if palette_last_page == "Units" and category != "unit": continue
		if palette_last_page == "Props" and category in ["unit", "ability"]: continue
		var heading := Label.new()
		heading.text = category.to_upper()
		list.add_child(heading)
		for definition in package.definitions:
			if definition.category == category:
				var button := Button.new()
				button.text = definition.display_name
				button.tooltip_text = definition.definition_id
				button.pressed.connect(start_placement.bind(definition.definition_id))
				list.add_child(button)
	if palette_last_page == "Units":
		var spawn_heading := Label.new()
		spawn_heading.text = "SPAWN POINTS"
		list.add_child(spawn_heading)
		var spawn_button := Button.new()
		spawn_button.text = "Player Start"
		spawn_button.tooltip_text = "Place or move player_start"
		spawn_button.pressed.connect(start_placement.bind("__player_start"))
		list.add_child(spawn_button)
	search.text_changed.connect(func(query):
		for control in list.get_children():
			if control is Button:
				control.visible = query.is_empty() or query.to_lower() in control.text.to_lower() or query.to_lower() in control.tooltip_text.to_lower()
	)


func refresh_world() -> void:
	if world_root == null:
		return
	for child in world_root.get_children():
		if child.has_meta("authored_preview"):
			child.free()
	for instance in package.world.get("objects", []):
		world_root.add_child(make_preview(instance))
	for spawn in package.world.get("spawn_points", []):
		world_root.add_child(make_spawn_preview(spawn))


func make_preview(instance: Dictionary) -> StaticBody3D:
	var definition := package.find_definition(instance.definition_id)
	var body := StaticBody3D.new()
	body.name = instance.instance_id
	body.set_meta("authored_preview", true)
	body.set_meta("instance_id", instance.instance_id)
	body.collision_layer = 1
	body.position = array_to_vector(instance.position)
	body.rotation_degrees.y = instance.rotation_y
	if DisplayServer.get_name() == "headless":
		return body
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	var height := 3.2 if definition.get("category") == "building" else 1.6
	box.size = Vector3(2.8, height, 2.8)
	var material := StandardMaterial3D.new()
	var scene_path: String = definition.get("scene_path", "")
	material.albedo_color = definition_color(definition.get("category", "")) if ResourceLoader.exists(scene_path) else Color("d34a87")
	if instance.instance_id == selected_instance_id:
		material.emission_enabled = true
		material.emission = Color("ffd166")
		material.emission_energy_multiplier = 0.7
	box.material = material
	mesh_instance.mesh = box
	mesh_instance.position.y = height / 2.0
	if ResourceLoader.exists(scene_path):
		var resource = load(scene_path)
		var authored_visual = resource.instantiate() if resource is PackedScene else null
		if authored_visual is Node3D:
			body.add_child(authored_visual)
		else:
			body.add_child(mesh_instance)
	else:
		body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	collision.position.y = height / 2.0
	body.add_child(collision)
	return body


func make_spawn_preview(spawn: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = spawn.spawn_id
	root.set_meta("authored_preview", true)
	root.position = array_to_vector(spawn.position)
	root.rotation_degrees.y = spawn.rotation_y
	if DisplayServer.get_name() == "headless":
		return root
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.7
	cylinder.height = 1.8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("56cfe1")
	cylinder.material = material
	mesh_instance.mesh = cylinder
	mesh_instance.position.y = 0.9
	root.add_child(mesh_instance)
	return root


func refresh_inspector() -> void:
	for child in inspector_content.get_children():
		if child.name != "Title":
			child.free()
	var instance := package.find_instance(selected_instance_id)
	if instance.is_empty():
		var empty := Label.new()
		empty.text = "Nothing selected."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		inspector_content.add_child(empty)
		return
	var definition := package.find_definition(instance.definition_id)
	for text in ["Instance: " + instance.instance_id, "Definition: " + instance.definition_id, definition.get("display_name", "Unknown")]:
		var label := Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_content.add_child(label)
	var position := array_to_vector(instance.position)
	var fields := {}
	for item in [["X", position.x], ["Y", position.y], ["Z", position.z], ["Yaw", instance.rotation_y]]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = item[0]
		label.custom_minimum_size.x = 42
		row.add_child(label)
		var spin := SpinBox.new()
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.step = 0.1
		spin.value = item[1]
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spin)
		fields[item[0]] = spin
		inspector_content.add_child(row)
	_add_button(inspector_content, "Apply Transform", func():
		package.update_instance(selected_instance_id, Vector3(fields.X.value, fields.Y.value, fields.Z.value), fields.Yaw.value)
		refresh_all()
	)
	_add_button(inspector_content, "Rotate 15°", func():
		package.update_instance(selected_instance_id, position, instance.rotation_y + 15.0)
		refresh_all()
	)
	_add_button(inspector_content, "Delete Instance", func():
		package.delete_instance(selected_instance_id)
		selected_instance_id = ""
		refresh_all()
	)


func _on_viewport_input(event: InputEvent) -> void:
	if terrain_tool_mode == "workflow" and workflow_dialog.visible and _handle_workflow_viewport_input(event):
		return
	if pathing_enabled and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		var point:=ground_position(event.position)
		if event.pressed:pathing.begin_paint(pathing_layer.get_item_metadata(pathing_layer.selected),pathing_blocked.button_pressed,Vector2(point.x,point.z),pathing_radius.value)
		else:
			pathing.commit_paint();pathing.rebuild_overlay(pathing_layer.get_item_metadata(pathing_layer.selected));refresh_pathing_overlay();refresh_all()
		return
	if not cliff_mode.is_empty() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		apply_cliff_at(event.position)
		return
	if surface_enabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		viewport_container.grab_focus()
		mouse_position = event.position
		var point := ground_position(event.position)
		if event.pressed:
			surface_painter.begin(surface_layers.selected, Vector2(point.x, point.z), {"radius_m": surface_radius.value, "opacity": surface_opacity.value, "falloff": surface_falloff.get_item_metadata(surface_falloff.selected), "erase": surface_erase.button_pressed})
		else:
			if surface_painter.commit():
				status("Surface stroke committed")
			else:
				package.errors = package.terrain.errors
				show_errors()
			refresh_all()
		return
	if sculpt_enabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		viewport_container.grab_focus()
		mouse_position = event.position
		var point := ground_position(event.position)
		if event.pressed:
			var selected_tool: String = sculpt_tool.get_item_metadata(sculpt_tool.selected)
			var parameters := _sculpt_parameters()
			if sculpt_sample_target.button_pressed:
				if workflow == null: workflow = TerrainWorkflowScript.new(package.terrain)
				workflow.height_snap_cm = int(workflow_fields.height_snap.value)
				parameters.target_height_cm = workflow.snapped_height_cm(roundi(package.terrain.sample_height(point.x, point.z) * 100.0))
			sculptor.begin(selected_tool, Vector2(point.x, point.z), parameters)
			refresh_terrain_preview()
		else:
			if sculptor.commit():
				status("Sculpt stroke committed")
			else:
				package.errors = package.terrain.errors
				show_errors()
			refresh_all()
		return
	if event is InputEventMouseMotion:
		mouse_position = event.position
		if pathing_enabled and pathing!=null and pathing.painting and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
			var point:=ground_position(event.position);pathing.extend_paint(Vector2(point.x,point.z))
		elif sculpt_enabled:
			_update_brush_preview(event.position)
			if sculptor != null and sculptor.active and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				var point := ground_position(event.position)
				sculptor.extend(Vector2(point.x, point.z))
				refresh_terrain_preview()
		elif surface_enabled:
			_update_brush_preview(event.position)
			if surface_painter != null and surface_painter.active and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				var point := ground_position(event.position)
				surface_painter.extend(Vector2(point.x, point.z))
				refresh_terrain_preview()
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			if event.shift_pressed:
				var right := camera.global_basis.x
				var forward := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized()
				orbit_target += (-right * event.relative.x + forward * event.relative.y) * orbit_distance * 0.002
			else:
				orbit_yaw -= event.relative.x * 0.01
				orbit_pitch = clamp(orbit_pitch - event.relative.y * 0.01, -1.45, -0.15)
			update_camera()
		if placement_ghost != null:
			placement_ghost.position = ground_position(event.position)
	elif event is InputEventMouseButton and event.pressed:
		viewport_container.grab_focus()
		mouse_position = event.position
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_distance = max(5.0, orbit_distance - 2.0)
			update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance = min(80.0, orbit_distance + 2.0)
			update_camera()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not placement_definition_id.is_empty():
				if placement_definition_id == "__player_start":
					package.set_player_start(ground_position(event.position), placement_rotation)
					selected_instance_id = ""
				else:
					selected_instance_id = package.place_instance(placement_definition_id, ground_position(event.position), placement_rotation)
				refresh_all()
				if placement_definition_id == "__player_start":
					cancel_placement()
					status("Placed player_start")
				else:
					start_placement(placement_definition_id)
			elif moving_instance and not selected_instance_id.is_empty():
				var instance := package.find_instance(selected_instance_id)
				package.update_instance(selected_instance_id, ground_position(event.position), instance.rotation_y)
				moving_instance = false
				terrain_tool_mode = "selection"
				terrain_mode_label.text = "Mode: Selection"
				status("Moved '%s'" % selected_instance_id)
				refresh_all()
			else:
				select_at(event.position)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			moving_instance = false
			_set_terrain_tool("selection", "Selection tool")
		elif sculpt_enabled and event.keycode >= KEY_1 and event.keycode <= KEY_6:
			sculpt_tool.select(int(event.keycode - KEY_1))
			status("Sculpt tool: %s" % sculpt_tool.get_item_text(sculpt_tool.selected))
		elif event.keycode == KEY_G and not selected_instance_id.is_empty():
			_set_terrain_tool("selection")
			moving_instance = true
			terrain_tool_mode = "move"
			terrain_mode_label.text = "Mode: Move"
			status("Move: click a ground position or Escape to cancel")
		elif event.keycode == KEY_Q and not placement_definition_id.is_empty():
			placement_rotation -= 15.0
			update_ghost_rotation()
		elif event.keycode == KEY_E and not placement_definition_id.is_empty():
			placement_rotation += 15.0
			update_ghost_rotation()


func _handle_workflow_viewport_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S:
			_workflow_begin_selection(); return true
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_workflow_confirm(); return true
		if event.keycode == KEY_ESCAPE:
			_workflow_cancel(); return true
		if event.keycode == KEY_F:
			_workflow_sample(); return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		viewport_container.grab_focus()
		var cell: Vector2i = workflow.world_to_cell(ground_position(event.position))
		if event.pressed:
			if workflow_sampling:
				_workflow_sample_cell(cell)
				return true
			if not workflow_pending_preview.is_empty():
				_workflow_update_preview(str(workflow_pending_preview.operation), cell)
				return true
			if workflow_select_armed:
				workflow_drag_start = cell
				workflow_dragging = true
				workflow.select_cells(cell, cell)
				_workflow_sync_source_fields(workflow.selection)
				refresh_workflow_overlay()
				return true
		elif workflow_dragging:
			workflow.select_cells(workflow_drag_start, cell)
			workflow_dragging = false
			workflow_select_armed = false
			workflow_selection_before_gesture = Rect2i()
			_workflow_sync_source_fields(workflow.selection)
			refresh_workflow_overlay()
			refresh_palette_summary()
			status("Selected %d × %d cells; Copy or Move is ready" % [workflow.selection.size.x, workflow.selection.size.y])
			return true
	if event is InputEventMouseMotion:
		if workflow_dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var cell: Vector2i = workflow.world_to_cell(ground_position(event.position))
			workflow.select_cells(workflow_drag_start, cell)
			_workflow_sync_source_fields(workflow.selection)
			refresh_workflow_overlay()
			return true
		if not workflow_pending_preview.is_empty() and not (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
			var cell: Vector2i = workflow.world_to_cell(ground_position(event.position))
			if cell != workflow_pending_preview.requested.position:
				_workflow_update_live_destination(str(workflow_pending_preview.operation), cell)
	return false


func select_at(screen_position: Vector2) -> void:
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var result := viewport.world_3d.direct_space_state.intersect_ray(query)
	selected_instance_id = result.collider.get_meta("instance_id", "") if result.has("collider") else ""
	refresh_world()
	refresh_inspector()


func ground_position(screen_position: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if abs(direction.y) < 0.0001:
		return Vector3.ZERO
	if package.terrain != null:
		var terrain_hit := _ray_terrain_position(from, direction)
		if terrain_hit.get("hit", false): return terrain_hit.position
	var distance := maxf(-from.y / direction.y, 0.0)
	var point: Vector3 = from + direction * distance
	if package.terrain != null:
		point.y = package.terrain.effective_height(point.x, point.z)
	return point


func _ray_terrain_position(from: Vector3, direction: Vector3) -> Dictionary:
	var grid: Dictionary = package.terrain.data.grid
	var west := float(grid.origin_x_m)
	var north := float(grid.origin_z_m)
	var east := west + int(grid.width_cells) * float(grid.cell_size_m)
	var south := north + int(grid.depth_cells) * float(grid.cell_size_m)
	var step := maxf(0.1, float(grid.cell_size_m) * 0.25)
	var previous_t := 0.0
	var previous_difference := INF
	var previous_valid := false
	var distance := 0.0
	while distance <= 1000.0:
		var point := from + direction * distance
		var valid := point.x >= west and point.x <= east and point.z >= north and point.z <= south
		if valid:
			var height: float = package.terrain.effective_height(point.x, point.z)
			var difference := point.y - height
			if difference <= 0.0:
				if not previous_valid:
					return {"hit": true, "position": Vector3(point.x, height, point.z)}
				var low := previous_t
				var high := distance
				for ignored in 12:
					var middle := (low + high) * 0.5
					var middle_point := from + direction * middle
					var middle_height: float = package.terrain.effective_height(middle_point.x, middle_point.z)
					if middle_point.y - middle_height > 0.0: low = middle
					else: high = middle
				var hit := from + direction * high
				hit.y = package.terrain.effective_height(hit.x, hit.z)
				return {"hit": true, "position": hit}
			previous_difference = difference
			previous_t = distance
			previous_valid = true
		elif previous_valid and previous_difference > 0.0:
			break
		distance += step
	return {"hit": false}


func start_placement(definition_id: String) -> void:
	_set_terrain_tool("selection")
	placement_definition_id = definition_id
	terrain_tool_mode = "placement"
	terrain_mode_label.text = "Mode: Placement"
	placement_ghost = MeshInstance3D.new()
	placement_ghost.name = "PlacementGhost"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.8, 1.2, 2.8)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.8, 0.55, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	placement_ghost.mesh = mesh
	placement_ghost.position = ground_position(mouse_position) + Vector3(0, 0.6, 0)
	world_root.add_child(placement_ghost)
	status("Player start: click to place, Q/E rotate, Escape cancel" if definition_id == "__player_start" else "Placement: click to place, Q/E rotate, Escape cancel")


func cancel_placement() -> void:
	placement_definition_id = ""
	if placement_ghost != null:
		placement_ghost.queue_free()
		placement_ghost = null
	if terrain_tool_mode == "placement":
		terrain_tool_mode = "selection"
		if terrain_mode_label != null:
			terrain_mode_label.text = "Mode: Selection"
	status("Selection tool")


func update_ghost_rotation() -> void:
	if placement_ghost != null:
		placement_ghost.rotation_degrees.y = placement_rotation


func update_camera() -> void:
	if camera == null:
		return
	var offset := Vector3(
		cos(orbit_pitch) * sin(orbit_yaw),
		-sin(orbit_pitch),
		cos(orbit_pitch) * cos(orbit_yaw)
	) * orbit_distance
	camera.position = orbit_target + offset
	camera.look_at(orbit_target)


func _build_object_editor() -> void:
	object_dialog = Window.new()
	object_dialog.title = "Object Editor"
	object_dialog.size = Vector2i(900, 600)
	object_dialog.close_requested.connect(object_dialog.hide)
	object_dialog.visible = false
	add_child(object_dialog)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 12
	root.offset_right = -12
	root.offset_bottom = -12
	object_dialog.add_child(root)
	var navigation := VBoxContainer.new()
	navigation.custom_minimum_size.x = 330
	root.add_child(navigation)
	var search := LineEdit.new()
	search.placeholder_text = "Search definitions"
	search.accessibility_name = "Search object definitions"
	navigation.add_child(search)
	definition_list = ItemList.new()
	definition_list.accessibility_name = "Object definitions"
	definition_list.custom_minimum_size.x = 330
	definition_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	definition_list.item_selected.connect(load_definition_form)
	navigation.add_child(definition_list)
	search.text_changed.connect(filter_definition_list)
	var form_scroll := ScrollContainer.new()
	form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(form_scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_scroll.add_child(form)
	definition_id_field = _add_labeled_field(form, "Stable definition ID")
	definition_name = _add_labeled_field(form, "Display name")
	definition_category = OptionButton.new()
	for category in WorldPackageScript.CATEGORIES:
		definition_category.add_item(category)
	_label_control(form,"Category",definition_category);form.add_child(definition_category)
	definition_category.item_selected.connect(func(_index): refresh_unit_field_visibility())
	definition_scene = _add_labeled_field(form, "Scene path")
	var unit_heading := Label.new()
	unit_heading.text = "UNIT GAMEPLAY"
	form.add_child(unit_heading)
	unit_section_controls.append(unit_heading)
	definition_owner = OptionButton.new()
	for owner in WorldPackageScript.OWNERS:
		definition_owner.add_item(owner)
	var owner_label:=_label_control(form,"Owner",definition_owner);form.add_child(definition_owner)
	unit_section_controls.append(owner_label);unit_section_controls.append(definition_owner)
	for field in WorldPackageScript.UNIT_FIELDS:
		if field != "owner":
			unit_fields[field] = _add_labeled_field(form, field.replace("_", " ").capitalize())
			unit_section_controls.append(_field_row(unit_fields[field]))
	var hero_heading:=Label.new();hero_heading.text="HERO, ABILITIES & INVENTORY";form.add_child(hero_heading);hero_section_controls.append(hero_heading)
	for field in WorldPackageScript.HERO_FIELDS:hero_fields[field]=_add_labeled_field(form,field.replace("_"," ").capitalize());hero_section_controls.append(_field_row(hero_fields[field]))
	var ability_heading:=Label.new();ability_heading.text="ABILITY";form.add_child(ability_heading);ability_section_controls.append(ability_heading)
	for field in WorldPackageScript.ABILITY_FIELDS:ability_fields[field]=_add_labeled_field(form,field.replace("_"," ").capitalize());ability_section_controls.append(_field_row(ability_fields[field]))
	var item_heading:=Label.new();item_heading.text="ITEM REWARD";form.add_child(item_heading);item_section_controls.append(item_heading)
	for field in WorldPackageScript.ITEM_FIELDS:item_fields[field]=_add_labeled_field(form,field.replace("_"," ").capitalize());item_section_controls.append(_field_row(item_fields[field]))
	_add_button(form,"Preview Gameplay Definition",_preview_gameplay_definition)
	definition_gameplay_preview=RichTextLabel.new();definition_gameplay_preview.fit_content=true;definition_gameplay_preview.custom_minimum_size.y=80;form.add_child(definition_gameplay_preview)
	_add_button(form, "Apply Changes", apply_definition_changes)
	_add_button(form, "New Definition", prepare_new_definition)
	_add_button(form, "Duplicate", prepare_duplicate_definition)
	_add_button(form, "Create Definition", create_definition_from_form)
	_add_button(form, "Delete", delete_definition)
	var help := Label.new()
	help.text = "Definition IDs are immutable. Scene paths reference project resources; asset importing is outside this MVP."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(help)


func _build_terrain_editor() -> void:
	terrain_dialog = Window.new()
	terrain_dialog.title = "Terrain Document"
	terrain_dialog.size = Vector2i(560, 620)
	terrain_dialog.close_requested.connect(terrain_dialog.hide)
	terrain_dialog.visible = false
	add_child(terrain_dialog)
	var form := VBoxContainer.new()
	form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	form.offset_left = 18
	form.offset_top = 18
	form.offset_right = -18
	form.offset_bottom = -18
	terrain_dialog.add_child(form)
	var explanation := Label.new()
	explanation.text = "Create or resize the canonical terrain grid. Dimensions count cells; heights use centimetres."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(explanation)
	for field in ["width_cells", "depth_cells", "cell_size_m", "base_height_cm", "origin_x_m", "origin_z_m"]:
		terrain_fields[field] = _add_field(form, field.replace("_", " ").capitalize())
	terrain_anchor = OptionButton.new()
	for anchor in ["north_west", "north_center", "north_east", "center_west", "center", "center_east", "south_west", "south_center", "south_east"]:
		terrain_anchor.add_item(anchor.replace("_", " ").capitalize())
		terrain_anchor.set_item_metadata(terrain_anchor.item_count - 1, anchor)
	form.add_child(terrain_anchor)
	_add_button(form, "Create Terrain", request_create_terrain)
	_add_button(form, "Resize / Edit Bounds", request_resize_terrain)
	_add_button(form, "Reset Terrain", request_reset_terrain)
	var limits := Label.new()
	limits.text = "Limits: 8–512 cells per axis; cell sizes 0.5, 1, 2, or 4 metres. Structural operations are one bounded undo transaction."
	limits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(limits)
	terrain_confirmation = ConfirmationDialog.new()
	terrain_confirmation.title = "Confirm Terrain Transaction"
	terrain_confirmation.confirmed.connect(commit_pending_terrain_action)
	add_child(terrain_confirmation)


func show_terrain_editor() -> void:
	var terrain = package.terrain
	terrain_fields.width_cells.text = str(terrain.data.grid.width_cells if terrain != null else 128)
	terrain_fields.depth_cells.text = str(terrain.data.grid.depth_cells if terrain != null else 128)
	terrain_fields.cell_size_m.text = str(terrain.data.grid.cell_size_m if terrain != null else 1.0)
	terrain_fields.base_height_cm.text = "0"
	terrain_fields.origin_x_m.text = str(terrain.data.grid.origin_x_m if terrain != null else -64.0)
	terrain_fields.origin_z_m.text = str(terrain.data.grid.origin_z_m if terrain != null else -64.0)
	terrain_dialog.popup_centered()


func request_create_terrain() -> void:
	request_terrain_transaction("Create terrain? Existing terrain data will be replaced.", _create_terrain)


func request_resize_terrain() -> void:
	if package.terrain == null:
		show_blocking_error("Create terrain before resizing it.")
		return
	var old_cells := int(package.terrain.data.grid.width_cells) * int(package.terrain.data.grid.depth_cells)
	var new_cells := int(terrain_fields.width_cells.text) * int(terrain_fields.depth_cells.text)
	var affected := _terrain_resize_impact()
	request_terrain_transaction("Resize terrain from %d to %d cells? %d object(s) and %d spawn(s) would lie outside the new bounds; their authored positions and attachment policies will be preserved. Cropped terrain remains undoable until its bounded history entry is evicted." % [old_cells, new_cells, affected.objects, affected.spawns], _resize_terrain)


func request_reset_terrain() -> void:
	if package.terrain == null:
		show_blocking_error("Create terrain before resetting it.")
		return
	request_terrain_transaction("Reset heights, surfaces, cliffs, water, and pathing? Environment and attachments are preserved. This is one undoable transaction.", _reset_terrain)


func _terrain_resize_impact() -> Dictionary:
	var width := int(terrain_fields.width_cells.text)
	var depth := int(terrain_fields.depth_cells.text)
	var anchor: String = terrain_anchor.get_item_metadata(terrain_anchor.selected)
	var bounds: Rect2 = package.terrain.prospective_bounds(width, depth, anchor)
	var affected := {"objects": 0, "spawns": 0}
	for instance in package.world.get("objects", []):
		if not bounds.has_point(Vector2(float(instance.position[0]), float(instance.position[2]))):
			affected.objects += 1
	for spawn in package.world.get("spawn_points", []):
		if not bounds.has_point(Vector2(float(spawn.position[0]), float(spawn.position[2]))):
			affected.spawns += 1
	return affected


func request_terrain_transaction(message: String, action: Callable) -> void:
	pending_terrain_action = action
	terrain_confirmation.dialog_text = message
	terrain_confirmation.popup_centered()


func commit_pending_terrain_action() -> void:
	if pending_terrain_action.is_valid():
		pending_terrain_action.call()


func _create_terrain() -> void:
	var terrain = package.terrain if package.terrain != null else preload("res://src/domain/terrain_document.gd").new()
	if terrain.replace(int(terrain_fields.width_cells.text), int(terrain_fields.depth_cells.text), float(terrain_fields.cell_size_m.text), int(terrain_fields.base_height_cm.text), float(terrain_fields.origin_x_m.text), float(terrain_fields.origin_z_m.text)):
		if package.terrain == null and not package.set_terrain(terrain):
			package.errors = ["Terrain could not be attached to the world package"]
			show_errors()
			return
		_reset_terrain_session(false)
		status("Created %s × %s terrain" % [terrain_fields.width_cells.text, terrain_fields.depth_cells.text])
		refresh_all()
	else:
		package.errors = terrain.errors
		show_errors()


func _resize_terrain() -> void:
	var anchor: String = terrain_anchor.get_item_metadata(terrain_anchor.selected)
	if package.terrain.resize(int(terrain_fields.width_cells.text), int(terrain_fields.depth_cells.text), anchor):
		_reset_terrain_session(false)
		status("Resized terrain using %s anchor" % anchor.replace("_", " "))
		refresh_all()
	else:
		package.errors = package.terrain.errors
		show_errors()


func _reset_terrain() -> void:
	if package.terrain.reset(int(terrain_fields.base_height_cm.text)):
		_reset_terrain_session(false)
		status("Reset terrain to %s cm" % terrain_fields.base_height_cm.text)
		refresh_all()
	else:
		package.errors = package.terrain.errors
		show_errors()


func _build_package_dialogs() -> void:
	package_dialog = FileDialog.new()
	package_dialog.title = "Open World Package Directory"
	package_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	package_dialog.access = FileDialog.ACCESS_FILESYSTEM
	package_dialog.dir_selected.connect(open_package)
	add_child(package_dialog)
	unsaved_dialog = ConfirmationDialog.new()
	unsaved_dialog.title = "Unsaved Changes"
	unsaved_dialog.dialog_text = "Save the current authored package before continuing?"
	unsaved_dialog.ok_button_text = "Save"
	unsaved_dialog.add_button("Discard", true, "discard")
	unsaved_dialog.confirmed.connect(save_then_continue)
	unsaved_dialog.custom_action.connect(discard_then_continue)
	add_child(unsaved_dialog)
	error_dialog = AcceptDialog.new()
	error_dialog.title = "Frontier World Editor"
	add_child(error_dialog)


func show_object_editor() -> void:
	refresh_definition_list()
	object_dialog.popup_centered()


func refresh_definition_list() -> void:
	if definition_list == null:
		return
	definition_list.clear()
	var ordered_definitions: Array[Dictionary] = package.definitions.duplicate()
	ordered_definitions.sort_custom(func(a, b): return [a.category, a.display_name] < [b.category, b.display_name])
	for definition in ordered_definitions:
		var index := definition_list.add_item("[%s] %s\n%s" % [definition.category, definition.display_name, definition.definition_id])
		definition_list.set_item_metadata(index, definition.definition_id)


func filter_definition_list(query: String) -> void:
	for index in definition_list.item_count:
		var definition: Dictionary = package.find_definition(definition_list.get_item_metadata(index))
		definition_list.set_item_disabled(index, not query.is_empty() and query.to_lower() not in definition.display_name.to_lower() and query.to_lower() not in definition.definition_id.to_lower())


func load_definition_form(index: int) -> void:
	var definition: Dictionary = package.find_definition(definition_list.get_item_metadata(index))
	creating_definition = false
	definition_id_field.text = definition.definition_id
	definition_id_field.editable = false
	definition_name.text = definition.display_name
	definition_category.select(WorldPackageScript.CATEGORIES.find(definition.category))
	definition_scene.text = definition.scene_path
	_load_unit_fields(definition)
	_load_special_fields(definition)
	refresh_unit_field_visibility()


func apply_definition_changes() -> void:
	var selected := definition_list.get_selected_items()
	if selected.is_empty():
		status("Select a definition to edit")
		return
	var definition: Dictionary = package.find_definition(definition_list.get_item_metadata(selected[0]))
	var changes := {"display_name": definition_name.text, "category": definition_category.get_item_text(definition_category.selected), "scene_path": definition_scene.text}
	if changes.category == "unit":
		changes.merge(_unit_form_data())
		if hero_fields.hero.text.to_lower()=="true":changes.merge(_hero_form_data())
	elif changes.category=="ability":changes.merge(_ability_form_data())
	elif changes.category=="item":changes.merge(_item_form_data())
	package.update_definition(definition.definition_id, changes)
	refresh_all()


func prepare_duplicate_definition() -> void:
	var selected := definition_list.get_selected_items()
	if selected.is_empty():
		return
	var source: Dictionary = package.find_definition(definition_list.get_item_metadata(selected[0]))
	creating_definition = true
	definition_id_field.editable = true
	definition_id_field.text = unique_definition_id(source.definition_id + "_copy")
	definition_name.text = source.display_name + " Copy"
	definition_category.select(WorldPackageScript.CATEGORIES.find(source.category))
	definition_scene.text = source.scene_path
	_load_unit_fields(source)
	_load_special_fields(source)
	refresh_unit_field_visibility()
	status("Review the duplicate ID, then choose Create Definition")


func prepare_new_definition() -> void:
	creating_definition = true
	definition_list.deselect_all()
	definition_id_field.editable = true
	definition_id_field.text = ""
	definition_name.text = ""
	definition_category.select(1)
	definition_scene.text = ""
	_load_unit_fields({})
	_load_special_fields({})
	refresh_unit_field_visibility()
	status("Enter all definition fields, then choose Create Definition")


func create_definition_from_form() -> void:
	if not creating_definition:
		status("Choose New Definition or Duplicate first")
		return
	var definition := {
		"definition_id": definition_id_field.text,
		"display_name": definition_name.text,
		"category": definition_category.get_item_text(definition_category.selected),
		"scene_path": definition_scene.text,
	}
	if definition.category == "unit":
		definition.merge(_unit_form_data())
		if hero_fields.hero.text.to_lower()=="true":definition.merge(_hero_form_data())
	elif definition.category=="ability":definition.merge(_ability_form_data())
	elif definition.category=="item":definition.merge(_item_form_data())
	var created := package.create_definition(definition)
	if not created:
		show_errors()
		return
	creating_definition = false
	definition_id_field.editable = false
	refresh_all()
	status("Created definition '%s'" % definition_id_field.text)


func _load_unit_fields(definition: Dictionary) -> void:
	definition_owner.select(maxi(0, WorldPackageScript.OWNERS.find(definition.get("owner", "player"))))
	var defaults := {"max_health": 100.0, "movement_speed": 4.0, "selection_radius": 0.8, "attack_damage": 10.0, "attack_interval": 1.0, "attack_range": 1.5, "acquisition_range": 7.0}
	for field in unit_fields:
		unit_fields[field].text = str(definition.get(field, defaults[field]))


func _unit_form_data() -> Dictionary:
	var data := {"owner": definition_owner.get_item_text(definition_owner.selected)}
	for field in unit_fields:
		data[field] = float(unit_fields[field].text)
	return data


func _load_special_fields(definition:Dictionary)->void:
	var hero_defaults:={"hero":"false","max_mana":100,"starting_level":1,"starting_experience":0,"strength":10,"agility":10,"intellect":10,"ability_ids":"","inventory_limit":6,"pickup_behavior":"automatic"}
	for field in hero_fields:hero_fields[field].text=", ".join(definition.get(field,[])) if field=="ability_ids" else str(definition.get(field,hero_defaults[field]))
	var ability_defaults:={"ability_mode":"targeted","damage":25,"cast_range":7,"cooldown_s":6,"mana_cost":20,"area_radius":0,"chain_count":1,"presentation":"A clear cast flash and impact cue."}
	for field in ability_fields:ability_fields[field].text=str(definition.get(field,ability_defaults[field]))
	var item_defaults:={"item_kind":"consumable","effect_stat":"health","effect_amount":25,"feedback_text":"Health restored."}
	for field in item_fields:item_fields[field].text=str(definition.get(field,item_defaults[field]))


func _hero_form_data()->Dictionary:
	return {"hero":true,"max_mana":float(hero_fields.max_mana.text),"starting_level":int(hero_fields.starting_level.text),"starting_experience":int(hero_fields.starting_experience.text),"strength":float(hero_fields.strength.text),"agility":float(hero_fields.agility.text),"intellect":float(hero_fields.intellect.text),"ability_ids":_csv_ids(hero_fields.ability_ids.text),"inventory_limit":int(hero_fields.inventory_limit.text),"pickup_behavior":hero_fields.pickup_behavior.text}


func _ability_form_data()->Dictionary:
	return {"ability_mode":ability_fields.ability_mode.text,"damage":float(ability_fields.damage.text),"cast_range":float(ability_fields.cast_range.text),"cooldown_s":float(ability_fields.cooldown_s.text),"mana_cost":float(ability_fields.mana_cost.text),"area_radius":float(ability_fields.area_radius.text),"chain_count":int(ability_fields.chain_count.text),"presentation":ability_fields.presentation.text}


func _item_form_data()->Dictionary:
	return {"item_kind":item_fields.item_kind.text,"effect_stat":item_fields.effect_stat.text,"effect_amount":float(item_fields.effect_amount.text),"feedback_text":item_fields.feedback_text.text}


func refresh_unit_field_visibility() -> void:
	var category:=definition_category.get_item_text(definition_category.selected);var is_unit := category == "unit"
	for control in unit_section_controls:
		control.visible = is_unit
	for control in hero_section_controls:control.visible=is_unit
	for control in ability_section_controls:control.visible=category=="ability"
	for control in item_section_controls:control.visible=category=="item"


func _preview_gameplay_definition()->void:
	var category:=definition_category.get_item_text(definition_category.selected)
	match category:
		"unit":
			definition_gameplay_preview.text="HERO %s — level %s, XP %s, mana %s, STR/AGI/INT %s/%s/%s\nAbilities: %s\nInventory: %s slots, %s pickup"%[definition_name.text,hero_fields.starting_level.text,hero_fields.starting_experience.text,hero_fields.max_mana.text,hero_fields.strength.text,hero_fields.agility.text,hero_fields.intellect.text,hero_fields.ability_ids.text,hero_fields.inventory_limit.text,hero_fields.pickup_behavior.text] if hero_fields.hero.text.to_lower()=="true" else "UNIT %s — health %s, attack %s"%[definition_name.text,unit_fields.max_health.text,unit_fields.attack_damage.text]
		"ability":definition_gameplay_preview.text="ABILITY %s — %s, %s damage, range %s, cooldown %ss, mana %s; %s"%[definition_name.text,ability_fields.ability_mode.text,ability_fields.damage.text,ability_fields.cast_range.text,ability_fields.cooldown_s.text,ability_fields.mana_cost.text,ability_fields.presentation.text]
		"item":definition_gameplay_preview.text="ITEM %s — %s: +%s %s; %s"%[definition_name.text,item_fields.item_kind.text,item_fields.effect_amount.text,item_fields.effect_stat.text,item_fields.feedback_text.text]
		_:definition_gameplay_preview.text="WORLD OBJECT %s"%definition_name.text
	status("Gameplay definition preview refreshed")


func delete_definition() -> void:
	var selected := definition_list.get_selected_items()
	if selected.is_empty():
		return
	var definition_id: String = definition_list.get_item_metadata(selected[0])
	if not package.delete_definition(definition_id):
		show_errors()
	refresh_all()


func unique_definition_id(base: String) -> String:
	var candidate := base
	var suffix := 2
	while not package.find_definition(candidate).is_empty():
		candidate = "%s_%d" % [base, suffix]
		suffix += 1
	return candidate


func perform_undo() -> void:
	_track_history_changes()
	while not global_undo_domains.is_empty():
		var transaction: Dictionary = global_undo_domains.pop_back()
		var domain: String = transaction.domain
		history_tracking_suspended = true
		var changed := _undo_domain(domain)
		if changed:
			global_redo_domains.append(transaction)
			_refresh_after_global_history()
		history_tracking_suspended = false
		tracked_history_depths = _domain_history_depths()
		if changed:
			status("Undo — %s" % domain.capitalize())
			return
	status("Nothing to undo")


func perform_redo() -> void:
	while not global_redo_domains.is_empty():
		var transaction: Dictionary = global_redo_domains.pop_back()
		var domain: String = transaction.domain
		history_tracking_suspended = true
		var changed := _redo_domain(domain)
		if changed:
			global_undo_domains.append(transaction)
			_refresh_after_global_history()
		history_tracking_suspended = false
		tracked_history_depths = _domain_history_depths()
		if changed:
			status("Redo — %s" % domain.capitalize())
			return
	status("Nothing to redo")


func _domain_history_depths() -> Dictionary:
	return {
		"world": package.history_depth(),
		"terrain": package.terrain.history_depth() if package.terrain != null else 0,
		"scenario": package.scenario.history_depth() if package.scenario != null else 0,
	}


func _reset_global_history_tracking() -> void:
	global_undo_domains = _current_undo_transactions()
	global_redo_domains.clear()
	known_history_transaction_ids.clear()
	for transaction in global_undo_domains:known_history_transaction_ids[int(transaction.id)]=true
	tracked_history_depths = _domain_history_depths()
	history_tracking_ready = true


func _track_history_changes() -> void:
	if history_tracking_suspended:
		return
	var current := _domain_history_depths()
	if not history_tracking_ready:
		tracked_history_depths = current
		history_tracking_ready = true
		return
	var current_transactions := _current_undo_transactions()
	var added := current_transactions.any(func(transaction): return not known_history_transaction_ids.has(int(transaction.id)))
	if added:
		global_redo_domains.clear()
		package.discard_redo_history()
		if package.terrain != null:
			package.terrain.discard_redo_history()
		if package.scenario != null:
			package.scenario.discard_redo_history()
		for transaction in current_transactions:known_history_transaction_ids[int(transaction.id)]=true
	var current_ids:={}
	for transaction in current_transactions:current_ids[int(transaction.id)]=true
	for transaction in global_undo_domains:
		if transaction.domain=="scenario" and package.scenario==null and not current_ids.has(int(transaction.id)):current_transactions.append(transaction)
	current_transactions.sort_custom(func(a,b):return int(a.id)<int(b.id))
	global_undo_domains = current_transactions
	tracked_history_depths = current


func _current_undo_transactions() -> Array[Dictionary]:
	var transactions: Array[Dictionary] = []
	for transaction_id in package.undo_transaction_ids():
		transactions.append({"id": transaction_id, "domain": "world"})
	if package.terrain != null:
		for transaction_id in package.terrain.undo_transaction_ids():
			transactions.append({"id": transaction_id, "domain": "terrain"})
	if package.scenario != null:
		for transaction_id in package.scenario.undo_transaction_ids():
			transactions.append({"id": transaction_id, "domain": "scenario"})
	transactions.sort_custom(func(a, b): return int(a.id) < int(b.id))
	return transactions


func _undo_domain(domain: String) -> bool:
	match domain:
		"world": return package.undo()
		"terrain": return package.terrain != null and package.terrain.undo()
		"scenario": return package.scenario != null and package.scenario.undo()
		_: return false


func _redo_domain(domain: String) -> bool:
	match domain:
		"world": return package.redo()
		"terrain": return package.terrain != null and package.terrain.redo()
		"scenario": return package.scenario != null and package.scenario.redo()
		_: return false


func _refresh_after_global_history() -> void:
	selected_instance_id = ""
	_reset_terrain_session(false)
	if package.scenario != null:
		_refresh_scenario_form()
		if guidance_dialog.visible: _refresh_guidance()
		if sequence_dialog.visible: _refresh_sequence_list()
		if encounter_dialog.visible: _refresh_encounters()
		if cinematic_dialog.visible: _refresh_cinematics()
	refresh_all()


func save_package() -> void:
	if package.save():
		status("Saved %s" % package.world.get("display_name", "world"))
	else:
		show_errors()
	refresh_all()


func test_world() -> void:
	if has_unsaved_changes():
		request_after_save(launch_test_world)
		return
	launch_test_world()


func launch_test_world() -> void:
	status("Test World 1/3 — validating authored package")
	var preflight: Dictionary = package.test_world_preflight({"renderer": "godot_4_7_1_forward_plus", "chunk_cells": 32})
	if not preflight.ok:
		package.errors = preflight.diagnostics
		package.errors.append("Recovery: %s" % preflight.recovery)
		show_errors()
		return
	status("Test World 2/3 — terrain cache %s" % preflight.cache.cache_key.left(12))
	var executable:=test_world_executable_field.text.strip_edges()
	var project_path:=test_world_project_field.text.strip_edges()
	var setup_error:=_test_world_setup_error(executable,project_path)
	if not setup_error.is_empty():show_test_world_setup(setup_error);return
	var launch := build_test_world_launch(executable,project_path,ProjectSettings.globalize_path(package.package_path),"player_start")
	var process_id := OS.create_process(launch.executable, launch.arguments)
	if process_id <= 0:
		show_test_world_setup("Frontier could not be launched. Check the values in Test Setup and try again.")
	else:
		status("Test World 3/3 — Frontier launched at player_start")


func build_test_world_launch(executable: String, frontier_project_path: String, package_path: String, spawn_id: String) -> Dictionary:
	var arguments := PackedStringArray()
	if not frontier_project_path.is_empty():
		arguments.append_array(["--path", frontier_project_path, "--"])
	arguments.append_array(["--world-package", package_path, "--spawn", spawn_id])
	return {"executable": executable, "arguments": arguments}


func request_open_package() -> void:
	if has_unsaved_changes():
		request_after_save(package_dialog.popup_centered_ratio.bind(0.75))
	else:
		package_dialog.popup_centered_ratio(0.75)


func open_package(path: String) -> void:
	if package.load_from_directory(path):
		selected_instance_id = ""
		_reset_terrain_session(true, true)
		refresh_all()
		var resource_failures: Array[String] = package.resource_errors()
		status("Opened %s" % package.world.get("display_name", path) if resource_failures.is_empty() else " | ".join(resource_failures))
	else:
		show_errors()


func request_after_save(callback: Callable) -> void:
	pending_after_save = callback
	unsaved_dialog.popup_centered()


func save_then_continue() -> void:
	if package.save():
		refresh_all()
		if pending_after_save.is_valid():
			pending_after_save.call()
	else:
		show_errors()


func discard_then_continue(action: StringName) -> void:
	if action != &"discard":
		return
	var current_path: String = package.package_path
	if not current_path.is_empty():
		package.load_from_directory(current_path)
	_reset_terrain_session(true, true)
	refresh_all()
	if pending_after_save.is_valid():
		pending_after_save.call()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode==KEY_ESCAPE and workflow_dialog.visible:
		_workflow_cancel();get_viewport().set_input_as_handled();return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or focus is SpinBox:
		return
	if event.ctrl_pressed and event.keycode == KEY_Z:
		perform_undo(); get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		perform_redo(); get_viewport().set_input_as_handled()
	elif package.terrain != null and event.ctrl_pressed and event.keycode == KEY_C:
		if workflow_dialog.visible: _workflow_copy(); get_viewport().set_input_as_handled()
	elif package.terrain != null and event.ctrl_pressed and event.keycode == KEY_V:
		if workflow_dialog.visible: _workflow_paste(); get_viewport().set_input_as_handled()
	elif package.terrain != null and workflow_dialog.visible and event.keycode == KEY_S:
		_workflow_begin_selection(); get_viewport().set_input_as_handled()
	elif package.terrain != null and workflow_dialog.visible and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_workflow_confirm(); get_viewport().set_input_as_handled()
	elif package.terrain != null and workflow_dialog.visible and event.keycode == KEY_F:
		_workflow_sample(); get_viewport().set_input_as_handled()
	elif package.terrain != null and workflow_dialog.visible and event.keycode == KEY_M:
		_workflow_recenter(); get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if package != null and has_unsaved_changes():
			request_after_save(func(): get_tree().quit())
		else:
			get_tree().quit()


func show_errors() -> void:
	show_blocking_error("\n".join(package.errors))


func show_blocking_error(message: String) -> void:
	status(message.replace("\n", " | "))
	if error_dialog != null:
		error_dialog.dialog_text = message
		error_dialog.popup_centered()


func status(message: String) -> void:
	if status_label != null:
		status_label.text = message


func has_unsaved_changes() -> bool:
	return package.dirty or package.scenario_removed or (package.terrain != null and package.terrain.dirty) or (package.scenario != null and package.scenario.dirty)


func array_to_vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])


func definition_color(category: String) -> Color:
	match category:
		"building": return Color("c69c6d")
		"landmark": return Color("8ecae6")
		"unit": return Color("e76f51")
		_: return Color("90be6d")


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_field(parent: Control, placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.accessibility_name = placeholder
	parent.add_child(field)
	return field


func _add_labeled_field(parent:Control,label_text:String)->LineEdit:
	var row:=VBoxContainer.new();row.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(row)
	var label:=Label.new();label.text=label_text;row.add_child(label)
	var field:=_add_field(row,label_text);field.accessibility_name=label_text;field.accessibility_description="Enter %s"%label_text.to_lower();field.set_meta("labeled_row",row)
	return field


func _add_labeled_path_field(parent:Control,label_text:String,browse_text:String,browse_callback:Callable)->LineEdit:
	var outer:=VBoxContainer.new();outer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(outer)
	var label:=Label.new();label.text=label_text;outer.add_child(label)
	var row:=HBoxContainer.new();outer.add_child(row)
	var field:=_add_field(row,label_text);field.size_flags_horizontal=Control.SIZE_EXPAND_FILL;field.accessibility_name=label_text;field.accessibility_description="Enter or browse for %s"%label_text.to_lower();field.set_meta("labeled_row",outer)
	var browse:=_add_button(row,browse_text,browse_callback);browse.accessibility_name="Browse for %s"%label_text
	return field


func _field_row(field:Control)->Control:
	return field.get_meta("labeled_row",field)


func _label_control(parent:Control,label_text:String,control:Control)->Label:
	var label:=Label.new();label.text=label_text;parent.add_child(label);control.accessibility_name=label_text;return label
