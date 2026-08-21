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
	background.color = color
	inner.color = Color.WHITE if is_mortgaged else color
	name_label.add_theme_color_override("font_color", Color.BLACK if is_mortgaged else Color.WHITE)


func _on_click_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(space_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			card_right_clicked.emit(space_index)
