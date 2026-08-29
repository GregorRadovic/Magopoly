extends PopupPanel

signal answered(yes: bool)

const POPUP_SIZE: Vector2i = Vector2i(460, 230)

var _answered: bool = false

# When true, a dismissal that isn't an explicit Yes/No press (e.g. clicking
# outside the popup) does NOT count as "No" -- it's just silently ignored.
# Used when some other button is meant to stay clickable while this prompt
# is up (Godot closes popups on any outside click, including presses on that
# other button); the caller is expected to reopen this prompt afterward.
var suppress_auto_decline: bool = false

# When true, ANY dismissal other than an explicit Yes/No press is undone --
# the popup reopens itself as soon as the game window has focus again.
# Godot auto-hides popups when the application loses focus (alt-tab), which
# would otherwise fire popup_hide and resolve the prompt as "No" behind the
# player's back. Set for prompts driven remotely over the network, where the
# player who owns the decision may well be looking at another window.
var sticky: bool = false

@onready var prompt_label: Label = $VBox/PromptLabel
@onready var yes_button: Button = $VBox/Buttons/YesButton
@onready var no_button: Button = $VBox/Buttons/NoButton


func _ready() -> void:
	yes_button.pressed.connect(_on_yes)
	no_button.pressed.connect(_on_no)
	popup_hide.connect(_on_popup_hide)
	set_process(false)


func open(prompt: String) -> void:
	prompt_label.text = prompt
	_answered = false
	popup_centered(POPUP_SIZE)
	set_process(sticky)


func _on_yes() -> void:
	_answered = true
	sticky = false
	set_process(false)
	hide()
	answered.emit(true)


func _on_no() -> void:
	_answered = true
	sticky = false
	set_process(false)
	hide()
	answered.emit(false)


# The popup was dismissed some other way (e.g. clicking outside it, or the
# application losing focus, both of which Godot uses to close popups). A
# sticky prompt ignores it -- _process reopens the popup once the window is
# focused again. Otherwise treat it as "No" so callers awaiting `answered`
# never hang -- unless suppress_auto_decline says some other button was
# meant to be pressed instead and the caller will reopen this itself.
func _on_popup_hide() -> void:
	if _answered or sticky:
		return
	if not suppress_auto_decline:
		answered.emit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and sticky and not _answered and not visible:
		popup_centered(POPUP_SIZE)


func _process(_delta: float) -> void:
	if sticky and not _answered and not visible and DisplayServer.window_is_focused():
		popup_centered(POPUP_SIZE)
