extends SceneTree

const PackageScript:=preload("res://src/domain/world_package.gd")
const ScenarioScript:=preload("res://src/domain/scenario_document.gd")
var failures:Array[String]=[]


func _init()->void:
	var package=PackageScript.new();_check(package.load_from_directory("res://worlds/crimsdale"),"Crimsdale package loads")
	var scenario=ScenarioScript.new();_check(scenario.create_guided_mission_template("template_proof",package.world,package.definitions),"One action creates a valid guided mission from placed role-compatible units: "+" | ".join(scenario.errors))
	if not scenario.data.is_empty():
		_check(scenario.validate(scenario.data,package.world).is_empty(),"Generated scenario passes the canonical contract")
		var authored_ids:Array=[scenario.data.scenario_id];for collection in [scenario.data.regions,scenario.data.unit_groups,scenario.data.objectives,scenario.data.tutorials,scenario.data.encounters,scenario.data.cinematics,scenario.data.sequences]:
			for value in collection:
				for key in ["region_id","group_id","objective_id","tutorial_id","encounter_id","cinematic_id","sequence_id"]:
					if value.has(key):authored_ids.append(value[key])
		_check(scenario.data.title=="Guided Mission" and authored_ids.all(func(value):return "lantern" not in value and "mara" not in value and "crimsdale" not in value),"Template-authored IDs contain no story- or world-specific names")
		_check(scenario.data.unit_groups.size()==4 and scenario.data.encounters.size()==2,"Template assigns leader, allies, and two staged hostile groups")
		_check(scenario.data.cinematics.size()==2 and scenario.data.sequences[-1].actions[-1].result=="victory","Template includes skippable bookends and an opening-to-victory sequence")
		_check(scenario.data.tutorials.any(func(value):return value.control=="ability"),"Hero capability automatically adds signature-ability guidance")
	var insufficient=ScenarioScript.new();_check(not insufficient.create_guided_mission_template("cannot_build",{"objects":[]},[]),"Template reports missing placed roles instead of producing broken data")
	if failures.is_empty():print("PASS: reusable guided mission template from empty scenario state");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)


func _check(condition:bool,message:String)->void:
	if not condition:failures.append(message)
