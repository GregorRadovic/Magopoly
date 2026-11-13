extends Control

# Player Profile, opened from the Start Menu: the player's name (editable),
# level and experience bar, what's unlocked, lifetime stats and recent games.
# Everything lives in user://profile.save (see saves.gd), so it's all still
# here after the game is closed and reopened.

const BODY: String = "Margin/VBox/Body/"

@onready var back_button: Button = $Margin/VBox/Header/BackButton
@onready var name_edit: LineEdit = get_node(BODY + "Identity/VBox/NameRow/NameEdit")
@onready var save_name_button: Button = get_node(BODY + "Identity/VBox/NameRow/SaveNameButton")
@onready var name_hint: Label = get_node(BODY + "Identity/VBox/NameHint")
@onready var level_label: Label = get_node(BODY + "Identity/VBox/LevelLabel")
@onready var bar: ProgressBar = get_node(BODY + "Identity/VBox/BarRow/Bar")
@onready var next_label: Label = get_node(BODY + "Identity/VBox/BarRow/NextLabel")
@onready var progress_hint: Label = get_node(BODY + "Identity/VBox/ProgressHint")
@onready var unlocks_label: RichTextLabel = get_node(BODY + "Identity/VBox/UnlocksLabel")
@onready var stats_label: RichTextLabel = get_node(BODY + "Record/VBox/StatsLabel")
@onready var history_label: RichTextLabel = get_node(BODY + "Record/VBox/HistoryLabel")

const XP_AWARD_SCENE: PackedScene = preload("res://scenes/xp_award.tscn")
# A cheat: levels the profile straight up to the highest unlock, playing the
# usual level-up screen for each level on the way.
var unlock_all_button: Button

const NAME_HINT: String = "Shown to other players online, and on your seat in local games."


func _ready() -> void:
	# The cheat button sits beside the big "Level N".
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var parent: Node = level_label.get_parent()
	parent.add_child(row)
	parent.move_child(row, level_label.get_index())
	parent.remove_child(level_label)
	row.add_child(level_label)
	unlock_all_button = Button.new()
	unlock_all_button.text = "Unlock all levels"
	unlock_all_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	unlock_all_button.add_theme_font_size_override("font_size", 20)
	unlock_all_button.pressed.connect(_unlock_all_levels)
	row.add_child(unlock_all_button)
	back_button.pressed.connect(_go_back)
	save_name_button.pressed.connect(_save_name)
	name_edit.text_submitted.connect(func(_t: String) -> void: _save_name())
	name_edit.text_changed.connect(func(_t: String) -> void: _refresh_save_button())
	name_edit.max_length = Saves.NAME_MAX_LENGTH
	_refresh()


func _refresh() -> void:
	var profile: Dictionary = Saves.load_profile()
	name_edit.text = profile["name"]
	_refresh_save_button()

	var xp: int = profile["xp"]
	var level: int = Saves.level_of(xp)
	level_label.text = "Level %d" % level
	bar.value = Saves.level_progress(xp)
	next_label.text = "Level %d" % (level + 1)
	# Half-levels left to the next level: 2 = a win (or two losses), 1 = any
	# finished game.
	if xp % 2 == 0:
		progress_hint.text = "Win a game to reach level %d, or finish two." % (level + 1)
	else:
		progress_hint.text = "Halfway there -- finish one more game to reach level %d." % (level + 1)

	unlocks_label.text = _unlocks_text(level)
	unlock_all_button.disabled = level >= _max_unlock_level()
	stats_label.text = _stats_text(profile["stats"])
	history_label.text = _history_text(profile["history"])


# Level 25, or higher if something unlocks later than that.
const CHEAT_LEVEL: int = 25


func _max_unlock_level() -> int:
	var top: int = CHEAT_LEVEL
	for u in Saves.all_unlocks():
		top = maxi(top, int(u["level"]))
	return top


func _unlock_all_levels() -> void:
	var profile: Dictionary = Saves.load_profile()
	var xp_before: int = profile["xp"]
	var xp_after: int = _max_unlock_level() * 2
	if xp_before >= xp_after:
		return
	profile["xp"] = xp_after
	Saves._write(Saves.PROFILE_PATH, profile)
	unlock_all_button.disabled = true
	var award: Control = XP_AWARD_SCENE.instantiate()
	add_child(award)
	award.fill_seconds_per_level = 0.35
	award.closed.connect(func() -> void:
		award.queue_free()
		_refresh())
	award.show_award("Unlocking everything!", null, xp_before, xp_after)
	award.result_label.text = "Cheat: straight to level %d" % (xp_after / 2)


func _refresh_save_button() -> void:
	save_name_button.disabled = name_edit.text.strip_edges() == Saves.get_player_name()


func _save_name() -> void:
	var saved: String = Saves.set_player_name(name_edit.text)
	name_edit.text = saved
	name_hint.text = "Saved." if saved != "" else "Name cleared -- you'll show up as \"Player N\"."
	_refresh_save_button()
	await get_tree().create_timer(2.5).timeout
	if is_inside_tree():
		name_hint.text = NAME_HINT


func _unlocks_text(level: int) -> String:
	var unlocks: Array[Dictionary] = Saves.all_unlocks()
	if unlocks.is_empty():
		return "[color=#8c93a8]New features unlock as you level up. Coming soon![/color]"
	var lines: Array[String] = []
	for u in unlocks:
		var need: int = int(u["level"])
		if level >= need:
			lines.append("[color=#5fd068]•[/color] [b]%s[/b] -- %s" % [u["name"], u.get("description", "")])
		else:
			lines.append("[color=#8c93a8]Level %d: %s -- %s[/color]" % [need, u["name"], u.get("description", "")])
	return "\n".join(lines)


func _stats_text(st: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b]Games played:[/b] %d" % st["games_played"])
	lines.append("[b]Wins:[/b] %d    [b]Losses:[/b] %d" % [st["games_won"], st["games_lost"]])
	if st["games_won"] + st["games_lost"] > 0:
		lines.append("[b]Win rate:[/b] %d%%" % roundi(100.0 * st["games_won"] / (st["games_won"] + st["games_lost"])))
	lines.append("[b]Spells cast:[/b] %d" % st["spells_cast"])
	lines.append("[b]Properties bought:[/b] %d" % st["properties_bought"])
	return "\n".join(lines)


func _history_text(history: Array) -> String:
	if history.is_empty():
		return "[color=#8c93a8]No finished games yet.[/color]"
	var lines: Array[String] = []
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
		lines.append("%s · %s · %d players · %d turn%s · %s" % [
			date, g.get("mode", ""), int(g.get("players", 0)), turns, "" if turns == 1 else "s", result])
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")
