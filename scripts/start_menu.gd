extends Control

# The top-level launcher: pick a game mode, or quit. Each mode opens its own
# setup screen (local_setup / host_lobby / join_menu).

@onready var local_game_button: Button = $VBox/Buttons/LocalGameButton
@onready var host_game_button: Button = $VBox/Buttons/HostGameButton
@onready var join_game_button: Button = $VBox/Buttons/JoinGameButton
@onready var tutorial_button: Button = $VBox/Buttons/TutorialButton
@onready var settings_button: Button = $VBox/Buttons/SettingsButton
@onready var quit_button: Button = $VBox/Buttons/QuitButton
# Credits / Roadmap sit in a small stack in the bottom-right corner, not the
# main button column. (Rules is in-game only -- the pause menu.)
@onready var credits_button: Button = $CornerButtons/CreditsButton
@onready var roadmap_button: Button = $CornerButtons/RoadmapButton
@onready var settings_menu: PopupPanel = $SettingsMenu
@onready var info_panel: ColorRect = $InfoPanel

const SettingsMenuScript = preload("res://scripts/settings_menu.gd")

const CREDITS_TEXT: String = """[b]Programming:[/b]
Gregor Radovic ([url=https://github.com/GregorRadovic]https://github.com/GregorRadovic[/url])

[b]Music:[/b]
"The Britons" Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
[url=http://creativecommons.org/licenses/by/4.0/]http://creativecommons.org/licenses/by/4.0/[/url]

[b]Art:[/b]
Artists credited on their cards.
Card layouts generated with Magic Set Editor (magicseteditor.boards.net).

[b]MONOPOLY®[/b], the MONOPOLY name and logo, the distinctive MONOPOLY gameboard design, Mr. Monopoly, and other related trademarks and distinctive elements are the property of Hasbro, Inc. and/or its licensors. All rights in those materials are reserved by their respective owners.

[b]Magic: The Gathering®[/b], including its card artwork, card names, characters, symbols, and other related intellectual property, is the property of Wizards of the Coast LLC and/or its licensors. All rights in those materials are reserved by their respective owners."""

const ROADMAP_TEXT: String = """[b]Coming Soon...[/b]

-Save and continue games
-Unlockable expansions
-Hero Mode
-Improved enemy AI
-Animations and Sounds"""


func _ready() -> void:
	# Coming back here means any previous online session is over.
	Net.leave()
	SettingsMenuScript.apply_saved()
	local_game_button.pressed.connect(func(): _go("res://scenes/local_setup.tscn"))
	host_game_button.pressed.connect(func(): _go("res://scenes/host_lobby.tscn"))
	join_game_button.pressed.connect(func(): _go("res://scenes/join_menu.tscn"))
	tutorial_button.pressed.connect(_start_tutorial)
	settings_button.pressed.connect(settings_menu.open)
	credits_button.pressed.connect(func() -> void: info_panel.open("Credits", CREDITS_TEXT))
	roadmap_button.pressed.connect(func() -> void: info_panel.open("Roadmap", ROADMAP_TEXT))
	quit_button.pressed.connect(get_tree().quit)


# Tutorial: straight into a one-human, one-Computer game with the scripted
# walkthrough turned on (see main.gd's TUTORIAL_STEPS). No setup screen.
func _start_tutorial() -> void:
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
	_go("res://scenes/main.tscn")


func _go(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
