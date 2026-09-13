class_name WorkflowInputGuard
extends Control

var dispatcher: Callable


func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_process_input(true)


func _input(event:InputEvent)->void:
	if is_visible_in_tree() and dispatcher.is_valid() and dispatcher.call(event):
		get_viewport().set_input_as_handled()
