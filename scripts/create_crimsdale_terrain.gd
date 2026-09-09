extends SceneTree

const TerrainDocumentScript = preload("res://src/domain/terrain_document.gd")


func _init() -> void:
	var terrain = TerrainDocumentScript.new()
	if not terrain.create(128, 128, 1.0, 0, -64.0, -64.0):
		for failure in terrain.errors:
			push_error(failure)
		quit(1)
		return
	if not terrain.save("res://worlds/crimsdale/terrain.json"):
		for failure in terrain.errors:
			push_error(failure)
		quit(1)
		return
	print("Created canonical 128 × 128 Crimsdale terrain")
	quit(0)
