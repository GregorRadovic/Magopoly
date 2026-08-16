extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

const PLAYER_COLORS: Array[Color] = [
	Color(0.85, 0.2, 0.2),
	Color(0.2, 0.4, 0.85),
	Color(0.2, 0.75, 0.3),
	Color(0.9, 0.8, 0.15),
]
const PLAYER_NAMES: Array[String] = ["Player 1", "Player 2", "Player 3", "Player 4"]
const MARKER_OFFSETS: Array[Vector2] = [
	Vector2(-14, -14),
	Vector2(14, -14),
	Vector2(-14, 14),
	Vector2(14, 14),
]

@onready var board: Node2D = $Board
@onready var players_container: Node2D = $Players
@onready var roll_button: Button = $UI/Panel/VBox/RollButton
@onready var admin_button: Button = $UI/Panel/VBox/AdminButton
@onready var turn_label: Label = $UI/Panel/VBox/TurnLabel
@onready var dice_label: Label = $UI/Panel/VBox/DiceLabel
@onready var number_prompt: PopupPanel = $UI/NumberPrompt
@onready var money_labels: Array[Label] = [
	$UI/MoneyPanel/VBox/Player0Money,
	$UI/MoneyPanel/VBox/Player1Money,
	$UI/MoneyPanel/VBox/Player2Money,
	$UI/MoneyPanel/VBox/Player3Money,
]

var players: Array[Node2D] = []
var current_player: int = 0
var _admin_die1: int = 0


func _ready() -> void:
	_spawn_players()
	roll_button.pressed.connect(_on_roll_pressed)
	admin_button.pressed.connect(_on_admin_pressed)
	_update_turn_label()
	_update_money_labels()


func _spawn_players() -> void:
	for i in PLAYER_COLORS.size():
		var player: Node2D = PLAYER_SCENE.instantiate()
		players_container.add_child(player)
		player.setup(i, PLAYER_COLORS[i])
		player.current_space = 0
		player.position = board.get_space_center(0) + MARKER_OFFSETS[i]
		players.append(player)
		money_labels[i].add_theme_color_override("font_color", PLAYER_COLORS[i])


func _on_roll_pressed() -> void:
	var die1: int = randi_range(1, 6)
	var die2: int = randi_range(1, 6)
	_perform_roll(die1, die2)


func _on_admin_pressed() -> void:
	roll_button.disabled = true
	admin_button.disabled = true
	number_prompt.value_confirmed.connect(_on_admin_die1_entered, CONNECT_ONE_SHOT)
	number_prompt.open("Enter first dice value:")


func _on_admin_die1_entered(value: int) -> void:
	_admin_die1 = value
	number_prompt.value_confirmed.connect(_on_admin_die2_entered, CONNECT_ONE_SHOT)
	# Deferred: this handler runs while the first popup's own OK button is
	# still processing its "pressed" event, so reopening the popup here
	# immediately (same call frame) silently fails to show it.
	number_prompt.call_deferred("open", "Enter second dice value:")


func _on_admin_die2_entered(value: int) -> void:
	roll_button.disabled = false
	admin_button.disabled = false
	_perform_roll(_admin_die1, value)


func _perform_roll(die1: int, die2: int) -> void:
	var roll: int = die1 + die2
	var is_double: bool = die1 == die2
	var player: Node2D = players[current_player]
	dice_label.text = "%s rolled: %d + %d = %d" % [PLAYER_NAMES[current_player], die1, die2, roll]

	var new_space_raw: int = player.current_space + roll
	var passed_go: bool = new_space_raw >= board.TOTAL_SPACES
	if passed_go:
		player.money += 200
		dice_label.text += "\nYou passed Go! (+200 Money)"
	if is_double:
		dice_label.text += "\nExtra turn!"

	player.current_space = new_space_raw % board.TOTAL_SPACES
	player.position = board.get_space_center(player.current_space) + MARKER_OFFSETS[current_player]

	var landed_info: Dictionary = board.get_space_info(player.current_space)
	if landed_info.get("type", "") == "tax":
		var tax_value: int = landed_info.get("value", 0)
		player.money -= tax_value
		dice_label.text += "\nLanded on %s! -%d Money" % [landed_info.get("name", ""), tax_value]

	if not is_double:
		current_player = (current_player + 1) % players.size()
	_update_turn_label()
	_update_money_labels()


func _update_turn_label() -> void:
	turn_label.text = "%s's turn" % PLAYER_NAMES[current_player]


func _update_money_labels() -> void:
	for i in players.size():
		money_labels[i].text = "%s: $%d" % [PLAYER_NAMES[i], players[i].money]
