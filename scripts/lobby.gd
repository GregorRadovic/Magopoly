extends Control

# Online lobby: host opens a server or a client joins one by IP, the host
# configures the four player slots (its own, plus Open / Computer / Disabled),
# and Start Game hands every connected peer into main.tscn together. See net.gd.

const KIND_LABELS: Array[String] = ["Open", "Computer", "Disabled"]
const KIND_VALUES: Array[int] = [Net.Slot.OPEN, Net.Slot.COMPUTER, Net.Slot.DISABLED]
const SLOT_LABEL_COLORS: Array[Color] = [
	Color(0.929, 0.106, 0.141), Color(0.2, 0.4, 0.85),
	Color(0.2, 0.75, 0.3), Color(0.9, 0.8, 0.15),
]

@onready var name_edit: LineEdit = $VBox/NameRow/NameEdit
@onready var address_edit: LineEdit = $VBox/ConnectRow/AddressEdit
@onready var port_edit: LineEdit = $VBox/ConnectRow/PortEdit
@onready var host_button: Button = $VBox/ConnectRow/HostButton
@onready var join_button: Button = $VBox/ConnectRow/JoinButton
@onready var status_label: Label = $VBox/StatusLabel
@onready var admin_checkbox: CheckBox = $VBox/OptionsRow/AdminModeCheckBox
@onready var quickstart_checkbox: CheckBox = $VBox/OptionsRow/QuickstartModeCheckBox
@onready var back_button: Button = $VBox/ButtonRow/BackButton
@onready var start_button: Button = $VBox/ButtonRow/StartButton
@onready var slot_rows: Array[HBoxContainer] = [
	$VBox/Slots/SlotRow0, $VBox/Slots/SlotRow1, $VBox/Slots/SlotRow2, $VBox/Slots/SlotRow3,
]


func _ready() -> void:
	Net.lobby_updated.connect(_refresh)
	Net.join_succeeded.connect(_on_join_succeeded)
	Net.join_failed.connect(_on_join_failed)
	Net.kicked.connect(_on_kicked)

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)

	for i in slot_rows.size():
		var row: HBoxContainer = slot_rows[i]
		(row.get_node("Label") as Label).add_theme_color_override("font_color", SLOT_LABEL_COLORS[i])
		var opt: OptionButton = row.get_node("KindOption")
		for label in KIND_LABELS:
			opt.add_item(label)
		opt.item_selected.connect(_on_slot_kind_selected.bind(i))

	name_edit.text = Net.my_name
	port_edit.text = str(Net.DEFAULT_PORT)
	_refresh()


func _refresh() -> void:
	var idle: bool = not Net.online
	name_edit.editable = idle
	address_edit.editable = idle
	port_edit.editable = idle
	host_button.disabled = not idle
	join_button.disabled = not idle

	var can_config: bool = Net.hosting
	for i in slot_rows.size():
		var row: HBoxContainer = slot_rows[i]
		var kind: int = Net.slots[i]
		(row.get_node("Status") as Label).text = _slot_status_text(i, kind)
		var opt: OptionButton = row.get_node("KindOption")
		var editable: bool = can_config and i != 0 and kind != Net.Slot.TAKEN
		opt.visible = editable
		if editable:
			var sel: int = KIND_VALUES.find(kind)
			opt.selected = sel if sel != -1 else 0

	start_button.visible = Net.hosting
	start_button.disabled = Net.active_slot_count() < 2
	if status_label.text == "":
		status_label.text = _default_status_text()


func _slot_status_text(slot: int, kind: int) -> String:
	match kind:
		Net.Slot.HOST:
			return "Host — %s" % Net.peer_names.get(1, "Host")
		Net.Slot.TAKEN:
			return "Joined — %s" % Net.peer_names.get(Net.slot_peer[slot], "?")
		Net.Slot.OPEN:
			return "Open — waiting for a player"
		Net.Slot.COMPUTER:
			return "Computer"
		Net.Slot.DISABLED:
			return "Disabled"
	return "-"


func _default_status_text() -> String:
	if not Net.online:
		return "Host a game, or enter a host's IP and Join."
	if Net.hosting:
		return "Waiting for players. Start when ready."
	return "Connected. Waiting for the host to start."


func _on_host_pressed() -> void:
	Net.my_name = _name_or_default()
	status_label.text = ""
	if not Net.host_game(_port()):
		status_label.text = "Couldn't start a server on port %d." % _port()
	_refresh()


func _on_join_pressed() -> void:
	var addr: String = address_edit.text.strip_edges()
	if addr == "":
		status_label.text = "Enter the host's IP address to join."
		return
	Net.my_name = _name_or_default()
	status_label.text = "Connecting to %s…" % addr
	if not Net.join_game(addr, _port()):
		status_label.text = "Couldn't start the client."
	_refresh()


func _on_join_succeeded() -> void:
	status_label.text = "Connected. Waiting for the host to start."
	_refresh()


func _on_join_failed(reason: String) -> void:
	status_label.text = reason
	_refresh()


func _on_kicked(reason: String) -> void:
	status_label.text = reason
	_refresh()


func _on_slot_kind_selected(choice: int, slot: int) -> void:
	Net.set_slot_kind(slot, KIND_VALUES[choice])


func _on_start_pressed() -> void:
	Net.start_game(admin_checkbox.button_pressed, quickstart_checkbox.button_pressed)


func _on_back_pressed() -> void:
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")


func _name_or_default() -> String:
	var n: String = name_edit.text.strip_edges()
	return n if n != "" else "Player"


func _port() -> int:
	var p: int = int(port_edit.text)
	return p if p > 0 and p < 65536 else Net.DEFAULT_PORT
