extends Control

const WorldPackageScript = preload("res://src/domain/world_package.gd")
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
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("222936")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a5b1c2")
	env.ambient_light_energy = 0.55
	environment.environment = env
	world_root.add_child(environment)
	var light := DirectionalLight3D.new()
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


func refresh_all() -> void:
	refresh_palette()
	refresh_world()
	refresh_inspector()
	refresh_definition_list()
	refresh_terrain_preview()
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
	var grid: Dictionary = package.terrain.data.grid
	for z in int(grid.depth_cells) + 1:
		for x in int(grid.width_cells) + 1:
			vertices.append(Vector3(float(grid.origin_x_m) + x * float(grid.cell_size_m), float(grid.heights_cm[z * (int(grid.width_cells) + 1) + x]) / 100.0, float(grid.origin_z_m) + z * float(grid.cell_size_m)))
	for z in int(grid.depth_cells):
		for x in int(grid.width_cells):
			var north_west := z * (int(grid.width_cells) + 1) + x
			var south_west := north_west + int(grid.width_cells) + 1
			indices.append_array([north_west, south_west, north_west + 1, north_west + 1, south_west, south_west + 1])
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	terrain_mesh.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4f6849")
	material.roughness = 1.0
	terrain_mesh.material_override = material
	world_root.add_child(terrain_mesh)


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
	if event is InputEventMouseMotion:
		mouse_position = event.position
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
			if moving_instance:
				moving_instance = false
				status("Move cancelled")
			else:
				cancel_placement()
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
