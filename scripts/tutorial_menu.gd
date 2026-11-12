extends Control

# The list of tutorials, shown when "Tutorial" is picked on the Start Menu.
#  - "Basic Rules" -- Monopoly's own rules, played out in a real game
#    (main.tscn with GameState.tutorial_mode, tutorial_kind "basic"; see
#    main.gd's BASIC_TUTORIAL_STEPS).
#  - "Casting Spells" -- the same, for spells (tutorial_kind "spells"; see
#    main.gd's TUTORIAL_STEPS).
#  - "Pause Settings" -- a standalone narrated slideshow (pause_tutorial.tscn).
# Both return here when they finish.

@onready var basic_rules_button: Button = $VBox/Buttons/BasicRulesButton
@onready var casting_spells_button: Button = $VBox/Buttons/CastingSpellsButton
@onready var pause_settings_button: Button = $VBox/Buttons/PauseSettingsButton
@onready var back_button: Button = $VBox/Buttons/BackButton


func _ready() -> void:
	basic_rules_button.pressed.connect(_start_basic_rules)
	casting_spells_button.pressed.connect(_start_casting_spells)
	pause_settings_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/pause_tutorial.tscn"))
	back_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/start_menu.tscn"))


func _start_basic_rules() -> void:
	_start_tutorial("basic")


func _start_casting_spells() -> void:
	_start_tutorial("spells")


# One human, one Computer, scripted walkthrough on. No setup screen.
func _start_tutorial(kind: String) -> void:
	var types: Array[GameState.PlayerType] = [
		GameState.PlayerType.HUMAN, GameState.PlayerType.COMPUTER,
	]
	while types.size() < GameState.MAX_PLAYERS:
		types.append(GameState.PlayerType.DISABLED)
	GameState.player_types = types
	# The tutorial's script refers to "Player 1" / "Player 2".
	GameState.player_names = GameState.default_player_names()
	GameState.player_markers = PlayerMarkers.defaults()
	GameState.expansions = []  # the tutorial's script assumes the base deck
	GameState.hero_mode = false
	GameState.admin_mode = false
	GameState.quickstart_mode = false
	GameState.blitzstart_mode = false
	GameState.tutorial_mode = true
	GameState.tutorial_kind = kind
	GameState.online = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")
