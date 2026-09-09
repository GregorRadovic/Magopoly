extends Node2D

# Wizard Vision: the line from the rolling player's token to where their roll
# would land, shown while a roll is in flight. main.gd drives it via
# show_line() / hide_line() -- see _update_wizard_vision(). The line is drawn
# in the moving player's own colour, over a dark casing so it stays legible
# on any board colour.

const CASING_COLOR: Color = Color(0, 0, 0, 0.55)
const CASING_WIDTH: float = 6.0
const LINE_WIDTH: float = 3.0

var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2.ZERO
var line_color: Color = Color.RED
var active: bool = false


func _draw() -> void:
	if not active:
		return
	draw_line(from_pos, to_pos, CASING_COLOR, CASING_WIDTH)
	draw_line(from_pos, to_pos, line_color, LINE_WIDTH)


func show_line(new_from: Vector2, new_to: Vector2, color: Color = Color.RED) -> void:
	from_pos = new_from
	to_pos = new_to
	line_color = color
	active = true
	queue_redraw()


func hide_line() -> void:
	if not active:
		return
	active = false
	queue_redraw()
