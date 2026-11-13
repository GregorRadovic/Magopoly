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

# Optional validator (Tutorial mode): called with the Yes/No answer; if it
# returns false the press is rejected and the prompt stays open (the gate
# handles any feedback).
var _gate: Callable = Callable()

@onready var vbox: VBoxContainer = $VBox
@onready var prompt_label: Label = $VBox/PromptLabel
@onready var buttons_row: HBoxContainer = $VBox/Buttons
@onready var yes_button: Button = $VBox/Buttons/YesButton
@onready var no_button: Button = $VBox/Buttons/NoButton

# Card layout (the buy prompt): a picture of the property on top, the
# question under it, then a green Yes over a red No.
const CARD_BUTTON_SIZE: Vector2 = Vector2(340, 60)
const CARD_LAYOUT_MIN_WIDTH: float = 440.0
const CARD_LAYOUT_MARGIN: float = 24.0
var _card_holder: CenterContainer
var _card_buttons: VBoxContainer
var _size: Vector2i = POPUP_SIZE


func _ready() -> void:
	yes_button.pressed.connect(_on_yes)
	no_button.pressed.connect(_on_no)
	# Y / N answer the prompt while it has the keyboard.
	yes_button.shortcut = _key_shortcut(KEY_Y)
	no_button.shortcut = _key_shortcut(KEY_N)
	yes_button.shortcut_in_tooltip = false
	no_button.shortcut_in_tooltip = false
	popup_hide.connect(_on_popup_hide)
	set_process(false)
	_card_holder = CenterContainer.new()
	_card_holder.visible = false
	vbox.add_child(_card_holder)
	vbox.move_child(_card_holder, 0)
	_card_buttons = VBoxContainer.new()
	_card_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_buttons.add_theme_constant_override("separation", 12)
	_card_buttons.visible = false
	vbox.add_child(_card_buttons)


# card: an optional picture shown above the question (see the buy prompt);
# without one this is the plain two-button prompt.
func open(prompt: String, gate: Callable = Callable(), card: Control = null) -> void:
	prompt_label.text = prompt
	_answered = false
	_gate = gate
	_set_card(card)
	popup_centered(_size)
	set_process(sticky or gate.is_valid())


func _set_card(card: Control) -> void:
	for child in _card_holder.get_children():
		_card_holder.remove_child(child)
		child.queue_free()
	var with_card: bool = card != null
	_card_holder.visible = with_card
	_card_buttons.visible = with_card
	buttons_row.visible = not with_card
	var target: Container = _card_buttons if with_card else buttons_row
	for btn in [yes_button, no_button]:
		if btn.get_parent() != target:
			btn.get_parent().remove_child(btn)
			target.add_child(btn)
	_style_button(yes_button, Color(0.16, 0.56, 0.26) if with_card else Color.TRANSPARENT)
	_style_button(no_button, Color(0.74, 0.2, 0.2) if with_card else Color.TRANSPARENT)
	if not with_card:
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		prompt_label.remove_theme_font_size_override("font_size")
		vbox.remove_theme_constant_override("separation")
		remove_theme_stylebox_override("panel")
		for btn in [yes_button, no_button]:
			btn.size_flags_horizontal = Control.SIZE_FILL
		vbox.position = Vector2(24, 24)
		vbox.size = Vector2(412, 182)
		_size = POPUP_SIZE
		return
	_card_holder.add_child(card)
	# Solid, so the board doesn't show through behind the card.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.13, 0.13, 0.15, 0.98)
	bg.border_color = Color(0.35, 0.36, 0.42)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(CARD_LAYOUT_MARGIN)
	add_theme_stylebox_override("panel", bg)
	for btn in [yes_button, no_button]:
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 24)
	vbox.add_theme_constant_override("separation", 16)
	var card_size: Vector2 = card.custom_minimum_size
	var width: float = maxf(CARD_LAYOUT_MIN_WIDTH, maxf(card_size.x, CARD_BUTTON_SIZE.x) + 2.0 * CARD_LAYOUT_MARGIN)
	# Height 0: the popup grows to fit what's in it.
	_size = Vector2i(roundi(width), 0)


func _key_shortcut(key: Key) -> Shortcut:
	var ev := InputEventKey.new()
	ev.keycode = key
	var sc := Shortcut.new()
	sc.events = [ev]
	return sc


# A coloured, rounded button (card layout), or back to the theme's default.
func _style_button(btn: Button, color: Color) -> void:
	if color == Color.TRANSPARENT:
		for state in ["normal", "hover", "pressed", "focus"]:
			btn.remove_theme_stylebox_override(state)
		btn.remove_theme_font_size_override("font_size")
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_color_override("font_hover_color")
		btn.custom_minimum_size = Vector2(168, 58)
		return
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(8)
		match state:
			"hover": box.bg_color = color.lightened(0.15)
			"pressed": box.bg_color = color.darkened(0.15)
			"focus":
				box.bg_color = Color(0, 0, 0, 0)
				box.border_color = Color(1, 1, 1, 0.6)
				box.set_border_width_all(2)
			_: box.bg_color = color
		btn.add_theme_stylebox_override(state, box)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.custom_minimum_size = CARD_BUTTON_SIZE


func _on_yes() -> void:
	if _gate.is_valid() and not _gate.call(true):
		return
	_answered = true
	sticky = false
	set_process(false)
	hide()
	answered.emit(true)


func _on_no() -> void:
	if _gate.is_valid() and not _gate.call(false):
		return
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
		popup_centered(_size)


func _process(_delta: float) -> void:
	if sticky and not _answered and not visible and DisplayServer.window_is_focused():
		popup_centered(_size)
