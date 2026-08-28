extends Control

# Local (hotseat) game setup: choose what each of the four seats is, set the
# testing toggles, and start. No networking -- see host_lobby.gd for that.

const TYPE_LABELS: Array[String] = ["Human", "Computer", "Disabled"]
const TYPE_VALUES: Array[GameState.PlayerType] = [
	GameState.PlayerType.HUMAN, GameState.PlayerType.COMPUTER, GameState.PlayerType.DISABLED,
]
# P1 Human, P2 Computer, P3/P4 Disabled.
const DEFAULT_SELECTIONS: Array[int] = [0, 1, 2, 2]

@onready var start_button: Button = $VBox/ButtonRow/StartButton
@onready var back_button: Button = $VBox/ButtonRow/BackButton
@onready var admin_checkbox: CheckBox = $VBox/OptionsRow/AdminModeCheckBox
@onready var quickstart_checkbox: CheckBox = $VBox/OptionsRow/QuickstartModeCheckBox
@onready var not_enough_players_dialog: AcceptDialog = $NotEnoughPlayersDialog
@onready var type_options: Array[OptionButton] = [
	$VBox/Players/PlayerRow0/TypeOption,
	$VBox/Players/PlayerRow1/TypeOption,
	$VBox/Players/PlayerRow2/TypeOption,
	$VBox/Players/PlayerRow3/TypeOption,
]


func _ready() -> void:
	for i in type_options.size():
		var opt: OptionButton = type_options[i]
		for label in TYPE_LABELS:
			opt.add_item(label)
		opt.selected = DEFAULT_SELECTIONS[i]
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/start_menu.tscn"))


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

	GameState.player_types = types
	GameState.admin_mode = admin_checkbox.button_pressed
	GameState.quickstart_mode = quickstart_checkbox.button_pressed
	GameState.online = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")
