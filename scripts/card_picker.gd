extends PopupPanel

# -1 means no card was chosen (Cancel, or dismissed some other way -- never
# emitted for a mandatory picker, see open()). skip_index (whatever the
# caller passed to open(), see _skip_index below) means the Skip button.
signal card_chosen(index: int)

# Emitted when a card's art is right-clicked, so the caller can route it to
# whatever popup shows full-size card art (main.gd's spell_card).
signal zoom_requested(icon: Texture2D)

const MINI_CARD_SCENE: PackedScene = preload("res://scenes/mini_spell_card.tscn")
# Default (non-large) size -- big enough for a handful of cards without
# scrolling; CardScroll handles far larger lists (Admin Spells' whole deck).
const POPUP_SIZE: Vector2i = Vector2i(800, 600)
# Card art aspect (matches mini_spell_card.tscn's 70 x 98).
const CARD_ASPECT: float = 70.0 / 98.0

# Points at the current session's own one-element "answered" box (see open()
# for why it's a boxed value rather than a plain bool) -- same reasoning as
# player_picker.gd.
var _answered_box: Array = [false]
var _mandatory: bool = false
# Like _mandatory for dismissal handling, but keeps Cancel/Skip available.
# Set for network-routed pickers so the app losing focus (alt-tab) can't
# silently resolve the picker -- see player_picker.gd's _sticky.
var _sticky: bool = false
# Fills (almost) the whole window and blows the cards up as large as they'll
# fit -- used for landing on Magic Forest / Spell Shop.
var _large: bool = false
var _skip_index: int = -2

@onready var prompt_label: Label = $VBox/PromptLabel
@onready var card_container: HFlowContainer = $VBox/CardScroll/CardContainer
@onready var skip_button: Button = $VBox/SkipButton
@onready var cancel_button: Button = $VBox/CancelButton


func _ready() -> void:
	skip_button.pressed.connect(_on_skip)
	cancel_button.pressed.connect(_on_cancel)
	set_process(false)


# entries: Array of {"index": int, "name": String, "icon": Texture2D,
#   "caption": String (optional -- shown under the card; BBCode, so e.g.
#   "$100" or "[s]$100[/s] [color=#e23c3c]$50[/color]" for a sale)}.
# mandatory: same meaning as player_picker.gd's -- no Cancel button, and any
# other way of dismissing it just reopens it instead of counting as a cancel.
# sticky: reopen on non-button dismissal but keep Cancel/Skip (network use).
# large: fill the window and enlarge the cards as much as they'll fit.
# skip_text: if non-empty, shows an always-available extra button (e.g.
# "Skip") -- distinct from Cancel/dismissal, which always resolve with -1
# (and are unavailable when mandatory) -- resolving instead with
# `skip_index`, whatever the caller wants that to mean.
#
# Deferred rather than done immediately, for the same reason as
# player_picker.gd's open(): a same-frame hide() -> open() on the same
# popup races Window's own internal close bookkeeping.
func open(prompt: String, entries: Array, mandatory: bool = false, skip_text: String = "", skip_index: int = -2, sticky: bool = false, large: bool = false) -> void:
	call_deferred("_do_open", prompt, entries, mandatory, skip_text, skip_index, sticky, large)


func _do_open(prompt: String, entries: Array, mandatory: bool, skip_text: String, skip_index: int, sticky: bool, large: bool) -> void:
	_mandatory = mandatory
	_sticky = sticky
	_large = large
	_skip_index = skip_index
	cancel_button.visible = not mandatory
	skip_button.visible = skip_text != ""
	skip_button.text = skip_text
	prompt_label.text = prompt

	var prompt_size: int = 40 if _large else 24
	var button_size: int = 30 if _large else 20
	var button_min_h: int = 64 if _large else 50
	prompt_label.add_theme_font_size_override("font_size", prompt_size)
	for btn in [skip_button, cancel_button]:
		btn.add_theme_font_size_override("font_size", button_size)
		btn.custom_minimum_size = Vector2(0, button_min_h)

	var answered_box: Array = [false]
	_answered_box = answered_box
	for child in card_container.get_children():
		child.queue_free()

	_show_popup()
	var has_caption: bool = false
	for e in entries:
		if str(e.get("caption", "")) != "":
			has_caption = true
			break
	var card_size: Vector2 = _card_size(entries.size(), has_caption) if _large else Vector2(70.0, 98.0)

	for entry in entries:
		var mini: Control = MINI_CARD_SCENE.instantiate()
		mini.custom_minimum_size = card_size
		var caption: String = str(entry.get("caption", ""))
		var node: Control = mini
		if caption != "":
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 6)
			var cap_font: int = 32 if _large else 18
			var label := RichTextLabel.new()
			label.bbcode_enabled = true
			label.fit_content = true
			label.scroll_active = false
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.custom_minimum_size = Vector2(card_size.x, 0)
			label.add_theme_font_size_override("normal_font_size", cap_font)
			label.add_theme_font_size_override("bold_font_size", cap_font)
			label.text = "[center]%s[/center]" % caption
			box.add_child(mini)
			box.add_child(label)
			node = box
		card_container.add_child(node)
		# setup() after add_child so the mini's @onready refs are ready.
		mini.setup(entry["index"], entry["icon"])
		mini.card_clicked.connect(_on_pick.bind(answered_box))
		mini.card_right_clicked.connect(_on_zoom.bind(entry["icon"]))

	popup_hide.connect(_on_popup_hide.bind(answered_box), CONNECT_ONE_SHOT)
	set_process(_mandatory or _sticky)


# The biggest the cards can be while every one of them fits inside the
# window at once. Starts with everything on one row and only adds a row if
# that would force the cards absurdly thin; height is filled as far as the
# prompt / button row / captions allow.
func _card_size(count: int, has_caption: bool) -> Vector2:
	var win: Vector2 = Vector2(get_tree().root.get_visible_rect().size) * 0.98
	var gap: float = 20.0
	var cap_h: float = 46.0 if has_caption else 0.0
	var avail_w: float = win.x - 60.0
	var avail_h: float = win.y - 190.0

	var rows: int = 1
	while rows <= maxi(count, 1):
		var cols: int = ceili(float(count) / float(rows))
		var w: float = (avail_w - (cols - 1) * gap) / cols
		var h: float = w / CARD_ASPECT
		if rows * (h + cap_h) + (rows - 1) * gap > avail_h:
			h = (avail_h - (rows - 1) * gap) / rows - cap_h
			w = h * CARD_ASPECT
		if w >= 150.0 or cols <= 2:
			return Vector2(maxf(w, 70.0), maxf(h, 98.0))
		rows += 1
	return Vector2(70.0, 98.0)


func _show_popup() -> void:
	if _large:
		# Explicit rect from the main viewport rather than
		# popup_centered_ratio(), which needs subwindow embedding to know the
		# parent size and otherwise collapses to the content minimum.
		var vp: Vector2 = Vector2(get_tree().root.get_visible_rect().size)
		var sz: Vector2i = Vector2i(vp * 0.98)
		popup(Rect2i(Vector2i((vp - Vector2(sz)) * 0.5), sz))
	else:
		popup_centered(POPUP_SIZE)


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
		_show_popup()
		popup_hide.connect(_on_popup_hide.bind(_answered_box), CONNECT_ONE_SHOT)
