extends Control

const TYPE_LABELS: Array[String] = ["Local Human", "Disabled", "Computer"]
# Index in TYPE_LABELS -> GameState.PlayerType.
const TYPE_VALUES: Array[GameState.PlayerType] = [
	GameState.PlayerType.HUMAN, GameState.PlayerType.DISABLED, GameState.PlayerType.COMPUTER,
]
# Default TYPE_LABELS selection per slot: P1 Local Human, P2 Computer, P3/P4
# Disabled.
const DEFAULT_SELECTIONS: Array[int] = [0, 2, 1, 1]

@onready var start_button: Button = $VBox/StartButton
@onready var close_game_button: Button = $VBox/CloseGameButton
@onready var admin_mode_checkbox: CheckBox = $VBox/AdminModeCheckBox
@onready var quickstart_mode_checkbox: CheckBox = $VBox/QuickstartModeCheckBox
@onready var not_enough_players_dialog: AcceptDialog = $NotEnoughPlayersDialog
@onready var player_type_options: Array[OptionButton] = [
	$VBox/PlayersSection/PlayerRow0/TypeOption,
	$VBox/PlayersSection/PlayerRow1/TypeOption,
	$VBox/PlayersSection/PlayerRow2/TypeOption,
	$VBox/PlayersSection/PlayerRow3/TypeOption,
]


func _ready() -> void:
	for i in player_type_options.size():
		var option: OptionButton = player_type_options[i]
		for label in TYPE_LABELS:
			option.add_item(label)
		option.selected = DEFAULT_SELECTIONS[i]
	start_button.pressed.connect(_on_start_pressed)
	close_game_button.pressed.connect(_on_close_game_pressed)


func _on_start_pressed() -> void:
	var types: Array[GameState.PlayerType] = []
	var active_count: int = 0
	for option in player_type_options:
		var type: GameState.PlayerType = TYPE_VALUES[option.selected]
		types.append(type)
		if type != GameState.PlayerType.DISABLED:
			active_count += 1

	if active_count < 2:
		not_enough_players_dialog.popup_centered()
		return

	GameState.player_types = types
	GameState.admin_mode = admin_mode_checkbox.button_pressed
	GameState.quickstart_mode = quickstart_mode_checkbox.button_pressed
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_close_game_pressed() -> void:
	get_tree().quit()
