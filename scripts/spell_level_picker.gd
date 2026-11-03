extends PopupPanel

# The "Cast <spell> at what level?" prompt: level buttons on the left, the
# full card on the right. Hovering (or keyboard-focusing) a level highlights
# the words on the card that make up that level's effect -- the text before
# the levels, that level's own line, and any text after the levels -- using
# the rects in SpellTextRegions (generated from the card images by
# tools/gen_spell_text_regions.py).
#
# Behaves like player_picker.gd otherwise (same entries format, same
# mandatory / sticky / tutorial-gate semantics, deferred open), so main.gd
# routes it the same way, locally or over the network.

# -1 means nothing was chosen (Cancel, or dismissed some other way).
signal level_chosen(index: int)

const HIGHLIGHT_COLOR: Color = Color(1.0, 0.82, 0.0, 0.40)
# Native card art size (all cards are 375 x 523).
const CARD_ASPECT: float = 375.0 / 523.0
const LEFT_WIDTH: float = 380.0
const MARGIN: float = 28.0
const GAP: float = 28.0

@onready var title_label: Label = $Margin/HBox/Left/TitleLabel
@onready var hint_label: Label = $Margin/HBox/Left/HintLabel
@onready var button_container: VBoxContainer = $Margin/HBox/Left/ButtonContainer
@onready var cancel_button: Button = $Margin/HBox/Left/CancelButton
@onready var card_rect: TextureRect = $Margin/HBox/Card
@onready var overlay: Control = $Margin/HBox/Card/Overlay

var _answered_box: Array = [false]
var _sticky: bool = false
var _gate: Callable = Callable()
var _regions: Dictionary = {}
var _hovered: int = -999
var _popup_size: Vector2i = Vector2i(1100, 900)


func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel)
	overlay.draw.connect(_draw_highlights)
	set_process(false)


# entries: Array of {"index": int, "name": String, "color": Color} -- level
# entries use the level number as their index; anything else (e.g. Burn for
# Attunement) just has no highlight.
# sticky: keep Cancel, but reopen on any non-button dismissal (network use).
# gate: optional tutorial validator, same as player_picker's.
func open(spell_name: String, icon_path: String, entries: Array, sticky: bool = false, gate: Callable = Callable()) -> void:
	call_deferred("_do_open", spell_name, icon_path, entries, sticky, gate)


func _do_open(spell_name: String, icon_path: String, entries: Array, sticky: bool, gate: Callable) -> void:
	_sticky = sticky
	_gate = gate
	cancel_button.visible = not gate.is_valid()
	title_label.text = "Cast %s" % spell_name
	card_rect.texture = load(icon_path) if icon_path != "" and ResourceLoader.exists(icon_path) else null
	_regions = SpellTextRegions.REGIONS.get(icon_path, {})
	_set_hovered(-999)

	var answered_box: Array = [false]
	_answered_box = answered_box
	for child in button_container.get_children():
		child.queue_free()
	for entry in entries:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 64)
		btn.text = entry["name"]
		btn.add_theme_font_size_override("font_size", 26)
		btn.add_theme_color_override("font_color", entry.get("color", Color.WHITE))
		var index: int = entry["index"]
		btn.mouse_entered.connect(_set_hovered.bind(index))
		btn.focus_entered.connect(_set_hovered.bind(index))
		btn.mouse_exited.connect(_on_button_exited.bind(index))
		btn.pressed.connect(_on_pick.bind(index, answered_box))
		button_container.add_child(btn)

	# The card as tall as comfortably fits; the popup wraps it plus the
	# button column.
	var vp: Vector2 = Vector2(get_tree().root.get_visible_rect().size)
	var card_h: float = minf(900.0, vp.y * 0.84 - MARGIN * 2.0)
	if _gate.is_valid():
		# Tutorial: fit between the toast strip at the top and the
		# instruction bubble at the bottom (see _show_popup).
		card_h = minf(card_h, vp.y * 0.76 - MARGIN * 2.0)
	var card_w: float = card_h * CARD_ASPECT
	card_rect.custom_minimum_size = Vector2(card_w, card_h)
	_popup_size = Vector2i(roundi(LEFT_WIDTH + GAP + card_w + MARGIN * 2.0), roundi(card_h + MARGIN * 2.0))
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
	popup(Rect2i(Vector2i(roundi((vp.x - _popup_size.x) * 0.5), roundi(vp.y * 0.105)), _popup_size))


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
