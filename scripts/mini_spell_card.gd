extends Control

signal card_clicked(hand_index: int)
signal card_right_clicked(hand_index: int)

@onready var texture_rect: TextureRect = $TextureRect
@onready var click_area: Control = $ClickArea

# Gold glow drawn around the card while the tutorial is pointing at this spell
# (built lazily on the first set_highlight(true) -- most cards never need it).
const HIGHLIGHT_COLOR: Color = Color(1.0, 0.82, 0.15)
var _highlight: Panel = null

var hand_index: int = -1
# False when the card is shown as a face-down cardback -- it can still be
# clicked (e.g. to pick it for a trade) but not inspected.
var face_up: bool = true


func _ready() -> void:
	click_area.gui_input.connect(_on_click_area_gui_input)


# Tutorial helper: draw / hide a bright outline around this card.
func set_highlight(on: bool) -> void:
	if on and not _highlight:
		_highlight = Panel.new()
		_highlight.name = "TutorialHighlight"
		_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
		_highlight.offset_left = -3.0
		_highlight.offset_top = -3.0
		_highlight.offset_right = 3.0
		_highlight.offset_bottom = 3.0
		var style := StyleBoxFlat.new()
		style.bg_color = Color(HIGHLIGHT_COLOR.r, HIGHLIGHT_COLOR.g, HIGHLIGHT_COLOR.b, 0.16)
		style.border_color = HIGHLIGHT_COLOR
		style.set_border_width_all(3)
		style.set_corner_radius_all(4)
		_highlight.add_theme_stylebox_override("panel", style)
		add_child(_highlight)
	if _highlight:
		_highlight.visible = on


func setup(index: int, icon: Texture2D, is_face_up: bool = true) -> void:
	hand_index = index
	texture_rect.texture = icon
	face_up = is_face_up


func _on_click_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(hand_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT and face_up:
			card_right_clicked.emit(hand_index)
