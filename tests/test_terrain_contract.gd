extends SceneTree

const TerrainDocumentScript = preload("res://src/domain/terrain_document.gd")
const FIXTURE := "res://tests/fixtures/terrain_tiny/terrain.json"
const EXPECTED_HASH := "9115f172ad772eed7c1263f9234407e42e1d723a10be6200c2de012f30e1b1d8"

var failures: Array[String] = []


func _init() -> void:
	var terrain = TerrainDocumentScript.new()
	_check(terrain.load_from_file(FIXTURE), "Tiny terrain fixture validates: %s" % " | ".join(terrain.errors))
	if terrain.errors.is_empty():
		_check(terrain.canonical_hash() == EXPECTED_HASH, "Canonical terrain hash matches")
		_check(is_equal_approx(terrain.sample_height(-4.0, -4.0), 0.0), "North-west boundary sample matches")
		_check(is_equal_approx(terrain.sample_height(0.0, 0.0), 1.0), "Interior height sample matches")
		_check(terrain.cell_index(3, 2) == 19, "Cell ordering is row-major")
		_check(terrain.pathing_reasons(3, 2) == ["authored_block"], "Movement pathing reason matches")
		_check(terrain.pathing_reasons(3, 3, "placement") == ["authored_block"], "Placement pathing remains separate")
	var future: Dictionary = terrain.data.duplicate(true)
	future.terrain_format_version = 2
	_check(terrain.validate(future).any(func(message): return "unsupported terrain_format_version" in message), "Future required terrain versions are rejected")
	var accepted_outward:Array[String]=[]
	for ramp in [{"x":0,"z":3,"direction":"west"},{"x":7,"z":3,"direction":"east"},{"x":3,"z":0,"direction":"north"},{"x":3,"z":7,"direction":"south"}]:
		var boundary:Dictionary=terrain.data.duplicate(true);boundary.cliffs.ramps=[ramp]
		if not terrain.validate(boundary).any(func(message):return "points outside terrain bounds" in message):accepted_outward.append(ramp.direction)
	_check(accepted_outward.is_empty(), "Canonical validation rejects all four outward-facing boundary ramps; accepted=%s" % [accepted_outward])
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PASS: terrain contract and golden probes")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
