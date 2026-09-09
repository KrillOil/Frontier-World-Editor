extends SceneTree

const TerrainScript=preload("res://src/domain/terrain_document.gd")
const PathingScript=preload("res://src/domain/terrain_pathing.gd")
var failures:Array[String]=[]


func _init()->void:
	var terrain=TerrainScript.new(); terrain.create(8,8,1.0,0)
	var pathing=PathingScript.new(terrain)
	_check(pathing.reasons(0,0).is_empty(),"Flat dry inherited cell is walkable")
	_check(pathing.paint("movement",true,Vector2(3.5,3.5),0.5),"Movement restriction paints")
	_check(pathing.reasons(3,3)==["authored_block"],"Movement overlay exposes authored reason")
	_check(pathing.paint("movement",false,Vector2(3.5,3.5),0.5) and pathing.reasons(3,3).is_empty(),"Erase restores inherit")
	pathing.paint("placement",true,Vector2(2.5,2.5),0.5)
	_check(pathing.reasons(2,2,"movement").is_empty() and pathing.reasons(2,2,"placement")==["authored_block"],"Movement and placement layers remain separate")
	terrain.data.water={"enabled":true,"level_cm":101}
	_check("deep_water" in pathing.reasons(1,1) and "water" in pathing.reasons(1,1,"placement"),"Water derivation has layer-specific reasons")
	terrain.data.water.enabled=false
	var width:=9; terrain.data.grid.heights_cm[4*width+4]=200
	_check("steep_slope" in pathing.reasons(3,3),"Movement derives steep slope restriction")
	terrain.data.grid.heights_cm[4*width+4]=0
	terrain.data.cliffs.levels[4*8+4]=1
	_check("cliff_edge" in pathing.reasons(3,4),"Un-ramped cliff edges restrict movement")
	terrain.data.cliffs.ramps=[{"direction":"east","x":3,"z":4}]
	_check("cliff_edge" not in pathing.reasons(3,4),"Authored ramp makes its shared edge traversable")
	terrain.data.cliffs.levels.fill(0); terrain.data.cliffs.ramps=[]
	pathing.paint("movement",true,Vector2(2.5,1.5),0.5)
	pathing.paint("movement",true,Vector2(1.5,2.5),0.5)
	_check(not pathing.can_step(Vector2i(1,1),Vector2i(2,2)),"Diagonal traversal cannot cut a blocked corner")
	_check(not pathing.has_clearance(0,0,1.0),"Clearance includes map bounds")
	_check(pathing.rebuild_overlay() and pathing.last_overlay.size()==64 and not pathing.stale,"Overlay rebuild publishes one atomic complete result")
	var valid_overlay:Array[Dictionary]=pathing.last_overlay.duplicate(true)
	pathing.cancel_rebuild()
	_check(not pathing.rebuild_overlay() and pathing.last_overlay==valid_overlay,"Cancelled rebuild retains the last complete overlay")
	pathing.reset_cancellation()
	var world={"spawn_points":[{"spawn_id":"player_start","position":[0.5,0,0.5],"rotation_y":0},{"spawn_id":"remote","position":[7.5,0,7.5],"rotation_y":0}]}
	for z in 8: pathing.paint("movement",true,Vector2(4.5,float(z)+0.5),0.5)
	var messages:=pathing.validate_connectivity(world)
	_check(messages.any(func(item):return item.code=="unreachable_spawn" and item.severity=="error"),"Unreachable spawn reports an exact error")
	_check(messages.any(func(item):return item.code=="isolated_area" and item.severity=="warning"),"Isolated traversable area reports cell locations")
	_check(terrain.undo(),"Pathing paint participates in terrain undo")
	_finish()


func _check(condition:bool,message:String)->void:
	if not condition:failures.append(message)


func _finish()->void:
	if failures.is_empty():print("PASS: effective pathing, clearance, overlay, and connectivity validation");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)
