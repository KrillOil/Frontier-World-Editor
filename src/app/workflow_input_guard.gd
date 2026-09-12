class_name WorkflowInputGuard
extends Control

signal escape_requested


func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_process_input(true)


func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		escape_requested.emit()
		get_viewport().set_input_as_handled()
