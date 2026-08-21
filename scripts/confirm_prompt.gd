extends PopupPanel

signal answered(yes: bool)

var _answered: bool = false

# When true, a dismissal that isn't an explicit Yes/No press (e.g. clicking
# outside the popup) does NOT count as "No" -- it's just silently ignored.
# Used when some other button is meant to stay clickable while this prompt
# is up (Godot closes popups on any outside click, including presses on that
# other button); the caller is expected to reopen this prompt afterward.
var suppress_auto_decline: bool = false

@onready var prompt_label: Label = $VBox/PromptLabel
@onready var yes_button: Button = $VBox/Buttons/YesButton
@onready var no_button: Button = $VBox/Buttons/NoButton


func _ready() -> void:
	yes_button.pressed.connect(_on_yes)
	no_button.pressed.connect(_on_no)
	popup_hide.connect(_on_popup_hide)


func open(prompt: String) -> void:
	prompt_label.text = prompt
	_answered = false
	popup_centered(Vector2i(460, 230))


func _on_yes() -> void:
	_answered = true
	hide()
	answered.emit(true)


func _on_no() -> void:
	_answered = true
	hide()
	answered.emit(false)


# The popup was dismissed some other way (e.g. clicking outside it, which
# Godot's default popup behavior uses to close it without pressing Yes/No).
# Treat that the same as "No" so callers awaiting `answered` never hang --
# otherwise whatever buttons they disabled while waiting stay disabled
# forever.
func _on_popup_hide() -> void:
	if not _answered and not suppress_auto_decline:
		answered.emit(false)
