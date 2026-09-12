extends SceneTree

const TerrainDocument=preload("res://src/domain/terrain_document.gd")
const TerrainPathing=preload("res://src/domain/terrain_pathing.gd")


func _init()->void:
	var output:=OS.get_environment("T0_PATHING_PROBE_PATH")
	if output.is_empty():push_error("T0_PATHING_PROBE_PATH is required");quit(1);return
	var terrain=TerrainDocument.new();terrain.data=terrain.make_default(8,8,1.0,0,-4.0,-4.0);var pathing=TerrainPathing.new(terrain);var result:Dictionary={}
	var cases:Array=[{"direction":"east","lower":Vector2i(3,4),"upper":Vector2i(4,4),"side":Vector2i(3,3)},{"direction":"west","lower":Vector2i(4,4),"upper":Vector2i(3,4),"side":Vector2i(4,3)},{"direction":"south","lower":Vector2i(4,3),"upper":Vector2i(4,4),"side":Vector2i(3,3)},{"direction":"north","lower":Vector2i(4,4),"upper":Vector2i(4,3),"side":Vector2i(3,4)}]
	for item in cases:
		terrain.data.grid.heights_cm.fill(0);terrain.data.cliffs.levels.fill(0);terrain.data.cliffs.levels[terrain.cell_index(item.upper.x,item.upper.y)]=1;terrain.data.cliffs.ramps=[{"x":item.lower.x,"z":item.lower.y,"direction":item.direction}]
		result[item.direction]={"ramp_step":pathing.can_step(item.lower,item.upper),"side_step":pathing.can_step(item.side,item.lower)}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:push_error("T0 pathing probe could not be written");quit(1);return
	file.store_string(JSON.stringify(result)+"\n");file.close();print("T0_EDITOR_PATHING_PROBE|directions=4");quit(0)
