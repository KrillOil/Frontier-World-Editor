class_name TerrainPathing
extends RefCounted

const CliffWaterScript = preload("res://src/domain/terrain_cliff_water.gd")
const RULES_VERSION := 1
const MOVEMENT_SLOPE_DEG := 45.0
const PLACEMENT_SLOPE_DEG := 15.0
const CLEARANCE_RADII_M := [0.5, 1.0, 2.0]

var terrain
var cancelled := false
var rebuilding := false
var stale := false
var last_overlay: Array[Dictionary] = []
var painting:=false
var paint_layer:="movement"
var paint_blocked:=true
var paint_radius_m:=1.0
var paint_cells:Dictionary={}
var _paint_last:=Vector2.ZERO
var _paint_until:=0.0


func _init(document = null) -> void:
	terrain = document


func reasons(x: int, z: int, layer := "movement") -> Array[String]:
	if not _valid_cell(x,z): return ["bounds"]
	var result: Array[String]=[]
	if terrain.data.pathing[layer][z*int(terrain.data.grid.width_cells)+x]=="blocked": result.append("authored_block")
	var water_class: String=CliffWaterScript.new(terrain).water_class_at_cell(x,z)
	if layer=="movement" and water_class=="deep": result.append("deep_water")
	if layer=="placement" and water_class!="dry": result.append("water")
	if _cell_has_cliff_edge(x,z): result.append("cliff_edge")
	var slope: float=_cell_slope_degrees(x,z)
	if layer=="movement" and slope>MOVEMENT_SLOPE_DEG: result.append("steep_slope")
	if layer=="placement" and slope>PLACEMENT_SLOPE_DEG: result.append("steep_slope")
	return result


func can_step(from:Vector2i,to:Vector2i)->bool:
	if not reasons(to.x,to.y).is_empty(): return false
	var delta: Vector2i=to-from
	if absi(delta.x)>1 or absi(delta.y)>1 or delta==Vector2i.ZERO: return false
	if delta.x!=0 and delta.y!=0:
		return reasons(from.x+delta.x,from.y).is_empty() and reasons(from.x,from.y+delta.y).is_empty()
	return not _edge_blocked(from,to)


func has_clearance(x:int,z:int,radius_m:float,layer:="movement")->bool:
	if radius_m not in CLEARANCE_RADII_M: return false
	var cell_size: float=float(terrain.data.grid.cell_size_m)
	var cells: int=ceili(radius_m/cell_size)
	for dz in range(-cells,cells+1):
		for dx in range(-cells,cells+1):
			if Vector2(dx,dz).length()*cell_size<=radius_m and not reasons(x+dx,z+dz,layer).is_empty(): return false
	return true


func paint(layer:String,blocked:bool,center:Vector2,radius_m:float)->bool:
	begin_paint(layer,blocked,center,radius_m)
	return commit_paint()


func begin_paint(layer:String,blocked:bool,center:Vector2,radius_m:float)->bool:
	if layer not in ["movement","placement"]: return false
	paint_layer=layer;paint_blocked=blocked;paint_radius_m=maxf(radius_m,float(terrain.data.grid.cell_size_m)*0.5)
	paint_cells.clear();_paint_last=center;_paint_until=_paint_spacing();painting=true
	_collect_paint(center)
	return true


func extend_paint(center:Vector2)->void:
	if not painting:return
	var segment:=center-_paint_last;var length:=segment.length()
	if length<=0.000001:return
	var direction:=segment/length;var travelled:=0.0
	while travelled+_paint_until<=length+0.000001:
		travelled+=_paint_until;_collect_paint(_paint_last+direction*travelled);_paint_until=_paint_spacing()
	_paint_until-=length-travelled;_paint_last=center


func commit_paint()->bool:
	if not painting:return false
	painting=false
	var indices:Array=paint_cells.keys();indices.sort();var after:Array=[]
	for index in indices:after.append("blocked" if paint_blocked else "inherit")
	if indices.is_empty():return true
	stale=true
	return terrain.commit_tile_delta("Paint %s pathing"%paint_layer,[{"path":["pathing",paint_layer],"indices":indices,"after":after}])


func cancel_paint()->void:
	painting=false;paint_cells.clear()


func _collect_paint(center:Vector2)->void:
	var grid:Dictionary=terrain.data.grid
	var cx: float=(center.x-float(grid.origin_x_m))/float(grid.cell_size_m)-0.5
	var cz: float=(center.y-float(grid.origin_z_m))/float(grid.cell_size_m)-0.5
	var cell_radius: float=maxf(paint_radius_m/float(grid.cell_size_m),0.5)
	for z in range(maxi(0,floori(cz-cell_radius)),mini(int(grid.depth_cells)-1,ceili(cz+cell_radius))+1):
		for x in range(maxi(0,floori(cx-cell_radius)),mini(int(grid.width_cells)-1,ceili(cx+cell_radius))+1):
			if Vector2(x-cx,z-cz).length()<=cell_radius:
				paint_cells[z*int(grid.width_cells)+x]=true


func _paint_spacing()->float:
	return maxf(float(terrain.data.grid.cell_size_m)*0.25,paint_radius_m*0.25)


func rebuild_overlay(layer:="movement")->bool:
	if cancelled:return false
	rebuilding=true
	var candidate:Array[Dictionary]=[]
	for z in int(terrain.data.grid.depth_cells):
		if cancelled: rebuilding=false; return false
		for x in int(terrain.data.grid.width_cells): candidate.append({"x":x,"z":z,"reasons":reasons(x,z,layer)})
	last_overlay=candidate; rebuilding=false; stale=false
	return true


func cancel_rebuild()->void:
	cancelled=true


func reset_cancellation()->void:
	cancelled=false


func validate_connectivity(world:Dictionary)->Array[Dictionary]:
	var messages:Array[Dictionary]=[]
	var start: Vector2i=_spawn_cell(world,"player_start")
	if not _valid_cell(start.x,start.y) or not reasons(start.x,start.y).is_empty():
		messages.append({"severity":"error","code":"invalid_start","cells":[start]}); return messages
	var reachable: Dictionary=_flood(start)
	for spawn in world.get("spawn_points",[]):
		var cell: Vector2i=_world_cell(spawn.position)
		if not reachable.has(cell): messages.append({"severity":"error","code":"unreachable_spawn","target_id":spawn.spawn_id,"cells":[cell]})
	var traversable: int=0
	for z in int(terrain.data.grid.depth_cells):
		for x in int(terrain.data.grid.width_cells):
			if reasons(x,z).is_empty(): traversable+=1
	if reachable.size()<traversable: messages.append({"severity":"warning","code":"isolated_area","cells":_unreachable_cells(reachable)})
	return messages


func _flood(start:Vector2i)->Dictionary:
	var visited: Dictionary={start:true}; var queue:Array[Vector2i]=[start]
	while not queue.is_empty():
		var cell: Vector2i=queue.pop_front()
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+step
			if not visited.has(next) and can_step(cell,next): visited[next]=true; queue.append(next)
	return visited


func _unreachable_cells(reachable:Dictionary)->Array[Vector2i]:
	var result:Array[Vector2i]=[]
	for z in int(terrain.data.grid.depth_cells):
		for x in int(terrain.data.grid.width_cells):
			var cell: Vector2i=Vector2i(x,z)
			if reasons(x,z).is_empty() and not reachable.has(cell): result.append(cell)
	return result


func _spawn_cell(world:Dictionary,id:String)->Vector2i:
	for spawn in world.get("spawn_points",[]):
		if spawn.spawn_id==id: return _world_cell(spawn.position)
	return Vector2i(-1,-1)


func _world_cell(position:Array)->Vector2i:
	return Vector2i(floori((float(position[0])-float(terrain.data.grid.origin_x_m))/float(terrain.data.grid.cell_size_m)),floori((float(position[2])-float(terrain.data.grid.origin_z_m))/float(terrain.data.grid.cell_size_m)))


func _cell_slope_degrees(x:int,z:int)->float:
	var width: int=int(terrain.data.grid.width_cells)+1
	var values: Array=[terrain.data.grid.heights_cm[z*width+x],terrain.data.grid.heights_cm[z*width+x+1],terrain.data.grid.heights_cm[(z+1)*width+x],terrain.data.grid.heights_cm[(z+1)*width+x+1]]
	return rad_to_deg(atan((float(values.max())-float(values.min()))/100.0/float(terrain.data.grid.cell_size_m)))


func _cell_has_cliff_edge(x:int,z:int)->bool:
	for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		if _valid_cell(x+step.x,z+step.y) and _edge_blocked(Vector2i(x,z),Vector2i(x+step.x,z+step.y)): return true
	return false


func _edge_blocked(a:Vector2i,b:Vector2i)->bool:
	var width: int=int(terrain.data.grid.width_cells)
	if int(terrain.data.cliffs.levels[a.y*width+a.x])==int(terrain.data.cliffs.levels[b.y*width+b.x]): return false
	var direction: String="east" if b.x>a.x else "west" if b.x<a.x else "south" if b.y>a.y else "north"
	return not CliffWaterScript.new(terrain).edge_has_ramp(a.x,a.y,direction)


func _valid_cell(x:int,z:int)->bool:
	return x>=0 and z>=0 and x<int(terrain.data.grid.width_cells) and z<int(terrain.data.grid.depth_cells)
