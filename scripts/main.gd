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
@onready var turn_label: Label = $UI/Panel/VBox/TurnLabel
@onready var dice_label: Label = $UI/Panel/VBox/DiceLabel

var players: Array[Node2D] = []
var current_player: int = 0


func _ready() -> void:
	_spawn_players()
	roll_button.pressed.connect(_on_roll_pressed)
	_update_turn_label()


func _spawn_players() -> void:
	for i in PLAYER_COLORS.size():
		var player: Node2D = PLAYER_SCENE.instantiate()
		players_container.add_child(player)
		player.setup(i, PLAYER_COLORS[i])
		player.current_space = 0
		player.position = board.get_space_center(0) + MARKER_OFFSETS[i]
		players.append(player)


func _on_roll_pressed() -> void:
	var die1: int = randi_range(1, 6)
	var die2: int = randi_range(1, 6)
	var roll: int = die1 + die2
	var is_double: bool = die1 == die2
	var player: Node2D = players[current_player]
	dice_label.text = "%s rolled: %d + %d = %d" % [PLAYER_NAMES[current_player], die1, die2, roll]

	var new_space_raw: int = player.current_space + roll
	var passed_go: bool = new_space_raw >= board.TOTAL_SPACES
	if passed_go:
		dice_label.text += "\nYou passed Go!"
	if is_double:
		dice_label.text += "\nExtra turn!"

	player.current_space = new_space_raw % board.TOTAL_SPACES
	player.position = board.get_space_center(player.current_space) + MARKER_OFFSETS[current_player]

	if not is_double:
		current_player = (current_player + 1) % players.size()
	_update_turn_label()


func _update_turn_label() -> void:
	turn_label.text = "%s's turn" % PLAYER_NAMES[current_player]
