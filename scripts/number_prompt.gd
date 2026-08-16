extends PopupPanel

signal value_confirmed(value: int)

@onready var prompt_label: Label = $VBox/PromptLabel
@onready var value_edit: LineEdit = $VBox/ValueEdit
@onready var confirm_button: Button = $VBox/ConfirmButton


func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm)
	value_edit.text_submitted.connect(_on_text_submitted)


func open(prompt: String) -> void:
	prompt_label.text = prompt
	value_edit.text = ""
	popup_centered(Vector2i(260, 120))
	value_edit.grab_focus()


func _on_text_submitted(_text: String) -> void:
	_on_confirm()


func _on_confirm() -> void:
	var value: int = int(value_edit.text)
	hide()
	value_confirmed.emit(value)
