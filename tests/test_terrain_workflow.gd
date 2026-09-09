extends SceneTree

const TERRAIN := preload("res://src/domain/terrain_document.gd")
const WORKFLOW := preload("res://src/domain/terrain_workflow.gd")
var failures: Array[String] = []


func _init() -> void:
	var terrain = TERRAIN.new()
	_check(terrain.create(8, 8, 1.0, 0), "Fixture terrain is created")
	var workflow = WORKFLOW.new(terrain)
	_check(workflow.select_cells(Vector2i(2, 3), Vector2i(0, 1)) == Rect2i(0, 1, 3, 3), "Selection is normalized and bounded")
	terrain.data.grid.heights_cm[9] = 125
	terrain.data.cliffs.levels[8] = 1
	terrain.data.pathing.movement[8] = "blocked"
	var clipboard: Dictionary = workflow.copy_selection()
	_check(clipboard.clipboard_version == 1 and clipboard.anchor == "north_west" and clipboard.mask.size() == 9, "Clipboard declares version, anchor, domains, and cell mask")
	var preview := workflow.preview_paste(clipboard, Vector2i(7, 7))
	_check(preview.ok and preview.clipped_cells == 8 and preview.atomic, "Destination preview reports clipping before mutation")
	var before := terrain.serialize()
	var incompatible := clipboard.duplicate(true)
	incompatible.cell_size_m = 2.0
	_check(not workflow.paste(incompatible, Vector2i(4, 4)) and terrain.serialize() == before, "Incompatible paste is rejected without partial mutation")
	_check(workflow.paste(clipboard, Vector2i(4, 4), "replace"), "Compatible multi-domain paste commits atomically")
	_check(terrain.data.cliffs.levels[4 * 8 + 4] == 1 and terrain.data.pathing.movement[4 * 8 + 4] == "blocked", "Cliff and pathing values paste together")
	_check(terrain.can_undo() and terrain.undo() and terrain.serialize() == before, "Paste is one undoable gesture")
	_check(terrain.redo() and terrain.data.cliffs.levels[36] == 1, "Redo restores the complete paste")
	_check(workflow.snapped_cell(Vector2i(3, 5)) == Vector2i(3, 5) and workflow.snapped_height_cm(112) == 100, "Grid and height snapping use explicit defaults")
	var sample := workflow.sample(Vector2i(4, 4))
	_check(sample.cliff_style_id == "cliff_crimsdale_stone" and sample.movement == "blocked" and sample.has("surface_weights"), "Eyedropper samples every authored terrain domain")
	var center := workflow.minimap_recenter(Vector2(0.5, 0.5))
	_check(is_equal_approx(center.x, 4.0) and is_equal_approx(center.z, 4.0), "Minimap coordinates recenter the world deterministically")
	if failures.is_empty(): print("PASS: terrain workflow, clipboard, history, snapping, sampling, and minimap"); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
