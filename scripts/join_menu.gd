extends Control

# Join menu: enter the host's IP and connect. Once connected, we wait here
# until the host starts the game -- Net._recv_start then swaps us into
# main.tscn. See net.gd.

@onready var address_edit: LineEdit = $VBox/AddressEdit
@onready var status_label: Label = $VBox/StatusLabel
@onready var join_button: Button = $VBox/ButtonRow/JoinButton
@onready var back_button: Button = $VBox/ButtonRow/BackButton

# Once we have a seat in the lobby: our playing piece. Picks go to the host
# (Net.pick_marker), which refuses one another seat already has.
var marker_row: HBoxContainer
var marker_option: OptionButton


func _ready() -> void:
	Net.join_succeeded.connect(_on_join_succeeded)
	Net.join_failed.connect(_on_join_failed)
	Net.kicked.connect(_on_kicked)

	Net.lobby_updated.connect(_refresh_marker)
	_build_marker_row()

	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back)
	address_edit.text_submitted.connect(func(_t): _on_join_pressed())

	# Pre-fill the last host we connected to, so reconnecting after a drop is
	# just Join Game -> Join.
	if Net.last_join_address != "":
		address_edit.text = Net.last_join_address
		status_label.text = "Reconnecting to a game in progress? Just press Join."

	# Start Menu -> Rejoin Game: the game we were in before the app closed.
	# Connect right away with the saved address (net.gd picks up the saved
	# reconnect token for it).
	if Saves.auto_rejoin:
		Saves.auto_rejoin = false
		var session: Dictionary = Saves.load_session()
		if not session.is_empty():
			address_edit.text = str(session["address"])
			_on_join_pressed()
			if join_button.disabled:
				status_label.text = "Rejoining your game at %s…" % session["address"]


func _build_marker_row() -> void:
	marker_row = HBoxContainer.new()
	marker_row.alignment = BoxContainer.ALIGNMENT_CENTER
	marker_row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = "Your marker:"
	label.add_theme_font_size_override("font_size", 24)
	marker_row.add_child(label)
	marker_option = PlayerMarkers.make_option(PlayerMarkers.LIST[0])
	marker_option.item_selected.connect(func(i: int) -> void: Net.pick_marker(PlayerMarkers.LIST[i]))
	marker_row.add_child(marker_option)
	marker_row.visible = false
	$VBox.add_child(marker_row)
	$VBox.move_child(marker_row, status_label.get_index() + 1)


func _refresh_marker() -> void:
	var slot: int = Net.my_slot()
	marker_row.visible = Net.online and not Net.hosting and not Net.game_started and slot > 0
	if not marker_row.visible:
		return
	PlayerMarkers.select(marker_option, Net.marker_picks[slot])
	PlayerMarkers.set_taken(marker_option, Net.markers_taken_by_others(slot))


func _on_join_pressed() -> void:
	var addr: String = address_edit.text.strip_edges()
	if addr == "":
		status_label.text = "Enter the host's IP address."
		return
	status_label.text = "Connecting to %s…" % addr
	if not Net.join_game(addr, Net.DEFAULT_PORT):
		status_label.text = "Couldn't start the client."
		return
	_set_busy(true)


func _on_join_succeeded() -> void:
	status_label.text = "Connected. Waiting for the host to start the game…"


func _on_join_failed(reason: String) -> void:
	status_label.text = reason
	if not Saves.load_session().is_empty():
		status_label.text += " If you're rejoining, the host may not have resumed the game yet -- try again in a moment."
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
