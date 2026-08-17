extends Node2D
class_name BoardSpace

signal clicked(index: int)

@export var index: int = 0:
	set(value):
		index = value
		_update_label()

@export var label_text: String = "":
	set(value):
		label_text = value
		_update_label()

@onready var label: Label = $IndexLabel
@onready var click_area: Control = $ClickArea

# Index into main.gd's `players` array; -1 means the property is unowned.
# Only meaningful for spaces whose SPACE_DATA type is "property".
# (Named owner_id, not "owner" -- that name collides with Node.owner.)
var owner_id: int = -1


func _ready() -> void:
	_update_label()
	click_area.gui_input.connect(_on_click_area_gui_input)


func _on_click_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)


func _update_label() -> void:
	if label:
		label.text = label_text if label_text != "" else str(index)
