extends Control

# The list of tutorials, shown when "Tutorial" is picked on the Start Menu.
#  - "Casting Spells" -- the scripted walkthrough inside a real game
#    (main.tscn with GameState.tutorial_mode; see main.gd's TUTORIAL_STEPS).
#  - "Pause Settings" -- a standalone narrated slideshow (pause_tutorial.tscn).
# Both return here when they finish.

@onready var casting_spells_button: Button = $VBox/Buttons/CastingSpellsButton
@onready var pause_settings_button: Button = $VBox/Buttons/PauseSettingsButton
@onready var back_button: Button = $VBox/Buttons/BackButton


func _ready() -> void:
	casting_spells_button.pressed.connect(_start_casting_spells)
	pause_settings_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/pause_tutorial.tscn"))
	back_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/start_menu.tscn"))


# One human, one Computer, scripted walkthrough on. No setup screen.
func _start_casting_spells() -> void:
	var types: Array[GameState.PlayerType] = [
		GameState.PlayerType.HUMAN, GameState.PlayerType.COMPUTER,
	]
	while types.size() < GameState.MAX_PLAYERS:
		types.append(GameState.PlayerType.DISABLED)
	GameState.player_types = types
	GameState.admin_mode = false
	GameState.quickstart_mode = false
	GameState.blitzstart_mode = false
	GameState.tutorial_mode = true
	GameState.online = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")
