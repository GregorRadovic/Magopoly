extends Control

signal card_clicked(space_index: int)

@onready var background: ColorRect = $Background
@onready var name_label: Label = $NameLabel
@onready var click_area: Control = $ClickArea

var space_index: int = -1


func _ready() -> void:
	click_area.gui_input.connect(_on_click_area_gui_input)


func setup(index: int, property_name: String, color: Color, house_count: int = 0) -> void:
	space_index = index
	name_label.text = "%s (%dH)" % [property_name, house_count] if house_count > 0 else property_name
	background.color = color


func _on_click_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(space_index)
