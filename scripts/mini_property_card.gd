extends Control

signal card_clicked(space_index: int)
signal card_right_clicked(space_index: int)

@onready var background: ColorRect = $Background
@onready var inner: ColorRect = $Inner
@onready var name_label: Label = $NameLabel
@onready var click_area: Control = $ClickArea

var space_index: int = -1


func _ready() -> void:
	click_area.gui_input.connect(_on_click_area_gui_input)


func setup(index: int, property_name: String, color: Color, house_count: int = 0, is_mortgaged: bool = false) -> void:
	space_index = index
	var suffix: String = ""
	if house_count > 0:
		suffix += " (%dH)" % house_count
	if is_mortgaged:
		suffix += " (mortgaged)"
	name_label.text = property_name + suffix
	_fit_name_font()
	background.color = color
	inner.color = Color.WHITE if is_mortgaged else color
	name_label.add_theme_color_override("font_color", Color.BLACK if is_mortgaged else Color.WHITE)


# Shrink the name until its longest word fits inside the coloured inner box
# ("Mediterranean" is wider than the card at the default size) and the
# wrapped text fits the card's height.
const NAME_FONT_SIZE: int = 11
const NAME_MIN_FONT_SIZE: int = 7
const NAME_INSET: float = 6.0


func _fit_name_font() -> void:
	var font: Font = name_label.get_theme_font("font")
	var max_w: float = name_label.size.x - NAME_INSET
	var max_h: float = name_label.size.y - 2.0
	var words: PackedStringArray = name_label.text.split(" ", false)
	var fs: int = NAME_FONT_SIZE
	while fs > NAME_MIN_FONT_SIZE:
		var widest: float = 0.0
		for w in words:
			widest = maxf(widest, font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var text_h: float = font.get_multiline_string_size(name_label.text, HORIZONTAL_ALIGNMENT_CENTER, max_w, fs).y
		if widest <= max_w and text_h <= max_h:
			break
		fs -= 1
	name_label.add_theme_font_size_override("font_size", fs)


func _on_click_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(space_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			card_right_clicked.emit(space_index)
