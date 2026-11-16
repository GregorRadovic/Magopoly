extends Node2D

# Wizard Vision: an arrow from the rolling player's token to the tile their
# roll would land them on, shown while a roll is in flight. main.gd drives it
# via show_line() / hide_line() -- see _update_wizard_vision(). Drawn in the
# moving player's own colour, over a dark casing so it stays legible on any
# board colour. The board tile it points at is highlighted separately by
# main.gd (BoardSpace.set_landing_highlight).

const CASING_COLOR: Color = Color(0, 0, 0, 0.55)
const CASING_WIDTH: float = 7.0
const LINE_WIDTH: float = 4.0
# Arrowhead: length along the shaft, and half-width at its base.
const HEAD_LEN: float = 24.0
const HEAD_HALF_W: float = 14.0

var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2.ZERO
var line_color: Color = Color.RED
var active: bool = false
# Short extra arrows, each [from, to] -- a teleport is shown as one pointing
# from the square the dice reach in towards the board's centre, and one
# pointing into the destination (no line across the board).
var extra_arrows: Array = []
const SMALL_HEAD_LEN: float = 16.0
const SMALL_HEAD_HALF_W: float = 10.0


func _draw() -> void:
	if not active:
		return
	for arrow in extra_arrows:
		_draw_arrow(arrow[0], arrow[1], SMALL_HEAD_LEN, SMALL_HEAD_HALF_W)
	var delta: Vector2 = to_pos - from_pos
	if delta.length() < HEAD_LEN + 4.0:
		# Too short to bother with an arrowhead -- just a stub line.
		draw_line(from_pos, to_pos, CASING_COLOR, CASING_WIDTH)
		draw_line(from_pos, to_pos, line_color, LINE_WIDTH)
		return
	var dir: Vector2 = delta.normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var base: Vector2 = to_pos - dir * HEAD_LEN  # where the shaft meets the head

	# Shaft (stops at the arrowhead base so the tip isn't doubled up).
	draw_line(from_pos, base, CASING_COLOR, CASING_WIDTH)
	draw_line(from_pos, base, line_color, LINE_WIDTH)

	# Arrowhead: a dark triangle a touch larger, then the coloured one on top.
	var tip: Vector2 = to_pos
	var left: Vector2 = base + perp * HEAD_HALF_W
	var right: Vector2 = base - perp * HEAD_HALF_W
	var pad: Vector2 = dir * 3.0
	draw_colored_polygon(PackedVector2Array([tip + pad, left + perp * 2.5 - pad, right - perp * 2.5 - pad]), CASING_COLOR)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), line_color)


# A straight arrow (cased like the main one) from `from` to `to`.
func _draw_arrow(from: Vector2, to: Vector2, head_len: float, head_half_w: float) -> void:
	var dir: Vector2 = (to - from).normalized()
	var base: Vector2 = to - dir * head_len
	draw_line(from, base, CASING_COLOR, CASING_WIDTH)
	draw_line(from, base, line_color, LINE_WIDTH)
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var left: Vector2 = base + perp * head_half_w
	var right: Vector2 = base - perp * head_half_w
	var pad: Vector2 = dir * 3.0
	draw_colored_polygon(PackedVector2Array([to + pad, left + perp * 2.5 - pad, right - perp * 2.5 - pad]), CASING_COLOR)
	draw_colored_polygon(PackedVector2Array([to, left, right]), line_color)


# `arrows`: extra short [from, to] arrows (a teleport's -- see extra_arrows).
func show_line(new_from: Vector2, new_to: Vector2, color: Color = Color.RED, arrows: Array = []) -> void:
	from_pos = new_from
	to_pos = new_to
	extra_arrows = arrows
	line_color = color
	active = true
	queue_redraw()


func hide_line() -> void:
	if not active:
		return
	active = false
	queue_redraw()
