extends SceneTree

const SHELL_PATH := "res://src/app/editor_shell.tscn"


func _init() -> void:
	var failures: Array[String] = []
	var packed_scene := load(SHELL_PATH) as PackedScene
	if packed_scene == null:
		failures.append("Editor shell could not be loaded: %s" % SHELL_PATH)
		finish(failures)
		return

	var shell := packed_scene.instantiate()
	for node_path in ["Workspace/Palette", "Workspace/Viewport", "Workspace/Inspector"]:
		if shell.get_node_or_null(node_path) == null:
			failures.append("Required shell pane is missing: %s" % node_path)

	if shell.find_children("*", "Button", true, false).size() != 0:
		failures.append("Foundation shell must not expose editing actions")

	shell.free()
	finish(failures)


func finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PASS: editor shell has palette, viewport, and inspector panes")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

