extends Node2D

# Small enough that a full 8-marker cluster fits on one board space (see
# main.gd's MARKER_OFFSETS).
const RADIUS: float = 10.0
# The playing piece (player_markers.gd) is drawn this big, centred on the
# player's position, tinted toward their colour by MARKER_TINT (0 = the plain
# white piece, 1 = solid colour). Its dark line art stays dark.
const MARKER_SIZE: float = 34.0
const MARKER_TINT: float = 0.6
const OUTLINE_OFFSETS: Array[Vector2] = [
	Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5),
	Vector2(-1.1, -1.1), Vector2(1.1, -1.1), Vector2(-1.1, 1.1), Vector2(1.1, 1.1),
]
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


var marker: String = ""
var _marker_texture: Texture2D = null


func setup(id: int, color: Color, marker_name: String = "") -> void:
	player_id = id
	player_color = color
	marker = marker_name
	_marker_texture = PlayerMarkers.icon(marker_name)
	queue_redraw()


func _draw() -> void:
	if _marker_texture == null:
		# No piece chosen: the plain coloured counter.
		draw_circle(Vector2.ZERO, RADIUS, player_color)
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color.BLACK, 2.0)
		return
	var rect := Rect2(Vector2(-MARKER_SIZE, -MARKER_SIZE) * 0.5, Vector2(MARKER_SIZE, MARKER_SIZE))
	# A dark outline (the piece's silhouette drawn black, nudged around it)
	# so it stands out on any tile, then the piece tinted toward the
	# player's colour.
	for off in OUTLINE_OFFSETS:
		draw_texture_rect(_marker_texture, Rect2(rect.position + off, rect.size), false, Color(0.05, 0.05, 0.08, 0.9))
	draw_texture_rect(_marker_texture, rect, false, Color.WHITE.lerp(player_color, MARKER_TINT))
