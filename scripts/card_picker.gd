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
# Largest fraction of the window width the large (Magic Forest / Spell Shop)
# popup uses; its height is sized to the card grid it ends up holding.
const LARGE_W_RATIO: float = 0.72

# Points at the current session's own one-element "answered" box (see open()
# for why it's a boxed value rather than a plain bool) -- same reasoning as
# player_picker.gd.
var _answered_box: Array = [false]
var _mandatory: bool = false
# Like _mandatory for dismissal handling, but keeps Cancel/Skip available.
# Set for network-routed pickers so the app losing focus (alt-tab) can't
# silently resolve the picker -- see player_picker.gd's _sticky.
var _sticky: bool = false
# Fills most of the window and enlarges the cards -- Magic Forest / Spell Shop.
var _large: bool = false
# The player pressed "Hide" to get the picker out of the way and look at the
# board. The decision is still pending; only pressing "Unhide" brings it back.
var _hidden: bool = false
var _unhide_button: Button = null
var _skip_index: int = -2
# Popup rect for the current large picker -- computed in _do_open from the
# card grid, reused by _show_popup (also called on Unhide / refocus).
var _large_size: Vector2i = Vector2i(1200, 700)
var _card_cols: int = 1

# Large pickers dim and blur everything behind them, so the choice has the
# player's full attention (Hide is how to look back at the game).
const BACKDROP_SHADER: Shader = preload("res://scripts/picker_backdrop.gdshader")
var _backdrop: ColorRect = null

# Magic Forest: the cards from this entry on are the ones just drawn. They
# appear one at a time, reveal_step_sec apart, and nothing can be picked
# until they're all in.
var reveal_step_sec: float = 0.5
var _revealing: bool = false

@onready var prompt_label: Label = $VBox/PromptLabel
@onready var card_container: HFlowContainer = $VBox/CardScroll/CardContainer
@onready var skip_button: Button = $VBox/ButtonRow/SkipButton
@onready var hide_button: Button = $VBox/ButtonRow/HideButton
@onready var cancel_button: Button = $VBox/ButtonRow/CancelButton


# Shown instead of prompt_label when the prompt has BBCode in it (Magic
# Forest's bold, larger "Discard").
var _rich_prompt: RichTextLabel


func _ready() -> void:
	_rich_prompt = RichTextLabel.new()
	_rich_prompt.bbcode_enabled = true
	_rich_prompt.fit_content = true
	_rich_prompt.scroll_active = false
	_rich_prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	_rich_prompt.visible = false
	prompt_label.get_parent().add_child(_rich_prompt)
	prompt_label.get_parent().move_child(_rich_prompt, prompt_label.get_index() + 1)
	skip_button.pressed.connect(_on_skip)
	hide_button.pressed.connect(_on_hide_pressed)
	cancel_button.pressed.connect(_on_cancel)
	set_process(false)


# entries: Array of {"index": int, "name": String, "icon": Texture2D,
#   "caption": String (optional -- shown under the card; BBCode, so e.g.
#   "$100" or "[s]$100[/s] [color=#e23c3c]$50[/color]" for a sale)}.
# mandatory: same meaning as player_picker.gd's -- no Cancel button, and any
# other way of dismissing it just reopens it instead of counting as a cancel.
# sticky: reopen on non-button dismissal but keep Cancel/Skip (network use).
# large: fill the window, enlarge the cards, and offer a Hide button.
# skip_text: if non-empty, shows an always-available extra button (e.g.
# "Skip") -- distinct from Cancel/dismissal, which always resolve with -1
# (and are unavailable when mandatory) -- resolving instead with
# `skip_index`, whatever the caller wants that to mean.
#
# Deferred rather than done immediately, for the same reason as
# player_picker.gd's open(): a same-frame hide() -> open() on the same
# popup races Window's own internal close bookkeeping.
# reveal_from: if >= 0, entries from that position on are held back and
# dealt in one at a time (see reveal_step_sec).
func open(prompt: String, entries: Array, mandatory: bool = false, skip_text: String = "", skip_index: int = -2, sticky: bool = false, large: bool = false, reveal_from: int = -1) -> void:
	call_deferred("_do_open", prompt, entries, mandatory, skip_text, skip_index, sticky, large, reveal_from)


func _do_open(prompt: String, entries: Array, mandatory: bool, skip_text: String, skip_index: int, sticky: bool, large: bool, reveal_from: int = -1) -> void:
	_mandatory = mandatory
	_sticky = sticky
	_large = large
	_hidden = false
	_clear_unhide_button()
	_skip_index = skip_index
	cancel_button.visible = not mandatory
	skip_button.visible = skip_text != ""
	skip_button.text = skip_text
	hide_button.visible = _large
	prompt_label.text = prompt
	var rich: bool = "[" in prompt
	prompt_label.visible = not rich
	_rich_prompt.visible = rich

	var prompt_size: int = 32 if _large else 24
	if rich:
		_rich_prompt.add_theme_font_size_override("normal_font_size", prompt_size)
		_rich_prompt.add_theme_font_size_override("bold_font_size", prompt_size)
		_rich_prompt.text = "[center]%s[/center]" % prompt
	var button_size: int = 24 if _large else 20
	var button_min: Vector2 = Vector2(240, 58) if _large else Vector2(200, 50)
	prompt_label.add_theme_font_size_override("font_size", prompt_size)
	for btn in [skip_button, hide_button, cancel_button]:
		btn.add_theme_font_size_override("font_size", button_size)
		btn.custom_minimum_size = button_min

	var answered_box: Array = [false]
	_answered_box = answered_box
	for child in card_container.get_children():
		child.queue_free()

	var has_caption: bool = false
	for e in entries:
		if str(e.get("caption", "")) != "":
			has_caption = true
			break
	var card_size: Vector2 = _card_size(entries.size(), has_caption) if _large else Vector2(70.0, 98.0)
	if _large:
		_large_size = _large_popup_size(card_size, entries.size(), has_caption)
	_show_popup()

	var held_back: Array[Control] = []
	for k in entries.size():
		var entry: Dictionary = entries[k]
		var mini: Control = MINI_CARD_SCENE.instantiate()
		mini.custom_minimum_size = card_size
		var caption: String = str(entry.get("caption", ""))
		var node: Control = mini
		if caption != "":
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 6)
			var cap_font: int = 52 if _large else 18
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
		if reveal_from >= 0 and k >= reveal_from:
			node.visible = false
			held_back.append(node)

	popup_hide.connect(_on_popup_hide.bind(answered_box), CONNECT_ONE_SHOT)
	set_process(_mandatory or _sticky)
	if not held_back.is_empty():
		_reveal(held_back, answered_box)


# Deals the held-back cards in one at a time: each pops in (fade + grow)
# reveal_step_sec after the last. Picking is blocked until the last lands.
func _reveal(nodes: Array[Control], answered_box: Array) -> void:
	_revealing = true
	for node in nodes:
		await get_tree().create_timer(reveal_step_sec).timeout
		if answered_box != _answered_box or not is_instance_valid(node):
			return
		node.visible = true
		node.modulate.a = 0.0
		await get_tree().process_frame
		if not is_instance_valid(node):
			return
		node.pivot_offset = node.size * 0.5
		node.scale = Vector2(0.6, 0.6)
		var tween: Tween = node.create_tween().set_parallel(true)
		tween.tween_property(node, "modulate:a", 1.0, 0.25)
		tween.tween_property(node, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if answered_box == _answered_box:
		_revealing = false


const GRID_GAP: float = 20.0
const CAPTION_H: float = 72.0
# Everything in the large popup that isn't the card grid: margins, prompt
# label, separators, button row.
const LARGE_CHROME_H: float = 190.0


# The biggest the cards can be while every one of them fits in the large
# popup at once. Starts with everything on one row and only adds a row if
# that would force the cards absurdly thin. Sets _card_cols as a side effect.
func _card_size(count: int, has_caption: bool) -> Vector2:
	var vp: Vector2 = Vector2(get_tree().root.get_visible_rect().size)
	var cap_h: float = CAPTION_H if has_caption else 0.0
	var avail_w: float = vp.x * LARGE_W_RATIO - 80.0
	var avail_h: float = vp.y * 0.66 - cap_h

	var rows: int = 1
	while rows <= maxi(count, 1):
		var cols: int = ceili(float(count) / float(rows))
		var w: float = (avail_w - (cols - 1) * GRID_GAP) / cols
		var h: float = w / CARD_ASPECT
		var max_h: float = (avail_h - (rows - 1) * GRID_GAP) / rows
		if h > max_h:
			h = max_h
			w = h * CARD_ASPECT
		if w >= 130.0 or cols <= 2:
			_card_cols = cols
			return Vector2(maxf(w, 60.0), maxf(h, 84.0))
		rows += 1
	_card_cols = count
	return Vector2(60.0, 84.0)


# Popup rect that snugly wraps `count` cards of `card_size` laid out
# `_card_cols` wide, plus the chrome.
func _large_popup_size(card_size: Vector2, count: int, has_caption: bool) -> Vector2i:
	var vp: Vector2 = Vector2(get_tree().root.get_visible_rect().size)
	var rows: int = ceili(float(count) / float(maxi(_card_cols, 1)))
	var cap_h: float = CAPTION_H if has_caption else 0.0
	var grid_w: float = card_size.x * _card_cols + GRID_GAP * (_card_cols - 1)
	var grid_h: float = (card_size.y + cap_h) * rows + GRID_GAP * (rows - 1)
	var w: float = minf(vp.x * LARGE_W_RATIO, grid_w + 80.0)
	var h: float = minf(vp.y * 0.92, grid_h + LARGE_CHROME_H)
	return Vector2i(roundi(w), roundi(h))


func _show_popup() -> void:
	if _large:
		# Explicit rect rather than popup_centered_ratio(), which needs
		# subwindow embedding to know the parent size and otherwise collapses
		# to the content minimum. Centred in the window.
		var vp: Vector2 = Vector2(get_tree().root.get_visible_rect().size)
		var x: int = roundi((vp.x - _large_size.x) * 0.5)
		var y: int = maxi(0, roundi((vp.y - _large_size.y) * 0.5))
		_show_backdrop()
		popup(Rect2i(Vector2i(x, y), _large_size))
	else:
		popup_centered(POPUP_SIZE)


# --- Backdrop -------------------------------------------------------------

func _show_backdrop() -> void:
	if not is_instance_valid(_backdrop):
		_backdrop = ColorRect.new()
		_backdrop.name = "CardPickerBackdrop"
		_backdrop.color = Color(0, 0, 0, 1)
		_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Swallows clicks so the game behind can't be used while choosing.
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		var mat := ShaderMaterial.new()
		mat.shader = BACKDROP_SHADER
		_backdrop.material = mat
		get_parent().add_child(_backdrop)
	var vp: Vector2 = Vector2(get_tree().root.get_visible_rect().size)
	_backdrop.position = Vector2.ZERO
	_backdrop.size = vp
	_backdrop.visible = true


func _hide_backdrop() -> void:
	if is_instance_valid(_backdrop):
		_backdrop.visible = false


# --- Hide / Unhide -------------------------------------------------------

func _on_hide_pressed() -> void:
	_hidden = true
	_hide_backdrop()
	hide()
	_ensure_unhide_button()
	_unhide_button.visible = true


func _on_unhide_pressed() -> void:
	_hidden = false
	_clear_unhide_button()
	_show_popup()
	popup_hide.connect(_on_popup_hide.bind(_answered_box), CONNECT_ONE_SHOT)


func _ensure_unhide_button() -> void:
	if is_instance_valid(_unhide_button):
		return
	var btn := Button.new()
	btn.text = "Unhide"
	btn.add_theme_font_size_override("font_size", 24)
	btn.custom_minimum_size = Vector2(240, 54)
	btn.size = Vector2(240, 54)
	btn.pressed.connect(_on_unhide_pressed)
	get_parent().add_child(btn)
	var vp: Vector2 = Vector2(get_tree().root.get_visible_rect().size)
	btn.position = Vector2((vp.x - btn.size.x) * 0.5, 10.0)
	_unhide_button = btn


func _clear_unhide_button() -> void:
	if is_instance_valid(_unhide_button):
		_unhide_button.queue_free()
	_unhide_button = null


func _finish(index: int) -> void:
	_answered_box[0] = true
	_revealing = false
	_hide_backdrop()
	_hidden = false
	_clear_unhide_button()
	set_process(false)
	hide()
	card_chosen.emit(index)


func _on_pick(index: int, answered_box: Array) -> void:
	if answered_box != _answered_box or _revealing:
		return
	_finish(index)


func _on_zoom(_hand_index: int, icon: Texture2D) -> void:
	zoom_requested.emit(icon)


func _on_skip() -> void:
	_finish(_skip_index)


func _on_cancel() -> void:
	_finish(-1)


# Dismissed some other way (e.g. clicking outside it, Escape, or the app
# losing focus). While deliberately hidden, or for a mandatory/sticky picker,
# this doesn't count -- _process (or Unhide) brings it back. Otherwise, treat
# it the same as Cancel so callers awaiting `card_chosen` never hang.
func _on_popup_hide(answered_box: Array) -> void:
	if answered_box[0] or _hidden:
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
	if _hidden or _answered_box[0] or visible:
		return
	if _mandatory or _sticky:
		_show_popup()
		popup_hide.connect(_on_popup_hide.bind(_answered_box), CONNECT_ONE_SHOT)
