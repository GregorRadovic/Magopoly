extends PopupPanel

signal closed

@onready var content_label: Label = $VBox/ContentLabel
@onready var close_button: Button = $VBox/CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)


func open(text: String) -> void:
	content_label.text = text
	popup_centered(Vector2i(480, 500))


func _on_close_pressed() -> void:
	hide()
	closed.emit()
