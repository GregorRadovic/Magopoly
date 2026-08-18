extends PopupPanel

signal value_confirmed(value: int)
# Emitted when the popup closes some other way (e.g. the player clicks a
# board tile behind it, which Godot's default outside-click behavior uses
# to dismiss the popup without ever pressing Confirm).
signal cancelled

var _confirmed: bool = false

@onready var prompt_label: Label = $VBox/PromptLabel
@onready var value_edit: LineEdit = $VBox/ValueEdit
@onready var confirm_button: Button = $VBox/ConfirmButton


func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm)
	value_edit.text_submitted.connect(_on_text_submitted)
	popup_hide.connect(_on_popup_hide)


func open(prompt: String) -> void:
	prompt_label.text = prompt
	value_edit.text = ""
	_confirmed = false
	popup_centered(Vector2i(430, 200))
	value_edit.grab_focus()


func _on_text_submitted(_text: String) -> void:
	_on_confirm()


func _on_confirm() -> void:
	var value: int = int(value_edit.text)
	_confirmed = true
	hide()
	value_confirmed.emit(value)


func _on_popup_hide() -> void:
	if not _confirmed:
		cancelled.emit()
