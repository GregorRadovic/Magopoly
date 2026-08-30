extends Control

# Host lobby: opens a server on entry, lets the host configure the non-host
# seats (Open for a remote player / Computer / Disabled), and starts the game
# for everyone. Mirrors local_setup.gd's layout. See net.gd.

const KIND_LABELS: Array[String] = ["Open", "Computer", "Disabled"]
const KIND_VALUES: Array[int] = [Net.Slot.OPEN, Net.Slot.COMPUTER, Net.Slot.DISABLED]
const SLOT_COLORS: Array[Color] = [
	Color(0.929, 0.106, 0.141), Color(0.2, 0.4, 0.85), Color(0.2, 0.75, 0.3), Color(0.9, 0.8, 0.15),
	Color(0.6, 0.3, 0.8), Color(0.95, 0.55, 0.1), Color(0.15, 0.75, 0.8), Color(0.95, 0.45, 0.65),
]
# Players past this can't use BlitzStart (not enough properties / spell cards
# to deal everyone a full opening hand).
const BLITZSTART_MAX_PLAYERS: int = 4

@onready var status_label: Label = $VBox/StatusLabel
@onready var address_value: LineEdit = $VBox/AddressRow/AddressValue
@onready var copy_button: Button = $VBox/AddressRow/CopyButton
@onready var slots_box: VBoxContainer = $VBox/SlotsScroll/Slots
@onready var start_button: Button = $VBox/ButtonRow/StartButton
@onready var back_button: Button = $VBox/ButtonRow/BackButton
@onready var admin_checkbox: CheckBox = $VBox/OptionsRow/AdminModeCheckBox
@onready var quickstart_checkbox: CheckBox = $VBox/OptionsRow/QuickstartModeCheckBox
@onready var blitzstart_checkbox: CheckBox = $VBox/OptionsRow/BlitzstartModeCheckBox
@onready var blitzstart_limit_dialog: AcceptDialog = $BlitzStartLimitDialog

# Per slot: {status: Label, option: OptionButton}
var slot_widgets: Array[Dictionary] = []

var _host_ok: bool = false


func _ready() -> void:
	Net.lobby_updated.connect(_refresh)

	back_button.pressed.connect(_on_back)
	copy_button.pressed.connect(_on_copy_pressed)
	start_button.pressed.connect(_on_start_pressed)

	for i in Net.SLOT_COUNT:
		slot_widgets.append(_build_slot_row(i))

	Net.my_name = "Host"
	_host_ok = Net.host_game(Net.DEFAULT_PORT)
	if not _host_ok:
		status_label.text = "Couldn't start a server on port %d." % Net.DEFAULT_PORT
		start_button.disabled = true
		address_value.text = ""
		copy_button.disabled = true
		for w in slot_widgets:
			(w["option"] as OptionButton).disabled = true
		return
	address_value.text = _local_ip()
	_refresh()


func _build_slot_row(index: int) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	slots_box.add_child(row)

	var label := Label.new()
	label.custom_minimum_size = Vector2(150, 0)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", SLOT_COLORS[index])
	label.text = "Player %d" % (index + 1)
	row.add_child(label)

	var status := Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 22)
	status.text = "-"
	row.add_child(status)

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(220, 44)
	opt.add_theme_font_size_override("font_size", 20)
	if index == 0:
		opt.visible = false  # slot 0 is always the host
	else:
		for kind_label in KIND_LABELS:
			opt.add_item(kind_label)
		opt.item_selected.connect(_on_slot_kind_selected.bind(index))
	row.add_child(opt)

	return {"status": status, "option": opt}


func _refresh() -> void:
	if not _host_ok:
		return
	for i in slot_widgets.size():
		var kind: int = Net.slots[i]
		(slot_widgets[i]["status"] as Label).text = _slot_status_text(kind)
		if i == 0:
			continue
		var opt: OptionButton = slot_widgets[i]["option"]
		var editable: bool = kind != Net.Slot.TAKEN
		opt.disabled = not editable
		if editable:
			var sel: int = KIND_VALUES.find(kind)
			opt.selected = sel if sel != -1 else 0

	start_button.disabled = Net.active_slot_count() < 2
	status_label.text = "Port %d. Start when your players have joined." % Net.DEFAULT_PORT


func _on_start_pressed() -> void:
	if blitzstart_checkbox.button_pressed and Net.active_slot_count() > BLITZSTART_MAX_PLAYERS:
		blitzstart_limit_dialog.popup_centered()
		return
	Net.start_game(admin_checkbox.button_pressed, quickstart_checkbox.button_pressed,
		blitzstart_checkbox.button_pressed)


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(address_value.text)
	copy_button.text = "Copied!"
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(copy_button):
		copy_button.text = "Copy"


func _slot_status_text(kind: int) -> String:
	match kind:
		Net.Slot.HOST:
			return "You (host)"
		Net.Slot.TAKEN:
			return "Joined"
		Net.Slot.OPEN:
			return "Open — waiting for a player"
		Net.Slot.COMPUTER:
			return "Computer"
		Net.Slot.DISABLED:
			return "Disabled"
	return "-"


func _on_slot_kind_selected(choice: int, slot: int) -> void:
	Net.set_slot_kind(slot, KIND_VALUES[choice])


func _on_back() -> void:
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")


# Best guess at this machine's LAN address to show the host, skipping
# loopback and IPv6.
func _local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("127.") or ":" in addr:
			continue
		return addr
	return "your IP address"
