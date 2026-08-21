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

signal debt_resolved

@onready var board: Node2D = $Board
@onready var players_container: Node2D = $Players
@onready var roll_button: Button = $UI/Panel/VBox/RollButton
@onready var admin_button: Button = $UI/Panel/VBox/AdminRow/AdminButton
@onready var admin_properties_button: Button = $UI/Panel/VBox/AdminRow/AdminPropertiesButton
@onready var buy_house_unmortgage_button: Button = $UI/Panel/VBox/BuyHouseUnmortgageButton
@onready var sell_house_mortgage_button: Button = $UI/Panel/VBox/SellHouseMortgageButton
@onready var declare_bankruptcy_button: Button = $UI/Panel/VBox/DeclareBankruptcyButton
@onready var trade_button: Button = $UI/Panel/VBox/TradeButton
@onready var turn_label: Label = $UI/Panel/VBox/TurnLabel
@onready var dice_label: Label = $UI/Panel/VBox/DiceLabel
@onready var number_prompt: PopupPanel = $UI/NumberPrompt
@onready var confirm_prompt: PopupPanel = $UI/ConfirmPrompt
@onready var quit_confirm_prompt: PopupPanel = $UI/QuitConfirmPrompt
@onready var info_prompt: PopupPanel = $UI/InfoPrompt
@onready var property_card: PopupPanel = $UI/PropertyCard
@onready var asset_card: PopupPanel = $UI/AssetCard
@onready var player_picker: PopupPanel = $UI/PlayerPicker
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
@onready var trade_hseparator: HSeparator = $UI/PlayersPanel/VBox/HSeparatorTrade
@onready var trade_display: VBoxContainer = $UI/PlayersPanel/VBox/TradeDisplay
@onready var trader1_label: Label = $UI/PlayersPanel/VBox/TradeDisplay/TradeHeader/Trader1Label
@onready var trader2_label: Label = $UI/PlayersPanel/VBox/TradeDisplay/TradeHeader/Trader2Label
@onready var trader1_flow: HFlowContainer = $UI/PlayersPanel/VBox/TradeDisplay/TradeColumns/Trader1Flow
@onready var trader2_flow: HFlowContainer = $UI/PlayersPanel/VBox/TradeDisplay/TradeColumns/Trader2Flow
@onready var trader1_money_edit: LineEdit = $UI/PlayersPanel/VBox/TradeDisplay/TradeMoneyRow/Trader1MoneyBox/Trader1MoneyEdit
@onready var trader2_money_edit: LineEdit = $UI/PlayersPanel/VBox/TradeDisplay/TradeMoneyRow/Trader2MoneyBox/Trader2MoneyEdit
@onready var offer_trade_button: Button = $UI/PlayersPanel/VBox/TradeDisplay/TradeActions/OfferTradeButton
@onready var decline_trade_button: Button = $UI/PlayersPanel/VBox/TradeDisplay/TradeActions/DeclineTradeButton

var players: Array[Node2D] = []
var current_player: int = 0
var _admin_die1: int = 0
var free_parking_amount: int = 0
var _quit_prompt_open: bool = false
var _admin_picking_property: bool = false
var _buying_house_or_unmortgaging: bool = false
var _selling_house_or_mortgaging: bool = false

# Set while the current player owes more money than they have on hand and is
# being given a chance to raise it (selling houses / mortgaging) before
# bankruptcy. See _collect_debt().
var _in_debt: bool = false
var _debt_amount: int = 0
var _debt_creditor: Node2D = null

# Set while the current player is deciding whether to buy the property they
# landed on, so they can sell houses / mortgage to raise the price first
# rather than the game pre-judging whether they can afford it. The pending_*
# fields let _sell_house_or_mortgage() reopen the same buy prompt afterward.
var _awaiting_buy_decision: bool = false
var _pending_buy_property_name: String = ""
var _pending_buy_price: int = 0

# Set while a trade is in progress. Trader1 is whoever clicked Trade (always
# the player whose turn it is when a trade starts); Trader2 is who they
# picked to trade with. CurrentPlayer is tracked separately and restored
# when the trade ends, since -- however complicated a trade gets -- play
# always resumes on whoever's turn it actually was.
var _trading: bool = false
var _trade_current_player: int = -1
var _trader1: int = -1
var _trader2: int = -1
var _trade1_offered: Array[int] = []
var _trade2_offered: Array[int] = []

# Trade negotiation is a back-and-forth: whoever is _trade_proposer is the
# one currently deciding what to do. If _trade_can_accept is true, the
# proposal on screen is exactly what the other side last sent, so the
# proposer can accept it as-is; any click or money edit invalidates that
# (the offer button reverts to "Offer Trade") since it now needs to go back
# to the other side before it can be accepted.
var _trade_proposer: int = -1
var _trade_can_accept: bool = false


func _ready() -> void:
	_spawn_players()
	roll_button.pressed.connect(_on_roll_pressed)
	admin_button.pressed.connect(_on_admin_pressed)
	admin_properties_button.pressed.connect(_on_admin_properties_pressed)
	buy_house_unmortgage_button.pressed.connect(_on_buy_house_unmortgage_pressed)
	sell_house_mortgage_button.pressed.connect(_on_sell_house_mortgage_pressed)
	declare_bankruptcy_button.pressed.connect(_on_declare_bankruptcy_pressed)
	trade_button.pressed.connect(_on_trade_pressed)
	offer_trade_button.pressed.connect(_on_offer_trade_pressed)
	decline_trade_button.pressed.connect(_on_decline_trade_pressed)
	trader1_money_edit.text_changed.connect(_on_trade_money_changed)
	trader2_money_edit.text_changed.connect(_on_trade_money_changed)
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
	declare_bankruptcy_button.disabled = true
	trade_button.disabled = true
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
	_refresh_action_buttons()
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
	_refresh_action_buttons()


func _on_admin_properties_pressed() -> void:
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true
	declare_bankruptcy_button.disabled = true
	trade_button.disabled = true
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

	_refresh_action_buttons()


func _on_buy_house_unmortgage_pressed() -> void:
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true
	declare_bankruptcy_button.disabled = true
	trade_button.disabled = true
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
	_refresh_action_buttons()


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
	declare_bankruptcy_button.disabled = true
	trade_button.disabled = true
	# Armed immediately, same reasoning as Buy House / Admin Properties.
	_selling_house_or_mortgaging = true
	info_prompt.open("Click a property to sell a house from it, or to mortgage it if it has no houses.")


# Dispatches to house-selling or mortgaging depending on whether the clicked
# property currently has any houses, per the combined button's behavior.
# Also checks whether this raised enough money to cover an outstanding debt
# (see _collect_debt()), since this is the only action allowed while in debt.
func _sell_house_or_mortgage(index: int) -> void:
	var space: Node2D = board.spaces[index]
	if space.house_count > 0:
		_sell_house(index)
	else:
		_mortgage_property(index)
	_maybe_resolve_debt()
	# Debt not yet cleared -- restate how much is still owed so the reminder
	# doesn't get lost behind whatever this action's own message said.
	if _in_debt:
		dice_label.text += "\nSell houses or properties? Need to raise $%d" % _debt_amount
	_refresh_action_buttons()


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


func _perform_roll(die1: int, die2: int) -> void:
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true
	declare_bankruptcy_button.disabled = true
	trade_button.disabled = true

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
		_advance_to_next_active_player()
	_update_turn_label()
	_update_player_panels()

	_refresh_action_buttons()


# Returns true if this move sent the player to Jail or ended in bankruptcy
# (including bankruptcy reached via debt collection), canceling a
# doubles-triggered extra turn. Debt collection that ends in the player
# successfully paying off what they owed does NOT cancel the extra turn --
# they're still in the game, so a rolled double still earns another go.
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
		if tax_value > player.money:
			dice_label.text += "\nLanded on %s! Owes $%d." % [landed_info.get("name", ""), tax_value]
			await _collect_debt(player, tax_value, null)
			return player.is_bankrupt
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
			# _ask_buy_property() only returns true once the player both said
			# yes AND actually has the money -- it keeps re-asking (letting
			# them sell houses / mortgage in between) until either that's
			# true or they say no.
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
				if rent_amount > player.money:
					dice_label.text += "\nLanded on %s (owned by %s)! Owes $%d rent." % [property_name, PLAYER_NAMES[space.owner_id], rent_amount]
					await _collect_debt(player, rent_amount, owner)
					return player.is_bankrupt
				player.money -= rent_amount
				owner.money += rent_amount
				dice_label.text += "\nLanded on %s (owned by %s)! Paid $%d rent%s." % [property_name, PLAYER_NAMES[space.owner_id], rent_amount, note]

	return false


# Gives the current player a chance to raise money (selling houses /
# mortgaging properties) before being forced into bankruptcy. Restricts the
# action buttons to just Sell Houses/Mortgage and Declare Bankruptcy until
# either they raise enough to cover `amount` (auto-paid, see
# _maybe_resolve_debt()) or they declare bankruptcy (see
# _on_declare_bankruptcy_pressed()) -- both of which emit debt_resolved.
# `creditor` is who they owe (null for a tax debt owed to the bank).
func _collect_debt(player: Node2D, amount: int, creditor: Node2D) -> void:
	_in_debt = true
	_debt_amount = amount
	_debt_creditor = creditor
	dice_label.text += "\nSell houses or properties? Need to raise $%d" % amount
	_refresh_action_buttons()
	await debt_resolved


# Called after every sell-house/mortgage action. If it raised enough to cover
# the outstanding debt, pays it automatically and lets the player continue.
func _maybe_resolve_debt() -> void:
	if not _in_debt:
		return
	var player: Node2D = players[current_player]
	if player.money < _debt_amount:
		return

	player.money -= _debt_amount
	if _debt_creditor:
		_debt_creditor.money += _debt_amount
	else:
		free_parking_amount += _debt_amount
	dice_label.text += "\n%s raised enough money and paid the $%d owed." % [_player_display_name(current_player), _debt_amount]

	_in_debt = false
	_debt_amount = 0
	_debt_creditor = null
	_update_player_panels()
	debt_resolved.emit()


# Sets each action button's enabled state for the current situation: while a
# debt is outstanding, only Sell Houses/Mortgage, Declare Bankruptcy, and
# Trade are usable -- trading lets the player try to raise money from an
# opponent instead of just liquidating. While deciding whether to buy a
# just-landed-on property, the same restriction applies except Declare
# Bankruptcy and Trade stay off -- there's nothing to forfeit or negotiate
# over, they can simply decline the purchase. While trading, everything here
# is off (the trade display's own buttons take over). Otherwise everything
# is usable.
func _refresh_action_buttons() -> void:
	var limited_to_selling: bool = _in_debt or _awaiting_buy_decision
	roll_button.disabled = limited_to_selling or _trading
	admin_button.disabled = limited_to_selling or _trading
	admin_properties_button.disabled = limited_to_selling or _trading
	buy_house_unmortgage_button.disabled = limited_to_selling or _trading
	sell_house_mortgage_button.disabled = _trading
	declare_bankruptcy_button.disabled = _awaiting_buy_decision or _trading
	trade_button.disabled = _awaiting_buy_decision or _trading


func _on_trade_pressed() -> void:
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true
	declare_bankruptcy_button.disabled = true
	trade_button.disabled = true

	var entries: Array = []
	for i in players.size():
		if i != current_player and not players[i].is_bankrupt:
			entries.append({"index": i, "name": PLAYER_NAMES[i], "color": PLAYER_COLORS[i]})

	if entries.is_empty():
		dice_label.text += "\nThere's no one left to trade with."
		_refresh_action_buttons()
		return

	player_picker.open("Trade with which player?", entries)
	var chosen: int = await player_picker.player_chosen
	if chosen == -1:
		_refresh_action_buttons()
		return

	_start_trade(current_player, chosen)


func _start_trade(p1_index: int, p2_index: int) -> void:
	_trading = true
	_trade_current_player = current_player
	_trader1 = p1_index
	_trader2 = p2_index
	_trade1_offered.clear()
	_trade2_offered.clear()
	trader1_money_edit.text = ""
	trader2_money_edit.text = ""
	_trade_proposer = p1_index
	_trade_can_accept = false

	trader1_label.text = PLAYER_NAMES[p1_index]
	trader1_label.add_theme_color_override("font_color", PLAYER_COLORS[p1_index])
	trader2_label.text = PLAYER_NAMES[p2_index]
	trader2_label.add_theme_color_override("font_color", PLAYER_COLORS[p2_index])
	trade_hseparator.visible = true
	trade_display.visible = true

	dice_label.text += "\n%s is trading with %s. Click properties to offer them; houses can't be traded." % [PLAYER_NAMES[p1_index], PLAYER_NAMES[p2_index]]
	_update_trade_action_button()
	_update_player_panels()
	_refresh_action_buttons()


# Toggles a property in or out of whichever trader's offer it belongs to.
# Reused for clicks both on a player's normal mini cards (offering it) and
# on the trade display's own mini cards (taking it back).
func _handle_trade_click(index: int) -> void:
	var space: Node2D = board.spaces[index]
	if space.owner_id != _trader1 and space.owner_id != _trader2:
		dice_label.text = "That property isn't part of this trade."
		return
	var color_name: String = board.get_space_info(index).get("color", "")
	if _max_houses_in_group(color_name) > 0:
		dice_label.text = "That property can't be traded while a property in its color set has houses."
		return

	var offered: Array[int] = _trade1_offered if space.owner_id == _trader1 else _trade2_offered
	if offered.has(index):
		offered.erase(index)
	else:
		offered.append(index)
	_mark_trade_modified()
	_update_player_panels()


func _on_trade_money_changed(_new_text: String) -> void:
	_mark_trade_modified()


# Any change to the terms -- a property clicked, a money box edited -- means
# the current proposer's screen no longer matches what the other side last
# sent, so it has to be offered again before it can be accepted.
func _mark_trade_modified() -> void:
	if _trade_can_accept:
		_trade_can_accept = false
		_update_trade_action_button()


func _update_trade_action_button() -> void:
	offer_trade_button.text = "Accept Trade" if _trade_can_accept else "Offer Trade"


# The single action button does double duty: it sends the current terms to
# the other side for a decision, or -- once they've sent back exactly what's
# already on screen -- finalizes the trade.
func _on_offer_trade_pressed() -> void:
	if _trade_can_accept:
		_finalize_trade()
	else:
		_send_trade_offer()


func _send_trade_offer() -> void:
	var sender: int = _trade_proposer
	var responder: int = _trader2 if sender == _trader1 else _trader1
	_trade_proposer = responder
	_trade_can_accept = true
	dice_label.text = "%s offered a trade to %s." % [PLAYER_NAMES[sender], PLAYER_NAMES[responder]]
	_update_trade_action_button()


func _finalize_trade() -> void:
	var p1: Node2D = players[_trader1]
	var p2: Node2D = players[_trader2]
	var p1_money: int = max(0, int(trader1_money_edit.text))
	var p2_money: int = max(0, int(trader2_money_edit.text))
	if p1_money > p1.money:
		dice_label.text = "%s doesn't have enough money to offer $%d." % [PLAYER_NAMES[_trader1], p1_money]
		return
	if p2_money > p2.money:
		dice_label.text = "%s doesn't have enough money to offer $%d." % [PLAYER_NAMES[_trader2], p2_money]
		return

	for index in _trade1_offered:
		p1.owned_property_indices.erase(index)
		p2.owned_property_indices.append(index)
		board.spaces[index].owner_id = _trader2
	for index in _trade2_offered:
		p2.owned_property_indices.erase(index)
		p1.owned_property_indices.append(index)
		board.spaces[index].owner_id = _trader1
	p1.money -= p1_money
	p2.money += p1_money
	p2.money -= p2_money
	p1.money += p2_money
	_sort_owned_properties(p1)
	_sort_owned_properties(p2)
	dice_label.text = "%s and %s completed a trade!" % [PLAYER_NAMES[_trader1], PLAYER_NAMES[_trader2]]
	_end_trade()


func _on_decline_trade_pressed() -> void:
	var decliner: int = _trade_proposer
	var other: int = _trader2 if decliner == _trader1 else _trader1
	dice_label.text = "%s declined to trade with %s." % [PLAYER_NAMES[decliner], PLAYER_NAMES[other]]
	_end_trade()


func _end_trade() -> void:
	_trading = false
	# However complicated the trade got, play always resumes on whoever's
	# turn it actually was.
	current_player = _trade_current_player
	_trader1 = -1
	_trader2 = -1
	_trade_current_player = -1
	_trade1_offered.clear()
	_trade2_offered.clear()
	trader1_money_edit.text = ""
	trader2_money_edit.text = ""
	_trade_proposer = -1
	_trade_can_accept = false
	trade_hseparator.visible = false
	trade_display.visible = false
	_update_turn_label()
	_update_player_panels()
	# A trade completed while in debt might have raised enough money to
	# cover it, same as selling a house or mortgaging a property would.
	_maybe_resolve_debt()
	if _in_debt:
		dice_label.text += "\nSell houses or properties? Need to raise $%d" % _debt_amount
	_refresh_action_buttons()


func _populate_trade_flow(flow: HFlowContainer, indices: Array[int]) -> void:
	for child in flow.get_children():
		child.queue_free()
	for space_index in indices:
		var info: Dictionary = board.get_space_info(space_index)
		var color_name: String = info.get("color", "")
		var color: Color = board.COLOR_GROUP_COLORS.get(color_name, Color.GRAY)
		var mini_card: Control = MINI_CARD_SCENE.instantiate()
		flow.add_child(mini_card)
		mini_card.setup(space_index, info.get("name", ""), color, board.spaces[space_index].house_count, board.spaces[space_index].is_mortgaged)
		mini_card.card_clicked.connect(_on_space_clicked)
		mini_card.card_right_clicked.connect(_show_property_details)


# Liquidates a bankrupt player: all their houses are sold back for half cost,
# then their remaining money and properties pass to `creditor` (the player
# they couldn't pay) or, if there is no creditor, their money is simply lost
# and their properties become unowned. The player stops taking turns and
# their board marker is hidden.
func _bankrupt_player(player: Node2D, creditor: Node2D) -> void:
	for space_index in player.owned_property_indices:
		var space: Node2D = board.spaces[space_index]
		if space.house_count > 0:
			var info: Dictionary = board.get_space_info(space_index)
			var house_cost: int = board.HOUSE_COSTS_BY_COLOR.get(info.get("color", ""), 0)
			player.money += (house_cost / 2) * space.house_count
			space.house_count = 0

	if creditor:
		creditor.money += player.money
		for space_index in player.owned_property_indices:
			var space: Node2D = board.spaces[space_index]
			space.owner_id = creditor.player_id
			creditor.owned_property_indices.append(space_index)
		_sort_owned_properties(creditor)
	else:
		for space_index in player.owned_property_indices:
			var space: Node2D = board.spaces[space_index]
			space.owner_id = -1
			space.is_mortgaged = false

	player.money = 0
	player.owned_property_indices.clear()
	player.is_bankrupt = true
	player.visible = false


# Called after a bankruptcy resolves. If it left exactly one player still in
# the game, announce them as the winner. Nothing further is done about it --
# the game just keeps working normally from here (only one active player
# means turns will simply keep cycling back to them); players are expected
# to close and start a new game if they want to play again.
func _check_for_winner() -> void:
	var remaining: Array[Node2D] = []
	for player in players:
		if not player.is_bankrupt:
			remaining.append(player)
	if remaining.size() == 1:
		dice_label.text += "\n%s wins!" % PLAYER_NAMES[remaining[0].player_id]


func _on_declare_bankruptcy_pressed() -> void:
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true
	declare_bankruptcy_button.disabled = true
	trade_button.disabled = true

	confirm_prompt.open("Are you sure you want to declare bankruptcy?")
	var yes: bool = await confirm_prompt.answered
	if yes:
		var player: Node2D = players[current_player]
		var forfeiting_name: String = _player_display_name(current_player)
		# If this happened while trying to raise money for a specific debt,
		# that creditor gets everything, per the debt-collection rules;
		# otherwise this is a plain voluntary forfeit with no one to credit.
		var creditor: Node2D = _debt_creditor if _in_debt else null
		_bankrupt_player(player, creditor)
		dice_label.text = "%s declared bankruptcy and forfeits the game." % forfeiting_name
		_check_for_winner()
		if _in_debt:
			_in_debt = false
			_debt_amount = 0
			_debt_creditor = null
			debt_resolved.emit()
		else:
			_advance_to_next_active_player()
			_update_turn_label()
		_update_player_panels()

	_refresh_action_buttons()


# Always offers the purchase, regardless of whether the player currently has
# enough money -- they get to judge that for themselves. While deciding, the
# Sell Houses/Mortgage button stays usable so they can raise the price first.
# Clicking it (or clicking anything else) dismisses this popup as a side
# effect (Godot closes popups on any outside click), so auto-decline-on-
# dismiss is suppressed here and _reassert_buy_prompt_if_needed() reopens it
# after every board click while still awaiting a decision.
#
# Saying yes without enough money doesn't end the decision -- it's reported
# and the prompt comes right back, so the player can keep raising money and
# try again. Only an explicit "No", or an explicit "Yes" that they can
# actually afford, returns.
func _ask_buy_property(property_name: String, price: int) -> bool:
	_awaiting_buy_decision = true
	_pending_buy_property_name = property_name
	_pending_buy_price = price
	_refresh_action_buttons()
	confirm_prompt.suppress_auto_decline = true
	var player: Node2D = players[current_player]
	var result: bool = false
	while true:
		confirm_prompt.open("Buy %s for $%d?" % [property_name, price])
		var yes: bool = await confirm_prompt.answered
		if not yes:
			break
		if player.money >= price:
			result = true
			break
		dice_label.text += "\n%s doesn't have enough money to buy %s." % [_player_display_name(current_player), property_name]
	confirm_prompt.suppress_auto_decline = false
	_awaiting_buy_decision = false
	_refresh_action_buttons()
	return result


func _reassert_buy_prompt_if_needed() -> void:
	if _awaiting_buy_decision and not confirm_prompt.visible:
		confirm_prompt.open("Buy %s for $%d?" % [_pending_buy_property_name, _pending_buy_price])


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
	# Any tile click can dismiss the buy-confirmation popup as a side effect
	# (Godot closes popups on any outside click, including whatever this
	# click actually does), which would otherwise auto-decline the purchase;
	# suppress_auto_decline on that popup stops that, so reassert it here
	# -- deferred so it runs after this click's own handling below, however
	# that handling resolves. A no-op if it's already showing or there's no
	# buy decision pending.
	_reassert_buy_prompt_if_needed.call_deferred()

	if _trading:
		_handle_trade_click(index)
		return

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

	_show_property_details(index)


# Shows the full property/asset card (or, for spaces without one, the plain
# text popup) for a space. Used both for the normal left-click-on-a-tile
# fallback above, and for right-clicking a mini card to inspect it without
# disturbing whatever picking mode (e.g. a trade) is currently active.
func _show_property_details(index: int) -> void:
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


# Skips bankrupt players, who no longer take turns. Bounded by players.size()
# so a table where every player is bankrupt can't spin forever.
func _advance_to_next_active_player() -> void:
	for i in players.size():
		current_player = (current_player + 1) % players.size()
		if not players[current_player].is_bankrupt:
			return


func _update_turn_label() -> void:
	turn_label.text = "%s's turn" % _player_display_name(current_player)


func _player_display_name(index: int) -> String:
	var player: Node2D = players[index]
	if player.is_bankrupt:
		return "%s (bankrupt)" % PLAYER_NAMES[index]
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
			# Properties currently staged in the trade display have "moved"
			# there visually, so they're left out of the normal row.
			if _trading and (_trade1_offered.has(space_index) or _trade2_offered.has(space_index)):
				continue
			var info: Dictionary = board.get_space_info(space_index)
			var color_name: String = info.get("color", "")
			var color: Color = board.COLOR_GROUP_COLORS.get(color_name, Color.GRAY)
			var mini_card: Control = MINI_CARD_SCENE.instantiate()
			flow.add_child(mini_card)
			mini_card.setup(space_index, info.get("name", ""), color, board.spaces[space_index].house_count, board.spaces[space_index].is_mortgaged)
			mini_card.card_clicked.connect(_on_space_clicked)
			mini_card.card_right_clicked.connect(_show_property_details)

	if _trading:
		_populate_trade_flow(trader1_flow, _trade1_offered)
		_populate_trade_flow(trader2_flow, _trade2_offered)
