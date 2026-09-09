extends SceneTree

const TerrainScript=preload("res://src/domain/terrain_document.gd")
const EnvironmentScript=preload("res://src/domain/terrain_environment.gd")
var failures:Array[String]=[]


func _init()->void:
	var terrain=TerrainScript.new();terrain.create(8,8,1.0,0)
	var environment=EnvironmentScript.new(terrain)
	var changes={"sun_azimuth_deg":120.0,"sun_elevation_deg":25.0,"sun_color_linear":[0.8,0.6,0.4],"sun_energy":2.0,"ambient_color_linear":[0.2,0.3,0.4],"ambient_energy":0.65,"fog_enabled":true,"fog_color_linear":[0.4,0.45,0.5],"fog_density":0.025,"fog_start_m":10.0,"fog_end_m":90.0,"sky_id":"sky_crimsdale_dusk"}
	_check(environment.apply(changes),"Complete environment applies")
	var probe:=environment.parity_probe()
	_check(probe.sun_rotation_degrees==Vector3(-25,-120,0) and probe.sun_color==Color(0.8,0.6,0.4),"Sun parity probe preserves coordinates and linear color")
	_check(probe.ambient_energy==0.65 and probe.fog_enabled and probe.fog_start_m==10.0 and probe.sky_id=="sky_crimsdale_dusk","Ambient, fog, and sky values preserve exactly")
	_check(terrain.undo() and terrain.data.environment.sky_id=="sky_crimsdale_day","Environment apply is one undoable transaction")
	_check(terrain.redo() and terrain.data.environment.sky_id=="sky_crimsdale_dusk","Environment redo restores exact values")
	var invalid:Dictionary=terrain.data.duplicate(true);invalid.environment.fog_end_m=invalid.environment.fog_start_m
	_check(not terrain.validate(invalid).is_empty(),"Invalid fog range is rejected")
	invalid=terrain.data.duplicate(true);invalid.environment.sun_energy=17
	_check(not terrain.validate(invalid).is_empty(),"Out-of-range light energy is rejected")
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://content/crimsdale/terrain_skies.json"))
	_check(catalog.catalog_format_version==1 and catalog.skies.size()==2,"Portable sky catalog is versioned and browseable")
	var path:="user://terrain_environment/terrain.json";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()));terrain.save(path);var bytes:=FileAccess.get_file_as_string(path)
	var reopened=TerrainScript.new();reopened.load_from_file(path);reopened.save();_check(FileAccess.get_file_as_string(path)==bytes,"Environment save/reopen remains byte deterministic")
	_finish()


func _check(condition:bool,message:String)->void:
	if not condition:failures.append(message)


func _finish()->void:
	if failures.is_empty():print("PASS: environment authoring, parity probes, validation, and persistence");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)
