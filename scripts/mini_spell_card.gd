extends Control

signal card_clicked(hand_index: int)
signal card_right_clicked(hand_index: int)

@onready var texture_rect: TextureRect = $TextureRect
@onready var click_area: Control = $ClickArea

var hand_index: int = -1


func _ready() -> void:
	click_area.gui_input.connect(_on_click_area_gui_input)


func setup(index: int, icon: Texture2D) -> void:
	hand_index = index
	texture_rect.texture = icon


func _on_click_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(hand_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			card_right_clicked.emit(hand_index)
