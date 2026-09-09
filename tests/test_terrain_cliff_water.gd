extends SceneTree

const TerrainScript = preload("res://src/domain/terrain_document.gd")
const CliffWaterScript = preload("res://src/domain/terrain_cliff_water.gd")
var failures: Array[String] = []


func _init() -> void:
	var terrain = TerrainScript.new()
	terrain.create(8, 8, 1.0, 0)
	var tools = CliffWaterScript.new(terrain)
	_check(tools.change_level(3, 3, 1), "Cliff cell raises one discrete level")
	_check(tools.change_level(3, 3, -1), "Cliff cell lowers one discrete level")
	_check(terrain.undo() and terrain.redo(), "Cliff level changes participate in exact undo/redo")
	terrain.data.cliffs.levels.fill(0)
	terrain.data.cliffs.levels[3 * 8 + 3] = 1
	terrain.data.cliffs.levels[2 * 8 + 3] = 1
	terrain.data.cliffs.levels[4 * 8 + 3] = 1
	terrain.data.cliffs.levels[3 * 8 + 2] = 1
	_check(not tools.change_level(3, 3, 1), "Difference above one rejects without a ramp")
	_check(tools.add_ramp(3, 3, "east"), "Authored traversable ramp adds at a stable edge")
	_check(tools.change_level(3, 3, 1), "Ramp explicitly permits its otherwise-invalid edge")
	_check(tools.set_style("cliff_dark_highland") and terrain.data.cliffs.style_id == "cliff_dark_highland", "Cliff presentation replaces without topology changes")

	terrain = TerrainScript.new()
	terrain.create(8, 8, 1.0, 0)
	tools = CliffWaterScript.new(terrain)
	_check(tools.set_water(true, 100), "Global water level enables")
	_check(tools.water_class_at_cell(0, 0) == "shallow", "Exactly 100 cm is shallow water")
	tools.set_water(true, 101)
	_check(tools.water_class_at_cell(0, 0) == "deep", "Above 100 cm is deep water")
	terrain.data.grid.heights_cm[0] = 200
	terrain.data.grid.heights_cm[1] = 200
	terrain.data.grid.heights_cm[9] = 200
	terrain.data.grid.heights_cm[10] = 200
	_check(tools.water_class_at_cell(0, 0) == "dry", "Water equality and terrain intersections classify as dry")
	var shores_a := tools.derived_shores()
	var shores_b := tools.derived_shores()
	_check(shores_a == shores_b and shores_a.size() > 0, "Derived shores regenerate idempotently in stable edge order")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PASS: cliff topology, ramps, water depth, and derived shores")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)
