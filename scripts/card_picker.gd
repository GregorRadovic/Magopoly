extends PopupPanel

# -1 means no card was chosen (Cancel, or dismissed some other way -- never
# emitted for a mandatory picker, see open()). skip_index (whatever the
# caller passed to open(), see _skip_index below) means the Skip button.
signal card_chosen(index: int)

# Emitted when a card's art is right-clicked, so the caller can route it to
# whatever popup shows full-size card art (main.gd's spell_card).
signal zoom_requested(icon: Texture2D)

const MINI_CARD_SCENE: PackedScene = preload("res://scenes/mini_spell_card.tscn")
# Big enough for a handful of cards (Magic Forest, Spell Shop) to show
# without ever needing to scroll; CardScroll (see below) handles it
# gracefully for far larger lists too (Admin Spells' entire deck).
const POPUP_SIZE: Vector2i = Vector2i(800, 600)

# Points at the current session's own one-element "answered" box (see open()
# for why it's a boxed value rather than a plain bool) -- same reasoning as
# player_picker.gd.
var _answered_box: Array = [false]
var _mandatory: bool = false
# Like _mandatory for dismissal handling, but keeps Cancel/Skip available.
# Set for network-routed pickers so the app losing focus (alt-tab) can't
# silently resolve the picker -- see player_picker.gd's _sticky.
var _sticky: bool = false
var _skip_index: int = -2

@onready var prompt_label: Label = $VBox/PromptLabel
@onready var card_container: HFlowContainer = $VBox/CardScroll/CardContainer
@onready var skip_button: Button = $VBox/SkipButton
@onready var cancel_button: Button = $VBox/CancelButton


func _ready() -> void:
	skip_button.pressed.connect(_on_skip)
	cancel_button.pressed.connect(_on_cancel)
	set_process(false)


# entries: Array of {"index": int, "name": String, "icon": Texture2D}.
# mandatory: same meaning as player_picker.gd's -- no Cancel button, and any
# other way of dismissing it just reopens it instead of counting as a cancel.
# sticky: reopen on non-button dismissal but keep Cancel/Skip (network use).
# skip_text: if non-empty, shows an always-available extra button (e.g.
# "Skip") -- distinct from Cancel/dismissal, which always resolve with -1
# (and are unavailable when mandatory) -- resolving instead with
# `skip_index`, whatever the caller wants that to mean.
#
# Deferred rather than done immediately, for the same reason as
# player_picker.gd's open(): a same-frame hide() -> open() on the same
# popup races Window's own internal close bookkeeping.
func open(prompt: String, entries: Array, mandatory: bool = false, skip_text: String = "", skip_index: int = -2, sticky: bool = false) -> void:
	call_deferred("_do_open", prompt, entries, mandatory, skip_text, skip_index, sticky)


func _do_open(prompt: String, entries: Array, mandatory: bool, skip_text: String, skip_index: int, sticky: bool) -> void:
	_mandatory = mandatory
	_sticky = sticky
	_skip_index = skip_index
	cancel_button.visible = not mandatory
	skip_button.visible = skip_text != ""
	skip_button.text = skip_text
	prompt_label.text = prompt
	var answered_box: Array = [false]
	_answered_box = answered_box
	for child in card_container.get_children():
		child.queue_free()
	for entry in entries:
		var mini: Control = MINI_CARD_SCENE.instantiate()
		card_container.add_child(mini)
		mini.setup(entry["index"], entry["icon"])
		# card_clicked/card_right_clicked already carry the index passed to
		# setup() above as their own signal argument -- no need to also
		# bind it (that would double it up with the signal's own arg).
		mini.card_clicked.connect(_on_pick.bind(answered_box))
		mini.card_right_clicked.connect(_on_zoom.bind(entry["icon"]))
	popup_centered(POPUP_SIZE)
	set_process(_mandatory or _sticky)
	popup_hide.connect(_on_popup_hide.bind(answered_box), CONNECT_ONE_SHOT)


func _on_pick(index: int, answered_box: Array) -> void:
	answered_box[0] = true
	set_process(false)
	hide()
	card_chosen.emit(index)


func _on_zoom(_hand_index: int, icon: Texture2D) -> void:
	zoom_requested.emit(icon)


func _on_skip() -> void:
	_answered_box[0] = true
	set_process(false)
	hide()
	card_chosen.emit(_skip_index)


func _on_cancel() -> void:
	_answered_box[0] = true
	set_process(false)
	hide()
	card_chosen.emit(-1)


# Dismissed some other way (e.g. clicking outside it, Escape, or the app
# losing focus). For a mandatory or sticky picker this doesn't count --
# _process reopens it once the window has focus again. Otherwise, treat it
# the same as Cancel so callers awaiting `card_chosen` never hang.
func _on_popup_hide(answered_box: Array) -> void:
	if answered_box[0]:
		return
	if _mandatory or _sticky:
		return
	card_chosen.emit(-1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_reshow_if_needed()


func _process(_delta: float) -> void:
	if DisplayServer.window_is_focused():
		_reshow_if_needed()


func _reshow_if_needed() -> void:
	# The previous popup_hide fired its one-shot and disconnected before we
	# got here (that's what hid us), so reconnecting for the next hide is safe.
	if (_mandatory or _sticky) and not _answered_box[0] and not visible:
		popup_centered(POPUP_SIZE)
		popup_hide.connect(_on_popup_hide.bind(_answered_box), CONNECT_ONE_SHOT)
