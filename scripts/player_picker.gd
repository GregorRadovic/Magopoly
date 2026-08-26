extends PopupPanel

# -1 means no player was chosen (Cancel, or dismissed some other way --
# never emitted for a mandatory picker, see open()).
signal player_chosen(index: int)

# Points at the current session's own one-element "answered" box (see open()
# for why it's a boxed value rather than a plain bool).
var _answered_box: Array = [false]
# True for the current session if it must be answered -- no Cancel button,
# and any other way of dismissing it (clicking outside, Escape) just
# reopens it instead of counting as a cancel. Set by open().
var _mandatory: bool = false

const POPUP_SIZE: Vector2i = Vector2i(420, 320)

@onready var prompt_label: Label = $VBox/PromptLabel
@onready var button_container: VBoxContainer = $VBox/ButtonContainer
@onready var cancel_button: Button = $VBox/CancelButton


func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel)


# entries: Array of {"index": int, "name": String, "color": Color}
# mandatory: if true, there's no Cancel button and the picker can't be
# dismissed without picking one of `entries` -- used for a forced choice
# like landing on Magic Forest or Spell Shop, where the game can't proceed
# until the player answers.
#
# Deferred rather than done immediately: a caller may turn straight around
# and call open() again in direct response to its own player_chosen (e.g. a
# spell chaining from picking a level straight into picking a target). A
# same-frame hide() -> open() on the same popup races Window's own internal
# close bookkeeping (itself deferred) -- reopening immediately can get
# silently clobbered back to hidden once that bookkeeping finally runs, or
# have its own popup_hide notification wrongly read as an instant cancel of
# the *new* session. Deferring this work queues it after that bookkeeping.
func open(prompt: String, entries: Array, mandatory: bool = false) -> void:
	call_deferred("_do_open", prompt, entries, mandatory)


func _do_open(prompt: String, entries: Array, mandatory: bool) -> void:
	_mandatory = mandatory
	cancel_button.visible = not mandatory
	prompt_label.text = prompt
	var answered_box: Array = [false]
	_answered_box = answered_box
	for child in button_container.get_children():
		child.queue_free()
	for entry in entries:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 50)
		btn.text = entry["name"]
		btn.add_theme_color_override("font_color", entry["color"])
		btn.pressed.connect(_on_pick.bind(entry["index"], answered_box))
		button_container.add_child(btn)
	popup_centered(POPUP_SIZE)
	popup_hide.connect(_on_popup_hide.bind(answered_box), CONNECT_ONE_SHOT)


func _on_pick(index: int, answered_box: Array) -> void:
	answered_box[0] = true
	hide()
	player_chosen.emit(index)


func _on_cancel() -> void:
	_answered_box[0] = true
	hide()
	player_chosen.emit(-1)


# Dismissed some other way (e.g. clicking outside it, or Escape). For a
# mandatory picker this doesn't count -- reopen it (deferred, same reasoning
# as open() itself) instead of treating it as a cancel. Otherwise, treat it
# the same as Cancel so callers awaiting `player_chosen` never hang.
func _on_popup_hide(answered_box: Array) -> void:
	if answered_box[0]:
		return
	if _mandatory:
		call_deferred("_reopen_mandatory", answered_box)
		return
	player_chosen.emit(-1)


func _reopen_mandatory(answered_box: Array) -> void:
	# Superseded by a later open() (or already answered) before this even
	# got a chance to reopen -- nothing to do.
	if answered_box != _answered_box or answered_box[0]:
		return
	popup_centered(POPUP_SIZE)
	popup_hide.connect(_on_popup_hide.bind(answered_box), CONNECT_ONE_SHOT)
