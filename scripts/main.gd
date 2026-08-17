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
	Vector2(-20, -20),
	Vector2(20, -20),
	Vector2(-20, 20),
	Vector2(20, 20),
]
const JAIL_SPACE_INDEX: int = 10
const JAIL_SENTENCE_TURNS: int = 3
const DOUBLES_JAIL_THRESHOLD: int = 3

@onready var board: Node2D = $Board
@onready var players_container: Node2D = $Players
@onready var roll_button: Button = $UI/Panel/VBox/RollButton
@onready var admin_button: Button = $UI/Panel/VBox/AdminButton
@onready var turn_label: Label = $UI/Panel/VBox/TurnLabel
@onready var dice_label: Label = $UI/Panel/VBox/DiceLabel
@onready var number_prompt: PopupPanel = $UI/NumberPrompt
@onready var confirm_prompt: PopupPanel = $UI/ConfirmPrompt
@onready var quit_confirm_prompt: PopupPanel = $UI/QuitConfirmPrompt
@onready var info_prompt: PopupPanel = $UI/InfoPrompt
@onready var property_card: PopupPanel = $UI/PropertyCard
@onready var free_parking_label: Label = $UI/PlayersPanel/VBox/FreeParkingLabel
@onready var player_header_labels: Array[Label] = [
	$UI/PlayersPanel/VBox/Player0/HeaderLabel,
	$UI/PlayersPanel/VBox/Player1/HeaderLabel,
	$UI/PlayersPanel/VBox/Player2/HeaderLabel,
	$UI/PlayersPanel/VBox/Player3/HeaderLabel,
]
@onready var player_properties_labels: Array[Label] = [
	$UI/PlayersPanel/VBox/Player0/PropertiesLabel,
	$UI/PlayersPanel/VBox/Player1/PropertiesLabel,
	$UI/PlayersPanel/VBox/Player2/PropertiesLabel,
	$UI/PlayersPanel/VBox/Player3/PropertiesLabel,
]

var players: Array[Node2D] = []
var current_player: int = 0
var _admin_die1: int = 0
var free_parking_amount: int = 0
var _quit_prompt_open: bool = false


func _ready() -> void:
	_spawn_players()
	roll_button.pressed.connect(_on_roll_pressed)
	admin_button.pressed.connect(_on_admin_pressed)
	board.space_clicked.connect(_on_space_clicked)
	_update_turn_label()
	_update_player_panels()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _quit_prompt_open:
		_confirm_quit()


func _confirm_quit() -> void:
	_quit_prompt_open = true
	quit_confirm_prompt.open("Are you sure you want to quit?")
	var yes: bool = await quit_confirm_prompt.answered
	_quit_prompt_open = false
	if yes:
		get_tree().quit()


func _spawn_players() -> void:
	for i in PLAYER_COLORS.size():
		var player: Node2D = PLAYER_SCENE.instantiate()
		players_container.add_child(player)
		player.setup(i, PLAYER_COLORS[i])
		player.current_space = 0
		player.position = board.get_space_center(0) + MARKER_OFFSETS[i]
		players.append(player)
		player_header_labels[i].add_theme_color_override("font_color", PLAYER_COLORS[i])
		player_properties_labels[i].add_theme_color_override("font_color", PLAYER_COLORS[i])


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
	roll_button.disabled = true
	admin_button.disabled = true

	var roll: int = die1 + die2
	var is_double: bool = die1 == die2
	var player: Node2D = players[current_player]
	dice_label.text = "%s rolled: %d + %d = %d" % [_player_display_name(current_player), die1, die2, roll]

	var grants_extra_turn: bool = is_double

	if player.in_jail:
		if is_double:
			player.in_jail = false
			player.consecutive_doubles = 0
			dice_label.text += "\nRolled doubles! Released from Jail."
			grants_extra_turn = false
			await _move_player(player, roll)
		else:
			player.jail_turns_left -= 1
			if player.jail_turns_left <= 0:
				player.money -= 50
				free_parking_amount += 50
				player.in_jail = false
				dice_label.text += "\nSentence served, paid $50 to Free Parking."
			else:
				dice_label.text += "\nStill in Jail. %d turn(s) left." % player.jail_turns_left
	else:
		player.consecutive_doubles = (player.consecutive_doubles + 1) if is_double else 0

		if player.consecutive_doubles >= DOUBLES_JAIL_THRESHOLD:
			_send_to_jail(player)
			dice_label.text += "\nRolled doubles %d times in a row! Sent to Jail." % DOUBLES_JAIL_THRESHOLD
			grants_extra_turn = false
		elif await _move_player(player, roll):
			grants_extra_turn = false

	if grants_extra_turn:
		dice_label.text += "\nExtra turn!"
	else:
		current_player = (current_player + 1) % players.size()
	_update_turn_label()
	_update_player_panels()

	roll_button.disabled = false
	admin_button.disabled = false


# Returns true if this move sent the player to Jail (which cancels any
# doubles-triggered extra turn).
func _move_player(player: Node2D, roll: int) -> bool:
	var new_space_raw: int = player.current_space + roll
	var passed_go: bool = new_space_raw >= board.TOTAL_SPACES
	if passed_go:
		player.money += 200
		dice_label.text += "\nYou passed Go! (+200 Money)"

	player.current_space = new_space_raw % board.TOTAL_SPACES
	player.position = board.get_space_center(player.current_space) + MARKER_OFFSETS[player.player_id]

	var landed_info: Dictionary = board.get_space_info(player.current_space)
	if landed_info.get("type", "") == "tax":
		var tax_value: int = landed_info.get("value", 0)
		player.money -= tax_value
		free_parking_amount += tax_value
		dice_label.text += "\nLanded on %s! -%d Money (added to Free Parking)" % [landed_info.get("name", ""), tax_value]
	elif landed_info.get("type", "") == "free_parking":
		if free_parking_amount > 0:
			player.money += free_parking_amount
			dice_label.text += "\nLanded on Free Parking! +%d Money" % free_parking_amount
			free_parking_amount = 0
		else:
			dice_label.text += "\nLanded on Free Parking!"
	elif landed_info.get("type", "") == "go_to_jail":
		_send_to_jail(player)
		dice_label.text += "\nLanded on Go To Jail! Sent to Jail."
		return true
	elif landed_info.get("type", "") == "property":
		var space: Node2D = board.spaces[player.current_space]
		var property_name: String = landed_info.get("name", "")
		var price: int = landed_info.get("price", 0)
		if space.owner_id == -1:
			dice_label.text += "\nLanded on %s ($%d)." % [property_name, price]
			var wants_to_buy: bool = await _ask_buy_property(property_name, price)
			if wants_to_buy:
				player.money -= price
				space.owner_id = player.player_id
				player.owned_properties.append({"name": property_name, "price": price})
				dice_label.text += "\nBought %s for $%d!" % [property_name, price]
			else:
				dice_label.text += "\nDeclined to buy %s." % property_name
		elif space.owner_id != player.player_id:
			var color_name: String = landed_info.get("color", "")
			var rents: Array = landed_info.get("rents", [])
			var rent_amount: int = 0
			var note: String = ""
			var charged: bool = false

			if color_name == "railroad" and not rents.is_empty():
				var owned_railroads: int = _count_owned_in_group(space.owner_id, "railroad")
				var tier: int = clampi(owned_railroads, 1, rents.size()) - 1
				rent_amount = rents[tier]
				note = " (%d railroad%s owned)" % [owned_railroads, "" if owned_railroads == 1 else "s"]
				charged = true
			elif color_name == "utility":
				var multipliers: Array = landed_info.get("rent_multipliers", [])
				if not multipliers.is_empty():
					var owned_utilities: int = _count_owned_in_group(space.owner_id, "utility")
					var multiplier_tier: int = clampi(owned_utilities, 1, multipliers.size()) - 1
					var multiplier: int = multipliers[multiplier_tier]
					rent_amount = multiplier * roll
					var utility_word: String = "utility" if owned_utilities == 1 else "utilities"
					note = " (%d %s owned, %dx dice roll of %d)" % [owned_utilities, utility_word, multiplier, roll]
					charged = true
			elif not rents.is_empty():
				rent_amount = rents[0]
				if _owns_full_color_group(space.owner_id, color_name):
					rent_amount *= 2
					note = " (monopoly, doubled)"
				charged = true

			if charged:
				var owner: Node2D = players[space.owner_id]
				player.money -= rent_amount
				owner.money += rent_amount
				dice_label.text += "\nLanded on %s (owned by %s)! Paid $%d rent%s." % [property_name, PLAYER_NAMES[space.owner_id], rent_amount, note]

	return false


func _ask_buy_property(property_name: String, price: int) -> bool:
	confirm_prompt.open("Buy %s for $%d?" % [property_name, price])
	var yes: bool = await confirm_prompt.answered
	return yes


func _owns_full_color_group(player_id: int, color_name: String) -> bool:
	if color_name == "":
		return false
	var group: Array = board.get_color_group(color_name)
	for space_index in group:
		if board.spaces[space_index].owner_id != player_id:
			return false
	return true


func _count_owned_in_group(player_id: int, color_name: String) -> int:
	var group: Array = board.get_color_group(color_name)
	var count: int = 0
	for space_index in group:
		if board.spaces[space_index].owner_id == player_id:
			count += 1
	return count


func _on_space_clicked(index: int) -> void:
	var info: Dictionary = board.get_space_info(index)
	var color_name: String = info.get("color", "")

	# Standard color-group properties get the visual card; railroads,
	# utilities, and everything else fall back to the plain text popup,
	# since their rent structures don't fit the 6-tier house-rent card.
	if info.has("rents") and color_name != "railroad" and color_name != "utility":
		var header_color: Color = board.COLOR_GROUP_COLORS.get(color_name, Color.GRAY)
		var house_cost: int = board.HOUSE_COSTS_BY_COLOR.get(color_name, 0)
		property_card.show_card(info.get("name", ""), header_color, info["rents"], house_cost)
		return

	var space_name: String = info.get("name", "Space %d" % index)
	var lines: Array[String] = [space_name]
	if info.has("price"):
		lines.append("Cost: $%d" % info["price"])
	if color_name == "railroad" and info.has("rents"):
		var rents: Array = info["rents"]
		for i in rents.size():
			var railroad_count: int = i + 1
			lines.append("%d Railroad%s: $%d" % [railroad_count, "" if railroad_count == 1 else "s", rents[i]])
	elif color_name == "utility" and info.has("rent_multipliers"):
		var multipliers: Array = info["rent_multipliers"]
		for i in multipliers.size():
			var utility_count: int = i + 1
			lines.append("%d Utilit%s: %dx dice roll" % [utility_count, "y" if utility_count == 1 else "ies", multipliers[i]])
	info_prompt.open("\n".join(lines))


func _send_to_jail(player: Node2D) -> void:
	player.current_space = JAIL_SPACE_INDEX
	player.position = board.get_space_center(JAIL_SPACE_INDEX) + MARKER_OFFSETS[player.player_id]
	player.in_jail = true
	player.jail_turns_left = JAIL_SENTENCE_TURNS
	player.consecutive_doubles = 0


func _update_turn_label() -> void:
	turn_label.text = "%s's turn" % _player_display_name(current_player)


func _player_display_name(index: int) -> String:
	var player: Node2D = players[index]
	if not player.in_jail:
		return PLAYER_NAMES[index]
	var turn_word: String = "turn" if player.jail_turns_left == 1 else "turns"
	return "%s (In Jail, %d %s left)" % [PLAYER_NAMES[index], player.jail_turns_left, turn_word]


func _update_player_panels() -> void:
	free_parking_label.text = "Free Parking: $%d" % free_parking_amount
	for i in players.size():
		player_header_labels[i].text = "%s -- $%d" % [_player_display_name(i), players[i].money]

		var owned: Array[Dictionary] = players[i].owned_properties
		var properties_summary: String = "(none)"
		if not owned.is_empty():
			var entries: Array[String] = []
			for card in owned:
				entries.append("%s ($%d)" % [card["name"], card["price"]])
			properties_summary = ", ".join(entries)
		player_properties_labels[i].text = "Properties: %s" % properties_summary
