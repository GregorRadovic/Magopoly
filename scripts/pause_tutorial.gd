extends Control

# "Pause Settings" tutorial -- a narrated slideshow (Tutorial Menu > Pause
# Settings). Each slide fully describes the screen; a left click anywhere
# advances, and a click past the last slide returns to the Tutorial Menu.
# Esc also backs out.
#
# Per-slide keys:
#   text      -- the narration shown in the bubble
#   settings  -- show the mock Settings panel
#   dropdown  -- show the Pause Options dropdown, opened
#   highlight -- which dropdown row (0 Manual / 1 Half-Control / 2 Full
#                Control) to spotlight; absent = none
#   cards     -- two spell names to show beside the panel; absent = none

const MENU_SCENE: String = "res://scenes/tutorial_menu.tscn"
const PAUSE_LABELS: Array[String] = ["Manual", "Half-Control", "Full Control"]

const SLIDES: Array[Dictionary] = [
	{"text": "By default, the game only pauses when you press the spacebar. It is possible to change this so you pause automatically at specific times."},
	{"text": "In-game, you can press Esc to access your settings, and from there you can access the Pause Settings.",
		"settings": true},
	{"text": "There are three Pause Settings.",
		"settings": true, "dropdown": true},
	{"text": "Manual is the default. You only pause when you manually press space bar.",
		"settings": true, "dropdown": true, "highlight": 0},
	{"text": "Half-Control automatically pauses whenever you roll.",
		"settings": true, "dropdown": true, "highlight": 1},
	{"text": "We recommend switching to this if you have a roll-modification spell.",
		"settings": true, "dropdown": true, "highlight": 1, "cards": ["Adrenaline", "Divine Protection"]},
	{"text": "Remember: If you don't pause in time and you land on the wrong space, it'll be too late to change your roll.",
		"settings": true, "dropdown": true, "highlight": 1, "cards": ["Adrenaline", "Divine Protection"]},
	{"text": "Full Control automatically pauses whenever you roll; and also when your opponents roll, or cast a spell.",
		"settings": true, "dropdown": true, "highlight": 2},
	{"text": "This is generally overkill, but it's useful for some spells.",
		"settings": true, "dropdown": true, "highlight": 2, "cards": ["Price Gouging", "Spell Mastery"]},
	{"text": "Using these settings wisely can help you avoid annoying situations where you missed the right moment to cast the spell.",
		"settings": true, "dropdown": true, "highlight": 2, "cards": ["Price Gouging", "Spell Mastery"]},
	{"text": "That's all for now. Good luck!"},
]

@onready var settings_mock: PanelContainer = $Stage/SettingsMock
@onready var pause_value_box: Panel = $Stage/SettingsMock/Margin/VBox/PauseRow/PauseValue
@onready var pause_value_label: Label = $Stage/SettingsMock/Margin/VBox/PauseRow/PauseValue/Label
@onready var dropdown: PanelContainer = $Stage/Dropdown
@onready var items: Array[Node] = [
	$Stage/Dropdown/DropVBox/Item0,
	$Stage/Dropdown/DropVBox/Item1,
	$Stage/Dropdown/DropVBox/Item2,
]
@onready var card_box: VBoxContainer = $Stage/CardBox
@onready var card1: TextureRect = $Stage/CardBox/Cards/Card1
@onready var card2: TextureRect = $Stage/CardBox/Cards/Card2
@onready var bubble_label: Label = $Bubble/Label
@onready var hint_label: Label = $Bubble/Hint

var _slide: int = -1
var _hl_style: StyleBoxFlat
var _plain_style: StyleBoxEmpty = StyleBoxEmpty.new()


func _ready() -> void:
	_hl_style = StyleBoxFlat.new()
	_hl_style.bg_color = Color(0.361, 0.549, 0.898, 0.4)
	_hl_style.border_color = Color(0.55, 0.72, 1.0)
	_hl_style.set_border_width_all(3)
	_hl_style.set_corner_radius_all(4)
	settings_mock.visible = false
	dropdown.visible = false
	card_box.visible = false
	_advance()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_advance()


func _advance() -> void:
	_slide += 1
	if _slide >= SLIDES.size():
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	await _apply_slide(SLIDES[_slide])


func _apply_slide(s: Dictionary) -> void:
	bubble_label.text = str(s.get("text", ""))
	hint_label.text = "(click to finish)" if _slide == SLIDES.size() - 1 else "(click anywhere to continue)"

	settings_mock.visible = bool(s.get("settings", false))
	dropdown.visible = bool(s.get("dropdown", false))

	var hl: int = int(s.get("highlight", -1))
	for i in items.size():
		(items[i] as Control).add_theme_stylebox_override("panel", _hl_style if i == hl else _plain_style)
	pause_value_label.text = PAUSE_LABELS[hl] if hl >= 0 else PAUSE_LABELS[0]

	var cards: Array = s.get("cards", [])
	card_box.visible = cards.size() == 2
	if cards.size() == 2:
		card1.texture = _spell_icon(cards[0])
		card2.texture = _spell_icon(cards[1])
	# Nudge the Settings panel left when the cards are up, so the two balance;
	# centre it again on the text-only / dropdown-only slides.
	var shift: float = -190.0 if cards.size() == 2 else 0.0
	settings_mock.offset_left = -300.0 + shift
	settings_mock.offset_right = 300.0 + shift

	if dropdown.visible:
		# Line the opened dropdown up under the Pause Options value box, once
		# the panel has finished laying itself out.
		await get_tree().process_frame
		if is_instance_valid(dropdown) and dropdown.visible:
			dropdown.global_position = pause_value_box.global_position + Vector2(0.0, pause_value_box.size.y + 6.0)
			dropdown.size.x = pause_value_box.size.x
			dropdown.custom_minimum_size.x = pause_value_box.size.x


func _spell_icon(spell_name: String) -> Texture2D:
	var path: String = SpellData.SPELLS.get(spell_name, {}).get("icon", "")
	return load(path) if path != "" and ResourceLoader.exists(path) else null
