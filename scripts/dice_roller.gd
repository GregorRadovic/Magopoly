extends Node2D

# Two dice shown just below the action panel while a roll is "in flight"
# (the response window). The real result is already known the moment Roll is
# pressed -- this is purely to cover the wait. roll() tumbles the faces for
# `duration_sec`, then settles on the real values; finish_now() settles them
# early (called when someone pauses); clear_dice() removes them (next roll /
# end of turn).

const DIE_SIZE: float = 60.0
const GAP: float = 18.0
const PIP_R: float = 5.0
const SHUFFLE_MS: int = 55

const BODY_COLOR: Color = Color(0.97, 0.97, 0.94)
const EDGE_COLOR: Color = Color(0.1, 0.1, 0.12)
const PIP_COLOR: Color = Color(0.1, 0.1, 0.12)
const DOUBLES_COLOR: Color = Color(1.0, 0.82, 0.25)
const DOUBLES_FONT_SIZE: int = 26
const DOUBLES_GAP: float = 12.0

var _shown: Array[int] = [1, 1]
var _final: Array[int] = [1, 1]
var _rolling: bool = false
var _visible_dice: bool = false
var _end_msec: int = 0
var _next_shuffle_msec: int = 0
var _jitter: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

# Die pick (main.gd's _pick_die): both dice get a gold frame and the one
# clicked is reported as 1 or 2.
signal die_picked(which: int)
const PICK_COLOR: Color = Color(1.0, 0.82, 0.25)
var _picking: bool = false
var _pick_hover: int = 0


func roll(die1: int, die2: int, duration_sec: float) -> void:
	_final = [die1, die2]
	_shown = [randi_range(1, 6), randi_range(1, 6)]
	_rolling = true
	_visible_dice = true
	_end_msec = Time.get_ticks_msec() + int(maxf(0.05, duration_sec) * 1000.0)
	_next_shuffle_msec = 0
	queue_redraw()


func finish_now() -> void:
	if not _rolling:
		return
	_rolling = false
	_shown = _final.duplicate()
	_jitter = [Vector2.ZERO, Vector2.ZERO]
	queue_redraw()


func start_pick() -> void:
	finish_now()
	_visible_dice = true
	_picking = true
	_pick_hover = 0
	queue_redraw()


func stop_pick() -> void:
	_picking = false
	_pick_hover = 0
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	queue_redraw()


# 1 or 2 for the die under `screen_pos`, else 0.
func _die_at(screen_pos: Vector2) -> int:
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * screen_pos
	for i in 2:
		var rect := Rect2(Vector2(i * (DIE_SIZE + GAP), 0.0), Vector2(DIE_SIZE, DIE_SIZE)).grow(6.0)
		if rect.has_point(local):
			return i + 1
	return 0


# _input, not _unhandled_input: the dice sit over the action panel, which
# would otherwise swallow the click.
func _input(event: InputEvent) -> void:
	if not _picking:
		return
	if event is InputEventMouseMotion:
		var hover: int = _die_at(event.position)
		if hover != _pick_hover:
			_pick_hover = hover
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hover else Input.CURSOR_ARROW)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var which: int = _die_at(event.position)
		if which:
			get_viewport().set_input_as_handled()
			die_picked.emit(which)


func clear_dice() -> void:
	_rolling = false
	_visible_dice = false
	queue_redraw()


func _process(_delta: float) -> void:
	if not _rolling:
		return
	var now: int = Time.get_ticks_msec()
	if now >= _end_msec:
		finish_now()
		return
	if now >= _next_shuffle_msec:
		_next_shuffle_msec = now + SHUFFLE_MS
		_shown = [randi_range(1, 6), randi_range(1, 6)]
		_jitter = [
			Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)),
			Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)),
		]
		queue_redraw()


func _draw() -> void:
	if not _visible_dice:
		return
	for i in 2:
		var origin: Vector2 = Vector2(i * (DIE_SIZE + GAP), 0.0) + _jitter[i]
		_draw_die(origin, _shown[i])
		if _picking:
			var frame := Rect2(origin, Vector2(DIE_SIZE, DIE_SIZE)).grow(6.0)
			if _pick_hover == i + 1:
				draw_rect(frame, Color(PICK_COLOR.r, PICK_COLOR.g, PICK_COLOR.b, 0.35))
				_draw_die(origin, _shown[i])
			draw_rect(frame, PICK_COLOR, false, 5.0 if _pick_hover == i + 1 else 3.0)
	# "Doubles!" for as long as the settled dice match (a zeroed die has no
	# value, so blank + blank doesn't count) -- it follows any spell that
	# changes the dice, since those re-roll() them.
	if not _rolling and _shown[0] == _shown[1] and _shown[0] > 0:
		var font: Font = ThemeDB.fallback_font
		var text: String = "Doubles!"
		var width: float = 2.0 * DIE_SIZE + GAP
		var y: float = -DOUBLES_GAP
		draw_string_outline(font, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, width, DOUBLES_FONT_SIZE, 6, Color(0.1, 0.1, 0.12))
		draw_string(font, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, width, DOUBLES_FONT_SIZE, DOUBLES_COLOR)


func _draw_die(origin: Vector2, face: int) -> void:
	var rect := Rect2(origin, Vector2(DIE_SIZE, DIE_SIZE))
	draw_rect(rect, BODY_COLOR)
	draw_rect(rect, EDGE_COLOR, false, 2.0)
	for p in _pips(face):
		draw_circle(origin + p * DIE_SIZE, PIP_R, PIP_COLOR)


func _pips(face: int) -> Array:
	var c := Vector2(0.5, 0.5)
	var tl := Vector2(0.27, 0.27)
	var tr := Vector2(0.73, 0.27)
	var bl := Vector2(0.27, 0.73)
	var br := Vector2(0.73, 0.73)
	var ml := Vector2(0.27, 0.5)
	var mr := Vector2(0.73, 0.5)
	match face:
		1: return [c]
		2: return [tl, br]
		3: return [tl, c, br]
		4: return [tl, tr, bl, br]
		5: return [tl, tr, c, bl, br]
		6: return [tl, tr, ml, mr, bl, br]
	return []
