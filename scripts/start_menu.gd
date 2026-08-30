extends Control

# The top-level launcher: pick a game mode, or quit. Each mode opens its own
# setup screen (local_setup / host_lobby / join_menu).

@onready var local_game_button: Button = $VBox/Buttons/LocalGameButton
@onready var host_game_button: Button = $VBox/Buttons/HostGameButton
@onready var join_game_button: Button = $VBox/Buttons/JoinGameButton
@onready var tutorial_button: Button = $VBox/Buttons/TutorialButton
@onready var settings_button: Button = $VBox/Buttons/SettingsButton
@onready var quit_button: Button = $VBox/Buttons/QuitButton
@onready var settings_menu: PopupPanel = $SettingsMenu

const SettingsMenuScript = preload("res://scripts/settings_menu.gd")


func _ready() -> void:
	# Coming back here means any previous online session is over.
	Net.leave()
	SettingsMenuScript.apply_saved()
	local_game_button.pressed.connect(func(): _go("res://scenes/local_setup.tscn"))
	host_game_button.pressed.connect(func(): _go("res://scenes/host_lobby.tscn"))
	join_game_button.pressed.connect(func(): _go("res://scenes/join_menu.tscn"))
	tutorial_button.pressed.connect(_start_tutorial)
	settings_button.pressed.connect(settings_menu.open)
	quit_button.pressed.connect(get_tree().quit)


# Tutorial: straight into a one-human, one-Computer game with the scripted
# walkthrough turned on (see main.gd's TUTORIAL_STEPS). No setup screen.
func _start_tutorial() -> void:
	var types: Array[GameState.PlayerType] = [
		GameState.PlayerType.HUMAN, GameState.PlayerType.COMPUTER,
		GameState.PlayerType.DISABLED, GameState.PlayerType.DISABLED,
	]
	GameState.player_types = types
	GameState.admin_mode = false
	GameState.quickstart_mode = false
	GameState.blitzstart_mode = false
	GameState.tutorial_mode = true
	GameState.online = false
	_go("res://scenes/main.tscn")


func _go(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
