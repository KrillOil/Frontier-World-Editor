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
	_check(terrain.data.cliffs.levels[4 * 8 + 4] == 1 and terrain.data.pathing.movement[4 * 8 + 4] == "blocked" and terrain.data.cliffs.levels[8] == 1, "Paste writes every enabled domain while preserving its source")
	_check(terrain.can_undo() and terrain.undo() and terrain.serialize() == before, "Paste is one undoable gesture")
	_check(terrain.redo() and terrain.data.cliffs.levels[36] == 1, "Redo restores the complete paste")
	_check(workflow.snapped_cell(Vector2i(3, 5)) == Vector2i(3, 5) and workflow.snapped_height_cm(112) == 100, "Grid and height snapping use explicit defaults")
	var sample := workflow.sample(Vector2i(4, 4))
	_check(sample.cliff_style_id == "cliff_crimsdale_stone" and sample.movement == "blocked" and sample.has("surface_weights"), "Eyedropper samples every authored terrain domain")
	var center := workflow.minimap_recenter(Vector2(0.5, 0.5))
	_check(is_equal_approx(center.x, 4.0) and is_equal_approx(center.z, 4.0), "Minimap coordinates recenter the world deterministically")
	_test_direct_manipulation()
	if failures.is_empty(): print("PASS: terrain workflow, clipboard, history, snapping, sampling, and minimap"); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func _test_direct_manipulation() -> void:
	var terrain = TERRAIN.new()
	_check(terrain.create(8, 8, 1.0, 0, -4.0, -6.0), "Direct-manipulation fixture terrain is created")
	var workflow = WORKFLOW.new(terrain)
	var drag_rect := Rect2i(1, 2, 3, 3)
	for pair in [
		[Vector2i(1, 2), Vector2i(3, 4)],
		[Vector2i(3, 2), Vector2i(1, 4)],
		[Vector2i(1, 4), Vector2i(3, 2)],
		[Vector2i(3, 4), Vector2i(1, 2)],
	]:
		_check(workflow.select_cells(pair[0], pair[1]) == drag_rect, "Four-direction drag selection stays inclusive and normalized")
	workflow.grid_snap_cells = 2
	_check(workflow.world_to_cell(Vector3(-1.1, 30.0, -2.1)) == Vector2i(2, 4), "World picking applies cell-space snap relative to a negative terrain origin")
	workflow.grid_snap_cells = 1

	workflow.select_cells(Vector2i(1, 1), Vector2i(2, 2))
	var width := int(terrain.data.grid.width_cells)
	for z in range(1, 4):
		for x in range(1, 4): terrain.data.grid.heights_cm[z * (width + 1) + x] = 100 + z * 10 + x
	terrain.data.cliffs.levels[1 * width + 1] = 1
	terrain.data.pathing.movement[1 * width + 1] = "blocked"
	terrain.data.cliffs.ramps = [{"x": 1, "z": 1, "direction": "east"}, {"x": 1, "z": 2, "direction": "south"}]
	var source_before := terrain.serialize()
	var revision_before := int(terrain.revision)
	var domains := {"height": true, "surface": true, "cliff": true, "water": false, "pathing": true}
	var clipboard: Dictionary = workflow.copy_selection(domains)
	_check(terrain.serialize() == source_before and int(terrain.revision) == revision_before and clipboard.ramps.size() == 1 and clipboard.boundary_ramps.size() == 1, "Copy is immutable and separates complete from boundary ramp edges")

	var move_preview := workflow.preview_operation(clipboard, Vector2i(2, 1), "move", "replace", ["guard_001"])
	_check(move_preview.confirm_enabled and move_preview.overlap_cells == 2 and move_preview.changed_cells > 0 and move_preview.changed_vertices > 0 and move_preview.intersecting_authored_ids == ["guard_001"], "Overlapping Move preview reports exact impact without mutation")
	_check(terrain.serialize() == source_before and int(terrain.revision) == revision_before and terrain.history_depth() == 0, "Preview does not change data, revision, dirty cursor, or history")
	var candidate: Dictionary = move_preview.candidate
	_check(candidate.pathing.movement[1 * width + 1] == "inherit" and candidate.pathing.movement[1 * width + 2] == "blocked", "Move neutralizes source before frozen destination wins overlap")
	_check(candidate.grid.heights_cm[1 * (width + 1) + 1] == 0 and candidate.grid.heights_cm[1 * (width + 1) + 2] == 111, "Move uses the full vertex footprint and destination wins shared vertices")
	_check(candidate.cliffs.ramps.has({"x": 1, "z": 2, "direction": "south"}) and candidate.cliffs.ramps.has({"x": 2, "z": 1, "direction": "east"}), "Boundary ramp remains while a complete source ramp moves")
	_check(workflow.confirm_operation(move_preview) and terrain.history_depth() == 1, "Confirm creates exactly one terrain history entry")
	_check(terrain.undo() and terrain.serialize() == source_before, "One Undo restores the complete overlapping Move")

	var same := workflow.preview_operation(clipboard, Vector2i(1, 1), "move")
	var clipped_move := workflow.preview_operation(clipboard, Vector2i(7, 7), "move")
	var clipped_paste := workflow.preview_operation(clipboard, Vector2i(7, 7), "paste")
	_check(not same.confirm_enabled and "unchanged" in same.error and not clipped_move.confirm_enabled and clipped_move.clipped_cells == 3, "Same-location and clipped Move previews are disabled with recovery")
	_check(clipped_paste.confirm_enabled and clipped_paste.clipped_cells == 3 and clipped_paste.requested == Rect2i(7, 7, 2, 2) and clipped_paste.destination == Rect2i(7, 7, 1, 1), "Paste preview exposes requested and committed clipping rectangles")

	var fresh_clipboard := workflow.copy_selection(domains)
	var stale_preview := workflow.preview_operation(fresh_clipboard, Vector2i(4, 4), "paste")
	var unrelated_candidate: Dictionary = terrain.data.duplicate(true)
	unrelated_candidate.pathing.placement[0] = "blocked"
	_check(terrain.commit_structural("Make preview stale", unrelated_candidate), "Stale-preview fixture changes terrain")
	var stale_state := terrain.serialize()
	_check(not workflow.confirm_operation(stale_preview) and terrain.serialize() == stale_state and "preview again" in workflow.last_error, "Confirm revalidates revision and rejects a stale preview without mutation")

	workflow.select_cells(Vector2i(0, 0), Vector2i(0, 0))
	var budget_clipboard := workflow.copy_selection({"height": false, "surface": false, "cliff": false, "water": false, "pathing": true})
	workflow.history_budget_bytes = 1
	var budget_preview := workflow.preview_operation(budget_clipboard, Vector2i(6, 6), "paste")
	_check(not budget_preview.confirm_enabled and "history budget" in budget_preview.error, "History-budget preflight disables Confirm before mutation")
	workflow.history_budget_bytes = TERRAIN.HISTORY_BUDGET_BYTES
	var invalid_cliff := budget_clipboard.duplicate(true)
	invalid_cliff.domains = {"height": false, "surface": false, "cliff": true, "water": false, "pathing": false}
	invalid_cliff.cliff_style_id = terrain.data.cliffs.style_id
	invalid_cliff.cliff_levels = [16]
	invalid_cliff.ramps = []
	var validation_preview := workflow.preview_operation(invalid_cliff, Vector2i(6, 6), "paste")
	_check(not validation_preview.confirm_enabled and "level difference" in validation_preview.error, "Candidate validation failures disable Confirm with recovery text")
	var foreign = TERRAIN.new(); foreign.create(8, 8, 1.0, 0)
	var foreign_workflow = WORKFLOW.new(foreign); foreign_workflow.select_cells(Vector2i.ZERO, Vector2i.ZERO)
	var foreign_clipboard := foreign_workflow.copy_selection(domains)
	var foreign_move := workflow.preview_operation(foreign_clipboard, Vector2i(2, 2), "move")
	_check(not foreign_move.confirm_enabled and "different terrain document" in foreign_move.error, "A Move source from another terrain document is recoverably rejected")
	terrain.data.grid.heights_cm[0] = 112
	workflow.select_cells(Vector2i.ZERO, Vector2i.ZERO)
	var exact_height_clipboard := workflow.copy_selection({"height": true, "surface": false, "cliff": false, "water": false, "pathing": false})
	_check(workflow.snapped_height_cm(112) == 100 and exact_height_clipboard.heights_cm[0] == 112, "Height snap affects an explicit sampled target but never copied height data")

	terrain.data.attachments = [{"target_id": "guard_001", "mode": "grounded", "offset_cm": 0}]
	var sampled := workflow.sample(Vector2i(1, 1), {"guard_001": [-2.5, 0.0, -4.5]})
	_check(sampled.world is Vector3 and sampled.has_all(["authored_height_cm", "effective_height_cm", "surfaces", "water_depth_cm", "water_class", "movement_reasons", "placement_reasons", "attachments"]) and sampled.attachments.size() == 1, "Eyedropper reports authored/effective terrain details and intersecting attachment targets")
	var target = TERRAIN.new(); target.create(128, 128, 1.0, 0, -64.0, -64.0)
	var target_workflow = WORKFLOW.new(target); target_workflow.select_cells(Vector2i(8, 8), Vector2i(23, 23))
	var target_clipboard := target_workflow.copy_selection({"height": true, "surface": true, "cliff": true, "water": false, "pathing": true})
	var timings: Array[int] = []
	for offset in 20:
		var started := Time.get_ticks_usec()
		target_workflow.preview_destination(target_clipboard, Vector2i(40 + offset, 40), "paste")
		timings.append(roundi(float(Time.get_ticks_usec() - started) / 1000.0))
	timings.sort()
	var median: int = timings[timings.size() / 2]
	var p95: int = timings[ceili(timings.size() * 0.95) - 1]
	_check(median <= 16 and p95 <= 33, "Target live-preview latency stays within 16 ms median / 33 ms p95; median=%d p95=%d" % [median, p95])
	var settled := target_workflow.preview_operation(target_clipboard, Vector2i(64, 64), "paste")
	var commit_started := Time.get_ticks_usec()
	var committed: bool = target_workflow.confirm_operation(settled)
	var commit_ms := roundi(float(Time.get_ticks_usec() - commit_started) / 1000.0)
	_check(committed and commit_ms <= 250, "Target confirmed gesture commits within 250 ms; commit=%d" % commit_ms)
