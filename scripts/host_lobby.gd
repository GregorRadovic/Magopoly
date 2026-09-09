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

# Services that echo back the caller's public IP as plain text, tried in
# order until one returns a valid IPv4. The "Others join with" box is meant
# for a friend on a different network, so it shows this -- not the LAN address.
const PUBLIC_IP_SERVICES: Array[String] = [
	"https://api.ipify.org",
	"https://icanhazip.com",
	"https://ifconfig.me/ip",
]

# Kept across Host Game visits in one app run, so re-opening this screen
# fills the box instantly instead of looking the address up again.
static var _cached_public_ip: String = ""

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

# This machine's LAN address (for same-network friends), and the state of the
# public-IP lookup: "loading" -> "ok" (box shows the public IP) or "failed"
# (box falls back to the LAN address).
var _lan_ip: String = ""
var _public_ip_state: String = "loading"
var _ip_request: HTTPRequest
var _ip_service_index: int = 0


func _ready() -> void:
	Net.lobby_updated.connect(_refresh)

	back_button.pressed.connect(_on_back)
	copy_button.pressed.connect(_on_copy_pressed)
	start_button.pressed.connect(_on_start_pressed)

	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ip_request = HTTPRequest.new()
	_ip_request.timeout = 8.0
	_ip_request.request_completed.connect(_on_ip_request_completed)
	add_child(_ip_request)

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

	_lan_ip = _local_ip()
	if _cached_public_ip != "":
		_public_ip_state = "ok"
		address_value.text = _cached_public_ip
	else:
		_public_ip_state = "loading"
		address_value.text = "Looking up…"
		copy_button.disabled = true
		_request_next_ip_service()
	_refresh()


# --- Public-IP lookup --------------------------------------------------

func _request_next_ip_service() -> void:
	if _ip_service_index >= PUBLIC_IP_SERVICES.size():
		# Nothing reachable -- fall back to the LAN address (same-network only).
		_public_ip_state = "failed"
		address_value.text = _lan_ip
		copy_button.disabled = false
		_refresh()
		return
	var err: int = _ip_request.request(PUBLIC_IP_SERVICES[_ip_service_index])
	if err != OK:
		_ip_service_index += 1
		_request_next_ip_service()


func _on_ip_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var ip: String = body.get_string_from_utf8().strip_edges()
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and _is_ipv4(ip):
		_cached_public_ip = ip
		_public_ip_state = "ok"
		address_value.text = ip
		copy_button.disabled = false
		_refresh()
		return
	# That service was unreachable / gave something odd -- try the next one.
	_ip_service_index += 1
	_request_next_ip_service()


# True for "ddd.ddd.ddd.ddd" with every octet in 0..255.
func _is_ipv4(s: String) -> bool:
	var parts: PackedStringArray = s.split(".")
	if parts.size() != 4:
		return false
	for p in parts:
		if not p.is_valid_int() or int(p) < 0 or int(p) > 255:
			return false
	return true


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
	status_label.text = _address_help_text()


func _address_help_text() -> String:
	var lan_note: String = ""
	if _lan_ip != "" and _lan_ip != "your IP address":
		lan_note = " On the same network, join with %s instead." % _lan_ip
	var head: String
	match _public_ip_state:
		"loading":
			head = "Finding the address for players on other networks…"
		"failed":
			head = "Couldn't look up your public address — the box shows your local address (same-network play only)."
		_:
			head = "Players on another network join with the address above — you may need to forward UDP %d on your router." % Net.DEFAULT_PORT
	return "%s%s Start when your players have joined." % [head, lan_note]


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


# Best guess at this machine's LAN address, skipping loopback, IPv6, and the
# link-local 169.254.x addresses Windows auto-assigns to dead / unplugged
# adapters (Bluetooth PAN, Wi-Fi Direct, a disconnected Ethernet port) --
# those aren't routable and can't be joined.
func _local_ip() -> String:
	for addr in IP.get_local_addresses():
		if ":" in addr or addr.begins_with("127.") or addr.begins_with("169.254."):
			continue
		return addr
	return "your IP address"
