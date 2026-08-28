extends Node2D

var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2.ZERO
var active: bool = false


func _draw() -> void:
	if active:
		draw_line(from_pos, to_pos, Color.RED, 3.0)


func show_line(new_from: Vector2, new_to: Vector2) -> void:
	from_pos = new_from
	to_pos = new_to
	active = true
	queue_redraw()


func hide_line() -> void:
	if not active:
		return
	active = false
	queue_redraw()
