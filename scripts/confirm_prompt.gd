extends PopupPanel

signal answered(yes: bool)

@onready var prompt_label: Label = $VBox/PromptLabel
@onready var yes_button: Button = $VBox/Buttons/YesButton
@onready var no_button: Button = $VBox/Buttons/NoButton


func _ready() -> void:
	yes_button.pressed.connect(_on_yes)
	no_button.pressed.connect(_on_no)


func open(prompt: String) -> void:
	prompt_label.text = prompt
	popup_centered(Vector2i(280, 130))


func _on_yes() -> void:
	hide()
	answered.emit(true)


func _on_no() -> void:
	hide()
	answered.emit(false)
