extends Control

const WorldPackageScript = preload("res://src/domain/world_package.gd")
const TerrainSculptorScript = preload("res://src/domain/terrain_sculptor.gd")
const TerrainSurfacePainterScript = preload("res://src/domain/terrain_surface_painter.gd")
const TerrainCliffWaterScript = preload("res://src/domain/terrain_cliff_water.gd")
const TerrainPathingScript = preload("res://src/domain/terrain_pathing.gd")
const TerrainEnvironmentScript = preload("res://src/domain/terrain_environment.gd")
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
var inspector_content: VBoxContainer
var palette_content: VBoxContainer
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
var pending_after_save: Callable
var definition_list: ItemList
var definition_id_field: LineEdit
var definition_name: LineEdit
var definition_category: OptionButton
var definition_scene: LineEdit
var definition_owner: OptionButton
var unit_fields: Dictionary = {}
var unit_section_controls: Array[Control] = []
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
	palette_content = $Workspace/Palette/Content
	inspector_content = $Workspace/Inspector/Content
	_build_viewport()
	_build_sculpt_hud()
	_build_surface_editor()
	_build_cliff_water_editor()
	_build_pathing_editor()
	_build_environment_editor()
	_build_object_editor()
	_build_terrain_editor()
	_build_package_dialogs()
	if not package.load_from_directory(DEFAULT_PACKAGE):
		show_errors()
	else:
		var resource_failures: Array[String] = package.resource_errors()
		status("Opened Crimsdale" if resource_failures.is_empty() else " | ".join(resource_failures))
	refresh_all()


func _build_toolbar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "Toolbar"
	bar.position = Vector2(12, 10)
	bar.size = Vector2(size.x - 24, 36)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 12
	bar.offset_top = 10
	bar.offset_right = -12
	bar.offset_bottom = 46
	add_child(bar)
	_add_button(bar, "World", func(): status("World workspace"))
	_add_button(bar, "Open", request_open_package)
	_add_button(bar, "Object Editor", show_object_editor)
	_add_button(bar, "Terrain", show_terrain_editor)
	_add_button(bar, "Sculpt", toggle_sculpt_mode)
	_add_button(bar, "Surfaces", show_surface_editor)
	_add_button(bar, "Cliffs & Water", show_cliff_water_editor)
	_add_button(bar, "Pathing", show_pathing_editor)
	_add_button(bar, "Environment", show_environment_editor)
	bar.add_spacer(false)
	_add_button(bar, "Undo", perform_undo)
	_add_button(bar, "Redo", perform_redo)
	_add_button(bar, "Save", save_package)
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
	sculpt_enabled = not sculpt_enabled
	if sculpt_enabled:
		surface_enabled = false
		$Workspace/Viewport/Content/SurfaceHUD.visible = false
		if surface_painter != null:
			surface_painter.cancel()
	$Workspace/Viewport/Content/SculptHUD.visible = sculpt_enabled
	if sculpt_enabled:
		cancel_placement()
		sculptor = TerrainSculptorScript.new(package.terrain)
		_make_brush_preview()
		status("Sculpt mode: drag on terrain; keys 1–6 select tools; Escape cancels a stroke")
	else:
		cancel_sculpt_stroke()
		if brush_preview != null:
			brush_preview.queue_free()
			brush_preview = null
		status("Selection tool")


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
	point.y = package.terrain.sample_height(point.x, point.z) + 0.03
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
	sculpt_enabled = false
	$Workspace/Viewport/Content/SculptHUD.visible = false
	surface_enabled = true
	$Workspace/Viewport/Content/SurfaceHUD.visible = true
	surface_painter = TerrainSurfacePainterScript.new(package.terrain)
	if brush_preview == null:
		_make_brush_preview()
	surface_dialog.hide()
	status("Surface paint: drag to paint; Escape cancels a stroke")


func _build_cliff_water_editor() -> void:
	cliff_dialog = Window.new()
	cliff_dialog.title = "Cliffs & Water"
	cliff_dialog.size = Vector2i(500, 500)
	cliff_dialog.close_requested.connect(cliff_dialog.hide)
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
	cliff_water_enabled.button_pressed = package.terrain.data.water.enabled
	cliff_water_level.value = package.terrain.data.water.level_cm
	var style_index := -1
	for index in cliff_style.item_count:
		if cliff_style.get_item_metadata(index) == package.terrain.data.cliffs.style_id:
			style_index = index
	if style_index >= 0: cliff_style.select(style_index)
	cliff_dialog.popup_centered()


func apply_cliff_style() -> void:
	if TerrainCliffWaterScript.new(package.terrain).set_style(cliff_style.get_item_metadata(cliff_style.selected)):
		refresh_all()
		status("Cliff style replaced without changing topology")


func set_cliff_mode(mode: String) -> void:
	cliff_mode = mode
	cliff_dialog.hide()
	status("%s: click a terrain cell; Escape returns to selection" % mode.capitalize())


func apply_water() -> void:
	if TerrainCliffWaterScript.new(package.terrain).set_water(cliff_water_enabled.button_pressed, roundi(cliff_water_level.value)):
		refresh_all()
		status("Water preview updated")


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
	pathing_dialog=Window.new();pathing_dialog.title="Pathing";pathing_dialog.size=Vector2i(500,360);pathing_dialog.close_requested.connect(pathing_dialog.hide);add_child(pathing_dialog)
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
	sculpt_enabled=false;surface_enabled=false;cliff_mode="";pathing_enabled=true
	$Workspace/Viewport/Content/SculptHUD.visible=false;$Workspace/Viewport/Content/SurfaceHUD.visible=false;$Workspace/Viewport/Content/PathingHUD.visible=true
	pathing_dialog.hide();pathing_overlay_visible=true;pathing.reset_cancellation();pathing.rebuild_overlay(pathing_layer.get_item_metadata(pathing_layer.selected));refresh_pathing_overlay()
	status("Pathing paint: drag cells; Escape cancels the active stroke")


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
		var x0: float=float(grid.origin_x_m)+cell.x*float(grid.cell_size_m);var z0: float=float(grid.origin_z_m)+cell.z*float(grid.cell_size_m);var size: float=float(grid.cell_size_m);var y: float=package.terrain.sample_height(x0+size/2,z0+size/2)+0.06
		for vertex in [Vector3(x0,y,z0),Vector3(x0,y,z0+size),Vector3(x0+size,y,z0),Vector3(x0+size,y,z0),Vector3(x0,y,z0+size),Vector3(x0+size,y,z0+size)]:mesh.surface_set_color(color);mesh.surface_add_vertex(vertex)
	mesh.surface_end();var preview:=MeshInstance3D.new();preview.name="PathingOverlay";preview.mesh=mesh
	var material:=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.vertex_color_use_as_albedo=true;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;preview.material_override=material;world_root.add_child(preview)


func _build_environment_editor()->void:
	environment_dialog=Window.new();environment_dialog.title="World Environment";environment_dialog.size=Vector2i(620,650);environment_dialog.close_requested.connect(environment_dialog.hide);add_child(environment_dialog)
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


func apply_environment_preview()->void:
	if DisplayServer.get_name()=="headless" or package.terrain==null:return
	var world_environment:WorldEnvironment=world_root.get_node("EnvironmentPreview");var sun:DirectionalLight3D=world_root.get_node("SunPreview")
	if not environment_preview_enabled:world_environment.visible=false;sun.visible=false;return
	world_environment.visible=true;sun.visible=true
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
	refresh_palette()
	refresh_world()
	refresh_inspector()
	refresh_definition_list()
	refresh_terrain_preview()
	apply_environment_preview()
	dirty_label.text = "Unsaved changes" if package.dirty or (package.terrain != null and package.terrain.dirty) else "Saved"


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
			var level_m := float(package.terrain.data.cliffs.levels[cell_index]) * 2.0
			var x0 := float(grid.origin_x_m) + x * float(grid.cell_size_m)
			var x1 := x0 + float(grid.cell_size_m)
			var z0 := float(grid.origin_z_m) + z * float(grid.cell_size_m)
			var z1 := z0 + float(grid.cell_size_m)
			var width := int(grid.width_cells) + 1
			var heights := [z * width + x, (z + 1) * width + x, z * width + x + 1, (z + 1) * width + x + 1]
			var corners: Array[Vector3] = []
			for corner in 4:
				var height_cm: int = sculptor.preview_height_cm(heights[corner]) if sculptor != null and sculptor.active else int(grid.heights_cm[heights[corner]])
				var px := x0 if corner < 2 else x1
				var pz := z0 if corner % 2 == 0 else z1
				corners.append(Vector3(px, float(height_cm) / 100.0 + level_m, pz))
			if x > 0 and cliff_tools.edge_has_ramp(x, z, "west"):
				var west_delta := (float(package.terrain.data.cliffs.levels[cell_index - 1]) * 2.0) - level_m
				corners[0].y += west_delta; corners[1].y += west_delta
			if x + 1 < int(grid.width_cells) and cliff_tools.edge_has_ramp(x, z, "east"):
				var east_delta := (float(package.terrain.data.cliffs.levels[cell_index + 1]) * 2.0) - level_m
				corners[2].y += east_delta; corners[3].y += east_delta
			if z > 0 and cliff_tools.edge_has_ramp(x, z, "north"):
				var north_delta := (float(package.terrain.data.cliffs.levels[cell_index - int(grid.width_cells)]) * 2.0) - level_m
				corners[0].y += north_delta; corners[2].y += north_delta
			if z + 1 < int(grid.depth_cells) and cliff_tools.edge_has_ramp(x, z, "south"):
				var south_delta := (float(package.terrain.data.cliffs.levels[cell_index + int(grid.width_cells)]) * 2.0) - level_m
				corners[1].y += south_delta; corners[3].y += south_delta
			_append_mesh_quad(vertices, colors, indices, corners[0], corners[1], corners[2], corners[3], blended)
			if x + 1 < int(grid.width_cells):
				var east_level := float(package.terrain.data.cliffs.levels[cell_index + 1]) * 2.0
				if not is_equal_approx(level_m, east_level) and not cliff_tools.edge_has_ramp(x, z, "east"):
					_append_mesh_quad(vertices, colors, indices, corners[2], corners[3], corners[2] + Vector3(0, east_level - level_m, 0), corners[3] + Vector3(0, east_level - level_m, 0), Color("686761"))
			if z + 1 < int(grid.depth_cells):
				var south_level := float(package.terrain.data.cliffs.levels[cell_index + int(grid.width_cells)]) * 2.0
				if not is_equal_approx(level_m, south_level) and not cliff_tools.edge_has_ramp(x, z, "south"):
					_append_mesh_quad(vertices, colors, indices, corners[1], corners[3], corners[1] + Vector3(0, south_level - level_m, 0), corners[3] + Vector3(0, south_level - level_m, 0), Color("686761"))
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
		if child.name != "Title":
			child.free()
	var search := LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "Search definitions"
	palette_content.add_child(search)
	var list := VBoxContainer.new()
	list.name = "Definitions"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_content.add_child(list)
	for category in WorldPackageScript.CATEGORIES:
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
			sculptor.begin(selected_tool, Vector2(point.x, point.z), _sculpt_parameters())
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
				status("Moved '%s'" % selected_instance_id)
				refresh_all()
			else:
				select_at(event.position)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if pathing_enabled and pathing!=null and pathing.painting:
				pathing.cancel_paint();status("Pathing stroke cancelled")
			elif not cliff_mode.is_empty():
				cliff_mode = ""
				status("Selection tool")
			elif surface_enabled and surface_painter != null and surface_painter.active:
				surface_painter.cancel()
				status("Surface stroke cancelled")
			elif sculpt_enabled and sculptor != null and sculptor.active:
				cancel_sculpt_stroke()
			elif moving_instance:
				moving_instance = false
				status("Move cancelled")
			else:
				cancel_placement()
		elif sculpt_enabled and event.keycode >= KEY_1 and event.keycode <= KEY_6:
			sculpt_tool.select(int(event.keycode - KEY_1))
			status("Sculpt tool: %s" % sculpt_tool.get_item_text(sculpt_tool.selected))
		elif event.keycode == KEY_G and not selected_instance_id.is_empty():
			moving_instance = true
			status("Move: click a ground position or Escape to cancel")
		elif event.keycode == KEY_Q and not placement_definition_id.is_empty():
			placement_rotation -= 15.0
			update_ghost_rotation()
		elif event.keycode == KEY_E and not placement_definition_id.is_empty():
			placement_rotation += 15.0
			update_ghost_rotation()


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
	var distance := -from.y / direction.y
	return from + direction * max(distance, 0.0)


func start_placement(definition_id: String) -> void:
	cancel_placement()
	placement_definition_id = definition_id
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
	navigation.add_child(search)
	definition_list = ItemList.new()
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
	definition_id_field = _add_field(form, "Stable definition ID")
	definition_name = _add_field(form, "Display name")
	definition_category = OptionButton.new()
	for category in WorldPackageScript.CATEGORIES:
		definition_category.add_item(category)
	form.add_child(definition_category)
	definition_category.item_selected.connect(func(_index): refresh_unit_field_visibility())
	definition_scene = _add_field(form, "Scene path")
	var unit_heading := Label.new()
	unit_heading.text = "UNIT GAMEPLAY"
	form.add_child(unit_heading)
	unit_section_controls.append(unit_heading)
	definition_owner = OptionButton.new()
	for owner in WorldPackageScript.OWNERS:
		definition_owner.add_item(owner)
	form.add_child(definition_owner)
	unit_section_controls.append(definition_owner)
	for field in WorldPackageScript.UNIT_FIELDS:
		if field != "owner":
			unit_fields[field] = _add_field(form, field.replace("_", " ").capitalize())
			unit_section_controls.append(unit_fields[field])
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
		package.terrain = terrain
		package.dirty = true
		status("Created %s × %s terrain" % [terrain_fields.width_cells.text, terrain_fields.depth_cells.text])
		refresh_all()
	else:
		package.errors = terrain.errors
		show_errors()


func _resize_terrain() -> void:
	var anchor: String = terrain_anchor.get_item_metadata(terrain_anchor.selected)
	if package.terrain.resize(int(terrain_fields.width_cells.text), int(terrain_fields.depth_cells.text), anchor):
		status("Resized terrain using %s anchor" % anchor.replace("_", " "))
		refresh_all()
	else:
		package.errors = package.terrain.errors
		show_errors()


func _reset_terrain() -> void:
	if package.terrain.reset(int(terrain_fields.base_height_cm.text)):
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


func refresh_unit_field_visibility() -> void:
	var is_unit := definition_category.get_item_text(definition_category.selected) == "unit"
	for control in unit_section_controls:
		control.visible = is_unit


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
	if package.terrain != null and package.terrain.can_undo() and package.terrain.undo():
		selected_instance_id = ""
		refresh_all()
	elif package.undo():
		selected_instance_id = ""
		refresh_all()


func perform_redo() -> void:
	if package.terrain != null and package.terrain.can_redo() and package.terrain.redo():
		selected_instance_id = ""
		refresh_all()
	elif package.redo():
		selected_instance_id = ""
		refresh_all()


func save_package() -> void:
	if package.save():
		status("Saved %s" % package.world.get("display_name", "world"))
	else:
		show_errors()
	refresh_all()


func test_world() -> void:
	if package.dirty:
		request_after_save(launch_test_world)
		return
	launch_test_world()


func launch_test_world() -> void:
	package.errors = package.validate()
	package.errors.append_array(package.resource_errors())
	if not package.errors.is_empty():
		show_errors()
		return
	var executable := OS.get_environment("FRONTIER_EXECUTABLE")
	if executable.is_empty():
		show_blocking_error("Set FRONTIER_EXECUTABLE to enable Test World")
		return
	var launch := build_test_world_launch(executable, OS.get_environment("FRONTIER_PROJECT_PATH"), ProjectSettings.globalize_path(package.package_path), "player_start")
	var process_id := OS.create_process(launch.executable, launch.arguments)
	if process_id <= 0:
		show_blocking_error("Frontier could not be launched. Check FRONTIER_EXECUTABLE and try again.")
	else:
		status("Frontier launched at player_start")


func build_test_world_launch(executable: String, frontier_project_path: String, package_path: String, spawn_id: String) -> Dictionary:
	var arguments := PackedStringArray()
	if not frontier_project_path.is_empty():
		arguments.append_array(["--path", frontier_project_path, "--"])
	arguments.append_array(["--world-package", package_path, "--spawn", spawn_id])
	return {"executable": executable, "arguments": arguments}


func request_open_package() -> void:
	if package.dirty:
		request_after_save(package_dialog.popup_centered_ratio.bind(0.75))
	else:
		package_dialog.popup_centered_ratio(0.75)


func open_package(path: String) -> void:
	if package.load_from_directory(path):
		selected_instance_id = ""
		cancel_placement()
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
	refresh_all()
	if pending_after_save.is_valid():
		pending_after_save.call()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if package != null and package.dirty:
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
	parent.add_child(field)
	return field
