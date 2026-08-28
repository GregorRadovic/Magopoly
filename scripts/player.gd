extends Node2D

const RADIUS: float = 15.0
const STARTING_MONEY: int = 1500

var player_id: int = 0
var player_color: Color = Color.WHITE
var current_space: int = 0
var money: int = STARTING_MONEY
var in_jail: bool = false
var jail_turns_left: int = 0
var consecutive_doubles: int = 0
var owned_property_indices: Array[int] = []
var is_bankrupt: bool = false
var is_ai: bool = false
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
# Spell name -> number of copies to pull back out of the shared deck and
# into this player's hand at the end of the turn they were cast on (Sanity
# Grinding, Step Forward). See _queue_spell_return_to_hand() in main.gd.
var pending_return_spells: Dictionary = {}
# The Cult of Terminus, Level 1: the next railroad this player buys this
# turn (via the normal landing-purchase flow only) costs $0.
var free_railroad_purchase: bool = false


func setup(id: int, color: Color) -> void:
	player_id = id
	player_color = color
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, player_color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color.BLACK, 2.0)
