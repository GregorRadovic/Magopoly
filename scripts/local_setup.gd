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
# Each seat's playing-piece dropdown (no two active seats may share one).
var marker_options: Array[OptionButton] = []
# The seats that were in play at the last _refresh_markers().
var _was_active: Array[int] = []
var expansion_picker: ExpansionPicker
var hero_mode_checkbox: CheckBox


func _ready() -> void:
	for i in GameState.MAX_PLAYERS:
		type_options.append(_build_player_row(i))
	_refresh_markers()
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/start_menu.tscn"))
	hero_mode_checkbox = _hero_mode_checkbox()
	$VBox/OptionsRow.add_child(hero_mode_checkbox)
	# Unlocked expansions, under the mode checkboxes.
	expansion_picker = ExpansionPicker.new()
	$VBox.add_child(expansion_picker)
	$VBox.move_child(expansion_picker, $VBox/OptionsRow.get_index() + 1)


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
	opt.item_selected.connect(func(_i: int) -> void: _refresh_markers())
	row.add_child(opt)

	var marker_opt: OptionButton = PlayerMarkers.make_option(PlayerMarkers.LIST[index])
	marker_opt.item_selected.connect(func(_i: int) -> void: _refresh_markers())
	row.add_child(marker_opt)
	marker_options.append(marker_opt)
	return opt


func _seat_active(i: int) -> bool:
	return TYPE_VALUES[type_options[i].selected] != GameState.PlayerType.DISABLED


# Keeps the playing pieces unique across the seats in play: a seat switched
# back on whose piece someone else now has takes the first free one, and
# every dropdown greys out what the other active seats are using. A Disabled
# seat's dropdown is off and doesn't hold its piece.
func _refresh_markers() -> void:
	if marker_options.size() < type_options.size():
		return
	# Seats already in play keep their pieces; a seat just switched on whose
	# piece was taken meanwhile is the one that moves to a free piece.
	var order: Array[int] = []
	for i in marker_options.size():
		if _seat_active(i) and _was_active.has(i):
			order.append(i)
	for i in marker_options.size():
		if _seat_active(i) and not _was_active.has(i):
			order.append(i)
	var taken: Array[String] = []
	for i in order:
		var m: String = PlayerMarkers.selected(marker_options[i])
		if taken.has(m):
			for free in PlayerMarkers.LIST:
				if not taken.has(free):
					m = free
					break
			PlayerMarkers.select(marker_options[i], m)
		taken.append(m)
	_was_active.clear()
	for i in order:
		_was_active.append(i)
	for i in marker_options.size():
		var active: bool = _seat_active(i)
		marker_options[i].disabled = not active
		var others: Array[String] = []
		for j in marker_options.size():
			if j != i and _seat_active(j):
				others.append(PlayerMarkers.selected(marker_options[j]))
		PlayerMarkers.set_taken(marker_options[i], others)


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
	var picks: Array = []
	for i in marker_options.size():
		picks.append(PlayerMarkers.selected(marker_options[i]) if _seat_active(i) else "")
	GameState.player_markers = PlayerMarkers.make_unique(picks)
	GameState.expansions = expansion_picker.selected_ids()
	# The first human seat is this player; it takes their profile name.
	var overrides: Dictionary = {}
	for i in types.size():
		if types[i] == GameState.PlayerType.HUMAN:
			overrides[i] = Saves.get_player_name()
			break
	GameState.player_names = GameState.names_with(overrides)
	GameState.admin_mode = admin_checkbox.button_pressed
	GameState.quickstart_mode = quickstart_checkbox.button_pressed
	GameState.blitzstart_mode = blitzstart_checkbox.button_pressed
	GameState.tutorial_mode = false
	GameState.online = false
	GameState.hero_mode = hero_mode_checkbox.button_pressed
	GameState.player_heroes = ["", "", "", "", "", "", "", ""] as Array[String]
	# Hero Mode: everyone picks a hero first (hero_select starts the game).
	get_tree().change_scene_to_file("res://scenes/hero_select.tscn" if GameState.hero_mode else "res://scenes/main.tscn")


func _hero_mode_checkbox() -> CheckBox:
	var box := CheckBox.new()
	box.text = "Hero Mode"
	box.tooltip_text = "Before the game starts, each player chooses a Hero with special effects."
	box.add_theme_font_size_override("font_size", 24)
	return box
