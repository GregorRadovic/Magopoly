extends Control

# One clickable die face (1-6) -- Master Plan's "set a die to..." picker
# (main.gd's _pick_die_face) is a row of six of these. Drawn like the dice
# in dice_roller.gd, with a gold frame that brightens on hover.

signal face_chosen(value: int)

const DIE_SIZE: float = 60.0
const PIP_R: float = 5.0
const BODY_COLOR: Color = Color(0.97, 0.97, 0.94)
const EDGE_COLOR: Color = Color(0.1, 0.1, 0.12)
const PIP_COLOR: Color = Color(0.1, 0.1, 0.12)
const PICK_COLOR: Color = Color(1.0, 0.82, 0.25)

var value: int = 1
var _hovered: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(DIE_SIZE + 12.0, DIE_SIZE + 12.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))


func _set_hovered(on: bool) -> void:
	_hovered = on
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		face_chosen.emit(value)


func _draw() -> void:
	var origin := Vector2(6.0, 6.0)
	var frame := Rect2(Vector2.ZERO, Vector2(DIE_SIZE + 12.0, DIE_SIZE + 12.0))
	if _hovered:
		draw_rect(frame, Color(PICK_COLOR.r, PICK_COLOR.g, PICK_COLOR.b, 0.35))
	var rect := Rect2(origin, Vector2(DIE_SIZE, DIE_SIZE))
	draw_rect(rect, BODY_COLOR)
	draw_rect(rect, EDGE_COLOR, false, 2.0)
	for p in _pips(value):
		draw_circle(origin + p * DIE_SIZE, PIP_R, PIP_COLOR)
	draw_rect(frame.grow(-1.5), PICK_COLOR, false, 5.0 if _hovered else 3.0)


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
