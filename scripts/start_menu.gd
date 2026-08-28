extends Control

# The top-level launcher: pick a game mode, or quit. Each mode opens its own
# setup screen (local_setup / host_lobby / join_menu).

@onready var local_game_button: Button = $VBox/Buttons/LocalGameButton
@onready var host_game_button: Button = $VBox/Buttons/HostGameButton
@onready var join_game_button: Button = $VBox/Buttons/JoinGameButton
@onready var quit_button: Button = $VBox/Buttons/QuitButton


func _ready() -> void:
	# Coming back here means any previous online session is over.
	Net.leave()
	local_game_button.pressed.connect(func(): _go("res://scenes/local_setup.tscn"))
	host_game_button.pressed.connect(func(): _go("res://scenes/host_lobby.tscn"))
	join_game_button.pressed.connect(func(): _go("res://scenes/join_menu.tscn"))
	quit_button.pressed.connect(get_tree().quit)


func _go(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
