extends Control

# The top-level launcher: pick a game mode, or quit. Each mode opens its own
# setup screen (local_setup / host_lobby / join_menu).

# Continue / Rejoin only show up when there's something to go back to.
@onready var continue_button: Button = $VBox/Buttons/ContinueButton
@onready var rejoin_button: Button = $VBox/Buttons/RejoinButton
@onready var local_game_button: Button = $VBox/Buttons/LocalGameButton
@onready var host_game_button: Button = $VBox/Buttons/HostGameButton
@onready var join_game_button: Button = $VBox/Buttons/JoinGameButton
@onready var tutorial_button: Button = $VBox/Buttons/TutorialButton
@onready var compendium_button: Button = $VBox/Buttons/CompendiumButton
@onready var settings_button: Button = $VBox/Buttons/SettingsButton
@onready var quit_button: Button = $VBox/Buttons/QuitButton
# Credits / Roadmap sit in a small stack in the bottom-right corner, not the
# main button column. (Rules is in-game only -- the pause menu.)
@onready var stats_button: Button = $CornerButtons/StatsButton
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
	tutorial_button.pressed.connect(func() -> void: _go("res://scenes/tutorial_menu.tscn"))
	compendium_button.pressed.connect(func() -> void: _go("res://scenes/compendium.tscn"))
	settings_button.pressed.connect(settings_menu.open)
	credits_button.pressed.connect(func() -> void: info_panel.open("Credits", CREDITS_TEXT))
	roadmap_button.pressed.connect(func() -> void: info_panel.open("Roadmap", ROADMAP_TEXT))
	quit_button.pressed.connect(get_tree().quit)
	stats_button.pressed.connect(func() -> void: info_panel.open("Stats", _stats_text()))
	continue_button.pressed.connect(_on_continue)
	rejoin_button.pressed.connect(_on_rejoin)
	_refresh_resume_buttons()


func _refresh_resume_buttons() -> void:
	var save: Dictionary = Saves.load_autosave()
	continue_button.visible = not save.is_empty()
	if not save.is_empty():
		var online: bool = bool(save.get("config", {}).get("online", false))
		var turn: int = int(save.get("summary", {}).get("turn", 1))
		continue_button.text = "Continue (%s, Turn %d)" % ["Online" if online else "Local", turn]
		continue_button.custom_minimum_size.x = 420
	rejoin_button.visible = not Saves.load_session().is_empty()


# Resume the autosaved game. A local game just reloads; an online one
# reopens the server for the same seats, and everyone else uses Rejoin Game.
func _on_continue() -> void:
	var save: Dictionary = Saves.load_autosave()
	if save.is_empty():
		_refresh_resume_buttons()
		return
	var cfg: Dictionary = save.get("config", {})
	var types: Array[GameState.PlayerType] = []
	for t in cfg.get("player_types", []):
		types.append(int(t))
	GameState.player_types = types
	GameState.admin_mode = bool(cfg.get("admin", false))
	GameState.quickstart_mode = bool(cfg.get("quick", false))
	GameState.blitzstart_mode = bool(cfg.get("blitz", false))
	GameState.tutorial_mode = false
	if bool(cfg.get("online", false)):
		if not Net.resume_hosting(save):
			info_panel.open("Couldn't resume", "Couldn't open the game server on port %d. Is another copy of the game already hosting?" % Net.DEFAULT_PORT)
			return
	else:
		GameState.online = false
	Saves.pending_load = save
	_go("res://scenes/main.tscn")


# Back to the online game this player was in, with the reconnect token the
# host knows their seat by (see net.gd's join_game / _try_reconnect).
func _on_rejoin() -> void:
	Saves.auto_rejoin = true
	_go("res://scenes/join_menu.tscn")


func _stats_text() -> String:
	var profile: Dictionary = Saves.load_profile()
	var st: Dictionary = profile["stats"]
	var lines: Array[String] = []
	lines.append("[b]Games played:[/b] %d" % st["games_played"])
	lines.append("[b]Wins:[/b] %d    [b]Losses:[/b] %d" % [st["games_won"], st["games_lost"]])
	if st["games_won"] + st["games_lost"] > 0:
		lines.append("[b]Win rate:[/b] %d%%" % roundi(100.0 * st["games_won"] / (st["games_won"] + st["games_lost"])))
	lines.append("[b]Spells cast:[/b] %d" % st["spells_cast"])
	lines.append("[b]Properties bought:[/b] %d" % st["properties_bought"])
	lines.append("")
	lines.append("[b]Recent games[/b]")
	var history: Array = profile["history"]
	if history.is_empty():
		lines.append("No finished games yet.")
	for g: Dictionary in history:
		var date: String = Time.get_date_string_from_unix_time(int(g.get("date", 0)))
		var result: String = "Finished"
		if g.get("won") == true:
			result = "[color=#5fd068]Won[/color]"
		elif g.get("won") == false:
			result = "[color=#e86a5a]Lost[/color]"
		if str(g.get("winner", "")) != "" and g.get("won") != true:
			result += " -- %s won" % g["winner"]
		var turns: int = int(g.get("turns", 0))
		lines.append("%s · %s · %d players · %d turn%s · %s" % [date, g.get("mode", ""), int(g.get("players", 0)), turns, "" if turns == 1 else "s", result])
	return "\n".join(lines)


func _go(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
