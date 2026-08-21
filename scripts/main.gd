extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const MINI_CARD_SCENE: PackedScene = preload("res://scenes/mini_property_card.tscn")

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
const PROPERTY_COLOR_ORDER: Array[String] = [
	"brown", "sky_blue", "pink", "orange", "red", "yellow", "green", "ocean_blue", "railroad", "utility",
]

@onready var board: Node2D = $Board
@onready var players_container: Node2D = $Players
@onready var roll_button: Button = $UI/Panel/VBox/RollButton
@onready var admin_button: Button = $UI/Panel/VBox/AdminButton
@onready var admin_properties_button: Button = $UI/Panel/VBox/AdminPropertiesButton
@onready var buy_house_unmortgage_button: Button = $UI/Panel/VBox/BuyHouseUnmortgageButton
@onready var sell_house_mortgage_button: Button = $UI/Panel/VBox/SellHouseMortgageButton
@onready var turn_label: Label = $UI/Panel/VBox/TurnLabel
@onready var dice_label: Label = $UI/Panel/VBox/DiceLabel
@onready var number_prompt: PopupPanel = $UI/NumberPrompt
@onready var confirm_prompt: PopupPanel = $UI/ConfirmPrompt
@onready var quit_confirm_prompt: PopupPanel = $UI/QuitConfirmPrompt
@onready var info_prompt: PopupPanel = $UI/InfoPrompt
@onready var property_card: PopupPanel = $UI/PropertyCard
@onready var asset_card: PopupPanel = $UI/AssetCard
@onready var free_parking_label: Label = $UI/PlayersPanel/VBox/FreeParkingLabel
@onready var player_header_labels: Array[Label] = [
	$UI/PlayersPanel/VBox/Player0/HeaderLabel,
	$UI/PlayersPanel/VBox/Player1/HeaderLabel,
	$UI/PlayersPanel/VBox/Player2/HeaderLabel,
	$UI/PlayersPanel/VBox/Player3/HeaderLabel,
]
@onready var player_properties_flows: Array[HFlowContainer] = [
	$UI/PlayersPanel/VBox/Player0/PropertiesFlow,
	$UI/PlayersPanel/VBox/Player1/PropertiesFlow,
	$UI/PlayersPanel/VBox/Player2/PropertiesFlow,
	$UI/PlayersPanel/VBox/Player3/PropertiesFlow,
]

var players: Array[Node2D] = []
var current_player: int = 0
var _admin_die1: int = 0
var free_parking_amount: int = 0
var _quit_prompt_open: bool = false
var _admin_picking_property: bool = false
var _buying_house_or_unmortgaging: bool = false
var _selling_house_or_mortgaging: bool = false


func _ready() -> void:
	_spawn_players()
	roll_button.pressed.connect(_on_roll_pressed)
	admin_button.pressed.connect(_on_admin_pressed)
	admin_properties_button.pressed.connect(_on_admin_properties_pressed)
	buy_house_unmortgage_button.pressed.connect(_on_buy_house_unmortgage_pressed)
	sell_house_mortgage_button.pressed.connect(_on_sell_house_mortgage_pressed)
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


func _on_roll_pressed() -> void:
	var die1: int = randi_range(1, 6)
	var die2: int = randi_range(1, 6)
	_perform_roll(die1, die2)


func _on_admin_pressed() -> void:
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true
	number_prompt.value_confirmed.connect(_on_admin_die1_entered, CONNECT_ONE_SHOT)
	number_prompt.cancelled.connect(_on_admin_number_prompt_cancelled, CONNECT_ONE_SHOT)
	number_prompt.open("Enter first dice value:")


func _on_admin_die1_entered(value: int) -> void:
	if number_prompt.cancelled.is_connected(_on_admin_number_prompt_cancelled):
		number_prompt.cancelled.disconnect(_on_admin_number_prompt_cancelled)
	_admin_die1 = value
	number_prompt.value_confirmed.connect(_on_admin_die2_entered, CONNECT_ONE_SHOT)
	number_prompt.cancelled.connect(_on_admin_number_prompt_cancelled, CONNECT_ONE_SHOT)
	# Deferred: this handler runs while the first popup's own OK button is
	# still processing its "pressed" event, so reopening the popup here
	# immediately (same call frame) silently fails to show it.
	number_prompt.call_deferred("open", "Enter second dice value:")


func _on_admin_die2_entered(value: int) -> void:
	if number_prompt.cancelled.is_connected(_on_admin_number_prompt_cancelled):
		number_prompt.cancelled.disconnect(_on_admin_number_prompt_cancelled)
	roll_button.disabled = false
	admin_button.disabled = false
	admin_properties_button.disabled = false
	buy_house_unmortgage_button.disabled = false
	sell_house_mortgage_button.disabled = false
	_perform_roll(_admin_die1, value)


func _on_admin_number_prompt_cancelled() -> void:
	# The number prompt was dismissed without a value being confirmed (e.g.
	# the player clicked a board tile behind it instead of Confirm). Clean
	# up whichever one-shot connection was still pending so it can't fire
	# later on an unrelated prompt use, and unlock the dice buttons.
	if number_prompt.value_confirmed.is_connected(_on_admin_die1_entered):
		number_prompt.value_confirmed.disconnect(_on_admin_die1_entered)
	if number_prompt.value_confirmed.is_connected(_on_admin_die2_entered):
		number_prompt.value_confirmed.disconnect(_on_admin_die2_entered)
	roll_button.disabled = false
	admin_button.disabled = false
	admin_properties_button.disabled = false
	buy_house_unmortgage_button.disabled = false
	sell_house_mortgage_button.disabled = false


func _on_admin_properties_pressed() -> void:
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true
	# Armed immediately (not after awaiting the popup's close signal): a
	# player clicking a tile directly, per the popup's own instruction,
	# dismisses the popup via Godot's default outside-click behavior
	# without ever emitting "closed", which used to leave pick mode
	# unarmed and the buttons disabled forever.
	_admin_picking_property = true
	info_prompt.open("Click the property you want to gain.")


func _admin_assign_property(index: int) -> void:
	var info: Dictionary = board.get_space_info(index)
	if info.get("type", "") != "property":
		dice_label.text = "Space %d is not a property." % index
	else:
		var space: Node2D = board.spaces[index]
		if space.owner_id != -1:
			players[space.owner_id].owned_property_indices.erase(index)

		var player: Node2D = players[current_player]
		space.owner_id = player.player_id
		space.house_count = 0
		space.is_mortgaged = false
		player.owned_property_indices.append(index)
		_sort_owned_properties(player)
		dice_label.text = "%s is now the admin-assigned owner of %s." % [_player_display_name(current_player), info.get("name", "")]
		_update_player_panels()

	roll_button.disabled = false
	admin_button.disabled = false
	admin_properties_button.disabled = false
	buy_house_unmortgage_button.disabled = false
	sell_house_mortgage_button.disabled = false


func _on_buy_house_unmortgage_pressed() -> void:
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true
	# Armed immediately, same as Admin Properties: clicking a tile directly
	# dismisses the popup via Godot's default outside-click behavior without
	# emitting "closed", so pick mode can't be left waiting on that signal.
	_buying_house_or_unmortgaging = true
	info_prompt.open("Click a property to build a house on it, or to unmortgage it if it's mortgaged.")


# Dispatches to unmortgaging or house-building depending on the clicked
# property's current mortgage status, per the combined button's behavior.
func _buy_house_or_unmortgage(index: int) -> void:
	var space: Node2D = board.spaces[index]
	if space.is_mortgaged:
		_unmortgage_property(index)
	else:
		_buy_house(index)


func _buy_house(index: int) -> void:
	var info: Dictionary = board.get_space_info(index)
	var color_name: String = info.get("color", "")
	var space: Node2D = board.spaces[index]
	var player: Node2D = players[current_player]
	var house_cost: int = board.HOUSE_COSTS_BY_COLOR.get(color_name, 0)
	var property_name: String = info.get("name", "")

	if info.get("type", "") != "property" or not board.HOUSE_COSTS_BY_COLOR.has(color_name):
		dice_label.text = "You can't build houses on that space."
	elif space.owner_id != player.player_id:
		dice_label.text = "You don't own %s." % property_name
	elif _group_has_mortgaged(color_name):
		dice_label.text = "You can't build houses on %s while a property in its color set is mortgaged." % property_name
	elif not _owns_full_color_group(player.player_id, color_name):
		dice_label.text = "You need the full color set to build a house on %s." % property_name
	elif space.house_count >= 5:
		dice_label.text = "%s already has the maximum of 5 houses." % property_name
	elif space.house_count > _min_houses_in_group(color_name):
		dice_label.text = "You must build evenly -- other properties in the color set have fewer houses than %s." % property_name
	elif player.money < house_cost:
		dice_label.text = "%s can't afford a house on %s ($%d)." % [_player_display_name(current_player), property_name, house_cost]
	else:
		player.money -= house_cost
		space.house_count += 1
		var house_word: String = "house" if space.house_count == 1 else "houses"
		dice_label.text = "%s built a house on %s for $%d (now %d %s)." % [_player_display_name(current_player), property_name, house_cost, space.house_count, house_word]
		_update_player_panels()

	roll_button.disabled = false
	admin_button.disabled = false
	admin_properties_button.disabled = false
	buy_house_unmortgage_button.disabled = false
	sell_house_mortgage_button.disabled = false


# The minimum house count among all properties in a color group, used to
# enforce even building: a property can only gain a house while it's tied
# for the fewest houses in its group.
func _min_houses_in_group(color_name: String) -> int:
	var group: Array = board.get_color_group(color_name)
	var min_houses: int = 5
	for space_index in group:
		min_houses = mini(min_houses, board.spaces[space_index].house_count)
	return min_houses


func _on_sell_house_mortgage_pressed() -> void:
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true
	# Armed immediately, same reasoning as Buy House / Admin Properties.
	_selling_house_or_mortgaging = true
	info_prompt.open("Click a property to sell a house from it, or to mortgage it if it has no houses.")


# Dispatches to house-selling or mortgaging depending on whether the clicked
# property currently has any houses, per the combined button's behavior.
func _sell_house_or_mortgage(index: int) -> void:
	var space: Node2D = board.spaces[index]
	if space.house_count > 0:
		_sell_house(index)
	else:
		_mortgage_property(index)


func _sell_house(index: int) -> void:
	var info: Dictionary = board.get_space_info(index)
	var color_name: String = info.get("color", "")
	var space: Node2D = board.spaces[index]
	var player: Node2D = players[current_player]
	var house_cost: int = board.HOUSE_COSTS_BY_COLOR.get(color_name, 0)
	var property_name: String = info.get("name", "")
	var sale_price: int = house_cost / 2

	if info.get("type", "") != "property" or not board.HOUSE_COSTS_BY_COLOR.has(color_name):
		dice_label.text = "That space doesn't have houses to sell."
	elif space.owner_id != player.player_id:
		dice_label.text = "You don't own %s." % property_name
	elif space.house_count <= 0:
		dice_label.text = "%s has no houses to sell." % property_name
	elif space.house_count < _max_houses_in_group(color_name):
		dice_label.text = "You must sell evenly -- other properties in the color set have more houses than %s." % property_name
	else:
		space.house_count -= 1
		player.money += sale_price
		var house_word: String = "house" if space.house_count == 1 else "houses"
		dice_label.text = "%s sold a house on %s for $%d (now %d %s)." % [_player_display_name(current_player), property_name, sale_price, space.house_count, house_word]
		_update_player_panels()

	roll_button.disabled = false
	admin_button.disabled = false
	admin_properties_button.disabled = false
	buy_house_unmortgage_button.disabled = false
	sell_house_mortgage_button.disabled = false


# The maximum house count among all properties in a color group, used to
# enforce even selling: a property can only lose a house while it's tied
# for the most houses in its group.
func _max_houses_in_group(color_name: String) -> int:
	var group: Array = board.get_color_group(color_name)
	var max_houses: int = 0
	for space_index in group:
		max_houses = maxi(max_houses, board.spaces[space_index].house_count)
	return max_houses


func _group_has_mortgaged(color_name: String) -> bool:
	var group: Array = board.get_color_group(color_name)
	for space_index in group:
		if board.spaces[space_index].is_mortgaged:
			return true
	return false


func _mortgage_property(index: int) -> void:
	var info: Dictionary = board.get_space_info(index)
	var color_name: String = info.get("color", "")
	var space: Node2D = board.spaces[index]
	var player: Node2D = players[current_player]
	var property_name: String = info.get("name", "")
	var mortgage_value: int = _mortgage_value(info.get("price", 0))

	if info.get("type", "") != "property":
		dice_label.text = "That space can't be mortgaged."
	elif space.owner_id != player.player_id:
		dice_label.text = "You don't own %s." % property_name
	elif space.is_mortgaged:
		dice_label.text = "%s is already mortgaged." % property_name
	elif _max_houses_in_group(color_name) > 0:
		dice_label.text = "You can't mortgage %s while its color set has houses." % property_name
	else:
		space.is_mortgaged = true
		player.money += mortgage_value
		dice_label.text = "%s mortgaged %s for $%d." % [_player_display_name(current_player), property_name, mortgage_value]
		_update_player_panels()

	roll_button.disabled = false
	admin_button.disabled = false
	admin_properties_button.disabled = false
	buy_house_unmortgage_button.disabled = false
	sell_house_mortgage_button.disabled = false


func _unmortgage_property(index: int) -> void:
	var info: Dictionary = board.get_space_info(index)
	var space: Node2D = board.spaces[index]
	var player: Node2D = players[current_player]
	var property_name: String = info.get("name", "")
	var unmortgage_value: int = _unmortgage_value(info.get("price", 0))

	if info.get("type", "") != "property":
		dice_label.text = "That space can't be unmortgaged."
	elif space.owner_id != player.player_id:
		dice_label.text = "You don't own %s." % property_name
	elif not space.is_mortgaged:
		dice_label.text = "%s isn't mortgaged." % property_name
	elif player.money < unmortgage_value:
		dice_label.text = "%s can't afford to unmortgage %s ($%d)." % [_player_display_name(current_player), property_name, unmortgage_value]
	else:
		space.is_mortgaged = false
		player.money -= unmortgage_value
		dice_label.text = "%s unmortgaged %s for $%d." % [_player_display_name(current_player), property_name, unmortgage_value]
		_update_player_panels()

	roll_button.disabled = false
	admin_button.disabled = false
	admin_properties_button.disabled = false
	buy_house_unmortgage_button.disabled = false
	sell_house_mortgage_button.disabled = false


func _perform_roll(die1: int, die2: int) -> void:
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true

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
	admin_properties_button.disabled = false
	buy_house_unmortgage_button.disabled = false
	sell_house_mortgage_button.disabled = false


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
				player.owned_property_indices.append(player.current_space)
				_sort_owned_properties(player)
				dice_label.text += "\nBought %s for $%d!" % [property_name, price]
			else:
				dice_label.text += "\nDeclined to buy %s." % property_name
		elif space.owner_id != player.player_id and space.is_mortgaged:
			dice_label.text += "\nLanded on %s (owned by %s, mortgaged)! No rent owed." % [property_name, PLAYER_NAMES[space.owner_id]]
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
				if space.house_count > 0:
					rent_amount = rents[space.house_count]
					note = " (%d house%s)" % [space.house_count, "" if space.house_count == 1 else "s"]
				else:
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


func _sort_owned_properties(player: Node2D) -> void:
	player.owned_property_indices.sort_custom(_compare_property_order)


# Orders by color group (per PROPERTY_COLOR_ORDER), then by board index
# within a group. Unlisted colors (shouldn't happen -- only owned property
# spaces get sorted) fall to the end rather than crashing on find()'s -1.
func _compare_property_order(a: int, b: int) -> bool:
	var color_a: String = board.get_space_info(a).get("color", "")
	var color_b: String = board.get_space_info(b).get("color", "")
	var rank_a: int = PROPERTY_COLOR_ORDER.find(color_a)
	var rank_b: int = PROPERTY_COLOR_ORDER.find(color_b)
	if rank_a == -1:
		rank_a = PROPERTY_COLOR_ORDER.size()
	if rank_b == -1:
		rank_b = PROPERTY_COLOR_ORDER.size()
	if rank_a != rank_b:
		return rank_a < rank_b
	return a < b


func _mortgage_value(price: int) -> int:
	return price / 2


func _unmortgage_value(price: int) -> int:
	return roundi(price * 0.55)


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
	if _buying_house_or_unmortgaging:
		_buying_house_or_unmortgaging = false
		if info_prompt.visible:
			info_prompt.hide()
		_buy_house_or_unmortgage(index)
		return

	if _selling_house_or_mortgaging:
		_selling_house_or_mortgaging = false
		if info_prompt.visible:
			info_prompt.hide()
		_sell_house_or_mortgage(index)
		return

	if _admin_picking_property:
		_admin_picking_property = false
		if info_prompt.visible:
			info_prompt.hide()
		_admin_assign_property(index)
		return

	var info: Dictionary = board.get_space_info(index)
	var color_name: String = info.get("color", "")

	# Standard color-group properties get the visual card; railroads,
	# utilities, and everything else fall back to the plain text popup,
	# since their rent structures don't fit the 6-tier house-rent card.
	var price: int = info.get("price", 0)
	var mortgage_value: int = _mortgage_value(price)
	var unmortgage_value: int = _unmortgage_value(price)

	if info.has("rents") and color_name != "railroad" and color_name != "utility":
		var header_color: Color = board.COLOR_GROUP_COLORS.get(color_name, Color.GRAY)
		var house_cost: int = board.HOUSE_COSTS_BY_COLOR.get(color_name, 0)
		property_card.show_card(info.get("name", ""), header_color, info["rents"], price, house_cost, mortgage_value, unmortgage_value)
		return

	if color_name == "railroad" and info.has("rents"):
		var rents: Array = info["rents"]
		var lines: Array[String] = [
			"Rent: $%d" % rents[0],
			"If 2 Railroads are owned: $%d" % rents[1],
			"If 3 Railroads are owned: $%d" % rents[2],
			"If 4 Railroads are owned: $%d" % rents[3],
			"Mortgage Value: $%d" % mortgage_value,
			"Unmortgage Value: $%d" % unmortgage_value,
		]
		asset_card.show_card(info.get("name", ""), load(info.get("icon", "")), lines)
		return

	if color_name == "utility" and info.has("rent_multipliers"):
		var multipliers: Array = info["rent_multipliers"]
		var lines: Array[String] = [
			"If one Utility is owned, rent is %d times amount shown on dice." % multipliers[0],
			"If both Utilities are owned, rent is %d times amount shown on dice." % multipliers[1],
			"Mortgage Value: $%d" % mortgage_value,
			"Unmortgage Value: $%d" % unmortgage_value,
		]
		asset_card.show_card(info.get("name", ""), load(info.get("icon", "")), lines)
		return

	var space_name: String = info.get("name", "Space %d" % index)
	var lines: Array[String] = [space_name]
	if info.has("price"):
		lines.append("Cost: $%d" % info["price"])
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

		var flow: HFlowContainer = player_properties_flows[i]
		for child in flow.get_children():
			child.queue_free()
		for space_index in players[i].owned_property_indices:
			var info: Dictionary = board.get_space_info(space_index)
			var color_name: String = info.get("color", "")
			var color: Color = board.COLOR_GROUP_COLORS.get(color_name, Color.GRAY)
			var mini_card: Control = MINI_CARD_SCENE.instantiate()
			flow.add_child(mini_card)
			mini_card.setup(space_index, info.get("name", ""), color, board.spaces[space_index].house_count, board.spaces[space_index].is_mortgaged)
			mini_card.card_clicked.connect(_on_space_clicked)
