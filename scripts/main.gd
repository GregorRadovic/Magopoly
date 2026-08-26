extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const MINI_CARD_SCENE: PackedScene = preload("res://scenes/mini_property_card.tscn")
const MINI_SPELL_CARD_SCENE: PackedScene = preload("res://scenes/mini_spell_card.tscn")

# Starting hands by player index -- the only way to gain spells for now.
# P2's single T1 Burn Spell is there for _ai_p2_opening_burn() to use.
const STARTING_SPELLS_BY_PLAYER: Dictionary = {
	0: ["T1 Burn Spell", "T1 Burn Spell", "T3 Escape Spell", "T3 Escape Spell", "T2 Response Spell", "T2 Response Spell"],
	1: ["T1 Burn Spell"],
}

# Sentinel "level" for the level-picker's extra "Burn for Attunement" entry --
# safe from colliding with a real spell level, which are always >= 1.
const BURN_FOR_ATTUNEMENT_INDEX: int = 0

# How long a response window (see _ensure_response_window()) lasts before
# automatically continuing, if nobody pauses it (or extends it by casting
# another spell in response).
const RESPONSE_WINDOW_SECONDS: float = 2.0

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
# Emitted whenever a trade negotiation reaches a conclusion (finalized or
# declined), so an AI-initiated trade (see _ai_trade_check) can await the
# outcome before moving on to its next check.
signal trade_concluded

@onready var board: Node2D = $Board
@onready var players_container: Node2D = $Players
@onready var roll_button: Button = $UI/Panel/VBox/RollButton
@onready var admin_row: HBoxContainer = $UI/Panel/VBox/AdminRow
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
@onready var spell_card: PopupPanel = $UI/SpellCard
@onready var free_parking_label: Label = $UI/PlayersPanel/VBox/FreeParkingLabel
@onready var player_header_labels: Array[Label] = [
	$UI/PlayersPanel/VBox/Player0/HeaderLabel,
	$UI/PlayersPanel/VBox/Player1/HeaderLabel,
	$UI/PlayersPanel/VBox/Player2/HeaderLabel,
	$UI/PlayersPanel/VBox/Player3/HeaderLabel,
]
@onready var player_properties_flows: Array[HFlowContainer] = [
	$UI/PlayersPanel/VBox/Player0/AssetsRow/PropertiesFlow,
	$UI/PlayersPanel/VBox/Player1/AssetsRow/PropertiesFlow,
	$UI/PlayersPanel/VBox/Player2/AssetsRow/PropertiesFlow,
	$UI/PlayersPanel/VBox/Player3/AssetsRow/PropertiesFlow,
]
@onready var player_spells_flows: Array[HFlowContainer] = [
	$UI/PlayersPanel/VBox/Player0/AssetsRow/SpellsFlow,
	$UI/PlayersPanel/VBox/Player1/AssetsRow/SpellsFlow,
	$UI/PlayersPanel/VBox/Player2/AssetsRow/SpellsFlow,
	$UI/PlayersPanel/VBox/Player3/AssetsRow/SpellsFlow,
]
@onready var player_attunement_flows: Array[HFlowContainer] = [
	$UI/PlayersPanel/VBox/Player0/AssetsRow/AttunementFlow,
	$UI/PlayersPanel/VBox/Player1/AssetsRow/AttunementFlow,
	$UI/PlayersPanel/VBox/Player2/AssetsRow/AttunementFlow,
	$UI/PlayersPanel/VBox/Player3/AssetsRow/AttunementFlow,
]
@onready var player_rows: Array[VBoxContainer] = [
	$UI/PlayersPanel/VBox/Player0,
	$UI/PlayersPanel/VBox/Player1,
	$UI/PlayersPanel/VBox/Player2,
	$UI/PlayersPanel/VBox/Player3,
]
@onready var player_row_separators: Array[HSeparator] = [
	$UI/PlayersPanel/VBox/HSeparator0,
	$UI/PlayersPanel/VBox/HSeparator1,
	$UI/PlayersPanel/VBox/HSeparator2,
	$UI/PlayersPanel/VBox/HSeparator3,
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
# Set once the current player has rolled (and that roll's landing has fully
# resolved) for a turn that isn't earning a doubles-driven extra roll. A
# turn doesn't end just because you've rolled -- houses, unmortgaging,
# trading, etc. are all still available -- so the Roll button turns into
# End Turn and waits for an explicit click before play moves on.
var _awaiting_end_turn: bool = false
var _admin_die1: int = 0
var free_parking_amount: int = 0
var _quit_prompt_open: bool = false
var _admin_picking_property: bool = false
var _buying_house_or_unmortgaging: bool = false
var _selling_house_or_mortgaging: bool = false
# Set while the current player is casting a spell (choosing its level, then
# any target it asks for), so a second spell card click can't start another
# cast on top of it and stomp the shared player_picker popup.
var _casting_spell: bool = false

# Set for the whole extent of a response window (see
# _ensure_response_window()), opened either by a roll (giving a chance to
# react before it's used for movement) or by a spell being cast (giving a
# chance to respond to *that spell*, e.g. counter it, before it resolves) --
# both kinds share this same window/pause machinery and the same
# RESPONSE_WINDOW_SECONDS deadline, which a new spell cast during the window
# pushes back out (see _window_deadline_msec). _response_window_open by
# itself just means the window's still running (open, ticking down, or
# paused by someone) and keeps the normal action buttons locked throughout
# either way; it takes at least one player actually pausing it (see
# _response_window_paused_by) to unlock casting, and only for them.
var _response_window_open: bool = false
# Indexed by player_id (Space Bar and "1" both pause index 0 -- P1's
# perspective -- "2" pauses index 1, and so on). Pausing is per-player on
# purpose: with multiple humans at the table, only the player who actually
# paused (from *their* perspective) may cast during that pause -- see
# _level_timing_allowed(). The window itself stays frozen as long as *any*
# entry is true, but each player's own casting eligibility only looks at
# their own entry.
var _response_window_paused_by: Array[bool] = [false, false, false, false]
var _window_deadline_msec: int = 0
# True for the whole time a roll is "in flight" -- from right after it's
# shown until movement actually happens -- so Instant spells timed to a roll
# (e.g. T3 Escape Spell) know a roll is actually what's being responded to,
# as opposed to a response window that only exists because of a spell cast
# on someone's ordinary turn.
var _roll_in_flight: bool = false
# The roll value being built up while a roll is in flight -- read/returned
# by _perform_roll() via _roll_in_flight's window, and mutated in place by
# an Instant spell like T3 Escape Spell while paused.
var _current_roll: int = 0

# The pending spell stack: each entry is {"id": int, "caster_id": int,
# "display_name": String, "resolve": Callable}. A spell is pushed here the
# moment it's cast (having already left the caster's hand and picked
# whatever targets it needs) and popped LIFO -- last cast, first resolved --
# once the response window that followed it finally closes. Countering a
# spell (T2 Response Spell, Level 1) just removes its entry before it's ever
# popped. See _finish_cast() and _resolve_spell_stack().
var _spell_stack: Array[Dictionary] = []
var _next_stack_id: int = 0

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
# True only for a trade _ai_trade_check() itself started, so _send_trade_offer()
# knows to actually evaluate a counter-offer instead of just always declining
# (that's still what happens for a trade an AI didn't ask for).
var _ai_initiated_trade: bool = false


func _ready() -> void:
	admin_row.visible = GameState.admin_mode
	_spawn_players()
	current_player = _first_active_player()
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
	_refresh_action_buttons()
	if players[current_player].is_ai:
		_run_ai_turn()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _quit_prompt_open:
		_confirm_quit()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# Space Bar always pauses from P1's perspective, same as "1" --
		# with multiple local humans, "2"/"3"/"4" pause from that player's
		# own perspective instead. See _response_window_paused_by.
		match event.keycode:
			KEY_SPACE, KEY_1:
				_toggle_pause_for_player(0)
			KEY_2:
				_toggle_pause_for_player(1)
			KEY_3:
				_toggle_pause_for_player(2)
			KEY_4:
				_toggle_pause_for_player(3)


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
		if STARTING_SPELLS_BY_PLAYER.has(i):
			player.spell_hand.append_array(STARTING_SPELLS_BY_PLAYER[i])
		if i == 1:
			# P2 starts owning Illinois Avenue, giving it enough Red
			# Attunement to open with _ai_p2_opening_burn()'s Level 1 cast.
			var illinois_index: int = 24
			board.spaces[illinois_index].owner_id = 1
			player.owned_property_indices.append(illinois_index)
			_sort_owned_properties(player)

		var type: GameState.PlayerType = GameState.player_types[i]
		if type == GameState.PlayerType.DISABLED:
			# Treated as already bankrupt so turn order, the trade picker,
			# and the win check all just skip over them -- this slot was
			# never really in the game.
			player.is_bankrupt = true
			player.visible = false
			player_rows[i].visible = false
			player_row_separators[i].visible = false
		elif type == GameState.PlayerType.COMPUTER:
			player.is_ai = true


# The player order always starts at index 0, but that slot might be
# Disabled, so find whoever's actually first in line.
func _first_active_player() -> int:
	for i in players.size():
		if not players[i].is_bankrupt:
			return i
	return 0


func _on_roll_pressed() -> void:
	if _awaiting_end_turn:
		_end_turn()
		return
	var die1: int = randi_range(1, 6)
	var die2: int = randi_range(1, 6)
	_perform_roll(die1, die2)


# Called when the button (showing "End Turn" at this point) is pressed after
# a roll that didn't earn another one. Actually hands play to the next
# active player -- until this, the current player can keep managing houses,
# mortgages, and trades.
func _end_turn() -> void:
	_advance_turn()
	_update_player_panels()
	_refresh_action_buttons()


# Shared by everywhere play moves to the next active player, so
# _awaiting_end_turn always resets with it -- otherwise the next player
# would inherit an "End Turn" button before ever rolling.
func _advance_turn() -> void:
	_awaiting_end_turn = false
	_advance_to_next_active_player()
	_update_turn_label()
	if players[current_player].is_ai:
		_run_ai_turn()


# Drives a Computer player's entire turn automatically: roll, decline any
# purchase, and end turn -- rolling again first if that roll was doubles.
# Debt it can't cover ends in an immediate forfeit, since it has no other
# way to raise money. Deliberately simple; smarter play comes later.
func _run_ai_turn() -> void:
	var ai_index: int = current_player
	await _ai_p2_opening_burn(players[ai_index])
	while current_player == ai_index and not players[ai_index].is_bankrupt:
		_refresh_action_buttons()
		await get_tree().create_timer(0.6).timeout
		var die1: int = randi_range(1, 6)
		var die2: int = randi_range(1, 6)
		await _perform_roll(die1, die2)
		if current_player != ai_index or players[ai_index].is_bankrupt:
			return
		if _awaiting_end_turn:
			await get_tree().create_timer(0.6).timeout
			await _ai_run_end_of_turn_checks(players[ai_index])
			if current_player != ai_index or players[ai_index].is_bankrupt:
				return
			_end_turn()
			return


# Scripted one-off for testing responses, per design: P2 opens each of its
# turns by casting its starting T1 Burn Spell at Level 1 on P1, if it's
# still holding it, before playing the rest of the turn normally. Bypasses
# _prepare_t1_burn_spell()'s own opponent-picker (an AI shouldn't be driving
# player-facing UI) and targets P1 directly, but still goes through
# _finish_cast() like any other cast, so a human still gets the usual
# response window to react (e.g. counter it) before it resolves.
func _ai_p2_opening_burn(player: Node2D) -> void:
	if player.player_id != 1:
		return
	var hand_index: int = player.spell_hand.find("T1 Burn Spell")
	if hand_index == -1:
		return
	var amount: int = SpellData.SPELLS["T1 Burn Spell"]["levels"][1].get("amount", 0)
	var resolve: Callable = _resolve_t1_burn_spell.bind(player, 1, 0, amount)
	await _finish_cast(player, hand_index, "T1 Burn Spell", 1, resolve)


# Runs once, right before a Computer player ends its turn: unmortgage what
# it can afford, chase down any color set it's one property short of, then
# spend what's safe to spend on houses. Order matters -- unmortgaging first
# frees up cash and properties that the later checks see; a completed set
# from trading is what the house check will actually build on.
func _ai_run_end_of_turn_checks(player: Node2D) -> void:
	_ai_mortgage_check(player)
	await _ai_trade_check(player)
	_ai_house_check(player)


# a) MortgageCheck: unmortgages whatever it can afford, priciest first, for
# as long as it can keep affording more.
func _ai_mortgage_check(player: Node2D) -> void:
	while true:
		var candidates: Array[int] = []
		for space_index in player.owned_property_indices:
			var space: Node2D = board.spaces[space_index]
			if not space.is_mortgaged:
				continue
			var price: int = board.get_space_info(space_index).get("price", 0)
			if player.money < _unmortgage_value(price):
				continue
			candidates.append(space_index)
		if candidates.is_empty():
			return
		candidates.sort_custom(func(a, b): return board.get_space_info(a).get("price", 0) > board.get_space_info(b).get("price", 0))
		_unmortgage_property(candidates[0])


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


# Mortgages the AI's eligible properties (unmortgaged, and not blocked by
# houses anywhere in their color group), priciest first, one at a time
# until `needed` is covered or nothing more can be mortgaged.
func _ai_mortgage_properties(player: Node2D, needed: int) -> void:
	while player.money < needed:
		var candidates: Array[int] = []
		for space_index in player.owned_property_indices:
			var space: Node2D = board.spaces[space_index]
			if space.is_mortgaged:
				continue
			var color_name: String = board.get_space_info(space_index).get("color", "")
			if _max_houses_in_group(color_name) > 0:
				continue
			candidates.append(space_index)
		if candidates.is_empty():
			return
		candidates.sort_custom(func(a, b): return board.get_space_info(a).get("price", 0) > board.get_space_info(b).get("price", 0))
		_mortgage_property(candidates[0])


# Sells one house at a time from whichever of the AI's properties currently
# has the most houses in its group (the only ones eligible, per the
# even-selling rule), preferring the priciest property when there's a
# choice, until `needed` is covered or no houses remain to sell.
func _ai_sell_houses(player: Node2D, needed: int) -> void:
	while player.money < needed:
		var candidates: Array[int] = []
		for space_index in player.owned_property_indices:
			var space: Node2D = board.spaces[space_index]
			if space.house_count <= 0:
				continue
			var color_name: String = board.get_space_info(space_index).get("color", "")
			if space.house_count == _max_houses_in_group(color_name):
				candidates.append(space_index)
		if candidates.is_empty():
			return
		candidates.sort_custom(func(a, b): return board.get_space_info(a).get("price", 0) > board.get_space_info(b).get("price", 0))
		_sell_house(candidates[0])


# The rent a property would charge right now if someone landed on it, given
# its owner's current houses / monopoly / mortgage status. Used only for the
# AI's Worst Case Scenario estimate below -- kept separate from the real
# landing-resolution logic in _move_player() so this hypothetical math can
# never affect an actual rent charge. Utilities use the maximum possible
# roll (12), since there's no real roll to reference for a hypothetical --
# fitting, since this feeds into a "worst case" figure.
func _hypothetical_rent(space_index: int) -> int:
	var space: Node2D = board.spaces[space_index]
	if space.is_mortgaged or space.owner_id == -1:
		return 0
	var info: Dictionary = board.get_space_info(space_index)
	var color_name: String = info.get("color", "")
	var rents: Array = info.get("rents", [])
	if color_name == "railroad" and not rents.is_empty():
		var owned_railroads: int = _count_owned_in_group(space.owner_id, "railroad")
		var tier: int = clampi(owned_railroads, 1, rents.size()) - 1
		return rents[tier]
	if color_name == "utility":
		var multipliers: Array = info.get("rent_multipliers", [])
		if multipliers.is_empty():
			return 0
		var owned_utilities: int = _count_owned_in_group(space.owner_id, "utility")
		var multiplier_tier: int = clampi(owned_utilities, 1, multipliers.size()) - 1
		return multipliers[multiplier_tier] * 12
	if rents.is_empty():
		return 0
	if space.house_count > 0:
		return rents[space.house_count]
	var rent: int = rents[0]
	if _owns_full_color_group(space.owner_id, color_name):
		rent *= 2
	return rent


# c) "Worst Case Scenario": what the AI would pay landing on the single
# most expensive property (by price) that an opponent currently owns.
func _ai_worst_case_scenario(player: Node2D) -> int:
	var priciest_index: int = -1
	var priciest_price: int = -1
	for space_index in board.spaces.size():
		var space: Node2D = board.spaces[space_index]
		if space.owner_id == -1 or space.owner_id == player.player_id:
			continue
		var price: int = board.get_space_info(space_index).get("price", 0)
		if price > priciest_price:
			priciest_price = price
			priciest_index = space_index
	if priciest_index == -1:
		return 0
	return _hypothetical_rent(priciest_index)


# "Nest Egg": cash on hand plus the mortgage value of every unmortgaged,
# houseless property the AI owns -- i.e. everything it could turn into cash
# without having to sell a house.
func _ai_nest_egg(player: Node2D) -> int:
	var total: int = player.money
	for space_index in player.owned_property_indices:
		var space: Node2D = board.spaces[space_index]
		if not space.is_mortgaged and space.house_count == 0:
			total += _mortgage_value(board.get_space_info(space_index).get("price", 0))
	return total


# Finds the best legal house purchase that still leaves the Nest Egg
# covering the Worst Case Scenario after paying for it: cheapest color set
# first, and the most expensive (of whichever properties are currently tied
# for fewest houses, per the even-building rule) within that set. Returns
# -1 if nothing qualifies.
func _ai_best_house_option(player: Node2D, worst_case: int) -> int:
	for color_rank in PROPERTY_COLOR_ORDER.size():
		var color_name: String = PROPERTY_COLOR_ORDER[color_rank]
		if not board.HOUSE_COSTS_BY_COLOR.has(color_name):
			continue
		if not _owns_full_color_group(player.player_id, color_name):
			continue
		if _group_has_mortgaged(color_name):
			continue
		var house_cost: int = board.HOUSE_COSTS_BY_COLOR[color_name]
		if player.money < house_cost:
			continue
		var min_houses: int = _min_houses_in_group(color_name)
		if min_houses >= 5:
			continue

		var candidate_index: int = -1
		var candidate_price: int = -1
		for space_index in board.get_color_group(color_name):
			var space: Node2D = board.spaces[space_index]
			if space.house_count != min_houses:
				continue
			var price: int = board.get_space_info(space_index).get("price", 0)
			if price > candidate_price:
				candidate_price = price
				candidate_index = space_index
		if candidate_index == -1:
			continue

		# Simulate the purchase to see whether the Nest Egg still covers the
		# Worst Case Scenario afterward, then undo it -- this is a check,
		# not a commitment.
		var candidate_space: Node2D = board.spaces[candidate_index]
		player.money -= house_cost
		candidate_space.house_count += 1
		var nest_egg_after: int = _ai_nest_egg(player)
		player.money += house_cost
		candidate_space.house_count -= 1
		if nest_egg_after < worst_case:
			continue

		# Ranks are checked cheapest-first, so the first one to qualify is
		# already the answer -- nothing later could ever be preferred.
		return candidate_index
	return -1


# c) HouseCheck: keeps buying houses -- cheapest color set first, priciest
# eligible property within it -- for as long as doing so is legal and still
# leaves the Nest Egg covering the Worst Case Scenario. Opponents' holdings
# don't change during this, so the Worst Case Scenario is computed once.
func _ai_house_check(player: Node2D) -> void:
	var worst_case: int = _ai_worst_case_scenario(player)
	while true:
		var option: int = _ai_best_house_option(player, worst_case)
		if option == -1:
			return
		_buy_house(option)


# The two Instant Timings implemented so far both open this same shared
# window: right after a roll is shown (see _perform_roll(), _roll_in_flight)
# and right after any spell is cast (see _finish_cast(), which pushes onto
# _spell_stack before calling this). Every player gets a
# RESPONSE_WINDOW_SECONDS window to hit Space and pause the game -- while
# paused, any player may cast an Instant spell (see _on_spell_clicked()).
# Pausing just freezes the countdown rather than resetting it, so unpausing
# resumes whatever was left rather than cutting it short (fair to everyone
# else at the table who might still want their own turn to react).
#
# Only the call that actually *opens* the window (finds it not already
# open) waits here and resolves the stack once it closes -- a call that
# arrives while it's already open (e.g. a second spell cast in response to
# the first) just pushes _window_deadline_msec back out, extending the
# window the first call is waiting on, and returns immediately.
func _ensure_response_window() -> void:
	_window_deadline_msec = Time.get_ticks_msec() + int(RESPONSE_WINDOW_SECONDS * 1000.0)
	if _response_window_open:
		return
	_response_window_open = true
	_response_window_paused_by = [false, false, false, false]
	_refresh_action_buttons()
	dice_label.text += "\n(Press Space/1/2/3/4 within %ds to pause from that player's perspective and react with an Instant spell.)" % int(RESPONSE_WINDOW_SECONDS)

	while _response_window_paused_by.has(true) or Time.get_ticks_msec() < _window_deadline_msec:
		await get_tree().process_frame

	_response_window_open = false
	_refresh_action_buttons()
	await _resolve_spell_stack()


# Pops and resolves _spell_stack LIFO -- last spell cast, first to resolve --
# once its response window has fully closed. Countering a spell (T2 Response
# Spell, Level 1) removes its entry before it's ever popped here, so it's
# simply skipped, per "countering negates the effect and discards it".
func _resolve_spell_stack() -> void:
	while not _spell_stack.is_empty():
		var entry: Dictionary = _spell_stack.pop_back()
		var resolve: Callable = entry["resolve"]
		if resolve.is_valid():
			await resolve.call()
	_update_player_panels()


# Handler for the response window above, per player_index (0 = P1, paused by
# either Space or "1"; 1-3 = P2-P4, paused by "2"-"4" -- see
# _unhandled_input()). Ignored while a spell's own cast prompts are up
# (_casting_spell) so resuming mid-cast can't yank the popup out from under
# whoever's answering it.
func _toggle_pause_for_player(player_index: int) -> void:
	if not _response_window_open or _casting_spell:
		return
	_response_window_paused_by[player_index] = not _response_window_paused_by[player_index]
	if _response_window_paused_by[player_index]:
		dice_label.text += "\nPaused from %s's perspective -- press %d to resume." % [PLAYER_NAMES[player_index], player_index + 1]
	_refresh_action_buttons()
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

	_current_roll = roll
	_roll_in_flight = true
	await _ensure_response_window()
	_roll_in_flight = false
	roll = _current_roll

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
	elif player.is_bankrupt:
		# Nothing left for them to manage -- move straight on rather than
		# pausing on an End Turn button they have no reason to see.
		_advance_turn()
	else:
		_awaiting_end_turn = true
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

	if player.is_ai:
		# Mortgage what it can first; if that's not enough, start selling
		# houses (freeing up more properties to mortgage in the process),
		# then take another pass at mortgaging. Forfeit only if all of that
		# still isn't enough.
		_ai_mortgage_properties(player, amount)
		if player.money < amount:
			_ai_sell_houses(player, amount)
		if player.money < amount:
			_ai_mortgage_properties(player, amount)
		if player.money >= amount:
			_maybe_resolve_debt()
		else:
			dice_label.text += "\n%s can't raise the money and forfeits the game." % _player_display_name(player.player_id)
			_forfeit_to_bankruptcy(player, creditor)
			_in_debt = false
			_debt_amount = 0
			_debt_creditor = null
		return

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
# over, they can simply decline the purchase. While trading, casting a
# spell, or inside the post-roll response window, everything here is off
# (the trade display's own buttons, the spell's own level/target prompts, or
# the response window itself, take over). Otherwise everything is usable --
# including once the player has rolled: rolling doesn't end a turn, so Roll
# turns into End Turn and stays enabled while Admin (a stand-in for rolling)
# turns off until that's clicked.
func _refresh_action_buttons() -> void:
	var limited_to_selling: bool = _in_debt or _awaiting_buy_decision
	# A Computer player's turn plays itself -- lock every button so the
	# human at the keyboard can't act (or trade) on its behalf while it's
	# "thinking".
	var ai_turn: bool = players[current_player].is_ai
	roll_button.disabled = limited_to_selling or _trading or _casting_spell or _response_window_open or ai_turn
	roll_button.text = "End Turn" if _awaiting_end_turn else "Roll"
	admin_button.disabled = limited_to_selling or _trading or _casting_spell or _response_window_open or _awaiting_end_turn or ai_turn
	admin_properties_button.disabled = limited_to_selling or _trading or _casting_spell or _response_window_open or ai_turn
	buy_house_unmortgage_button.disabled = limited_to_selling or _trading or _casting_spell or _response_window_open or ai_turn
	sell_house_mortgage_button.disabled = _trading or _casting_spell or _response_window_open or ai_turn
	declare_bankruptcy_button.disabled = _awaiting_buy_decision or _trading or _casting_spell or _response_window_open or ai_turn
	trade_button.disabled = _awaiting_buy_decision or _trading or _casting_spell or _response_window_open or ai_turn


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
	if players[responder].is_ai:
		if _ai_initiated_trade:
			# Evaluate whatever the other side just sent back -- see
			# _ai_evaluate_trade_counter_offer() for what it'll accept.
			_ai_evaluate_trade_counter_offer(responder)
		else:
			# A trade it didn't ask for itself; it has no negotiation logic
			# for that yet, so it just says no.
			_on_decline_trade_pressed()


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


# b) TradeCheck: for every color set the AI is exactly one property short of
# completing, offers a trade for the missing property if another player
# owns it (does nothing if it's unowned). Only chases the sets that were
# nearly complete at the start of the check -- a trade completed along the
# way doesn't trigger re-scanning for newly-opened opportunities this turn.
func _ai_trade_check(player: Node2D) -> void:
	for color_name in _ai_nearly_completed_sets(player):
		if player.is_bankrupt:
			return
		var group: Array = board.get_color_group(color_name)
		var missing_index: int = -1
		for space_index in group:
			if board.spaces[space_index].owner_id != player.player_id:
				missing_index = space_index
				break
		if missing_index == -1:
			continue
		var owner_id: int = board.spaces[missing_index].owner_id
		if owner_id == -1 or owner_id == player.player_id or players[owner_id].is_bankrupt:
			continue
		var offer_index: int = _ai_pick_trade_offer(player, color_name)
		if offer_index == -1:
			continue
		await _ai_propose_trade(player.player_id, owner_id, offer_index, missing_index)


# Color sets where the AI owns every property but exactly one.
func _ai_nearly_completed_sets(player: Node2D) -> Array[String]:
	var result: Array[String] = []
	for color_name in PROPERTY_COLOR_ORDER:
		var group: Array = board.get_color_group(color_name)
		if group.size() <= 1:
			continue
		var owned_count: int = 0
		for space_index in group:
			if board.spaces[space_index].owner_id == player.player_id:
				owned_count += 1
		if owned_count == group.size() - 1:
			result.append(color_name)
	return result


# The most expensive property the AI can safely offer away in exchange for
# `target_color`: never one from that same set (defeats the point of the
# trade), never one from a set it already owns outright (protects its
# monopolies), and never one with houses anywhere in its group (the trade
# UI won't allow that anyway).
func _ai_pick_trade_offer(player: Node2D, target_color: String) -> int:
	var candidates: Array[int] = []
	for space_index in player.owned_property_indices:
		var color_name: String = board.get_space_info(space_index).get("color", "")
		if color_name == target_color:
			continue
		if _owns_full_color_group(player.player_id, color_name):
			continue
		if _max_houses_in_group(color_name) > 0:
			continue
		candidates.append(space_index)
	if candidates.is_empty():
		return -1
	candidates.sort_custom(func(a, b): return board.get_space_info(a).get("price", 0) > board.get_space_info(b).get("price", 0))
	return candidates[0]


func _ai_propose_trade(ai_id: int, target_id: int, offer_index: int, want_index: int) -> void:
	_ai_initiated_trade = true
	_start_trade(ai_id, target_id)
	_trade1_offered.append(offer_index)
	_trade2_offered.append(want_index)
	_update_player_panels()
	_send_trade_offer()
	await trade_concluded


# Called when a modified counter-offer comes back to an AI in a trade it
# itself started (see _ai_trade_check). It only ever accepts a clean
# one-for-one property swap with no money attached, and only if what it
# would be giving away still respects the same rules that governed its
# original offer. Anything else -- more properties, any money, or a
# property from a protected set -- gets declined.
func _ai_evaluate_trade_counter_offer(ai_index: int) -> void:
	var ai_offered: Array[int] = _trade1_offered if ai_index == _trader1 else _trade2_offered
	var other_offered: Array[int] = _trade2_offered if ai_index == _trader1 else _trade1_offered
	var money1: int = int(trader1_money_edit.text)
	var money2: int = int(trader2_money_edit.text)
	var acceptable: bool = ai_offered.size() == 1 and other_offered.size() == 1 and money1 == 0 and money2 == 0
	if acceptable:
		var give_color: String = board.get_space_info(ai_offered[0]).get("color", "")
		var get_color: String = board.get_space_info(other_offered[0]).get("color", "")
		if give_color == get_color or _owns_full_color_group(players[ai_index].player_id, give_color):
			acceptable = false
	if acceptable:
		_finalize_trade()
	else:
		_on_decline_trade_pressed()


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
	_ai_initiated_trade = false
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
	trade_concluded.emit()


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


# Shared tail of every bankruptcy path (voluntary or debt-forced, human or
# AI): liquidate, check for a winner, and refresh the panels. Callers are
# responsible for the dice_label message, since its wording differs and has
# to be set before this runs -- _check_for_winner() appends to it.
func _forfeit_to_bankruptcy(player: Node2D, creditor: Node2D) -> void:
	_bankrupt_player(player, creditor)
	_check_for_winner()
	_update_player_panels()


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
		dice_label.text = "%s declared bankruptcy and forfeits the game." % forfeiting_name
		_forfeit_to_bankruptcy(player, creditor)
		if _in_debt:
			_in_debt = false
			_debt_amount = 0
			_debt_creditor = null
			debt_resolved.emit()
		else:
			_advance_turn()

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
	if players[current_player].is_ai:
		# Always wants the property; mortgages (never sells houses) to
		# cover the price if it's short, and gives up only if that's not
		# enough either.
		var player: Node2D = players[current_player]
		if player.money < price:
			_ai_mortgage_properties(player, price)
		return player.money >= price
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


# Attunement to a color: how many properties of that color the player owns,
# plus any Temporary Attunement from burning spells of that color this turn.
func _color_attunement(player: Node2D, color_name: String) -> int:
	if color_name == "":
		return 0
	return _count_owned_in_group(player.player_id, color_name) + player.temp_attunement.get(color_name, 0)


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


# Shows the full card art for a spell, regardless of whose turn it is --
# same as right-clicking a property mini card, this is just for looking, so
# it isn't gated by any turn/state checks.
func _on_spell_right_clicked(hand_index: int, player_index: int) -> void:
	if hand_index < 0 or hand_index >= players[player_index].spell_hand.size():
		return
	var spell_name: String = players[player_index].spell_hand[hand_index]
	var spell_info: Dictionary = SpellData.SPELLS.get(spell_name, {})
	spell_card.show_card(load(spell_info.get("icon", "")))


# Kicks off interacting with a spell from `player_index`'s hand: pick a
# level, or Burn for Attunement instead. Only one such interaction at a
# time, per _casting_spell, and only the card's owner (obviously) -- neither
# of those depend on timing. Burning is always legal (it's Instant Speed for
# every spell, not just ones marked Instant -- see _burn_spell_for_attunement()),
# but actually casting a level checks _level_timing_allowed() (most spells
# are turn-only; some levels are only usable responding to a roll or another
# spell) and then Attunement (_color_attunement() must be >= the level).
func _on_spell_clicked(hand_index: int, player_index: int) -> void:
	if _casting_spell:
		return
	var caster: Node2D = players[player_index]
	if caster.is_bankrupt or caster.is_ai:
		return
	if hand_index < 0 or hand_index >= caster.spell_hand.size():
		return
	var spell_name: String = caster.spell_hand[hand_index]
	var spell_info: Dictionary = SpellData.SPELLS.get(spell_name, {})
	var levels: Dictionary = spell_info.get("levels", {})
	if levels.is_empty():
		return
	var color_name: String = spell_info.get("color", "")

	_casting_spell = true
	_refresh_action_buttons()

	var level_entries: Array = []
	for level in levels.keys():
		level_entries.append({"index": level, "name": "Level %d: %s" % [level, levels[level].get("description", "")], "color": Color.WHITE})
	level_entries.sort_custom(func(a, b): return a["index"] < b["index"])
	level_entries.append({"index": BURN_FOR_ATTUNEMENT_INDEX, "name": "Burn for Attunement (+1 %s Attunement)" % color_name.capitalize(), "color": Color.WHITE})

	player_picker.open("Cast %s at what level?" % spell_name, level_entries)
	var choice: int = await player_picker.player_chosen

	# Only actually push a cast onto the stack -- and open/extend the
	# response window for it -- once _casting_spell is released below, so
	# other players' clicks (e.g. a response to this very cast) aren't
	# locked out for the window's whole 2+ seconds.
	var post_cast: Callable = Callable()
	if choice == BURN_FOR_ATTUNEMENT_INDEX:
		_burn_spell_for_attunement(caster, hand_index, spell_name, color_name)
	elif choice != -1:
		if not _level_timing_allowed(caster, spell_name, choice):
			dice_label.text = "%s can't cast %s at Level %d right now -- wrong timing." % [_player_display_name(caster.player_id), spell_name, choice]
		else:
			var attunement: int = _color_attunement(caster, color_name)
			if attunement < choice:
				dice_label.text = "%s doesn't have enough %s Attunement to cast %s at Level %d (has %d, needs %d)." % [_player_display_name(caster.player_id), color_name.capitalize(), spell_name, choice, attunement, choice]
			else:
				var resolve: Callable = await _prepare_spell_cast(caster, spell_name, choice)
				if resolve.is_valid():
					post_cast = _finish_cast.bind(caster, hand_index, spell_name, choice, resolve)

	_casting_spell = false
	_refresh_action_buttons()

	if post_cast.is_valid():
		await post_cast.call()


# Discards a spell without its effect in exchange for +1 Temporary
# Attunement of its color, lasting until the start of this player's next
# turn (see _advance_to_next_active_player()). Always legal regardless of
# timing or whether the spell itself is Instant -- burning for Attunement is
# Instant Speed for every spell.
func _burn_spell_for_attunement(caster: Node2D, hand_index: int, spell_name: String, color_name: String) -> void:
	caster.spell_hand.remove_at(hand_index)
	if color_name != "":
		caster.temp_attunement[color_name] = caster.temp_attunement.get(color_name, 0) + 1
	dice_label.text = "%s burned %s for +1 %s Attunement." % [_player_display_name(caster.player_id), spell_name, color_name.capitalize()]
	_update_player_panels()


# Whether `level` of `spell_name` can actually be *cast* (not burned -- that
# has no timing restriction) right now, per its "timings" list:
# - "turn": only the current player, only on their own ordinary turn (no
#   response window open, and not mid-trade/debt/buy-decision) -- this is
#   the only timing most spells have.
# - "roll_response": only while a roll is in flight and *this caster*
#   (specifically) has paused the window from their own perspective -- see
#   _roll_in_flight, _response_window_paused_by. With several humans at the
#   table, one pausing doesn't open casting to everyone; each player only
#   ever unlocks their own casting by pausing themselves.
# - "spell_response": same, but there just needs to be a spell on the stack
#   to respond to, instead of a roll in flight.
# "exclude_current_player" (used by T2 Response Spell's roll-decreasing
# Level 2 -- it only makes sense against an *opponent's* roll) additionally
# requires the caster not be whoever the timing is centered on.
# "requires_current_player" is the opposite (used by T3 Escape Spell -- it
# only makes sense on your *own* roll, not an opponent's) and additionally
# requires the caster BE whoever the timing is centered on.
func _level_timing_allowed(caster: Node2D, spell_name: String, level: int) -> bool:
	var level_info: Dictionary = SpellData.SPELLS[spell_name]["levels"][level]
	var timings: Array = level_info.get("timings", ["turn"])
	var is_caster_current: bool = caster.player_id == current_player
	var excludes_caster: bool = level_info.get("exclude_current_player", false) and is_caster_current
	var requires_caster: bool = level_info.get("requires_current_player", false) and not is_caster_current
	var caster_has_paused: bool = _response_window_paused_by[caster.player_id]

	if timings.has("turn") and not _response_window_open:
		if is_caster_current and not _trading and not _in_debt and not _awaiting_buy_decision:
			return true
	if timings.has("spell_response") and caster_has_paused and not _spell_stack.is_empty() and not excludes_caster and not requires_caster:
		return true
	if timings.has("roll_response") and caster_has_paused and _roll_in_flight and not excludes_caster and not requires_caster:
		return true
	return false


# Gathers whatever targets `spell_name` at `level` needs (which may fail or
# be cancelled, e.g. an empty opponent-picker or a target picker the caster
# backs out of) and returns a zero-arg Callable that applies the effect --
# or an invalid Callable if nothing was actually cast, in which case the
# caller must leave the card in the caster's hand untouched.
func _prepare_spell_cast(caster: Node2D, spell_name: String, level: int) -> Callable:
	match spell_name:
		"T1 Burn Spell":
			return await _prepare_t1_burn_spell(caster, level)
		"T3 Escape Spell":
			return _prepare_t3_escape_spell(caster, level)
		"T2 Response Spell":
			if level == 1:
				return await _prepare_t2_counter(caster)
			elif level == 2:
				return _prepare_t2_decrease_roll(caster)
	return Callable()


# Removes the card from `caster`'s hand, pushes `resolve` onto the stack,
# and opens (or, if one's already running, just extends) the response
# window for it -- see _ensure_response_window().
func _finish_cast(caster: Node2D, hand_index: int, spell_name: String, level: int, resolve: Callable) -> void:
	caster.spell_hand.remove_at(hand_index)
	var stack_id: int = _next_stack_id
	_next_stack_id += 1
	var display_name: String = "%s (Level %d)" % [spell_name, level]
	_spell_stack.append({"id": stack_id, "caster_id": caster.player_id, "display_name": display_name, "resolve": resolve})
	dice_label.text += "\n%s casts %s!" % [_player_display_name(caster.player_id), display_name]
	_update_player_panels()
	await _ensure_response_window()


# T1 Burn Spell: the caster picks an opponent to target now; the payment
# itself (checked against the opponent's money at the time) happens at
# resolution, in case things change while it's pending on the stack.
func _prepare_t1_burn_spell(caster: Node2D, level: int) -> Callable:
	var entries: Array = []
	for i in players.size():
		if i != caster.player_id and not players[i].is_bankrupt:
			entries.append({"index": i, "name": PLAYER_NAMES[i], "color": PLAYER_COLORS[i]})
	if entries.is_empty():
		dice_label.text += "\nThere's no opponent to burn."
		return Callable()

	player_picker.open("T1 Burn Spell: choose an opponent to pay you.", entries)
	var target_index: int = await player_picker.player_chosen
	if target_index == -1:
		return Callable()

	var amount: int = SpellData.SPELLS["T1 Burn Spell"]["levels"][level].get("amount", 0)
	return _resolve_t1_burn_spell.bind(caster, level, target_index, amount)


# An opponent who can't afford the full amount just pays what they have --
# there's no bankruptcy-by-spell yet, only the usual debt collection from
# landing on rent/tax. If the target's since gone bankrupt entirely (e.g.
# forfeited while this was pending), the spell just fizzles.
func _resolve_t1_burn_spell(caster: Node2D, level: int, target_index: int, amount: int) -> void:
	var opponent: Node2D = players[target_index]
	if opponent.is_bankrupt:
		dice_label.text = "%s's T1 Burn Spell (Level %d) fizzles -- %s is already out of the game." % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index]]
		return
	var payment: int = mini(amount, opponent.money)
	opponent.money -= payment
	caster.money += payment
	if payment < amount:
		dice_label.text = "%s's T1 Burn Spell (Level %d) resolves on %s, who could only pay $%d of the $%d owed." % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index], payment, amount]
	else:
		dice_label.text = "%s's T1 Burn Spell (Level %d) resolves on %s for $%d!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index], amount]
	_update_player_panels()


# T3 Escape Spell (Instant): no target to pick, so preparing it just needs
# the level's bonus.
func _prepare_t3_escape_spell(caster: Node2D, level: int) -> Callable:
	var bonus: int = SpellData.SPELLS["T3 Escape Spell"]["levels"][level].get("roll_bonus", 0)
	return _resolve_t3_escape_spell.bind(caster, level, bonus)


# Bumps _current_roll, which whichever _ensure_response_window() call is
# covering the in-flight roll is holding onto, regardless of who casts this.
func _resolve_t3_escape_spell(caster: Node2D, level: int, bonus: int) -> void:
	_current_roll += bonus
	dice_label.text = "%s's T3 Escape Spell (Level %d) resolves! Roll increased by %d (now %d)." % [_player_display_name(caster.player_id), level, bonus, _current_roll]
	_update_player_panels()


# T2 Response Spell, Level 1 (Instant, spell_response only): the caster
# picks which pending spell on the stack to counter.
func _prepare_t2_counter(caster: Node2D) -> Callable:
	var entries: Array = []
	for entry in _spell_stack:
		entries.append({"index": entry["id"], "name": "%s's %s" % [_player_display_name(entry["caster_id"]), entry["display_name"]], "color": PLAYER_COLORS[entry["caster_id"]]})
	entries.reverse()  # show the most recently cast (top of stack) first

	player_picker.open("T2 Response Spell: choose a spell to counter.", entries)
	var target_id: int = await player_picker.player_chosen
	if target_id == -1:
		return Callable()
	return _resolve_t2_counter.bind(caster, target_id)


# Removes the targeted entry from the stack before it's ever popped --
# per "countering negates the effect and discards it". If it's already gone
# (resolved or countered by someone else in the meantime), this just
# fizzles.
func _resolve_t2_counter(caster: Node2D, target_id: int) -> void:
	for i in _spell_stack.size():
		if _spell_stack[i]["id"] == target_id:
			var countered: Dictionary = _spell_stack[i]
			_spell_stack.remove_at(i)
			dice_label.text = "%s's T2 Response Spell (Level 1) counters %s's %s!" % [_player_display_name(caster.player_id), _player_display_name(countered["caster_id"]), countered["display_name"]]
			return
	dice_label.text = "%s's T2 Response Spell (Level 1) had nothing left to counter." % _player_display_name(caster.player_id)


# T2 Response Spell, Level 2 (Instant, roll_response only, opponent's roll
# only): no target to pick -- there's only ever one roll in flight, and
# exclude_current_player already keeps the caster from targeting their own.
func _prepare_t2_decrease_roll(caster: Node2D) -> Callable:
	return _resolve_t2_decrease_roll.bind(caster)


func _resolve_t2_decrease_roll(caster: Node2D) -> void:
	_current_roll = maxi(0, _current_roll - 1)
	dice_label.text = "%s's T2 Response Spell (Level 2) resolves! %s's roll decreased by 1 (now %d)." % [_player_display_name(caster.player_id), _player_display_name(current_player), _current_roll]
	_update_player_panels()


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
			# Temporary Attunement (from burning spells) only lasts until the
			# start of the turn it was gained on.
			players[current_player].temp_attunement.clear()
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
		var pause_marker: String = " (Paused)" if _response_window_paused_by[i] else ""
		player_header_labels[i].text = "%s%s -- $%d" % [_player_display_name(i), pause_marker, players[i].money]

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

		var spell_flow: HFlowContainer = player_spells_flows[i]
		for child in spell_flow.get_children():
			child.queue_free()
		for hand_index in players[i].spell_hand.size():
			var spell_name: String = players[i].spell_hand[hand_index]
			var spell_info: Dictionary = SpellData.SPELLS.get(spell_name, {})
			var mini_spell: Control = MINI_SPELL_CARD_SCENE.instantiate()
			spell_flow.add_child(mini_spell)
			mini_spell.setup(hand_index, load(spell_info.get("icon", "")))
			mini_spell.card_clicked.connect(_on_spell_clicked.bind(i))
			mini_spell.card_right_clicked.connect(_on_spell_right_clicked.bind(i))

		var attunement_flow: HFlowContainer = player_attunement_flows[i]
		for child in attunement_flow.get_children():
			child.queue_free()
		for color_name in players[i].temp_attunement:
			var count: int = players[i].temp_attunement[color_name]
			if count <= 0:
				continue
			var chip := Label.new()
			chip.text = "%s +%d" % [color_name.capitalize(), count]
			chip.add_theme_color_override("font_color", board.COLOR_GROUP_COLORS.get(color_name, Color.WHITE))
			attunement_flow.add_child(chip)

	if _trading:
		_populate_trade_flow(trader1_flow, _trade1_offered)
		_populate_trade_flow(trader2_flow, _trade2_offered)
