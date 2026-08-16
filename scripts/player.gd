extends Node2D

const RADIUS: float = 10.0
const STARTING_MONEY: int = 1500

var player_id: int = 0
var player_color: Color = Color.WHITE
var current_space: int = 0
var money: int = STARTING_MONEY
var in_jail: bool = false
var jail_turns_left: int = 0


func setup(id: int, color: Color) -> void:
	player_id = id
	player_color = color
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, player_color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color.BLACK, 2.0)
