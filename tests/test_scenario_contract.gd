extends SceneTree

const ScenarioScript := preload("res://src/domain/scenario_document.gd")
var failures: Array[String] = []


func _init() -> void:
	var world := {"objects":[{"instance_id":"crimsdale_guard_001"}]}
	var scenario = ScenarioScript.new()
	_check(scenario.load_from_file("res://tests/fixtures/scenario_tiny/scenario.json", world), "Shared golden scenario loads")
	_check(scenario.content_hash() == "1744db8ea85b5221fb30e527ca071a7563f7c767e6cd79e4f545a3a2b5937491", "Canonical scenario probe is pinned")
	_check(float(scenario.data.regions[0].points[0][0]) == 2.0 and float(scenario.data.regions[0].points[0][2]) == 3.0 and scenario.data.sequences[0].actions.size() == 2, "Coordinates and action order match the contract")
	var unsupported: Dictionary = scenario.data.duplicate(true); unsupported.scenario_format_version = 2
	_check(_contains(scenario.validate(unsupported, world), "unsupported scenario_format_version"), "Unsupported versions fail actionably")
	var unknown: Dictionary = scenario.data.duplicate(true); unknown.sequences[0].actions[0].mystery = true
	_check(_contains(scenario.validate(unknown, world), "unknown field"), "Unknown action fields fail instead of being ignored")
	var unresolved: Dictionary = scenario.data.duplicate(true); unresolved.unit_groups[0].instance_ids = ["missing_unit"]
	_check(_contains(scenario.validate(unresolved, world), "unknown world instance"), "Unresolved world references fail")
	if failures.is_empty(): print("PASS: scenario v1 contract and golden probes"); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
func _contains(messages: Array[String], fragment: String) -> bool:
	return messages.any(func(message): return fragment in message)
