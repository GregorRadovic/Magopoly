extends PopupPanel

# The "cast at what level?" prompt: a column of level-number buttons to the
# left of the full card, with Burn for Attunement under the card. Hovering
# (or keyboard-focusing) a level button highlights the words on the card that
# make up that level's effect -- the text before the levels, that level's own
# line (its circled number included), and any text after the levels -- using
# the rects in SpellTextRegions (generated from the card images by
# tools/gen_spell_text_regions.py).
#
# Otherwise behaves like player_picker.gd (deferred open; sticky / tutorial
# gate reopen on stray dismissal), so main.gd routes it the same way, locally
# or over the network. The × in the corner is Cancel.

# The chosen level, the burn entry's index, or -1 for cancel / dismissal.
signal level_chosen(index: int)

const HIGHLIGHT_COLOR: Color = Color(1.0, 0.82, 0.0, 0.40)
# Native card art size (all cards are 375 x 523).
const CARD_ASPECT: float = 375.0 / 523.0
const LEVEL_BUTTON_SIZE: float = 84.0
# Must match spell_level_picker.tscn's Margin / HBox / CardColumn settings.
const MARGIN_LEFT: float = 28.0
const MARGIN_RIGHT: float = 64.0  # room for the × button
const MARGIN_V: float = 28.0
const GAP: float = 28.0
const BURN_ROW_H: float = 60.0 + 14.0

@onready var levels_box: VBoxContainer = $Root/Margin/HBox/Levels
@onready var card_rect: TextureRect = $Root/Margin/HBox/CardColumn/Card
@onready var overlay: Control = $Root/Margin/HBox/CardColumn/Card/Overlay
@onready var burn_button: Button = $Root/Margin/HBox/CardColumn/BurnButton
@onready var close_button: Button = $Root/CloseButton

var _answered_box: Array = [false]
var _sticky: bool = false
var _gate: Callable = Callable()
var _regions: Dictionary = {}
var _hovered: int = -999
var _burn_index: int = -1
var _popup_size: Vector2i = Vector2i(900, 900)
# Tutorial: the y the popup must stay above (the top of the tutorial's text
# box) and below (under the toast strip); 0 = use the screen-relative band.
# Set by main.gd, so it holds at any screen resolution.
var keep_above: float = 0.0
var keep_below: float = 0.0


func _ready() -> void:
	close_button.pressed.connect(_on_cancel)
	burn_button.pressed.connect(func() -> void: _on_pick(_burn_index, _answered_box))
	overlay.draw.connect(_draw_highlights)
	set_process(false)


# levels: the spell's level numbers, in order (one button each).
# burn: {"index": int, "name": String} for the Burn for Attunement button
#   under the card, or {} when the spell can't be burned (Manastone).
# sticky: keep the × but reopen on any non-button dismissal (network use).
# gate: optional tutorial validator, same as player_picker's.
func open(icon_path: String, levels: Array, burn: Dictionary, sticky: bool = false, gate: Callable = Callable()) -> void:
	call_deferred("_do_open", icon_path, levels, burn, sticky, gate)


func _do_open(icon_path: String, levels: Array, burn: Dictionary, sticky: bool, gate: Callable) -> void:
	_sticky = sticky
	_gate = gate
	close_button.visible = not gate.is_valid()
	card_rect.texture = load(icon_path) if icon_path != "" and ResourceLoader.exists(icon_path) else null
	_regions = SpellTextRegions.REGIONS.get(icon_path, {})
	_set_hovered(-999)

	var answered_box: Array = [false]
	_answered_box = answered_box
	for child in levels_box.get_children():
		child.queue_free()
	for level in levels:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(LEVEL_BUTTON_SIZE, LEVEL_BUTTON_SIZE)
		btn.text = str(level)
		btn.add_theme_font_size_override("font_size", 40)
		btn.mouse_entered.connect(_set_hovered.bind(int(level)))
		btn.focus_entered.connect(_set_hovered.bind(int(level)))
		btn.mouse_exited.connect(_on_button_exited.bind(int(level)))
		btn.pressed.connect(_on_pick.bind(int(level), answered_box))
		levels_box.add_child(btn)

	_burn_index = int(burn.get("index", -1))
	burn_button.visible = not burn.is_empty()
	burn_button.text = str(burn.get("name", ""))

	# The card as tall as comfortably fits; the popup wraps the level column,
	# the card and the burn row.
	var vp: Vector2 = Vector2(get_tree().root.get_visible_rect().size)
	var extra_h: float = BURN_ROW_H if burn_button.visible else 0.0
	var card_h: float = minf(860.0, vp.y * 0.86 - MARGIN_V * 2.0 - extra_h)
	if _gate.is_valid():
		# Tutorial: fit between the toast strip at the top and the
		# instruction bubble at the bottom (see _show_popup).
		var band: float = (keep_above - keep_below) if keep_above > 0.0 else vp.y * 0.76
		card_h = minf(card_h, band - MARGIN_V * 2.0 - extra_h)
	var card_w: float = card_h * CARD_ASPECT
	card_rect.custom_minimum_size = Vector2(card_w, card_h)
	_popup_size = Vector2i(
		roundi(MARGIN_LEFT + LEVEL_BUTTON_SIZE + GAP + card_w + MARGIN_RIGHT),
		roundi(MARGIN_V * 2.0 + card_h + extra_h))
	_show_popup()
	set_process(_sticky or _gate.is_valid())
	popup_hide.connect(_on_popup_hide.bind(answered_box), CONNECT_ONE_SHOT)


# Centered normally. In the tutorial (gated) it sits in the band between the
# toast strip at the top and the instruction bubble along the bottom, so
# neither "Follow the instructions!" nor the current step gets covered.
func _show_popup() -> void:
	if not _gate.is_valid():
		popup_centered(_popup_size)
		return
	var vp: Vector2 = Vector2(get_tree().root.get_visible_rect().size)
	var top: float = vp.y * 0.105
	if keep_above > 0.0:
		top = keep_below + maxf(0.0, (keep_above - keep_below - _popup_size.y) * 0.5)
	popup(Rect2i(Vector2i(roundi((vp.x - _popup_size.x) * 0.5), roundi(top)), _popup_size))


func _set_hovered(index: int) -> void:
	_hovered = index
	overlay.queue_redraw()


func _on_button_exited(index: int) -> void:
	# Leaving a button clears the highlight, unless the pointer has already
	# moved on to another one (its mouse_entered fired first).
	if _hovered == index:
		_set_hovered(-999)


func _draw_highlights() -> void:
	var levels: Dictionary = _regions.get("levels", {})
	if not levels.has(_hovered):
		return
	var rects: Array = []
	rects.append_array(_regions.get("pre", []))
	rects.append_array(levels[_hovered])
	rects.append_array(_regions.get("post", []))
	var size: Vector2 = overlay.size
	for r: Rect2 in rects:
		overlay.draw_rect(Rect2(r.position * size, r.size * size), HIGHLIGHT_COLOR)


func _on_pick(index: int, answered_box: Array) -> void:
	if answered_box != _answered_box:
		return
	if _gate.is_valid() and not _gate.call(index):
		return
	answered_box[0] = true
	set_process(false)
	hide()
	level_chosen.emit(index)


func _on_cancel() -> void:
	_answered_box[0] = true
	set_process(false)
	hide()
	level_chosen.emit(-1)


# Dismissed some other way (clicking outside, Escape, losing focus). Sticky
# or gated pickers reopen instead (see _process); otherwise it's a cancel.
func _on_popup_hide(answered_box: Array) -> void:
	if answered_box[0]:
		return
	if _sticky or _gate.is_valid():
		return
	level_chosen.emit(-1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_reshow_if_needed()


func _process(_delta: float) -> void:
	if DisplayServer.window_is_focused():
		_reshow_if_needed()


func _reshow_if_needed() -> void:
	if (_sticky or _gate.is_valid()) and not _answered_box[0] and not visible:
		_show_popup()
		popup_hide.connect(_on_popup_hide.bind(_answered_box), CONNECT_ONE_SHOT)
