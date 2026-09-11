extends SceneTree

const ScenarioScript := preload("res://src/domain/scenario_document.gd")
var failures: Array[String] = []


func _init() -> void:
	var world := {"objects":[{"instance_id":"guide_001"}]}
	var scenario = ScenarioScript.new()
	_check(scenario.create("guided_path","Guided Path","A test journey","frontier_company",world), "Scenario document creates without JSON editing")
	_check(scenario.update_metadata("New Title","Updated","player_company",world) and scenario.data.title == "New Title", "Metadata update is validated and undoable")
	_check(scenario.add_region("start","Start","point",[[0,0,0]],world), "Point region is added")
	_check(scenario.add_region("arena","Arena","rectangle",[[1,0,1],[5,0,5]],world), "Rectangle region is added")
	_check(scenario.add_region("route","Route","path",[[0,0,0],[2,0,3],[5,0,5]],world), "Ordered path region is added")
	_check(scenario.reverse_path("route",world) and scenario.find_region("route").points[0] == [5,0,5], "Path point order can be reversed")
	_check(scenario.update_region("arena",{"display_name":"Encounter Arena","points":[[2,0,2],[6,0,6]]},world), "Region rename, move, and resize commit together")
	_check(scenario.undo() and scenario.find_region("arena").display_name == "Arena", "Region editing participates in undo")
	_check(scenario.redo() and scenario.find_region("arena").display_name == "Encounter Arena", "Region editing participates in redo")
	_check(scenario.delete_region("start",world) and scenario.find_region("start").is_empty(), "Unreferenced region deletes")
	scenario.data.sequences.append({"sequence_id":"enter_arena","enabled":true,"one_shot":true,"event":{"type":"unit_enters_region","group_id":"guide","region_id":"arena"},"conditions":[],"actions":[{"type":"complete_scenario","result":"victory"}]})
	scenario.data.unit_groups.append({"group_id":"guide","instance_ids":["guide_001"]})
	_check(not scenario.delete_region("arena",world) and "enter_arena" in scenario.errors[0], "Referenced region deletion names its sequence")
	_check(scenario.canonical_text().find('"region_id":"arena"') < scenario.canonical_text().find('"region_id":"route"'), "Region save order is deterministic by ID")
	if failures.is_empty(): print("PASS: scenario metadata and region lifecycle"); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
