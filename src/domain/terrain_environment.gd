class_name TerrainEnvironment
extends RefCounted

var terrain


func _init(document=null)->void:terrain=document


func apply(values:Dictionary)->bool:
	var candidate:Dictionary=terrain.data.duplicate(true)
	for key in values:candidate.environment[key]=values[key]
	return terrain.commit_structural("Edit environment",candidate)


func sun_rotation_degrees()->Vector3:
	return Vector3(-float(terrain.data.environment.sun_elevation_deg),-float(terrain.data.environment.sun_azimuth_deg),0)


func parity_probe()->Dictionary:
	var environment:Dictionary=terrain.data.environment
	return {"sun_rotation_degrees":sun_rotation_degrees(),"sun_color":Color(float(environment.sun_color_linear[0]),float(environment.sun_color_linear[1]),float(environment.sun_color_linear[2])),"sun_energy":float(environment.sun_energy),"ambient_color":Color(float(environment.ambient_color_linear[0]),float(environment.ambient_color_linear[1]),float(environment.ambient_color_linear[2])),"ambient_energy":float(environment.ambient_energy),"fog_enabled":bool(environment.fog_enabled),"fog_color":Color(float(environment.fog_color_linear[0]),float(environment.fog_color_linear[1]),float(environment.fog_color_linear[2])),"fog_density":float(environment.fog_density),"fog_start_m":float(environment.fog_start_m),"fog_end_m":float(environment.fog_end_m),"sky_id":environment.sky_id}
