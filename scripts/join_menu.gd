extends Control

# Join menu: enter the host's IP and connect. Once connected, we wait here
# until the host starts the game -- Net._recv_start then swaps us into
# main.tscn. See net.gd.

@onready var address_edit: LineEdit = $VBox/AddressEdit
@onready var status_label: Label = $VBox/StatusLabel
@onready var join_button: Button = $VBox/ButtonRow/JoinButton
@onready var back_button: Button = $VBox/ButtonRow/BackButton


func _ready() -> void:
	Net.join_succeeded.connect(_on_join_succeeded)
	Net.join_failed.connect(_on_join_failed)
	Net.kicked.connect(_on_kicked)

	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back)
	address_edit.text_submitted.connect(func(_t): _on_join_pressed())


func _on_join_pressed() -> void:
	var addr: String = address_edit.text.strip_edges()
	if addr == "":
		status_label.text = "Enter the host's IP address."
		return
	Net.my_name = "Player"
	status_label.text = "Connecting to %s…" % addr
	if not Net.join_game(addr, Net.DEFAULT_PORT):
		status_label.text = "Couldn't start the client."
		return
	_set_busy(true)


func _on_join_succeeded() -> void:
	status_label.text = "Connected. Waiting for the host to start the game…"


func _on_join_failed(reason: String) -> void:
	status_label.text = reason
	_set_busy(false)


func _on_kicked(reason: String) -> void:
	status_label.text = reason
	_set_busy(false)


func _on_back() -> void:
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")


func _set_busy(busy: bool) -> void:
	join_button.disabled = busy
	address_edit.editable = not busy
