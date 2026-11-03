extends Control

# One box in the hero selection roster: a placeholder portrait (the hero's
# colour with a simple silhouette) and name, or a locked tile with a padlock.
# Drawn in code until real portrait art exists.

signal picked(slot: int)
signal hovered(slot: int)

const BOX_SIZE: Vector2 = Vector2(136, 168)
const LOCKED_BG: Color = Color(0.16, 0.16, 0.19)
const LOCK_COLOR: Color = Color(0.42, 0.44, 0.52)
const SELECTED_BORDER: Color = Color(0.996, 0.85, 0.35)
const HOVER_BORDER: Color = Color(0.75, 0.78, 0.88)

var slot: int = -1
var hero_id: String = ""          # "" for an empty "coming soon" slot
var locked: bool = true
var caption: String = ""          # name, "Level N" or "Coming soon"
var portrait_color: Color = Color.GRAY
var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()
var _hover: bool = false


func _init() -> void:
	custom_minimum_size = BOX_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw()
		hovered.emit(slot))
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(slot)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var portrait := Rect2(Vector2(8, 8), Vector2(size.x - 16, size.y - 48))
	draw_rect(r, LOCKED_BG if locked else Color(0.2, 0.2, 0.24))
	if locked:
		_draw_padlock(portrait.get_center() + Vector2(0, 4))
	else:
		draw_rect(portrait, portrait_color.darkened(0.25))
		_draw_silhouette(portrait)
	var font: Font = get_theme_default_font()
	# Shrink long names until they fit the box.
	var font_size: int = 17
	while font_size > 11 and font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x - 10:
		font_size -= 1
	var text_color: Color = LOCK_COLOR if locked else Color(0.95, 0.95, 0.97)
	draw_string(font, Vector2(4, size.y - 15), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, font_size, text_color)
	var border: Color = SELECTED_BORDER if selected else (HOVER_BORDER if _hover and not locked else Color(0.3, 0.3, 0.36))
	draw_rect(r, border, false, 4.0 if selected else 2.0)


func _draw_silhouette(area: Rect2) -> void:
	var c: Color = portrait_color.lightened(0.35)
	var cx: float = area.get_center().x
	var head_r: float = area.size.x * 0.17
	draw_circle(Vector2(cx, area.position.y + area.size.y * 0.36), head_r, c)
	var shoulders := Rect2(cx - area.size.x * 0.32, area.position.y + area.size.y * 0.62,
		area.size.x * 0.64, area.size.y * 0.38)
	draw_rect(shoulders, c)
	draw_circle(Vector2(cx, shoulders.position.y + 2), area.size.x * 0.32, c)


func _draw_padlock(center: Vector2) -> void:
	var body := Rect2(center + Vector2(-20, -6), Vector2(40, 32))
	draw_arc(center + Vector2(0, -8), 13, PI, TAU, 24, LOCK_COLOR, 5.0)
	draw_line(center + Vector2(-13, -8), center + Vector2(-13, -4), LOCK_COLOR, 5.0)
	draw_line(center + Vector2(13, -8), center + Vector2(13, -4), LOCK_COLOR, 5.0)
	draw_rect(body, LOCK_COLOR)
	draw_circle(body.get_center() + Vector2(0, -3), 4, LOCKED_BG)
