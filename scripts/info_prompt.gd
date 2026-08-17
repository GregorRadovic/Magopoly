extends PopupPanel

@onready var content_label: Label = $VBox/ContentLabel
@onready var close_button: Button = $VBox/CloseButton


func _ready() -> void:
	close_button.pressed.connect(hide)


func open(text: String) -> void:
	content_label.text = text
	popup_centered(Vector2i(260, 220))
