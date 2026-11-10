extends Node2D

# Small enough that a full 8-marker cluster fits on one board space (see
# main.gd's MARKER_OFFSETS).
const RADIUS: float = 10.0
const STARTING_MONEY: int = 1500

var player_id: int = 0
var player_color: Color = Color.WHITE
var current_space: int = 0

# Emitted whenever money goes down, for any reason (Fragile Goods discards
# itself on this -- see main.gd's _on_player_money_lost()).
signal money_lost(player_id: int)

var money: int = STARTING_MONEY:
	set(value):
		var lost: bool = value < money
		money = value
		if lost:
			money_lost.emit(player_id)
var in_jail: bool = false
var jail_turns_left: int = 0
var consecutive_doubles: int = 0
var owned_property_indices: Array[int] = []
var is_bankrupt: bool = false
var is_ai: bool = false
# A disconnected human this seat belongs to hasn't reconnected -- the seat sits
# idle (no one can act for it) until they come back, the host kicks them
# (instant bankruptcy, see main.gd's _host_kick_player), or the host takes
# their turn (see below). Display-only otherwise; never implies is_ai.
var is_disconnected: bool = false
# True only while the host's "Take Player's Turn" tool is actively driving
# this seat's turn (main.gd's _host_take_player_turn / _on_peer_gone no longer
# sets this on a plain disconnect). Always implies is_ai for that one turn;
# a stripped-down AI that only rolls, buys what it lands on, and pays what it
# owes -- it skips the regular AI's house / trade / mortgage upkeep. Cleared
# the moment that single turn ends.
var is_placeholder_ai: bool = false
# Spell names held in hand, one entry per copy (duplicates allowed, no limit).
var spell_hand: Array[String] = []
# Color name -> bonus Attunement from burning spells for it this turn. Wiped
# at the start of this player's next turn.
var temp_attunement: Dictionary = {}

# "This turn" spell buffs -- all wiped at the end of whichever turn they
# were set on (see _advance_to_next_active_player() in main.gd), regardless
# of whose turn that is.
#
# Counterfeit Currency: cuts the next payment this player owes an opponent
# by this much (floored at $0), then resets to 0 -- covers one payment only.
var payment_reduction_buffer: int = 0
# Hasty Exit, Level 1: added to this player's own next roll this turn, then
# reset to 0 once that roll happens.
var next_roll_bonus: int = 0
# Price Gouging: extra house-equivalents (capped at 5 total) any opponent's
# rent is calculated with when they land on one of this player's properties
# this turn.
var price_gouging_bonus_houses: int = 0
# Unstable Portal: multiplies this player's own next roll this turn, then
# resets to 1 (no-op) once that roll happens.
var next_roll_multiplier: int = 1
# Haggling: percent discount (50 or 100) on this player's next property or
# house purchase this turn; 0 = no discount active. Consumed (reset to 0,
# along with haggling_bank_bonus) the moment it's used.
var haggling_discount_percent: int = 0
# Haggling, Level 3: the purchase is already free (100% discount); on top of
# that, the bank also pays out the property/house's full undiscounted price.
var haggling_bank_bonus: bool = false
# Misplaced Payment: the next payment this player would make to an opponent
# this turn goes to Free Parking instead, scaled to this percent of the
# amount (100 = all of it, 50 = half); 0 = no redirect active. Consumed the
# moment it's used.
var misplaced_payment_percent: int = 0
# Siren's Song: this player's next roll this turn is increased until it
# lands on the opponent's property with the highest rent. Consumed by that
# roll.
var siren_song_active: bool = false

# Loaded Dice -- "this turn" state, cleared at the end of the turn:
# Master Plan level (0 = none) applied to this player's next roll.
var master_plan_level: int = 0
# Pilgrimage: space indices this player may buy as they pass them.
var pilgrimage_spaces: Array[int] = []
# Go For the Kill: what each player passed while moving pays this player
# (summed across casts).
var go_for_the_kill_amount: int = 0
# Critical Hit's "if you rolled doubles this turn".
var rolled_doubles_this_turn: bool = false

# Fated Ending -- NOT a "this turn" buff: applied to this player's next roll
# on a later turn. {} = none, else {"level": int, "caster": player id}.
var fated_ending: Dictionary = {}

# Cramped Cell -- NOT a "this turn" buff: lasts for as long as this player
# stays in jail. One entry per resolved cast: {"creditor": player id,
# "amount": int}, charged at the start of each of this player's turns while
# in_jail, and cleared whenever they leave jail (see main.gd's
# _release_from_jail() / _send_to_jail()).
var cramped_cell_debts: Array = []

# Spell name -> number of copies to pull back out of the shared deck and
# into this player's hand at the end of the turn they were cast on (Sanity
# Grinding, Step Forward). See _queue_spell_return_to_hand() in main.gd.
var pending_return_spells: Dictionary = {}


func setup(id: int, color: Color) -> void:
	player_id = id
	player_color = color
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, player_color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color.BLACK, 2.0)
