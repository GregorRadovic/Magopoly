extends Node2D

# Wizard Vision: an arrow tracing the route the rolling player's token will
# take -- forward round the board's edges, turning at the corners -- to the
# tile their roll would land them on. Shown while a roll is in flight. main.gd
# builds the route (see _wizard_vision_path()) and drives it via show_path() /
# hide_line(). Drawn in the moving player's own colour, over a dark casing so
# it stays legible on any board colour. Each extra lap round the board is
# offset further inward by main.gd, so the route never overlaps itself. The
# board tile it points at is highlighted separately by main.gd
# (BoardSpace.set_landing_highlight).

const CASING_COLOR: Color = Color(0, 0, 0, 0.55)
const CASING_WIDTH: float = 7.0
const LINE_WIDTH: float = 4.0
# Arrowhead: length along the shaft, and half-width at its base.
const HEAD_LEN: float = 24.0
const HEAD_HALF_W: float = 14.0

var points: PackedVector2Array = PackedVector2Array()
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
	if points.size() < 2:
		return
	var tip: Vector2 = points[points.size() - 1]
	var last_from: Vector2 = points[points.size() - 2]
	var dir: Vector2 = (tip - last_from).normalized()
	# Shaft stops at the arrowhead base so the tip isn't doubled up -- unless
	# the final leg is too short, then the head just overlaps the route.
	var shaft: PackedVector2Array = points.duplicate()
	var last_len: float = (tip - last_from).length()
	var has_head: bool = _route_length() >= HEAD_LEN + 4.0
	var base: Vector2 = tip - dir * HEAD_LEN
	if has_head and last_len > HEAD_LEN:
		shaft[shaft.size() - 1] = base
	_draw_route(shaft, CASING_COLOR, CASING_WIDTH)
	_draw_route(shaft, line_color, LINE_WIDTH)
	if not has_head:
		return
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var left: Vector2 = base + perp * HEAD_HALF_W
	var right: Vector2 = base - perp * HEAD_HALF_W
	var pad: Vector2 = dir * 3.0
	draw_colored_polygon(PackedVector2Array([tip + pad, left + perp * 2.5 - pad, right - perp * 2.5 - pad]), CASING_COLOR)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), line_color)


# A straight arrow (cased like the route) from `from` to `to`.
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


# A polyline with round joints, so the corners turn cleanly.
func _draw_route(route: PackedVector2Array, color: Color, width: float) -> void:
	for i in route.size() - 1:
		draw_line(route[i], route[i + 1], color, width)
	for i in range(1, route.size() - 1):
		draw_circle(route[i], width * 0.5, color)


func _route_length() -> float:
	var total: float = 0.0
	for i in points.size() - 1:
		total += (points[i + 1] - points[i]).length()
	return total


# `route`: the token's position, then every point where the route turns,
# ending on the landing spot.
# `arrows`: extra short [from, to] arrows (a teleport's -- see extra_arrows).
func show_path(route: PackedVector2Array, color: Color = Color.RED, arrows: Array = []) -> void:
	points = route
	extra_arrows = arrows
	line_color = color
	active = true
	queue_redraw()


func show_line(new_from: Vector2, new_to: Vector2, color: Color = Color.RED, arrows: Array = []) -> void:
	show_path(PackedVector2Array([new_from, new_to]), color, arrows)


func hide_line() -> void:
	if not active:
		return
	active = false
	queue_redraw()
