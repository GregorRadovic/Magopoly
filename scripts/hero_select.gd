extends Control

# Hero Mode's hero selection, between game setup and the game itself.
#
# The roster shows Heroes.ROSTER_SIZE boxes: every defined hero (locked ones
# as padlocked tiles saying what level unlocks them) and "coming soon" tiles
# for the rest. Each human picks a hero they've unlocked; Computer seats get
# Heroes.default_ai_hero().
#
# Local game: humans pick in turn on this screen (click a seat to change its
# pick); Start begins the game. Online: each player picks for their own seat
# with their own unlocks (net.gd relays picks through the host); everyone
# sees all picks, and the host starts once every human has picked.

const HERO_BOX := preload("res://scripts/hero_box.gd")
const PLAYER_COLORS: Array[Color] = [
	Color(0.929, 0.106, 0.141), Color(0.2, 0.4, 0.85), Color(0.2, 0.75, 0.3), Color(0.9, 0.8, 0.15),
	Color(0.6, 0.3, 0.8), Color(0.95, 0.55, 0.1), Color(0.15, 0.75, 0.8), Color(0.95, 0.45, 0.65),
]
const MUTED: Color = Color(0.65, 0.7, 0.8)

@onready var prompt_label: Label = $Margin/VBox/PromptLabel
@onready var grid: GridContainer = $Margin/VBox/GridCenter/Grid
@onready var detail_name: Label = $Margin/VBox/Bottom/Detail/VBox/NameLabel
@onready var detail_text: Label = $Margin/VBox/Bottom/Detail/VBox/TextLabel
@onready var seats_box: VBoxContainer = $Margin/VBox/Bottom/Seats/VBox/SeatList
@onready var start_button: Button = $Margin/VBox/Bottom/Buttons/StartButton
@onready var back_button: Button = $Margin/VBox/Bottom/Buttons/BackButton
@onready var wait_label: Label = $Margin/VBox/Bottom/Buttons/WaitLabel

var _boxes: Array = []
# Local game only: seat -> hero id, and the seat currently choosing.
var _local_picks: Array[String] = ["", "", "", "", "", "", "", ""]
var _active_seat: int = -1


func _ready() -> void:
	_build_roster()
	back_button.pressed.connect(_on_back)
	start_button.pressed.connect(_on_start)
	if GameState.online:
		back_button.text = "Leave"
		Net.hero_state_updated.connect(_refresh)
		Net.kicked.connect(_on_kicked)
		start_button.visible = Net.hosting
		wait_label.visible = not Net.hosting
	else:
		wait_label.visible = false
		for i in GameState.MAX_PLAYERS:
			if GameState.player_types[i] == GameState.PlayerType.COMPUTER:
				_local_picks[i] = Heroes.default_ai_hero()
		_active_seat = _next_unpicked_human(-1)
	_show_detail(-1)
	_refresh()


func _build_roster() -> void:
	for i in Heroes.ROSTER_SIZE:
		var box: Control = HERO_BOX.new()
		box.slot = i
		if i < Heroes.LIST.size():
			var h: Dictionary = Heroes.LIST[i]
			box.hero_id = h["id"]
			box.locked = not Saves.is_hero_unlocked(h["id"])
			box.portrait_color = h.get("color", Color.GRAY)
			box.caption = "Level %d" % int(h["unlock_level"]) if box.locked else str(h["name"])
		else:
			box.caption = "Coming soon"
		box.picked.connect(_on_box_picked)
		box.hovered.connect(_show_detail)
		grid.add_child(box)
		_boxes.append(box)


# --- picking -------------------------------------------------------------

func _on_box_picked(slot: int) -> void:
	_show_detail(slot)
	var box: Control = _boxes[slot]
	if box.locked:
		return
	if GameState.online:
		Net.pick_hero(box.hero_id)
		return
	if _active_seat < 0:
		return
	_local_picks[_active_seat] = box.hero_id
	_active_seat = _next_unpicked_human(_active_seat)
	_refresh()


func _picks() -> Array[String]:
	return Net.hero_picks if GameState.online else _local_picks


func _my_seat() -> int:
	if GameState.online:
		var mine: Array[int] = GameState.local_slots()
		return mine[0] if not mine.is_empty() else -1
	return _active_seat


func _next_unpicked_human(after: int) -> int:
	for k in GameState.MAX_PLAYERS:
		var i: int = (after + 1 + k) % GameState.MAX_PLAYERS
		if GameState.player_types[i] == GameState.PlayerType.HUMAN and _local_picks[i] == "":
			return i
	return -1


func _all_picked() -> bool:
	if GameState.online:
		return Net.all_heroes_picked()
	for i in GameState.MAX_PLAYERS:
		if GameState.player_types[i] == GameState.PlayerType.HUMAN and _local_picks[i] == "":
			return false
	return true


# --- display ---------------------------------------------------------------

func _refresh() -> void:
	var picks: Array[String] = _picks()
	var seat: int = _my_seat()
	var current: String = picks[seat] if seat >= 0 else ""
	for box in _boxes:
		box.selected = box.hero_id != "" and box.hero_id == current

	if GameState.online:
		prompt_label.text = "Pick your hero." if current == "" else "You're playing as %s." % Heroes.hero_name(current)
	elif _active_seat >= 0:
		prompt_label.text = "%s, choose your hero." % GameState.player_names[_active_seat]
	else:
		prompt_label.text = "Everyone has a hero. Click a player to change their pick, or start the game."
	if seat >= 0 and (not GameState.online or current == ""):
		prompt_label.add_theme_color_override("font_color", PLAYER_COLORS[seat])
	else:
		prompt_label.add_theme_color_override("font_color", MUTED)

	for child in seats_box.get_children():
		child.queue_free()
	for i in GameState.MAX_PLAYERS:
		var t: int = GameState.player_types[i]
		if t == GameState.PlayerType.DISABLED:
			continue
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 22)
		row.add_theme_color_override("font_color", PLAYER_COLORS[i])
		row.add_theme_color_override("font_hover_color", PLAYER_COLORS[i].lightened(0.3))
		var who: String = GameState.player_names[i]
		if t == GameState.PlayerType.COMPUTER:
			who += " (Computer)"
		var hero: String = Heroes.hero_name(picks[i]) if picks[i] != "" else "choosing…"
		var marker: String = "» " if not GameState.online and i == _active_seat else ""
		row.text = "%s%s — %s" % [marker, who, hero]
		# Local game: click a human seat to (re)pick for it.
		if not GameState.online and t == GameState.PlayerType.HUMAN:
			row.pressed.connect(func() -> void:
				_active_seat = i
				_refresh())
		else:
			row.disabled = true
			row.add_theme_color_override("font_disabled_color", PLAYER_COLORS[i])
		seats_box.add_child(row)

	start_button.disabled = not _all_picked()
	if GameState.online and not Net.hosting:
		wait_label.text = "Waiting for the host to start…" if current != "" else "Pick a hero."


func _show_detail(slot: int) -> void:
	if slot < 0 or slot >= _boxes.size():
		detail_name.text = "Heroes"
		detail_text.text = "Each player plays as a hero with special effects for this game. Unlock more heroes by levelling up."
		return
	var box: Control = _boxes[slot]
	if box.hero_id == "":
		detail_name.text = "Coming soon"
		detail_text.text = "A new hero will appear here in a future update."
		return
	var h: Dictionary = Heroes.get_hero(box.hero_id)
	detail_name.text = str(h["name"])
	if box.locked:
		detail_text.text = "%s\nLocked -- reach level %d to unlock (you're level %d)." % [h["description"], int(h["unlock_level"]), Saves.get_level()]
	else:
		detail_text.text = str(h["description"])


# --- buttons ---------------------------------------------------------------

func _on_start() -> void:
	if not _all_picked():
		return
	if GameState.online:
		var o: Dictionary = Net.pending_options
		Net.start_game(bool(o.get("admin", false)), bool(o.get("quick", false)), bool(o.get("blitz", false)))
		return
	GameState.player_heroes = _local_picks.duplicate()
	GameState.hero_mode = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back() -> void:
	if GameState.online:
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/start_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/local_setup.tscn")


func _on_kicked(reason: String) -> void:
	prompt_label.text = reason
	prompt_label.add_theme_color_override("font_color", Color(0.9, 0.42, 0.35))
	start_button.disabled = true
	await get_tree().create_timer(2.5).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/start_menu.tscn")
