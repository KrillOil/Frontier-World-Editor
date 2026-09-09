extends SceneTree

const TerrainScript = preload("res://src/domain/terrain_document.gd")
const SculptorScript = preload("res://src/domain/terrain_sculptor.gd")

var failures: Array[String] = []


func _init() -> void:
	var terrain = TerrainScript.new()
	_check(terrain.create(16, 16, 1.0, 0), "Sculpt fixture creates")
	var sculptor = SculptorScript.new(terrain)
	sculptor.begin("raise", Vector2(8, 8), {"radius_m": 2.0, "strength": 100.0, "falloff": "linear"})
	sculptor.extend(Vector2(12, 8))
	_check(terrain.data.grid.heights_cm.all(func(value): return value == 0), "Preview does not mutate canonical terrain")
	_check(sculptor.commit() and terrain.history.size() == 1, "A stroke commits as one delta transaction")
	var replay: Array = terrain.data.grid.heights_cm.duplicate()
	_check(terrain.undo() and terrain.data.grid.heights_cm.all(func(value): return value == 0), "Stroke undo restores exact before-state")
	sculptor = SculptorScript.new(terrain)
	sculptor.begin("raise", Vector2(8, 8), {"radius_m": 2.0, "strength": 100.0, "falloff": "linear"})
	for x in [9.0, 10.0, 11.0, 12.0]:
		sculptor.extend(Vector2(x, 8))
	sculptor.commit()
	_check(terrain.data.grid.heights_cm == replay, "Distance sampling ignores input-event segmentation")

	terrain.undo()
	terrain.data.grid.heights_cm.fill(100)
	for selected_tool in ["lower", "flatten", "smooth", "plateau", "noise"]:
		var before: Array = terrain.data.grid.heights_cm.duplicate()
		var operation = SculptorScript.new(terrain)
		operation.begin(selected_tool, Vector2(0, 0), {"radius_m": 3.0, "strength": 50.0, "target_height_cm": 250, "noise_seed": 42})
		_check(operation.commit(), "%s commits at a clamped border" % selected_tool)
		_check(terrain.data.grid.heights_cm != before or selected_tool == "smooth", "%s behavior is available" % selected_tool)
	_check(_noise_result(77) == _noise_result(77), "Seeded noise replays identically")
	var cancel_before: Array = terrain.data.grid.heights_cm.duplicate()
	sculptor = SculptorScript.new(terrain)
	sculptor.begin("raise", Vector2(4, 4), {"strength": 500})
	sculptor.cancel()
	_check(terrain.data.grid.heights_cm == cancel_before, "Cancel discards the preview buffer")
	var target = TerrainScript.new()
	target.create(128, 128, 1.0, 0, -64.0, -64.0)
	var timed = SculptorScript.new(target)
	var preview_start := Time.get_ticks_usec()
	timed.begin("raise", Vector2.ZERO, {"radius_m": 8.0, "strength": 20.0})
	timed.extend(Vector2(2.0, 0.0))
	var preview_ms := float(Time.get_ticks_usec() - preview_start) / 1000.0
	var commit_start := Time.get_ticks_usec()
	timed.commit()
	var commit_ms := float(Time.get_ticks_usec() - commit_start) / 1000.0
	_check(preview_ms <= 33.0, "128×128 pointer-to-preview stays within the 33 ms p95 ceiling")
	_check(commit_ms <= 2000.0, "128×128 commit stays within the 2 s ceiling")
	_finish()


func _noise_result(seed: int) -> Array:
	var terrain = TerrainScript.new()
	terrain.create(8, 8, 1.0, 0)
	var sculptor = SculptorScript.new(terrain)
	sculptor.begin("noise", Vector2(4, 4), {"radius_m": 4.0, "strength": 80.0, "noise_seed": seed})
	sculptor.commit()
	return terrain.data.grid.heights_cm


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PASS: deterministic terrain sculpt tools and gesture transactions")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
