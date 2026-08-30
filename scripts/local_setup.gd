extends Control

# Local (hotseat) game setup: choose what each of the (up to 8) seats is, set
# the testing toggles, and start. No networking -- see host_lobby.gd for that.

const TYPE_LABELS: Array[String] = ["Human", "Computer", "Disabled"]
const TYPE_VALUES: Array[GameState.PlayerType] = [
	GameState.PlayerType.HUMAN, GameState.PlayerType.COMPUTER, GameState.PlayerType.DISABLED,
]
# P1 Human, P2 Computer, everyone else Disabled.
const DEFAULT_SELECTIONS: Array[int] = [0, 1, 2, 2, 2, 2, 2, 2]
# Matches main.gd's PLAYER_COLORS / PLAYER_NAMES (kept here so the setup screen
# doesn't depend on the in-game script).
const LABEL_COLORS: Array[Color] = [
	Color(0.929, 0.106, 0.141), Color(0.2, 0.4, 0.85), Color(0.2, 0.75, 0.3), Color(0.9, 0.8, 0.15),
	Color(0.6, 0.3, 0.8), Color(0.95, 0.55, 0.1), Color(0.15, 0.75, 0.8), Color(0.95, 0.45, 0.65),
]
# Human/Computer players past this can't use BlitzStart (not enough properties
# / spell cards to deal everyone a full opening hand).
const BLITZSTART_MAX_PLAYERS: int = 4

@onready var players_box: VBoxContainer = $VBox/PlayersScroll/Players
@onready var start_button: Button = $VBox/ButtonRow/StartButton
@onready var back_button: Button = $VBox/ButtonRow/BackButton
@onready var admin_checkbox: CheckBox = $VBox/OptionsRow/AdminModeCheckBox
@onready var quickstart_checkbox: CheckBox = $VBox/OptionsRow/QuickstartModeCheckBox
@onready var blitzstart_checkbox: CheckBox = $VBox/OptionsRow/BlitzstartModeCheckBox
@onready var not_enough_players_dialog: AcceptDialog = $NotEnoughPlayersDialog
@onready var blitzstart_limit_dialog: AcceptDialog = $BlitzStartLimitDialog

var type_options: Array[OptionButton] = []


func _ready() -> void:
	for i in GameState.MAX_PLAYERS:
		type_options.append(_build_player_row(i))
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/start_menu.tscn"))


func _build_player_row(index: int) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	players_box.add_child(row)

	var label := Label.new()
	label.custom_minimum_size = Vector2(160, 0)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", LABEL_COLORS[index])
	label.text = "Player %d" % (index + 1)
	row.add_child(label)

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(260, 44)
	opt.add_theme_font_size_override("font_size", 20)
	for opt_label in TYPE_LABELS:
		opt.add_item(opt_label)
	opt.selected = DEFAULT_SELECTIONS[index]
	row.add_child(opt)
	return opt


func _on_start_pressed() -> void:
	var types: Array[GameState.PlayerType] = []
	var active_count: int = 0
	for opt in type_options:
		var type: GameState.PlayerType = TYPE_VALUES[opt.selected]
		types.append(type)
		if type != GameState.PlayerType.DISABLED:
			active_count += 1

	if active_count < 2:
		not_enough_players_dialog.popup_centered()
		return

	if blitzstart_checkbox.button_pressed and active_count > BLITZSTART_MAX_PLAYERS:
		blitzstart_limit_dialog.popup_centered()
		return

	GameState.player_types = types
	GameState.admin_mode = admin_checkbox.button_pressed
	GameState.quickstart_mode = quickstart_checkbox.button_pressed
	GameState.blitzstart_mode = blitzstart_checkbox.button_pressed
	GameState.tutorial_mode = false
	GameState.online = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")
