extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const PLAYER_ROW_SCENE: PackedScene = preload("res://scenes/player_row.tscn")
const MINI_CARD_SCENE: PackedScene = preload("res://scenes/mini_property_card.tscn")
const MINI_SPELL_CARD_SCENE: PackedScene = preload("res://scenes/mini_spell_card.tscn")
const CARDBACK_TEXTURE: Texture2D = preload("res://Magopoly Assets/Cardback.jpg")

# The shared Spell Deck's starting contents -- T1/T2/T3 were placeholder
# test cards and are no longer part of it; only real created cards belong
# here now, 1 copy each. See _build_spell_deck().
const SPELL_DECK_STARTING_COUNTS: Dictionary = {
	"Counterfeit Currency": 1,
	"Snatch Purse": 1,
	"Hasty Exit": 1,
	"Price Gouging": 1,
	"Divination": 1,
	"Migraine": 1,
	"Counterbalance": 1,
	"Impossible Architecture": 1,
	"Promised Land": 1,
	"Break Bread": 1,
	"Smite": 1,
	"Divine Protection": 1,
	"Art of the Deal": 1,
	"Escape Plan": 1,
	"Offer You Can't Refuse": 1,
	"Haggling": 1,
	"Burn to the Ground": 1,
	"Line of Fire": 1,
	"Unstable Portal": 1,
	"Threaten": 1,
	"Royal Aid": 1,
	"Taxes": 1,
	"Far-Reaching Empire": 1,
	"Annexation": 1,
	"Adrenaline": 1,
	"Overflowing Bounty": 1,
	"Sinkhole": 1,
	"Reclaimed by Nature": 1,
	"Sanity Grinding": 1,
	"Spell Mastery": 1,
	"Tax Haven": 1,
	"Step Forward": 1,
	"Manastone": 4,
	"The Cult of Terminus": 4,
}
# Sentinel "level" for the level-picker's extra "Burn for Attunement" entry --
# safe from colliding with a real spell level. Real levels are almost always
# >= 1, but Manastone has a real Level 0, so this has to sit well outside
# that range rather than just below it.
const BURN_FOR_ATTUNEMENT_INDEX: int = -100

# Sentinel for the Spell Shop picker's "Skip" entry -- safe from colliding
# with a real top-of-deck card index (0..3).
const SPELL_SHOP_SKIP_INDEX: int = -2

# How long a response window (see _ensure_response_window()) lasts before
# automatically continuing, if nobody pauses it (or extends it by casting
# another spell in response). Doubled online (see _response_window_seconds())
# to cover the round trip of a remote player's pause.
const RESPONSE_WINDOW_SECONDS: float = 1.5

# Up to GameState.MAX_PLAYERS (8) of each. Colours are the four classic
# player colours plus four more that still read clearly on the board.
const PLAYER_COLORS: Array[Color] = [
	Color(0.85, 0.2, 0.2),    # red
	Color(0.2, 0.4, 0.85),    # blue
	Color(0.2, 0.75, 0.3),    # green
	Color(0.9, 0.8, 0.15),    # yellow
	Color(0.6, 0.3, 0.8),     # purple
	Color(0.95, 0.55, 0.1),   # orange
	Color(0.15, 0.75, 0.8),   # cyan
	Color(0.95, 0.45, 0.65),  # pink
]
const PLAYER_NAMES: Array[String] = [
	"Player 1", "Player 2", "Player 3", "Player 4",
	"Player 5", "Player 6", "Player 7", "Player 8",
]
# Where each player's marker sits within its board space (screen-space offset
# from the space centre). A 4x2 grid, tight enough for the narrow edge tiles.
const MARKER_OFFSETS: Array[Vector2] = [
	Vector2(-27, -13), Vector2(-9, -13), Vector2(9, -13), Vector2(27, -13),
	Vector2(-27, 13), Vector2(-9, 13), Vector2(9, 13), Vector2(27, 13),
]
const JAIL_SPACE_INDEX: int = 10
const JAIL_SENTENCE_TURNS: int = 3
const DOUBLES_JAIL_THRESHOLD: int = 3
const PROPERTY_COLOR_ORDER: Array[String] = [
	"brown", "sky_blue", "pink", "orange", "red", "yellow", "green", "ocean_blue", "railroad", "utility",
]
# The 8 real Monopoly color groups -- excludes "railroad" and "utility",
# which aren't "colors" for spells like Far-Reaching Empire and Overflowing
# Bounty that count/target "each color".
const REAL_PROPERTY_COLORS: Array[String] = [
	"brown", "sky_blue", "pink", "orange", "red", "yellow", "green", "ocean_blue",
]
# Every color a player can actually hold Temporary Attunement for (used by
# Manastone's color picker and Overflowing Bounty's "gain to each color").
# Includes "black" (no board color group, but explicitly attunable per
# Manastone/Overflowing Bounty) -- deliberately excludes "railroad" and
# "utility", neither of which can ever be Temporary Attunement targets (see
# _on_spell_clicked()'s Burn for Attunement gating for the Utility case).
const ATTUNABLE_COLORS: Array[String] = [
	"brown", "sky_blue", "pink", "orange", "red", "yellow", "green", "ocean_blue", "black",
]
# Tax Haven's two eligible spaces.
const LUXURY_TAX_INDEX: int = 38
const INCOME_TAX_INDEX: int = 4
# Terminus Station (created by The Cult of Terminus, Level 4) shares a
# normal railroad's rent tiers, plus the extra 5th tier every railroad gains
# once it exists.
const TERMINUS_RAILROAD_RENTS: Array[int] = [25, 50, 100, 200]
const TERMINUS_FIVE_RAILROAD_RENT: int = 300

# Tutorial mode script (Main Menu > Tutorial). Each step shows its "text" in
# the bubble at the bottom of the screen. A step with an "action" forces the
# player to make exactly that play -- anything else toasts "Follow the
# instructions!". A step with no "action" advances on any click (see
# _input()). "tag" names a jump target (used by _tutorial_goto, e.g. the
# rewind after missing the pause window). "forced_roll" pins the dice.
#
# Action slugs and where they're handled:
#   inspect_migraine -- right-click the Migraine card        (_on_spell_right_clicked)
#   cast_<spell>     -- left-click that card, then its pickers (_on_spell_clicked
#                       + _tutorial_gate_check + _tutorial_on_spell_finished)
#   burn_rbn         -- pick "Burn for Attunement" in RbN's picker
#   pick_level / pick_target -- Migraine's two pickers
#   roll             -- click the Roll button
#   press_space      -- press Space to pause the roll's response window
#   await_manastone / await_adrenaline -- no input: the game un-pauses and the
#                       open reaction window runs down so that spell resolves
#                       on its own (advanced by _tutorial_on_spell_resolved).
#                       The caster is auto-paused again once it resolves (the
#                       cast-while-paused rule -- see _apply_auto_pause).
#   unpause_after_adrenaline -- press Space to lift that auto-pause so the
#                       (Adrenaline-boosted) roll finally resolves
#   buy_oriental     -- click Yes on the Oriental Avenue buy prompt
#   end_turn         -- click End Turn
const TUTORIAL_STEPS: Array[Dictionary] = [
	{"text": "Welcome to the Magopoly tutorial!"},
	{"text": "We assume you know the rules of regular Monopoly; this tutorial will tell you how spells work."},
	{"text": "We've started you with a few properties and a few spells to make this easier."},
	{"text": "Right click on a spell to see what it does. Right click on the sky blue spell, Migraine.", "action": "inspect_migraine"},
	{"text": "Each spell has different levels, determined by the amount of unmortgaged properties you own of that spell's color."},
	{"text": "For example, since you have two sky-blue properties, you can cast Migraine at level 2."},
	{"text": "Left click Migraine to cast it.", "action": "cast_migraine"},
	{"text": "For now let's cast it at level 2.", "action": "pick_level"},
	{"text": "Now target your opponent.", "action": "pick_target"},
	{"text": "Great job! You just cast your first spell!"},
	{"text": "Now let's roll the dice to move for our turn. Click the Roll button.", "action": "roll", "forced_roll": Vector2i(1, 3), "tag": "roll"},
	{"text": "Quick! Press Space Bar!", "action": "press_space"},
	{"text": "Space Bar is how you pause the game to indicate that you want to cast a spell."},
	{"text": "This is important because many spells have effects that can only be used at certain times. For example, look at Adrenaline."},
	{"text": "Adrenaline lets you increase your roll so that instead of landing on Income Tax, you can land on a property you want."},
	{"text": "The problem is, you don't own any green properties! But fortunately, there's another way to gain Attunement to a color."},
	{"text": "Left-click on your other green spell, Reclaimed by Nature.", "action": "cast_rbn"},
	{"text": "As you can see, all spells have the 'burn for attunement' option. This means you can discard that spell to gain 1 Temporary Attunement to that color. Burn Reclaimed by Nature now.", "action": "burn_rbn"},
	{"text": "Now we'd be able to cast Adrenaline at Level 1, but we can do better than that. Look at your Manastone."},
	{"text": "Manastones are a special type of card that help smooth out your mana. They get stronger if you own utilities, but even without them, you can still cast them at level 0."},
	{"text": "Cast Manastone at level 0 now, adding 1 Green Attunement.", "action": "cast_manastone"},
	{"text": "Spells go on the stack when cast, where they wait to resolve. Players can cast other spells in response."},
	{"text": "You could pause now to cast a spell in response to Manastone, but we want to let it resolve first to give you your attunement."},
	{"text": "Wait for the Manastone to resolve...", "action": "await_manastone"},
	{"text": "You automatically pause again after your spell resolves. Now you have all the Green attunement you need."},
	{"text": "Cast Adrenaline at level 2.", "action": "cast_adrenaline"},
	{"text": "Wait for Adrenaline to resolve...", "action": "await_adrenaline"},
	{"text": "As you can see, your path has changed. Now you are landing on Oriental Avenue instead of Income Tax."},
	{"text": "Since you have no more spells to cast, press spacebar again to unpause.", "action": "unpause_after_adrenaline"},
	{"text": "Now you can buy Oriental Avenue.", "action": "buy_oriental"},
	{"text": "One last thing: You'll notice you still have your temporary attunement. That lasts until the start of your next turn."},
	{"text": "Let's make use of it before it goes away. Cast Sinkhole on your opponent.", "action": "cast_sinkhole"},
	{"text": "Great job!"},
	{"text": "There are three times when you can pause to cast spells: After your roll; after an opponent's roll; and whenever a player casts a spell."},
	{"text": "Some spells are marked as \"Slow\", meaning you can only play them on your turn before or after your roll."},
	{"text": "You can still do things on your turn after rolling, such as trading or building houses. For now, simply click End Turn to end the tutorial.", "action": "end_turn"},
	{"text": "Congratulations! That's the basics of casting spells in Magopoly!"},
	{"text": "Now you're ready to start playing for real. Good luck!"},
]
# Shown by _tutorial_rewind_roll() when the player misses the "press Space"
# window; the next click jumps back to the "roll" step. Not a TUTORIAL_STEPS
# entry so it never lands in the linear flow.
const TUTORIAL_MISSED_TEXT: String = "Darn, you missed it! Let's rewind and try that again."

# The fixed opening hands for Tutorial mode -- the script relies on exactly
# these cards. P1 (the human) gets two sky-blue properties and five spells;
# the Computer gets five Step Forwards.
const TUTORIAL_P1_PROPERTIES: Array[int] = [8, 9]  # Vermont Ave, Connecticut Ave
const TUTORIAL_P1_SPELLS: Array[String] = [
	"Migraine", "Reclaimed by Nature", "Adrenaline", "Sinkhole", "Manastone",
]
const TUTORIAL_OPPONENT_SPELLS: Array[String] = [
	"Step Forward", "Step Forward", "Step Forward", "Step Forward", "Step Forward",
]

signal debt_resolved
# Emitted whenever a trade negotiation reaches a conclusion (finalized or
# declined), so an AI-initiated trade (see _ai_trade_check) can await the
# outcome before moving on to its next check.
signal trade_concluded
# Emitted by _on_space_clicked() when _picking_promised_land_property is
# armed, so _prepare_promised_land()'s Level 3 can await a board click the
# same way other picking modes (admin, house-building) are driven by that
# flag, just via a signal instead of a follow-up function call. -1 if the
# clicked space isn't actually a valid target (see _prepare_promised_land()).
signal board_space_picked(index: int)

@onready var board: Node2D = $Board
@onready var players_container: Node2D = $Players
@onready var wizard_vision_line: Node2D = $WizardVisionLine
@onready var roll_button: Button = $UI/Panel/VBox/RollButton
@onready var admin_row: HBoxContainer = $UI/Panel/VBox/AdminRow
@onready var admin_button: Button = $UI/Panel/VBox/AdminRow/AdminButton
@onready var admin_properties_button: Button = $UI/Panel/VBox/AdminRow/AdminPropertiesButton
@onready var admin_spells_button: Button = $UI/Panel/VBox/AdminRow/AdminSpellsButton
@onready var buy_house_unmortgage_button: Button = $UI/Panel/VBox/BuyHouseUnmortgageButton
@onready var sell_house_mortgage_button: Button = $UI/Panel/VBox/SellHouseMortgageButton
@onready var buy_house_mode_outline: Panel = $UI/Panel/VBox/BuyHouseUnmortgageButton/ModeOutline
@onready var sell_house_mode_outline: Panel = $UI/Panel/VBox/SellHouseMortgageButton/ModeOutline
@onready var declare_bankruptcy_button: Button = $UI/Panel/VBox/DeclareBankruptcyButton
@onready var trade_button: Button = $UI/Panel/VBox/TradeButton
@onready var turn_label: Label = $UI/Panel/VBox/TurnLabel
@onready var game_log: RichTextLabel = $UI/LogPanel/Log
@onready var toast_panel: Panel = $UI/Toast
@onready var toast_label: Label = $UI/Toast/ToastLabel
@onready var dice_roller: Node2D = $UI/DiceRoller
# The old on-screen status line is gone -- the scrollable log (see _log())
# is the only record now. `dice_label` stays as a throwaway text sink so the
# ~200 `dice_label.text = ...` / `+= ...` call sites don't all need touching.
var dice_label: DiceSink = DiceSink.new()
@onready var number_prompt: PopupPanel = $UI/NumberPrompt
@onready var confirm_prompt: PopupPanel = $UI/ConfirmPrompt
@onready var info_prompt: PopupPanel = $UI/InfoPrompt
@onready var pause_menu: Control = $UI/PauseMenu
@onready var pause_settings_menu: PopupPanel = $UI/SettingsMenu
@onready var rules_viewer: Control = $UI/RulesViewer
@onready var property_card: PopupPanel = $UI/PropertyCard
@onready var asset_card: PopupPanel = $UI/AssetCard
@onready var player_picker: PopupPanel = $UI/PlayerPicker
@onready var spell_card: PopupPanel = $UI/SpellCard
@onready var card_picker: PopupPanel = $UI/CardPicker
@onready var free_parking_label: Label = $UI/PlayersPanel/VBox/FreeParkingLabel
@onready var player_list: VBoxContainer = $UI/PlayersPanel/VBox/PlayersScroll/PlayerList
# One entry per slot, filled by _build_player_rows() from player_row.tscn.
var player_header_labels: Array[Label] = []
var player_properties_flows: Array[HFlowContainer] = []
var player_spells_flows: Array[HFlowContainer] = []
var player_attunement_flows: Array[HFlowContainer] = []
var player_rows: Array[VBoxContainer] = []
var player_row_separators: Array[HSeparator] = []
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
@onready var spell_cast_hseparator: HSeparator = $UI/PlayersPanel/VBox/HSeparatorSpellCast
@onready var spell_cast_display: VBoxContainer = $UI/PlayersPanel/VBox/SpellCastDisplay
@onready var spell_cast_stack: Control = $UI/PlayersPanel/VBox/SpellCastDisplay/SpellCastStack
@onready var tutorial_bubble: Panel = $UI/TutorialBubble
@onready var tutorial_bubble_label: Label = $UI/TutorialBubble/Label
@onready var tutorial_bubble_hint: Label = $UI/TutorialBubble/Hint

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
var _admin_picking_property: bool = false
var _buying_house_or_unmortgaging: bool = false
var _selling_house_or_mortgaging: bool = false
# Promised Land, Level 3: waiting on a board click to pick which unowned
# property to (maybe) buy -- see board_space_picked and
# _prepare_promised_land().
var _picking_promised_land_property: bool = false
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
var _response_window_paused_by: Array[bool] = [false, false, false, false, false, false, false, false]
var _window_deadline_msec: int = 0
# True only while _ensure_response_window() is actually resolving a spell off
# the stack (between reaction windows). Pausing is blocked during this -- the
# resolution itself isn't interruptible.
var _resolving_stack: bool = false

# Pause Options (Settings window). MANUAL: nothing automatic. HALF: the seat
# auto-pauses its own roll windows and the window after its own spell
# resolves. FULL: also every other roll, every cast, and every resolution.
# Auto-pause only ever fires for a seat holding >= 1 spell.
const PAUSE_MANUAL: int = 0
const PAUSE_HALF: int = 1
const PAUSE_FULL: int = 2
# This machine's setting (mirrors pause_settings_menu.pause_option).
var _pause_option: int = PAUSE_MANUAL
# This machine's Wizard Vision setting (mirrors pause_settings_menu). The
# roll-prediction arrow + landing-tile highlight; on by default.
var _wizard_vision_enabled: bool = true
# The board space currently lit up as the predicted landing tile, or -1.
var _wv_landing_index: int = -1
# Per player_id, host-authoritative. Local seats copy _pause_option; remote
# seats report theirs via _net_report_pause_option. Read by _apply_auto_pause.
var _seat_pause_option: Array[int] = []
# True for the whole time a roll is "in flight" -- from right after it's
# shown until movement actually happens -- so Instant spells timed to a roll
# (e.g. T3 Escape Spell) know a roll is actually what's being responded to,
# as opposed to a response window that only exists because of a spell cast
# on someone's ordinary turn.
var _roll_in_flight: bool = false:
	set(value):
		_roll_in_flight = value
		_update_wizard_vision()
# The roll value being built up while a roll is in flight -- read/returned
# by _perform_roll() via _roll_in_flight's window, and mutated in place by
# an Instant spell like T3 Escape Spell while paused.
var _current_roll: int = 0:
	set(value):
		_current_roll = value
		_update_wizard_vision()

# The physical dice of the roll in flight (0/0 = no dice shown) and a
# counter bumped on every roll, so a client can tell one roll from the next
# even if the faces happen to repeat. Drives the dice-rolling animation
# (see dice_roller / _apply_dice_animation).
var _die1: int = 0
var _die2: int = 0
var _roll_seq: int = 0


# Wizard Vision: while a roll is in flight (the response window right after
# rolling, before it resolves into a move), draws an arrow -- in the rolling
# player's own colour -- from the roller's token to the tile they'd land on,
# and highlights that tile. Kept live as _current_roll changes (a roll-
# modifying Instant spell like T3 Escape Spell/Adrenaline), so players can see
# at a glance whether it's worth reacting. Off if the player unchecked it in
# Settings. Both setters above call this on every change.
func _update_wizard_vision() -> void:
	if not wizard_vision_line:
		return
	if not _roll_in_flight or not _wizard_vision_enabled:
		wizard_vision_line.hide_line()
		_clear_wv_landing_highlight()
		return
	var roller: Node2D = players[current_player]
	var landing_index: int = (roller.current_space + _current_roll) % board.TOTAL_SPACES
	var col: Color = PLAYER_COLORS[current_player]
	wizard_vision_line.show_line(roller.position, board.get_space_center(landing_index), col)
	if landing_index != _wv_landing_index:
		_clear_wv_landing_highlight()
		board.spaces[landing_index].set_landing_highlight(true, col)
		_wv_landing_index = landing_index


func _clear_wv_landing_highlight() -> void:
	if _wv_landing_index != -1 and _wv_landing_index < board.spaces.size():
		board.spaces[_wv_landing_index].set_landing_highlight(false)
	_wv_landing_index = -1


func _on_wizard_vision_changed(on: bool) -> void:
	_wizard_vision_enabled = on
	_update_wizard_vision()

# The pending spell stack: each entry is {"id": int, "caster_id": int,
# "spell_name": String, "level": int, "display_name": String, "resolve":
# Callable}. A spell is pushed here the moment it's cast (having already
# left the caster's hand and picked whatever targets it needs) and popped
# LIFO -- last cast, first resolved -- one entry per elapsed reaction window
# (see _ensure_response_window). Countering a spell (T2 Response Spell Level
# 1, or Counterbalance matching its own level) just removes its entry before
# it's ever popped, so it never reaches _resolve_top_of_stack()'s own
# shuffle-back -- _resolve_counter_spell() shuffles it back into
# _spell_deck itself instead. See _finish_cast().
var _spell_stack: Array[Dictionary] = []
var _next_stack_id: int = 0
# Client-side mirror of the stack's spell names (bottom -> top), from the
# snapshot -- clients don't have the real _spell_stack. Drives the
# spell-cast card display; see _spell_stack_names().
var _net_spell_stack_names: Array = []
# Targets picked by the _prepare_* step of the cast currently being set up.
# Each entry is {"kind": "player"|"property", "id": int}. _finish_cast copies
# this onto the stack entry (as "target_marks"), names it in the log line
# ("... targeting X"), then clears it. Also cleared at the top of
# _prepare_spell_cast so a cancelled cast can't leak its picks into the next.
# An optional label overrides the derived name in the log only (used by
# side-of-the-board spells like Line of Fire, and by counter spells naming
# the spell they target).
var _pending_spell_target_marks: Array = []
var _pending_spell_target_label: String = ""
# Client mirror (host has the real _spell_stack): flat list of every live
# stack entry's target marks, from the snapshot. Drives the red outlines.
var _net_spell_target_marks: Array = []
# Board side (0 bottom, 1 left, 2 top, 3 right) -> display name, for the log.
const BOARD_SIDE_NAMES: Array[String] = ["Bottom", "Left", "Top", "Right"]
# Shown next to a player's name in the Players panel while a pending spell
# targets them (renders via the OS emoji-font fallback, like the ★ markers).
const SPELL_TARGET_SYMBOL: String = "🎯"

# The shared Spell Deck every player draws from (game start, and one card
# whenever anyone passes Go). Every spell that leaves a hand -- resolved,
# countered, or burned for Attunement -- gets shuffled back in once it's
# done; see _return_spell_to_deck() and its callers. Built once in _ready()
# from SPELL_DECK_STARTING_COUNTS.
var _spell_deck: Array[String] = []

# Raise Money mode -- entered whenever someone owes more than they hold on
# hand (unpayable rent/tax, a spell charge, or an optional buy they can't
# afford). See _collect_debt() / _raise_money().
#
# It's a LIFO STACK, not one debt: a spell the debtor casts to earn the money
# can itself charge someone who can't pay, so that debt goes on top and is
# settled first (P2 owes P1 -> P2's spell charges P1 -> P1 raises money and
# pays P2 -> P2, now flush, finishes their own debt). Each entry is
# {"player_id", "amount", "creditor" (Node2D or null), "cancellable",
# "auto_pay", "outcome" ("" | "paid" | "cancelled" | "bankrupt")}.
#
# The _debt_* vars below always MIRROR the top entry (or are cleared when the
# stack is empty) -- read them anywhere, but only ever change a debt through
# the helpers (_raise_money / _finish_current_debt / _fail_all_debts_for /
# _sync_current_debt).
var _debt_stack: Array[Dictionary] = []
var _in_debt: bool = false
var _debt_amount: int = 0
var _debt_creditor: Node2D = null
# Who actually owes the debt -- not necessarily current_player, since a
# spell can force *any* player into debt regardless of whose turn it is.
# See _acting_player_id().
var _debt_player_id: int = -1
# True when this "raise money" was entered by choosing to buy something
# optional (a property, a Spell Shop spell) without the cash for it: the
# player gets a Cancel button back to that choice instead of Declare
# Bankruptcy, and reaching the amount does NOT auto-pay (the buy flow that
# opened this does the actual charge).
var _debt_cancellable: bool = false
var _debt_auto_pay: bool = true
# How the current (top) raise-money window is going: "" while unresolved,
# then "paid", "cancelled" or "bankrupt".
var _debt_outcome: String = ""

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
# Spells offered, as indices into the offering player's own spell_hand (not
# globally meaningful on their own, unlike a board-space index -- always
# paired with knowing whether it's _trader1's or _trader2's hand).
var _trade1_spells_offered: Array[int] = []
var _trade2_spells_offered: Array[int] = []

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

# --- Tutorial mode ----------------------------------------------------
# Running the scripted walkthrough (see TUTORIAL_STEPS). While active, the
# player may only make the play the current step asks for.
var _tutorial_active: bool = false
var _tutorial_step: int = -1
# The play the current step demands ("" = advance on any click), and the
# dice it forces when that play is "roll" (ZERO = a normal random roll).
var _tutorial_expected_action: String = ""
var _tutorial_forced_roll: Vector2i = Vector2i.ZERO
# How many picks the player has made in the current step's multi-pick cast
# (0 = still needs to click the card; 1 = card clicked, level picker next; ...).
var _tutorial_pick_phase: int = 0
# True while the "Darn, you missed it!" message is showing -- the next click
# jumps back to the roll step rather than advancing.
var _tutorial_rewind_pending: bool = false
# Focus cues for the current step, recomputed from its text by
# _tutorial_refresh_focus(): every spell name the bubble mentions (highlighted
# on that card in the Players panel) and whether it points at the Roll / End
# Turn button (glow overlay on roll_button).
var _tutorial_focus_spells: Array[String] = []
var _tutorial_focus_roll_button: bool = false
var _tutorial_roll_button_glow: Panel = null


func _ready() -> void:
	admin_row.visible = GameState.admin_mode
	# Keep the log panel clear of the board, whatever size the board is.
	$UI/LogPanel.offset_top = board.BOARD_SIZE + 12.0
	_build_player_rows()
	_build_spell_deck()
	_spawn_players()
	_response_window_paused_by.resize(players.size())
	_response_window_paused_by.fill(false)
	current_player = _first_active_player()
	roll_button.pressed.connect(_on_roll_pressed)
	admin_button.pressed.connect(_on_admin_pressed)
	admin_properties_button.pressed.connect(_on_admin_properties_pressed)
	admin_spells_button.pressed.connect(_on_admin_spells_pressed)
	buy_house_unmortgage_button.pressed.connect(_on_buy_house_unmortgage_pressed)
	sell_house_mortgage_button.pressed.connect(_on_sell_house_mortgage_pressed)
	declare_bankruptcy_button.pressed.connect(_on_declare_bankruptcy_pressed)
	trade_button.pressed.connect(_on_trade_pressed)
	offer_trade_button.pressed.connect(_on_offer_trade_pressed)
	decline_trade_button.pressed.connect(_on_decline_trade_pressed)
	trader1_money_edit.text_changed.connect(_on_trade_money_changed)
	trader2_money_edit.text_changed.connect(_on_trade_money_changed)
	card_picker.zoom_requested.connect(spell_card.show_card)
	spell_card.reveal_pressed.connect(_on_zoom_reveal_pressed)
	_seat_pause_option.resize(players.size())
	_seat_pause_option.fill(PAUSE_MANUAL)
	_pause_option = pause_settings_menu.pause_option
	_apply_local_pause_option()
	pause_settings_menu.pause_option_changed.connect(_on_pause_option_changed)
	_wizard_vision_enabled = pause_settings_menu.wizard_vision_on
	pause_settings_menu.wizard_vision_changed.connect(_on_wizard_vision_changed)
	if GameState.online and not GameState.is_authority():
		_net_report_pause_option.rpc_id(1, _pause_option)
	pause_menu.set_settings_menu(pause_settings_menu)
	pause_menu.set_rules_viewer(rules_viewer)
	pause_menu.quit_to_menu_requested.connect(_quit_to_main_menu)
	pause_menu.quit_to_desktop_requested.connect(get_tree().quit)
	board.space_clicked.connect(_on_space_clicked)
	_build_log_markup()
	game_log.meta_clicked.connect(_on_log_meta_clicked)
	_update_turn_label()
	_update_player_panels()
	_refresh_action_buttons()
	if GameState.online:
		if GameState.is_authority():
			multiplayer.peer_disconnected.connect(_on_peer_gone)
			Net.player_reconnected.connect(_on_player_reconnected)
			# Host-only AFK tools in the pause menu's Settings window.
			pause_settings_menu.enable_host_tools()
			pause_settings_menu.kick_player_requested.connect(_host_kick_player)
			pause_settings_menu.unpause_player_requested.connect(_host_unpause_player)
		else:
			multiplayer.server_disconnected.connect(_on_host_gone)
	if GameState.online and not GameState.is_authority():
		_net_request_initial_snapshot()
		return
	# The first turn -- every later one is logged from _advance_to_next_active_player.
	_log_turn_start(current_player)
	if GameState.tutorial_mode:
		_start_tutorial()
	if GameState.is_authority() and players[current_player].is_ai:
		_run_ai_turn()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_menu.visible:
			pause_menu.close()
		else:
			pause_menu.open()
		return
	# While the pause menu is up the game is frozen -- swallow every other key
	# (S/B mode toggles, Space/1-4 pause keys) so nothing happens behind it.
	if pause_menu.visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# S / B toggle Sell Houses / Buy Houses mode, exactly like clicking those
	# buttons (which is also where a client forwards the intent to the host).
	# Gated on the button being live so the key can't do anything the button
	# couldn't -- and a focused text field eats the key before it reaches here.
	if event.keycode == KEY_S and not sell_house_mortgage_button.disabled:
		_on_sell_house_mortgage_pressed()
		return
	if event.keycode == KEY_B and not buy_house_unmortgage_button.disabled:
		_on_buy_house_unmortgage_pressed()
		return

	# Enter presses the Roll / End Turn button. Space is deliberately NOT bound
	# to it (roll_button has focus_mode NONE) -- Space is the response-window
	# pause key. Gated on the button being live, same as S / B above.
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER] and not roll_button.disabled:
		_on_roll_pressed()
		return

	var pause_slot: int = _pause_key_slot(event.keycode)
	if pause_slot == -1:
		return

	if _tutorial_active:
		if not (event.keycode in [KEY_SPACE, KEY_1] and _tutorial_handle_space()):
			_toast("Follow the instructions!")
		return

	if GameState.online:
		# A client controls one seat, so any pause key pauses that seat; the
		# press is sent to the host. The host's own keys pause only the
		# seat(s) it controls -- another player's seat is paused by that
		# player's own client.
		if not GameState.is_authority():
			var mine: Array[int] = GameState.local_slots()
			if not mine.is_empty():
				_net_pause_intent.rpc_id(1, mine[0])
			return
		_try_local_pause(pause_slot)
		return

	# Local hotseat: Space/1 = P1's perspective, 2..8 = that player's.
	_toggle_pause_for_player(pause_slot)


# Space and "1" both mean player 0; "2".."8" mean players 1..7. -1 for any
# other key. (KEY_1..KEY_8 are consecutive keycodes.)
func _pause_key_slot(keycode: int) -> int:
	if keycode == KEY_SPACE:
		return 0
	if keycode >= KEY_1 and keycode <= KEY_1 + GameState.MAX_PLAYERS - 1:
		return keycode - KEY_1
	return -1


func _try_local_pause(slot: int) -> void:
	if slot >= 0 and slot < players.size() and GameState.is_slot_local(slot):
		_toggle_pause_for_player(slot)


func _quit_to_main_menu() -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	if GameState.online:
		Net.leave()
	# Let any in-flight coroutine (response window loop, AI turn, routed
	# prompt) see _returning_to_menu and bail before this scene is freed --
	# otherwise it resumes on a get_tree() that's gone null.
	await get_tree().process_frame
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/start_menu.tscn")


# ============================================================================
# Host AFK tools (multiplayer only) -- reachable from the pause menu's Settings
# window, host side only. See settings_menu.gd's "Host tools" section.
# ============================================================================

# "Kick Player": pick a remote human and drop their connection. The host's own
# multiplayer.peer_disconnected -> _on_peer_gone then hands their seat(s) to a
# Computer, exactly like a genuine disconnect.
func _host_kick_player() -> void:
	if not (GameState.online and GameState.is_authority()):
		return
	pause_menu.hide()
	var entries: Array = []
	for i in players.size():
		# slot_peer > 1 == a connected client peer (1 is the host itself).
		if GameState.slot_peer[i] > 1 and not players[i].is_bankrupt:
			entries.append({"index": i, "name": PLAYER_NAMES[i], "color": PLAYER_COLORS[i]})
	if entries.is_empty():
		_toast("No remote players to kick.")
		return
	player_picker.open("Kick which player?", entries)
	var slot: int = await player_picker.player_chosen
	if slot < 0:
		return
	var peer_id: int = GameState.slot_peer[slot]
	if peer_id <= 1:
		return
	_log("%s was kicked by the host." % PLAYER_NAMES[slot])
	# Bar the reconnect path first: a kick is meant to stick.
	Net.note_kick(slot)
	_net_you_were_kicked.rpc_id(peer_id)
	# Give the reliable RPC a moment to land before we sever the link.
	await get_tree().create_timer(0.2).timeout
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


# Client: the host removed you. Mirrors _on_host_gone (which also fires, a beat
# later, when the host severs the link -- the guard keeps it a no-op then).
@rpc("authority", "reliable")
func _net_you_were_kicked() -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	Net.leave()
	info_prompt.open("You were removed from the game by the host.")
	await info_prompt.closed
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")


# "Unpause Player": pick a player who is currently holding a response window
# frozen and act as if they pressed their pause key -- resolves the top of the
# spell stack, or unpauses for real once it's empty (see
# _toggle_pause_for_player).
func _host_unpause_player() -> void:
	if not (GameState.online and GameState.is_authority()):
		return
	pause_menu.hide()
	var entries: Array = []
	for i in players.size():
		if _response_window_paused_by[i]:
			entries.append({"index": i, "name": PLAYER_NAMES[i], "color": PLAYER_COLORS[i]})
	if entries.is_empty():
		_toast("No players are paused.")
		return
	player_picker.open("Unpause which player?", entries)
	var slot: int = await player_picker.player_chosen
	if slot < 0:
		return
	if not _response_window_paused_by[slot]:
		_toast("%s is no longer paused." % PLAYER_NAMES[slot])
		return
	_log("The host unpaused %s." % PLAYER_NAMES[slot])
	_toggle_pause_for_player(slot)


# ============================================================================
# Tutorial mode -- a fixed script of steps (TUTORIAL_STEPS), each shown in a
# bubble at the bottom of the screen. Steps with an "action" make the player
# perform exactly that play; steps without one advance on any click (_input()
# swallows the click so it can't disturb anything -- e.g. an open picker).
# When the script runs out the tutorial ends and returns to the Main Menu.
# ============================================================================

func _start_tutorial() -> void:
	_tutorial_active = true
	_tutorial_step = -1
	_tutorial_advance()


func _tutorial_advance() -> void:
	_tutorial_step += 1
	if _tutorial_step >= TUTORIAL_STEPS.size():
		_end_tutorial()
		return
	_tutorial_apply_current_step()


func _tutorial_apply_current_step() -> void:
	_tutorial_pick_phase = 0
	_tutorial_rewind_pending = false
	var step: Dictionary = TUTORIAL_STEPS[_tutorial_step]
	_tutorial_expected_action = step.get("action", "")
	_tutorial_forced_roll = step.get("forced_roll", Vector2i.ZERO)
	tutorial_bubble_label.text = step.get("text", "")
	tutorial_bubble.visible = true
	tutorial_bubble_hint.visible = _tutorial_expected_action == ""
	_tutorial_refresh_focus(step.get("text", ""))

	# The "await a spell to resolve" steps just un-pause the player and re-arm
	# the open reaction window's countdown, so _ensure_response_window()'s loop
	# runs it down and resolves the spell on its own (which then advances the
	# step via _tutorial_on_spell_resolved).
	if _tutorial_expected_action in ["await_manastone", "await_adrenaline"]:
		if _response_window_paused_by.size() > 0:
			_response_window_paused_by[0] = false
		_window_deadline_msec = Time.get_ticks_msec() + int(_response_window_seconds() * 1000.0)
		_refresh_action_buttons()
		_update_player_panels()


# Works out what the current bubble text is pointing at and lights it up:
# any spell it names by card title gets a gold outline on that card in the
# Players panel, and phrases like "Roll the dice" / "Click the Roll button" /
# "End Turn" glow the Roll button. Called on every step change (and the
# missed-window message).
func _tutorial_refresh_focus(text: String) -> void:
	_tutorial_focus_spells.clear()
	if _tutorial_active:
		for p in players:
			for spell_name in p.spell_hand:
				if spell_name != "" and spell_name in text and not _tutorial_focus_spells.has(spell_name):
					_tutorial_focus_spells.append(spell_name)
	var lower: String = text.to_lower()
	_tutorial_focus_roll_button = _tutorial_active and (
		"roll button" in lower or "roll the dice" in lower or "end turn" in lower)
	_tutorial_apply_roll_button_glow()
	_update_player_panels()


func _tutorial_apply_roll_button_glow() -> void:
	if not _tutorial_roll_button_glow:
		if not _tutorial_focus_roll_button:
			return
		_tutorial_roll_button_glow = Panel.new()
		_tutorial_roll_button_glow.name = "TutorialGlow"
		_tutorial_roll_button_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tutorial_roll_button_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		_tutorial_roll_button_glow.offset_left = -3.0
		_tutorial_roll_button_glow.offset_top = -3.0
		_tutorial_roll_button_glow.offset_right = 3.0
		_tutorial_roll_button_glow.offset_bottom = 3.0
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.82, 0.15, 0.0)
		style.border_color = Color(1.0, 0.82, 0.15)
		style.set_border_width_all(3)
		style.set_corner_radius_all(6)
		_tutorial_roll_button_glow.add_theme_stylebox_override("panel", style)
		roll_button.add_child(_tutorial_roll_button_glow)
	_tutorial_roll_button_glow.visible = _tutorial_focus_roll_button


func _tutorial_find_step(tag: String) -> int:
	for i in TUTORIAL_STEPS.size():
		if TUTORIAL_STEPS[i].get("tag", "") == tag:
			return i
	return -1


func _tutorial_goto(tag: String) -> void:
	var idx: int = _tutorial_find_step(tag)
	if idx == -1:
		_end_tutorial()
		return
	_tutorial_step = idx
	_tutorial_apply_current_step()


func _end_tutorial() -> void:
	_tutorial_active = false
	_tutorial_expected_action = ""
	_tutorial_forced_roll = Vector2i.ZERO
	_tutorial_focus_spells.clear()
	_tutorial_focus_roll_button = false
	if _tutorial_roll_button_glow:
		_tutorial_roll_button_glow.visible = false
	tutorial_bubble.visible = false
	GameState.tutorial_mode = false
	get_tree().call_deferred("change_scene_to_file", "res://scenes/tutorial_menu.tscn")


# Runs before GUI/subwindow handling, so set_input_as_handled() actually stops
# the click. Jobs while the tutorial is running:
#  - a zoomed-in spell card is dismissed by the next click, which is then
#    swallowed and does NOT advance (the card was covering the text; the
#    player reads it after, then clicks again to move on);
#  - on a "click to continue" step, a LEFT click is swallowed (so it can't
#    dismiss an open picker or hit a button underneath) and advances -- unless
#    a spell is mid-resolution (window open, nobody paused), in which case the
#    click is still eaten but we wait. A RIGHT click falls through, so you can
#    right-click a card to zoom it at any point in the tutorial.
# Action steps otherwise let input through untouched.
func _input(event: InputEvent) -> void:
	if not _tutorial_active:
		return
	# The pause menu is a modal overlay -- let its buttons handle their own
	# clicks instead of treating them as "advance the tutorial".
	if pause_menu.visible:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if spell_card.visible:
		spell_card.hide()
		get_viewport().set_input_as_handled()
		return
	if _tutorial_expected_action != "":
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	_tutorial_try_click_advance()


func _tutorial_try_click_advance() -> void:
	# Hold on a "click to continue" step while a spell is actively resolving
	# (a response window is open and nobody has it paused).
	if _response_window_open and not _response_window_paused_by.has(true):
		return
	if _tutorial_rewind_pending:
		_tutorial_rewind_pending = false
		_tutorial_goto("roll")
		return
	_tutorial_advance()


# The gate handed to player_picker while the tutorial runs: it decides whether
# a pick is the one the current step wants. Rejected picks toast and leave the
# picker open. `index` is a level (or BURN_FOR_ATTUNEMENT_INDEX), a color
# index (Manastone), or a player index (targets); -1 is Cancel.
func _tutorial_picker_gate() -> Callable:
	return _tutorial_gate_check if _tutorial_active else Callable()


func _tutorial_gate_check(index: int) -> bool:
	match _tutorial_expected_action:
		"pick_level":  # Migraine level
			if index == 2:
				_tutorial_advance()
				return true
		"pick_target":  # Migraine target
			if index == 1:
				_tutorial_advance()
				return true
		"burn_rbn":
			if index == BURN_FOR_ATTUNEMENT_INDEX:
				_tutorial_advance()  # -> "Right click on your Manastone."
				return true
		"cast_manastone":
			if _tutorial_pick_phase == 1 and index == 0:  # Level 0
				_tutorial_pick_phase = 2
				return true
			if _tutorial_pick_phase == 2 and index == ATTUNABLE_COLORS.find("green"):
				_tutorial_pick_phase = 3
				return true
		"cast_adrenaline":
			if _tutorial_pick_phase == 1 and index == 2:  # Level 2
				_tutorial_pick_phase = 2
				return true
		"cast_sinkhole":
			if _tutorial_pick_phase == 1 and (index == 1 or index == 2):  # level
				_tutorial_pick_phase = 2
				return true
			if _tutorial_pick_phase == 2 and index == 1:  # the opponent
				_tutorial_pick_phase = 3
				return true
	_toast("Follow the instructions!")
	return false


# The gate handed to confirm_prompt -- only the Oriental Avenue buy prompt is
# gated, and only "Yes" is accepted there.
func _tutorial_confirm_gate() -> Callable:
	if _tutorial_active and _tutorial_expected_action == "buy_oriental":
		return _tutorial_buy_gate
	return Callable()


func _tutorial_buy_gate(yes: bool) -> bool:
	if yes:
		_tutorial_advance()  # -> "You'll notice you still have your temporary attunement."
		return true
	_toast("Follow the instructions!")
	return false


# The spell the current step wants LEFT-clicked from the hand ("" = none).
func _tutorial_left_click_spell() -> String:
	match _tutorial_expected_action:
		"cast_migraine": return "Migraine"
		"cast_rbn": return "Reclaimed by Nature"
		"cast_manastone": return "Manastone"
		"cast_adrenaline": return "Adrenaline"
		"cast_sinkhole": return "Sinkhole"
	return ""


# The spell the current step wants RIGHT-clicked ("" = none). Adrenaline and
# Manastone are only "look at" steps now (plain click-to-continue), so
# right-clicking them just zooms the card without advancing.
func _tutorial_right_click_spell() -> String:
	match _tutorial_expected_action:
		"inspect_migraine": return "Migraine"
	return ""


# Called from _finish_cast once a tutorial-driven spell has been put on the
# stack (or, for an ordinary turn cast, already resolved by then).
func _tutorial_on_spell_finished(spell_name: String) -> void:
	match _tutorial_expected_action:
		"cast_manastone":
			if spell_name == "Manastone":
				_tutorial_advance()  # -> "Spells go on the stack when cast..."
		"cast_adrenaline":
			if spell_name == "Adrenaline":
				_tutorial_advance()  # -> "Wait for Adrenaline to resolve..."
		"cast_sinkhole":
			if spell_name == "Sinkhole":
				_tutorial_advance()  # -> "Great job!"


# Called from _ensure_response_window() right after a spell has come off the
# stack -- drives the "await_*" steps, which just wait for their spell to
# resolve on its own.
func _tutorial_on_spell_resolved(spell_name: String) -> void:
	match _tutorial_expected_action:
		"await_manastone":
			if spell_name == "Manastone":
				_tutorial_advance()  # -> "You automatically pause again..."
		"await_adrenaline":
			if spell_name == "Adrenaline":
				_tutorial_advance()  # -> "As you can see, your path has changed..."


# Space during the tutorial: pause a reaction window. Returns true if it
# handled the press (else the caller toasts "Follow the instructions!").
func _tutorial_handle_space() -> bool:
	if not _response_window_open:
		return false
	match _tutorial_expected_action:
		"press_space":
			if _response_window_paused_by[0]:
				return false
			_toggle_pause_for_player(0)
			if _response_window_paused_by[0]:
				_tutorial_advance()  # -> "Space Bar is how you pause the game..."
			return true
		"unpause_after_adrenaline":
			if not _response_window_paused_by[0]:
				return false
			_toggle_pause_for_player(0)
			if not _response_window_paused_by[0]:
				_tutorial_advance()  # -> "Now you can buy Oriental Avenue."
			return true
	return false


func _tutorial_rewind_roll() -> void:
	var p: Node2D = players[current_player]
	_roll_in_flight = false
	_current_roll = 0
	_awaiting_end_turn = false
	p.consecutive_doubles = 0
	dice_roller.clear_dice()
	_prompt_slot = -1
	_refresh_action_buttons()
	_update_turn_label()
	_update_player_panels()
	# Show "Darn, you missed it!" -- the next click jumps back to the roll step.
	_tutorial_rewind_pending = true
	_tutorial_expected_action = ""
	tutorial_bubble_label.text = TUTORIAL_MISSED_TEXT
	tutorial_bubble_hint.visible = true
	tutorial_bubble.visible = true
	_tutorial_refresh_focus(TUTORIAL_MISSED_TEXT)


# Whether hand slot `hand_index` of player `player_index` currently holds
# `spell_name` -- used to check the player clicked the card the step named.
func _tutorial_hand_spell_is(player_index: int, hand_index: int, spell_name: String) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var hand: Array = players[player_index].spell_hand
	return hand_index >= 0 and hand_index < hand.size() and hand[hand_index] == spell_name


func _grant_tutorial_start(player: Node2D) -> void:
	if player.player_id == 0:
		for space_index in TUTORIAL_P1_PROPERTIES:
			board.spaces[space_index].owner_id = player.player_id
			player.owned_property_indices.append(space_index)
		_sort_owned_properties(player)
		for spell_name in TUTORIAL_P1_SPELLS:
			_spell_add(player, spell_name)
	elif player.player_id == 1:
		for spell_name in TUTORIAL_OPPONENT_SPELLS:
			_spell_add(player, spell_name)


# True (and shows the "Follow the instructions!" toast) when the tutorial is
# waiting for a specific play and `action` isn't it. Action handlers call
# this at the top and bail when it returns true.
func _tutorial_blocks(action: String) -> bool:
	if not _tutorial_active:
		return false
	if _tutorial_expected_action == action:
		return false
	_toast("Follow the instructions!")
	return true


# Builds the Players-panel rows from player_row.tscn -- one per slot -- and
# fills the parallel lookup arrays. Runs before _spawn_players(), which needs
# them. The rows live inside a ScrollContainer, so 5+ active players just make
# the panel scroll.
func _build_player_rows() -> void:
	for i in GameState.MAX_PLAYERS:
		var row: VBoxContainer = PLAYER_ROW_SCENE.instantiate()
		player_list.add_child(row)
		player_rows.append(row)
		player_row_separators.append(row.get_node("TopSeparator"))
		player_header_labels.append(row.get_node("HeaderLabel"))
		player_properties_flows.append(row.get_node("AssetsRow/PropertiesFlow"))
		player_spells_flows.append(row.get_node("AssetsRow/SpellsFlow"))
		player_attunement_flows.append(row.get_node("AssetsRow/AttunementFlow"))


func _spawn_players() -> void:
	for i in PLAYER_COLORS.size():
		var player: Node2D = PLAYER_SCENE.instantiate()
		players_container.add_child(player)
		player.setup(i, PLAYER_COLORS[i])
		player.current_space = 0
		player.position = board.get_space_center(0) + MARKER_OFFSETS[i]
		players.append(player)
		player_header_labels[i].add_theme_color_override("font_color", PLAYER_COLORS[i])

		var type: GameState.PlayerType = GameState.player_types[i]
		if type == GameState.PlayerType.DISABLED:
			# Treated as already bankrupt so turn order, the trade picker,
			# and the win check all just skip over them -- this slot was
			# never really in the game.
			player.is_bankrupt = true
			player.visible = false
			player_rows[i].visible = false
			player_row_separators[i].visible = false
		else:
			if type == GameState.PlayerType.COMPUTER:
				player.is_ai = true
			if GameState.tutorial_mode:
				_grant_tutorial_start(player)
			elif GameState.blitzstart_mode:
				_grant_starting_hand(player, 6, 4)
			elif GameState.quickstart_mode:
				_grant_starting_hand(player, 3, 2)


func _build_spell_deck() -> void:
	_spell_deck.clear()
	for spell_name in SPELL_DECK_STARTING_COUNTS:
		for i in SPELL_DECK_STARTING_COUNTS[spell_name]:
			_spell_deck.append(spell_name)
	_spell_deck.shuffle()


# Quickstart / BlitzStart: grants `property_count` random unowned properties
# and `spell_count` random spells, in place of the normal empty-handed,
# property-less start. (Quickstart: 3 / 2. BlitzStart: 6 / 4.)
func _grant_starting_hand(player: Node2D, property_count: int, spell_count: int) -> void:
	var unowned: Array[int] = _unowned_property_indices()
	unowned.shuffle()
	for i in mini(property_count, unowned.size()):
		var space_index: int = unowned[i]
		board.spaces[space_index].owner_id = player.player_id
		player.owned_property_indices.append(space_index)
	_sort_owned_properties(player)
	for i in spell_count:
		_draw_spell(player)


# Draws one card from the shared deck into `player`'s hand, returning its
# name (or "" if the deck happens to be empty -- e.g. more players drawing
# their starting hand than the placeholder deck actually holds). A no-op
# other than the return value in that case.
func _draw_spell(player: Node2D) -> String:
	if _spell_deck.is_empty():
		return ""
	var spell_name: String = _spell_deck.pop_back()
	_spell_add(player, spell_name)
	return spell_name


# The player order always starts at index 0, but that slot might be
# Disabled, so find whoever's actually first in line.
func _first_active_player() -> int:
	for i in players.size():
		if not players[i].is_bankrupt:
			return i
	return 0


func _on_roll_pressed() -> void:
	# Tutorial: the roll is only allowed on the step that asks for it. (End
	# Turn presses go through -- no tutorial step gates those yet.)
	if not _awaiting_end_turn and _tutorial_blocks("roll"):
		return
	# Online: only the machine controlling the current player may act, and a
	# client sends the press to the host rather than running it locally.
	if GameState.online:
		if not GameState.is_slot_local(current_player):
			return
		if not GameState.is_authority():
			_net_roll_intent.rpc_id(1)
			return
	_perform_roll_button_action()


# The actual effect of the Roll / End Turn button, run only on the authority
# (locally on the host, or via _net_roll_intent for a remote player).
func _perform_roll_button_action() -> void:
	if _awaiting_end_turn:
		# Tutorial: End Turn only on the step that asks for it.
		if _tutorial_active and _tutorial_expected_action != "end_turn":
			_toast("Follow the instructions!")
			return
		var was_end_turn_step: bool = _tutorial_active and _tutorial_expected_action == "end_turn"
		_end_turn()
		if was_end_turn_step:
			_tutorial_advance()  # -> "Congratulations!..."
		return
	# Tutorial: a step pins the dice to fixed faces; _perform_roll then drives
	# the tutorial itself (the pause window, the spell casts, the purchase).
	if _tutorial_active and _tutorial_forced_roll != Vector2i.ZERO:
		var forced: Vector2i = _tutorial_forced_roll
		_tutorial_forced_roll = Vector2i.ZERO
		await _perform_roll(forced.x, forced.y)
		return
	_perform_roll(randi_range(1, 6), randi_range(1, 6))


# Whether the current player could press Roll / End Turn right now. Shared by
# button enablement and the host's validation of a remote roll intent.
func _can_take_roll_action() -> bool:
	if _in_debt or _awaiting_buy_decision or _trading or _casting_spell or _response_window_open:
		return false
	var p: Node2D = players[current_player]
	return not p.is_ai and not p.is_bankrupt


@rpc("any_peer", "call_remote", "reliable")
func _net_roll_intent() -> void:
	if not GameState.is_authority():
		return
	if GameState.slot_peer[current_player] != multiplayer.get_remote_sender_id():
		return
	if not _can_take_roll_action():
		return
	_perform_roll_button_action()


# A remote player clicked one of their own spell cards (own turn, or during a
# response window they've paused). Validated and run as that seat.
@rpc("any_peer", "call_remote", "reliable")
func _net_spell_click_intent(hand_index: int, slot: int) -> void:
	if not GameState.is_authority():
		return
	if _peer_for_slot(slot) != multiplayer.get_remote_sender_id():
		return
	_begin_spell_cast(hand_index, slot)


# A remote player pressed a pause key during a response window.
@rpc("any_peer", "call_remote", "reliable")
func _net_pause_intent(slot: int) -> void:
	if not GameState.is_authority():
		return
	if _peer_for_slot(slot) != multiplayer.get_remote_sender_id():
		return
	_toggle_pause_for_player(slot)


# A remote player pressed one of their own-turn action buttons (buy/sell
# houses, mortgage, declare bankruptcy). Validated against the acting seat
# and run as if the button were pressed on the host.
@rpc("any_peer", "call_remote", "reliable")
func _net_action_intent(action: String) -> void:
	if not GameState.is_authority():
		return
	if _peer_for_slot(_acting_player_id()) != multiplayer.get_remote_sender_id():
		return
	match action:
		"buy_house_unmortgage":
			_on_buy_house_unmortgage_pressed()
		"sell_house_mortgage":
			_on_sell_house_mortgage_pressed()
		"declare_bankruptcy":
			_on_declare_bankruptcy_pressed()
		"trade":
			_on_trade_pressed()


# A remote player clicked a board tile while their seat was in a pick mode.
@rpc("any_peer", "call_remote", "reliable")
func _net_board_click_intent(index: int) -> void:
	if not GameState.is_authority():
		return
	if _peer_for_slot(_acting_player_id()) != multiplayer.get_remote_sender_id():
		return
	# Only meaningful while a pick mode is actually armed -- otherwise a
	# stale click (mode already consumed by an earlier one) would pop a
	# property card on the host.
	if not (_buying_house_or_unmortgaging or _selling_house_or_mortgaging or _picking_promised_land_property):
		return
	_on_space_clicked(index)


# --- trade intents: a remote proposer's clicks / edits / buttons -------

@rpc("any_peer", "call_remote", "reliable")
func _net_trade_click_intent(index: int) -> void:
	if not GameState.is_authority() or not _trading:
		return
	if _peer_for_slot(_trade_proposer) != multiplayer.get_remote_sender_id():
		return
	_apply_trade_click(index)


@rpc("any_peer", "call_remote", "reliable")
func _net_trade_spell_click_intent(hand_index: int, player_index: int) -> void:
	if not GameState.is_authority() or not _trading:
		return
	if _peer_for_slot(_trade_proposer) != multiplayer.get_remote_sender_id():
		return
	_apply_trade_spell_click(hand_index, player_index)


@rpc("any_peer", "call_remote", "reliable")
func _net_trade_money_intent(m1: int, m2: int) -> void:
	if not GameState.is_authority() or not _trading:
		return
	if _peer_for_slot(_trade_proposer) != multiplayer.get_remote_sender_id():
		return
	trader1_money_edit.text = str(maxi(0, m1))
	trader2_money_edit.text = str(maxi(0, m2))
	_mark_trade_modified()


@rpc("any_peer", "call_remote", "reliable")
func _net_trade_offer_intent() -> void:
	if not GameState.is_authority() or not _trading:
		return
	if _peer_for_slot(_trade_proposer) != multiplayer.get_remote_sender_id():
		return
	_on_offer_trade_pressed()


@rpc("any_peer", "call_remote", "reliable")
func _net_trade_decline_intent() -> void:
	if not GameState.is_authority() or not _trading:
		return
	if _peer_for_slot(_trade_proposer) != multiplayer.get_remote_sender_id():
		return
	_on_decline_trade_pressed()


# ============================================================================
# Online multiplayer -- disconnects (Phase 7)
# ============================================================================

# Client: lost the connection to the host (host quit, or our own link dropped
# -- both look the same from here). Back to the menu, but the session token and
# last host address are kept so "Join Game" can drop us straight back in while
# the host is still holding our seat (see net.gd's reconnect flow).
func _on_host_gone() -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	Net.leave()
	info_prompt.open("Lost connection to the host. Returning to the menu -- choose Join Game to reconnect.")
	await info_prompt.closed
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")


var _returning_to_menu: bool = false


# Host: a client dropped. Hand its seat(s) to the AI and unblock anything the
# game was waiting on that player for.
func _on_peer_gone(peer_id: int) -> void:
	if not (GameState.online and GameState.is_authority()):
		return
	_net_ready_peers.erase(peer_id)
	var affected: Array[int] = []
	for slot in GameState.slot_peer.size():
		if GameState.slot_peer[slot] == peer_id:
			affected.append(slot)
	if affected.is_empty():
		return

	for slot in affected:
		# Reconnectable (an ordinary drop) -> a stripped-down Placeholder AI
		# holds the seat and the player can rejoin. Not reconnectable (the host
		# kicked them) -> a normal Computer, permanently.
		var reconnectable: bool = Net.slot_is_reconnectable(slot)
		GameState.slot_peer[slot] = 0
		players[slot].is_ai = true
		players[slot].is_placeholder_ai = reconnectable
		_response_window_paused_by[slot] = false
		if reconnectable:
			dice_label.text += "\n%s lost connection -- a Placeholder AI holds their seat until they reconnect." % PLAYER_NAMES[slot]
			_log("%s lost connection; a Placeholder AI holds their seat until they reconnect." % PLAYER_NAMES[slot])
		else:
			dice_label.text += "\n%s was removed -- a Computer takes over." % PLAYER_NAMES[slot]
			_log("%s was removed; a Computer takes over." % PLAYER_NAMES[slot])

	# A trade with the departed player can't continue.
	if _trading and (affected.has(_trader1) or affected.has(_trader2)):
		_end_trade()

	# Debts a departed player was raising money for (the live one and any
	# suspended deeper in the stack): settle them AI-style now (mortgage, sell
	# houses, forfeit if still short).
	while _in_debt and affected.has(_debt_player_id):
		_ai_settle_debt_now(_debt_player_id)

	_update_player_panels()
	_refresh_action_buttons()

	# If it's their turn and the turn is idle, get the AI moving. A turn
	# mid-await (a routed prompt, response window) resolves to a default on
	# its own and then lands on the End Turn step, which the watchdog clears.
	if affected.has(current_player) and not players[current_player].is_bankrupt:
		if _awaiting_end_turn:
			_end_turn()
		elif not (_casting_spell or _response_window_open or _trading or _in_debt or _awaiting_buy_decision):
			_run_ai_turn()


# The AI branch of _collect_debt(), run after the fact when a human in debt
# disconnects mid-collection. Emits debt_resolved either way so the
# _collect_debt() call still awaiting it can continue.
func _ai_settle_debt_now(slot: int) -> void:
	if _debt_stack.is_empty() or int(_debt_stack.back()["player_id"]) != slot:
		return
	var player: Node2D = players[slot]
	var amount: int = int(_debt_stack.back()["amount"])
	var creditor: Node2D = _debt_stack.back()["creditor"]
	var cancellable: bool = bool(_debt_stack.back()["cancellable"])
	_ai_mortgage_properties(player, amount)
	if player.money < amount:
		_ai_sell_houses(player, amount)
	if player.money < amount:
		_ai_mortgage_properties(player, amount)
	if _debt_stack.is_empty() or int(_debt_stack.back()["player_id"]) != slot:
		return  # a mid-loop _maybe_resolve_debt already cleared it
	if player.money >= amount:
		_maybe_resolve_debt()
	elif cancellable:
		_finish_current_debt("cancelled")
	else:
		dice_label.text += "\n%s can't raise the money and forfeits the game." % _player_display_name(slot)
		_forfeit_to_bankruptcy(player, creditor)
		_fail_all_debts_for(slot, "bankrupt")


# Host: a dropped player reconnected (Net.player_reconnected). Splice their new
# peer id back in and take the Placeholder AI off their seat. If the Placeholder
# AI is mid-turn for them right now, defer the hand-off until _run_ai_turn()
# finishes that turn (so a buy prompt can't get routed to a half-loaded client).
var _reconnect_finalize_slot: int = -1

func _on_player_reconnected(slot: int, peer_id: int) -> void:
	if slot < 0 or slot >= players.size():
		return
	GameState.slot_peer[slot] = peer_id
	_log("%s reconnected." % PLAYER_NAMES[slot])
	if _ai_turn_running and current_player == slot:
		_reconnect_finalize_slot = slot
	else:
		_finish_reconnect(slot)
	_update_player_panels()


func _finish_reconnect(slot: int) -> void:
	players[slot].is_ai = false
	players[slot].is_placeholder_ai = false
	_update_player_panels()
	_refresh_action_buttons()


# A seat that went AI via a disconnect can get stuck on the End Turn step --
# _perform_roll() finished, but nothing clicks the button. Once the turn is
# genuinely idle (no prompt, window, trade or debt in flight) and no real AI
# turn coroutine is running, end it.
func _net_ai_takeover_watchdog() -> void:
	if not _awaiting_end_turn or _ai_turn_running:
		return
	if not players[current_player].is_ai or players[current_player].is_bankrupt:
		return
	if _casting_spell or _response_window_open or _trading or _in_debt or _awaiting_buy_decision:
		return
	_end_turn()


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
	_buying_house_or_unmortgaging = false
	_selling_house_or_mortgaging = false
	_die1 = 0
	_die2 = 0
	dice_roller.clear_dice()
	_advance_to_next_active_player()
	_update_turn_label()
	# In the tutorial the opponent never actually takes a turn -- the script
	# ends (back to the Main Menu) right after the player's first End Turn.
	if GameState.is_authority() and players[current_player].is_ai and not _tutorial_active:
		_run_ai_turn()


# Drives a Computer player's entire turn automatically: roll, decline any
# purchase, and end turn -- rolling again first if that roll was doubles.
# Debt it can't cover ends in an immediate forfeit, since it has no other
# way to raise money. Deliberately simple; smarter play comes later.
#
# _ai_turn_running is true for the whole span so the disconnect watchdog
# (_net_ai_takeover_watchdog) can tell "AI turn in progress" from "AI seat
# stranded on the End Turn step after a disconnect".
var _ai_turn_running: bool = false


func _run_ai_turn() -> void:
	_ai_turn_running = true
	await _run_ai_turn_body()
	_ai_turn_running = false
	# A player who reconnected mid-turn (while the Placeholder AI was finishing
	# their turn) gets handed control now that it's safely over.
	if _reconnect_finalize_slot != -1:
		var slot: int = _reconnect_finalize_slot
		_reconnect_finalize_slot = -1
		_finish_reconnect(slot)


func _run_ai_turn_body() -> void:
	var ai_index: int = current_player
	# The Placeholder AI (a dropped human's stand-in) never casts spells.
	if not players[ai_index].is_placeholder_ai:
		await _ai_p2_opening_burn(players[ai_index])
	while current_player == ai_index and not players[ai_index].is_bankrupt:
		if _returning_to_menu or not is_inside_tree():
			return
		_refresh_action_buttons()
		await get_tree().create_timer(0.6).timeout
		var die1: int = randi_range(1, 6)
		var die2: int = randi_range(1, 6)
		await _perform_roll(die1, die2)
		if current_player != ai_index or players[ai_index].is_bankrupt or _returning_to_menu or not is_inside_tree():
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
	if not player.spell_hand.has("T1 Burn Spell"):
		return
	var amount: int = SpellData.SPELLS["T1 Burn Spell"]["levels"][1].get("amount", 0)
	var resolve: Callable = _resolve_t1_burn_spell.bind(player, 1, 0, amount)
	# This bypasses _prepare_spell_cast, so set the target mark by hand (P1).
	_pending_spell_target_marks = []
	_pending_spell_target_label = ""
	_spell_target_player(0)
	await _finish_cast(player, "T1 Burn Spell", 1, resolve)


# Runs once, right before a Computer player ends its turn: unmortgage what
# it can afford, chase down any color set it's one property short of, then
# spend what's safe to spend on houses. Order matters -- unmortgaging first
# frees up cash and properties that the later checks see; a completed set
# from trading is what the house check will actually build on.
func _ai_run_end_of_turn_checks(player: Node2D) -> void:
	# The Placeholder AI holding a disconnected player's seat does none of this
	# upkeep -- it just rolls, buys what it lands on, pays what it owes, and
	# ends the turn. It shouldn't be spending the absent player's money on
	# houses or making trades for them.
	if player.is_placeholder_ai:
		return
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
	admin_spells_button.disabled = true
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
	admin_spells_button.disabled = true
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
	_info_open("Click the property you want to gain.")


func _admin_assign_property(index: int) -> void:
	var info: Dictionary = board.get_space_info(index)
	if info.get("type", "") != "property":
		_toast("Space %d is not a property." % index)
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


# Admin Spells: shows every distinct spell in the game (one entry per name in
# SPELL_DECK_STARTING_COUNTS -- real, currently-in-play spells only, not the
# vestigial T1/T2/T3 test cards) as clickable card art, same picker Magic
# Forest/Spell Shop use. Picking one adds a free copy straight to the current
# player's hand -- doesn't touch the shared deck at all, same as Admin
# Properties assigns ownership without a real purchase, so it can't throw off
# deck composition for testing.
func _on_admin_spells_pressed() -> void:
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	admin_spells_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true
	declare_bankruptcy_button.disabled = true
	trade_button.disabled = true

	var spell_names: Array = SPELL_DECK_STARTING_COUNTS.keys()
	var entries: Array = []
	for i in spell_names.size():
		var spell_info: Dictionary = SpellData.SPELLS.get(spell_names[i], {})
		entries.append({"index": i, "name": spell_names[i], "icon": load(spell_info.get("icon", ""))})
	_cp_open("Admin Spells: choose a spell to add to your hand.", entries)
	var choice: int = await _cp_result()
	_refresh_action_buttons()
	if choice < 0 or choice >= spell_names.size():
		return
	var chosen_name: String = spell_names[choice]
	var player: Node2D = players[current_player]
	_spell_add(player, chosen_name)
	dice_label.text = "%s's hand admin-gained a copy of %s." % [_player_display_name(current_player), chosen_name]
	_update_player_panels()


# A sticky mode, not a one-shot: while it's on, a light-blue outline marks
# the button and every tile click builds a house / unmortgages, until the
# button (or the B key) is pressed again to turn it off. _refresh_action_
# buttons() handles the outline and locks the other actions while it's on.
func _on_buy_house_unmortgage_pressed() -> void:
	if _tutorial_blocks("buy_house"):
		return
	if GameState.online and not GameState.is_authority():
		_net_action_intent.rpc_id(1, "buy_house_unmortgage")
		return
	_buying_house_or_unmortgaging = not _buying_house_or_unmortgaging
	if _buying_house_or_unmortgaging:
		_selling_house_or_mortgaging = false
	_refresh_action_buttons()


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
	var player: Node2D = players[_acting_player_id()]
	var house_cost: int = board.HOUSE_COSTS_BY_COLOR.get(color_name, 0)
	var property_name: String = info.get("name", "")
	# A peek at what Haggling would charge, without consuming it yet -- only
	# an actually-successful purchase (the "else" below) should use it up.
	var effective_cost: int = house_cost
	if player.haggling_discount_percent > 0:
		effective_cost = maxi(0, house_cost - (house_cost * player.haggling_discount_percent / 100))

	if info.get("type", "") != "property" or not board.HOUSE_COSTS_BY_COLOR.has(color_name):
		_toast("You can't build houses on that space.")
	elif space.owner_id != player.player_id:
		_toast("You don't own %s." % property_name)
	elif _group_has_mortgaged(color_name):
		_toast("You can't build houses on %s while a property in its color set is mortgaged." % property_name)
	elif not _owns_full_color_group(player.player_id, color_name):
		_toast("You need the full color set to build a house on %s." % property_name)
	elif space.house_count >= 5:
		_toast("%s already has the maximum of 5 houses." % property_name)
	elif space.house_count > _min_houses_in_group(color_name):
		_toast("You must build evenly -- other properties in the color set have fewer houses than %s." % property_name)
	elif player.money < effective_cost:
		_toast("%s can't afford a house on %s ($%d)." % [_player_display_name(player.player_id), property_name, effective_cost])
	else:
		dice_label.text = ""
		var final_cost: int = _apply_haggling_discount(player, house_cost)
		player.money -= final_cost
		space.house_count += 1
		var house_word: String = "house" if space.house_count == 1 else "houses"
		dice_label.text += "%s built a house on %s for $%d (now %d %s)." % [_player_display_name(player.player_id), property_name, final_cost, space.house_count, house_word]
		_log("%s built a house on %s for $%d (now %d %s)." % [PLAYER_NAMES[player.player_id], property_name, final_cost, space.house_count, house_word])
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
	if _tutorial_blocks("sell_house"):
		return
	if GameState.online and not GameState.is_authority():
		_net_action_intent.rpc_id(1, "sell_house_mortgage")
		return
	_selling_house_or_mortgaging = not _selling_house_or_mortgaging
	if _selling_house_or_mortgaging:
		_buying_house_or_unmortgaging = false
	_refresh_action_buttons()


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
	var player: Node2D = players[_acting_player_id()]
	var house_cost: int = board.HOUSE_COSTS_BY_COLOR.get(color_name, 0)
	var property_name: String = info.get("name", "")
	var sale_price: int = house_cost / 2

	if info.get("type", "") != "property" or not board.HOUSE_COSTS_BY_COLOR.has(color_name):
		_toast("That space doesn't have houses to sell.")
	elif space.owner_id != player.player_id:
		_toast("You don't own %s." % property_name)
	elif space.house_count <= 0:
		_toast("%s has no houses to sell." % property_name)
	elif space.house_count < _max_houses_in_group(color_name, player.player_id):
		_toast("You must sell evenly -- other properties you own in the color set have more houses than %s." % property_name)
	else:
		space.house_count -= 1
		player.money += sale_price
		var house_word: String = "house" if space.house_count == 1 else "houses"
		dice_label.text = "%s sold a house on %s for $%d (now %d %s)." % [_player_display_name(player.player_id), property_name, sale_price, space.house_count, house_word]
		_log("%s sold a house on %s for $%d (now %d %s)." % [PLAYER_NAMES[player.player_id], property_name, sale_price, space.house_count, house_word])
		_update_player_panels()


# The most houses on any one property in a color group that `owner_id` owns.
# Used both to enforce even selling (you can only pull a house off a property
# that's tied for the most among your own in the group) and to block
# mortgaging / selling / trading a property while another of yours in the same
# set still has houses. Only that owner's houses count -- an opponent building
# on the same colour (e.g. via Impossible Architecture, without the full set)
# never locks your properties.
func _max_houses_in_group(color_name: String, owner_id: int) -> int:
	var group: Array = board.get_color_group(color_name)
	var max_houses: int = 0
	for space_index in group:
		if board.spaces[space_index].owner_id == owner_id:
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
	var player: Node2D = players[_acting_player_id()]
	# Terminus Station (index 0) isn't a normal SPACE_DATA "property" -- see
	# _terminus_aware_price() -- but the card explicitly allows mortgaging it.
	var property_name: String = _property_name(index)
	var mortgage_value: int = _mortgage_value(_terminus_aware_price(index))

	if index != 0 and info.get("type", "") != "property":
		_toast("That space can't be mortgaged.")
	elif space.owner_id != player.player_id:
		_toast("You don't own %s." % property_name)
	elif space.is_mortgaged:
		_toast("%s is already mortgaged." % property_name)
	elif _max_houses_in_group(color_name, player.player_id) > 0:
		_toast("You can't mortgage %s while another property you own in its color set has houses." % property_name)
	else:
		space.is_mortgaged = true
		player.money += mortgage_value
		dice_label.text = "%s mortgaged %s for $%d." % [_player_display_name(player.player_id), property_name, mortgage_value]
		_log("%s mortgaged %s for $%d." % [PLAYER_NAMES[player.player_id], property_name, mortgage_value])
		_update_player_panels()


func _unmortgage_property(index: int) -> void:
	var info: Dictionary = board.get_space_info(index)
	var space: Node2D = board.spaces[index]
	var player: Node2D = players[_acting_player_id()]
	var property_name: String = _property_name(index)
	var unmortgage_value: int = _unmortgage_value(_terminus_aware_price(index))

	if index != 0 and info.get("type", "") != "property":
		_toast("That space can't be unmortgaged.")
	elif space.owner_id != player.player_id:
		_toast("You don't own %s." % property_name)
	elif not space.is_mortgaged:
		_toast("%s isn't mortgaged." % property_name)
	elif player.money < unmortgage_value:
		_toast("%s can't afford to unmortgage %s ($%d)." % [_player_display_name(player.player_id), property_name, unmortgage_value])
	else:
		space.is_mortgaged = false
		player.money -= unmortgage_value
		dice_label.text = "%s unmortgaged %s for $%d." % [_player_display_name(player.player_id), property_name, unmortgage_value]
		_log("%s unmortgaged %s for $%d." % [PLAYER_NAMES[player.player_id], property_name, unmortgage_value])
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
			if space_index != 0 and board.get_space_info(space_index).get("type", "") != "property":
				continue
			var color_name: String = board.get_space_info(space_index).get("color", "")
			if _max_houses_in_group(color_name, player.player_id) > 0:
				continue
			candidates.append(space_index)
		if candidates.is_empty():
			return
		candidates.sort_custom(func(a, b): return _terminus_aware_price(a) > _terminus_aware_price(b))
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
			if space.house_count == _max_houses_in_group(color_name, player.player_id):
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
		var owned_railroads: int = _unmortgaged_railroad_count(space.owner_id)
		return _railroad_rent(owned_railroads, rents)
	if color_name == "utility":
		var multipliers: Array = info.get("rent_multipliers", [])
		if multipliers.is_empty():
			return 0
		var owned_utilities: int = _count_unmortgaged_in_group(space.owner_id, "utility")
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
# open) waits here and drives resolution -- a call that arrives while it's
# already open (e.g. a spell cast in response to the first) just pushes
# _window_deadline_msec back out, extending the window the first call is
# waiting on, and returns immediately.
#
# Resolution is deliberately hands-off: a spell comes off the stack only when
# the window fully elapses with nobody paused (no player can force it by
# pausing/unpausing). Each spell going onto the stack opens a fresh window
# (see _finish_cast, which also un-pauses the caster -- their reaction is
# spent), and while a roll is still in flight each spell coming *off* the
# stack opens another one, so everyone gets a chance to answer every spell
# and to react to what each one did before the roll finally resolves.
func _response_window_seconds() -> float:
	if _tutorial_active:
		# A generous window for the moments the player has to react to; snappier
		# for the tutorial's own auto-resolutions (Migraine, Manastone, etc.).
		return 5.0 if _tutorial_expected_action == "press_space" else 1.5
	# Online, widen the window so a remote player's pause has time to reach
	# the host before the countdown expires.
	return RESPONSE_WINDOW_SECONDS * 2.0 if GameState.online else RESPONSE_WINDOW_SECONDS


# trigger / trigger_seat drive auto-pause (Pause Options) -- "roll" from
# _perform_roll, "cast" from _finish_cast, "resolve" is applied by the loop
# itself as each spell comes off the stack.
func _ensure_response_window(trigger: String = "", trigger_seat: int = -1) -> void:
	var seconds: float = _response_window_seconds()
	_window_deadline_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	# When a spell's resolution has stalled inside Raise Money mode -- it
	# charged someone who can't pay and is now awaiting `debt_resolved` -- the
	# loop that owns the stack is frozen and can't drain anything. A spell the
	# debtor now casts to earn their way out needs THIS call to run the stack
	# instead. `drain_only`: drive it down to empty (ignoring any roll still in
	# flight), then hand control back to the frozen loop.
	var drain_only: bool = _resolving_stack and _in_debt and not _response_window_open
	if (_response_window_open or _resolving_stack) and not drain_only:
		# A cast landing in a window that's already running still auto-pauses.
		_apply_auto_pause(trigger, trigger_seat)
		return
	_response_window_open = true
	_response_window_paused_by.resize(players.size())
	_response_window_paused_by.fill(false)
	_apply_auto_pause(trigger, trigger_seat)
	_refresh_action_buttons()
	dice_label.text += "\n(Press Space or your player number within %ds to pause from that player's perspective and react with an Instant spell.)" % int(seconds)

	# window -> resolve one spell -> (maybe) another window -> ... until the
	# stack is empty and there's nothing left to react to.
	while true:
		# _casting_spell also holds the window open: Reveal and
		# Burn-for-Attunement are pickable straight off a spell card without
		# pausing first, so without this the countdown could expire and the
		# roll resolve while _begin_spell_cast is still suspended in its own
		# pickers -- at which point _prompt_slot still points at the caster and
		# the rolling player's buy prompt gets misrouted to them (see
		# _prompt_target / _ask_buy_property).
		while _response_window_paused_by.has(true) or _casting_spell or Time.get_ticks_msec() < _window_deadline_msec:
			# Quit to Main Menu (or a disconnect) frees this scene mid-loop --
			# bail before touching a get_tree() that's about to go null.
			if _returning_to_menu or not is_inside_tree():
				return
			await get_tree().process_frame

		_response_window_open = false
		_refresh_action_buttons()
		if _spell_stack.is_empty():
			break

		_resolving_stack = true
		var resolved: Dictionary = await _resolve_top_of_stack()
		var resolved_name: String = resolved.get("spell_name", "")
		_resolving_stack = false
		_update_player_panels()
		# A spell cast to earn money out of a raise-money window may have done it.
		_maybe_resolve_debt()
		if _tutorial_active:
			_tutorial_on_spell_resolved(resolved_name)

		# Nothing more to answer -- the stack is empty and no roll is waiting on
		# a final reaction to what just resolved. (`drain_only`: stop the moment
		# the stack is clear and let the frozen Raise Money loop take over.)
		if _spell_stack.is_empty() and (drain_only or not _roll_in_flight):
			break

		# Fresh reaction window: more spells still on the stack to answer, or a
		# roll still in flight that the effect that just resolved could be
		# reacted to -- in the tutorial this includes the window after Adrenaline
		# resolves, kept so the player sees the response window a real game
		# would give them here even though there's nothing left to do.
		_response_window_open = true
		_window_deadline_msec = Time.get_ticks_msec() + int(_response_window_seconds() * 1000.0)
		_response_window_paused_by.fill(false)
		var resolved_caster: int = int(resolved.get("caster_id", -1))
		# A player who cast this spell while paused gets paused again now, so
		# they keep reacting -- for every Pause Options setting.
		var repause_seat: int = resolved_caster if resolved.get("caster_was_paused", false) else -1
		_apply_auto_pause("resolve", resolved_caster, repause_seat)
		_refresh_action_buttons()
		if not _tutorial_active:
			dice_label.text += "\n(Reaction window -- press Space or your player number to respond.)"

	_update_player_panels()
	_maybe_resolve_debt()
	# If the debtor cast a spell that didn't raise quite enough, they're back
	# in Raise Money mode -- make sure its buttons are showing.
	_refresh_action_buttons()


# Pops and resolves just the top of _spell_stack (LIFO), returning its stack
# entry ({} if the stack was empty) -- driven by _ensure_response_window()
# once a reaction window has fully elapsed. Countering a spell (T2 Response
# Spell, Level 1) removes its entry before it's ever popped here, so it's
# simply skipped -- per "countering negates the effect and discards it", its
# own resolve never runs, but _resolve_t2_counter() shuffles it back into the
# deck itself, same as any spell that resolves normally here does.
func _resolve_top_of_stack() -> Dictionary:
	if _spell_stack.is_empty():
		return {}
	var entry: Dictionary = _spell_stack.pop_back()
	# The card leaves the visual stack the moment it starts resolving.
	_update_spell_stack_display()
	var resolve: Callable = entry["resolve"]
	if resolve.is_valid():
		await resolve.call()
		_return_spell_to_deck(entry["spell_name"])
	return entry


# Spell names on the stack, bottom (oldest) -> top (newest / resolves first).
# From the real stack on the host; from the snapshot mirror on a client.
func _spell_stack_names() -> Array:
	if GameState.online and not GameState.is_authority():
		return _net_spell_stack_names
	var out: Array = []
	for entry in _spell_stack:
		out.append(entry["spell_name"])
	return out


# Shows the spell(s) currently being cast as big overlapping cards where the
# trade display normally sits (the two never happen together). Each newer
# card sits on top of and 50% of a card-width to the right of the previous
# one, so the rightmost card -- which resolves first -- reads as "next".
const SPELL_STACK_CARD_ASPECT: float = 375.0 / 523.0
const SPELL_STACK_MAX_CARD_W: float = 168.0
const SPELL_STACK_AVAIL_W: float = 810.0
var _spell_stack_display_cache: Array = []

func _update_spell_stack_display() -> void:
	if spell_cast_stack == null:
		return
	_refresh_spell_target_highlights()
	var names: Array = _spell_stack_names()
	if names == _spell_stack_display_cache:
		return
	_spell_stack_display_cache = names.duplicate()
	var showing: bool = not names.is_empty()
	spell_cast_display.visible = showing
	spell_cast_hseparator.visible = showing
	for child in spell_cast_stack.get_children():
		child.queue_free()
	if not showing:
		return

	var n: int = names.size()
	var card_w: float = minf(SPELL_STACK_MAX_CARD_W, SPELL_STACK_AVAIL_W / (0.5 * n + 0.5))
	var card_h: float = card_w / SPELL_STACK_CARD_ASPECT
	spell_cast_stack.custom_minimum_size = Vector2(0, card_h)

	for i in n:
		var info: Dictionary = SpellData.SPELLS.get(names[i], {})
		var tr := TextureRect.new()
		if info.has("icon"):
			tr.texture = load(info["icon"])
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(card_w, card_h)
		tr.position = Vector2(i * card_w * 0.5, 0.0)
		# Added last = drawn on top, so the newest card overlaps the rest.
		spell_cast_stack.add_child(tr)


# Every spell that's used -- resolved here, countered (_resolve_t2_counter),
# or burned for Attunement (_burn_spell_for_attunement) -- shuffles back into
# the shared deck via this.
func _return_spell_to_deck(spell_name: String) -> void:
	_spell_deck.append(spell_name)
	_spell_deck.shuffle()


# Sanity Grinding / Step Forward: called from their resolve functions once
# the effect has actually gone through (a countered cast never reaches this,
# so it just returns to the deck like any other countered spell instead).
func _queue_spell_return_to_hand(caster: Node2D, spell_name: String) -> void:
	caster.pending_return_spells[spell_name] = caster.pending_return_spells.get(spell_name, 0) + 1


# For each spell name `player` queued via _queue_spell_return_to_hand() this
# turn, pulls one copy back out of the shared deck (it's already in there --
# _resolve_top_of_stack() shuffled it back in right after resolving, same as
# any other spell) and into their hand, bypassing a normal random draw.
func _process_pending_spell_returns(player: Node2D) -> void:
	for spell_name in player.pending_return_spells:
		for i in player.pending_return_spells[spell_name]:
			if _spell_deck.has(spell_name):
				_spell_deck.erase(spell_name)
				_spell_add(player, spell_name)
	player.pending_return_spells.clear()


# Handler for the response window above, per player_index (0 = P1, paused by
# either Space or "1"; "2".."8" pause 1..7 -- see _unhandled_input()). Ignored
# while a spell's own cast prompts are up (_casting_spell) or while a spell is
# actually resolving (_resolving_stack) so nothing can yank a popup out or
# interrupt a resolution.
#
# Just a plain toggle: a spell comes off the stack only when the window
# elapses on its own (see _ensure_response_window), so unpausing here can't
# force resolution -- it only stops holding the window open.
func _toggle_pause_for_player(player_index: int) -> void:
	if not _response_window_open or _casting_spell or _resolving_stack:
		return
	_response_window_paused_by[player_index] = not _response_window_paused_by[player_index]
	if _response_window_paused_by[player_index]:
		# Pausing during the tumble skips straight to the real faces.
		dice_roller.finish_now()
		dice_label.text += "\nPaused from %s's perspective -- press %d to resume." % [PLAYER_NAMES[player_index], player_index + 1]
	_refresh_action_buttons()
	_update_player_panels()


# --- Pause Options (Settings): auto-pause ------------------------------

# Copies this machine's Pause Options setting onto the seat(s) it controls
# (every human seat in a hotseat game; this client's own online). Remote seats
# keep whatever they last reported via _net_report_pause_option.
func _apply_local_pause_option() -> void:
	for seat in players.size():
		if seat >= _seat_pause_option.size():
			continue
		var local: bool = GameState.is_slot_local(seat) if GameState.online else not players[seat].is_ai
		if local:
			_seat_pause_option[seat] = _pause_option


func _on_pause_option_changed(option: int) -> void:
	_pause_option = option
	_apply_local_pause_option()
	if GameState.online and not GameState.is_authority():
		_net_report_pause_option.rpc_id(1, option)


# A client tells the host which Pause Options mode it's on, so the host can
# auto-pause that seat on its behalf (the seat's pause state then reaches the
# client through the normal snapshot).
@rpc("any_peer", "call_remote", "reliable")
func _net_report_pause_option(option: int) -> void:
	if not GameState.is_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var opt: int = clampi(option, PAUSE_MANUAL, PAUSE_FULL)
	for seat in players.size():
		if seat < GameState.slot_peer.size() and GameState.slot_peer[seat] == sender and seat < _seat_pause_option.size():
			_seat_pause_option[seat] = opt


# Auto-pauses seats whose Pause Options setting says to, for a reaction-window
# trigger: event is "roll" | "cast" | "resolve" and trigger_seat is the roller
# / caster. Host-side; normally only pauses a seat that holds at least one
# spell. `force_seat`, if set, is a seat that pauses regardless of its Pause
# Options setting or hand size -- used to re-pause a player after a spell they
# cast while paused resolves.
func _apply_auto_pause(event: String, trigger_seat: int, force_seat: int = -1) -> void:
	if not _response_window_open or not GameState.is_authority():
		return
	# The tutorial choreographs its own pauses -- but the cast-while-paused
	# re-pause (force_seat) still applies, so its script can rely on it.
	if _tutorial_active and force_seat < 0:
		return
	var paused_names: Array[String] = []
	for seat in players.size():
		if seat >= _response_window_paused_by.size() or _response_window_paused_by[seat]:
			continue
		if players[seat].is_ai or players[seat].is_bankrupt:
			continue
		var forced: bool = seat == force_seat
		if not forced and players[seat].spell_hand.is_empty():
			continue
		var opt: int = _seat_pause_option[seat] if seat < _seat_pause_option.size() else PAUSE_MANUAL
		if not forced and not _auto_pause_applies(opt, event, seat, trigger_seat):
			continue
		_response_window_paused_by[seat] = true
		paused_names.append(PLAYER_NAMES[seat])
	if not paused_names.is_empty():
		dice_roller.finish_now()
		dice_label.text += "\nAuto-paused: %s (press Space / your number to resume)." % ", ".join(paused_names)
		_refresh_action_buttons()
		_update_player_panels()


func _auto_pause_applies(opt: int, event: String, seat: int, trigger_seat: int) -> bool:
	match opt:
		PAUSE_HALF:
			return (event == "roll" or event == "resolve") and trigger_seat == seat
		PAUSE_FULL:
			if event == "cast":
				return trigger_seat != seat
			return event == "roll" or event == "resolve"
	return false  # PAUSE_MANUAL / unknown


func _perform_roll(die1: int, die2: int) -> void:
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	admin_spells_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true
	declare_bankruptcy_button.disabled = true
	trade_button.disabled = true

	var roll: int = die1 + die2
	var is_double: bool = die1 == die2
	var player: Node2D = players[current_player]
	# Register the dice and start the tumble animation -- it runs for the
	# first half of the response window, then settles on the real faces.
	_die1 = die1
	_die2 = die2
	_roll_seq += 1
	dice_roller.roll(die1, die2, _response_window_seconds() * 0.5)
	dice_label.text = "%s rolled: %d + %d = %d" % [_player_display_name(current_player), die1, die2, roll]
	_log("%s rolled %d + %d = %d." % [PLAYER_NAMES[current_player], die1, die2, roll])
	if is_double:
		_log("%s rolled doubles." % PLAYER_NAMES[current_player])

	# Unstable Portal, then Hasty Exit Level 1 -- both set up before this
	# roll, "before rolling"; the multiplier applies to the base roll first,
	# with any flat bonus stacking on top of that.
	if player.next_roll_multiplier != 1:
		roll *= player.next_roll_multiplier
		dice_label.text += "\nUnstable Portal multiplies by %d (now %d)." % [player.next_roll_multiplier, roll]
		_log("%s's roll is multiplied by %d (now %d)." % [PLAYER_NAMES[current_player], player.next_roll_multiplier, roll])
		player.next_roll_multiplier = 1
	if player.next_roll_bonus != 0:
		roll += player.next_roll_bonus
		dice_label.text += "\nHasty Exit adds %d (now %d)." % [player.next_roll_bonus, roll]
		_log("%s's roll is modified by %+d (now %d)." % [PLAYER_NAMES[current_player], player.next_roll_bonus, roll])
		player.next_roll_bonus = 0

	_current_roll = roll
	_roll_in_flight = true
	# Tutorial: the "roll" step becomes "Quick! Press Space Bar!" as the window
	# opens; the player must pause it within the window (see _unhandled_input).
	if _tutorial_active and _tutorial_expected_action == "roll":
		_tutorial_advance()
	await _ensure_response_window("roll", current_player)
	if _returning_to_menu or not is_inside_tree():
		return
	_roll_in_flight = false
	dice_roller.finish_now()
	roll = _current_roll

	# Tutorial: still on "press_space" once the window has closed = the player
	# never paused. Rewind and let them roll again.
	if _tutorial_active and _tutorial_expected_action == "press_space":
		_tutorial_rewind_roll()
		return

	# Belt-and-suspenders: _prompt_slot is only ever meant to be set mid
	# _begin_spell_cast (routing that caster's own level/target pickers).
	# The rest of this turn -- move, landing, buy decision -- must prompt
	# whoever's turn it is, so make sure a spell someone cast/revealed during
	# the response window can't leave it pointing elsewhere.
	_prompt_slot = -1

	var grants_extra_turn: bool = is_double

	if player.in_jail:
		if is_double:
			player.in_jail = false
			player.consecutive_doubles = 0
			dice_label.text += "\nRolled doubles! Released from Jail."
			_log("%s left Jail (rolled doubles)." % PLAYER_NAMES[current_player])
			grants_extra_turn = false
			await _move_player(player, roll)
		else:
			player.jail_turns_left -= 1
			if player.jail_turns_left <= 0:
				player.money -= 50
				free_parking_amount += 50
				player.in_jail = false
				dice_label.text += "\nSentence served, paid $50 to Free Parking."
				_log_payment(current_player, 50, "Free Parking")
				_log("%s left Jail." % PLAYER_NAMES[current_player])
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
	# A big enough roll (roll-multiplier spells like Unstable Portal) can carry
	# a player past Go more than once in one move -- $200 and a spell draw for
	# each pass.
	var go_passes: int = new_space_raw / board.TOTAL_SPACES if new_space_raw > 0 else 0
	if go_passes > 0:
		player.money += 200 * go_passes
		var drawn: Array[String] = []
		for _i in go_passes:
			var s: String = _draw_spell(player)
			if s != "":
				drawn.append(s)
		var times: String = "" if go_passes == 1 else " %d times" % go_passes
		var draw_note: String = "" if drawn.is_empty() else (", drew %s" % ", ".join(drawn))
		dice_label.text += "\nYou passed Go%s! (+$%d Money%s)" % [times, 200 * go_passes, draw_note]
		_log("%s passed Go%s (+$%d)." % [PLAYER_NAMES[player.player_id], times, 200 * go_passes])
		_update_player_panels()

	player.current_space = new_space_raw % board.TOTAL_SPACES
	player.position = board.get_space_center(player.current_space) + MARKER_OFFSETS[player.player_id]
	_log("%s landed on %s." % [PLAYER_NAMES[player.player_id], _property_name(player.current_space)])

	# Terminus Station: an overlay on Go, not a real SPACE_DATA space, so
	# this is a standalone check rather than part of the "type" chain below
	# (Go's own type is always "", so it never matches anything there
	# anyway). "Go" landing/passing money above still applies independently.
	if player.current_space == 0 and board.spaces[0].owner_id != -1 and board.spaces[0].owner_id != player.player_id and not board.spaces[0].is_mortgaged:
		var terminus_owner: Node2D = players[board.spaces[0].owner_id]
		var owned_railroads: int = _unmortgaged_railroad_count(board.spaces[0].owner_id)
		var rent_amount: int = _apply_payment_reduction(player, _railroad_rent(owned_railroads, TERMINUS_RAILROAD_RENTS))
		if rent_amount > player.money:
			dice_label.text += "\nTerminus (owned by %s)! Owes $%d rent." % [PLAYER_NAMES[board.spaces[0].owner_id], rent_amount]
			await _collect_debt(player, rent_amount, terminus_owner)
			return player.is_bankrupt
		player.money -= rent_amount
		terminus_owner.money += rent_amount
		dice_label.text += "\nTerminus (owned by %s)! Paid $%d rent (%d railroads owned)." % [PLAYER_NAMES[board.spaces[0].owner_id], rent_amount, owned_railroads]
		_log_payment(player.player_id, rent_amount, PLAYER_NAMES[board.spaces[0].owner_id])

	var landed_info: Dictionary = board.get_space_info(player.current_space)
	if landed_info.get("type", "") == "tax":
		var tax_value: int = landed_info.get("value", 0)
		var tax_space: Node2D = board.spaces[player.current_space]
		if tax_space.owner_id == player.player_id:
			dice_label.text += "\nLanded on %s! You own it, so you pay nothing." % landed_info.get("name", "")
		elif tax_space.owner_id != -1:
			# Tax Haven: an opponent landing on a claimed tax space pays its
			# owner instead of Free Parking.
			var owner: Node2D = players[tax_space.owner_id]
			var owed: int = _apply_payment_reduction(player, tax_value)
			if owed > player.money:
				dice_label.text += "\nLanded on %s (owned by %s)! Owes $%d." % [landed_info.get("name", ""), PLAYER_NAMES[tax_space.owner_id], owed]
				await _collect_debt(player, owed, owner)
				return player.is_bankrupt
			player.money -= owed
			owner.money += owed
			dice_label.text += "\nLanded on %s (owned by %s)! Paid $%d." % [landed_info.get("name", ""), PLAYER_NAMES[tax_space.owner_id], owed]
			_log_payment(player.player_id, owed, PLAYER_NAMES[tax_space.owner_id])
		else:
			if tax_value > player.money:
				dice_label.text += "\nLanded on %s! Owes $%d." % [landed_info.get("name", ""), tax_value]
				await _collect_debt(player, tax_value, null)
				return player.is_bankrupt
			player.money -= tax_value
			free_parking_amount += tax_value
			dice_label.text += "\nLanded on %s! -%d Money (added to Free Parking)" % [landed_info.get("name", ""), tax_value]
			_log_payment(player.player_id, tax_value, "Free Parking")
	elif landed_info.get("type", "") == "free_parking":
		if free_parking_amount > 0:
			player.money += free_parking_amount
			dice_label.text += "\nLanded on Free Parking! +%d Money" % free_parking_amount
			_log("%s collected $%d from Free Parking." % [PLAYER_NAMES[player.player_id], free_parking_amount])
			free_parking_amount = 0
		else:
			dice_label.text += "\nLanded on Free Parking!"
	elif landed_info.get("type", "") == "go_to_jail":
		_send_to_jail(player)
		dice_label.text += "\nLanded on Go To Jail! Sent to Jail."
		return true
	elif landed_info.get("type", "") == "magic_forest":
		dice_label.text += "\nLanded on Magic Forest!"
		await _visit_magic_forest(player)
	elif landed_info.get("type", "") == "spell_shop":
		dice_label.text += "\nLanded on Spell Shop!"
		await _visit_spell_shop(player)
	elif landed_info.get("type", "") == "property":
		var space: Node2D = board.spaces[player.current_space]
		var property_name: String = landed_info.get("name", "")
		var price: int = landed_info.get("price", 0)
		var color_name_for_purchase: String = landed_info.get("color", "")
		var free_railroad: bool = color_name_for_purchase == "railroad" and player.free_railroad_purchase
		if space.owner_id == -1:
			dice_label.text += "\nLanded on %s ($%d)." % [property_name, price]
			# A peek at what the player would actually pay, without consuming
			# anything yet -- only an actual purchase (below) should use it up.
			var effective_price: int = price
			if free_railroad:
				effective_price = 0
			elif player.haggling_discount_percent > 0:
				effective_price = maxi(0, price - (price * player.haggling_discount_percent / 100))
			# _ask_buy_property() only returns true once the player both said
			# yes AND actually has the money -- it keeps re-asking (letting
			# them sell houses / mortgage in between) until either that's
			# true or they say no.
			var wants_to_buy: bool = await _ask_buy_property(property_name, effective_price)
			if wants_to_buy:
				var final_price: int = price
				if free_railroad:
					final_price = 0
					player.free_railroad_purchase = false
					dice_label.text += "\nThe Cult of Terminus makes this railroad free!"
				else:
					final_price = _apply_haggling_discount(player, price)
				player.money -= final_price
				space.owner_id = player.player_id
				player.owned_property_indices.append(player.current_space)
				_sort_owned_properties(player)
				dice_label.text += "\nBought %s for $%d!" % [property_name, final_price]
				_log("%s bought %s for $%d." % [PLAYER_NAMES[player.player_id], property_name, final_price])
				_note_ownership(player.current_space)
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
				var owned_railroads: int = _unmortgaged_railroad_count(space.owner_id)
				rent_amount = _railroad_rent(owned_railroads, rents)
				note = " (%d unmortgaged railroad%s)" % [owned_railroads, "" if owned_railroads == 1 else "s"]
				charged = true
			elif color_name == "utility":
				var multipliers: Array = landed_info.get("rent_multipliers", [])
				if not multipliers.is_empty():
					var owned_utilities: int = _count_unmortgaged_in_group(space.owner_id, "utility")
					var multiplier_tier: int = clampi(owned_utilities, 1, multipliers.size()) - 1
					var multiplier: int = multipliers[multiplier_tier]
					rent_amount = multiplier * roll
					var utility_word: String = "utility" if owned_utilities == 1 else "utilities"
					note = " (%d unmortgaged %s, %dx dice roll of %d)" % [owned_utilities, utility_word, multiplier, roll]
					charged = true
			elif not rents.is_empty():
				# Price Gouging treats the property as having extra houses
				# (capped at 5 total) purely for this calculation -- it
				# doesn't touch space.house_count itself.
				var effective_houses: int = mini(5, space.house_count + players[space.owner_id].price_gouging_bonus_houses)
				if effective_houses > 0:
					rent_amount = rents[effective_houses]
					note = " (%d house%s)" % [effective_houses, "" if effective_houses == 1 else "s"]
					if players[space.owner_id].price_gouging_bonus_houses > 0:
						note += " (Price Gouging)"
				else:
					rent_amount = rents[0]
					if _owns_full_color_group(space.owner_id, color_name):
						rent_amount *= 2
						note = " (monopoly, doubled)"
				charged = true

			if charged:
				rent_amount = _apply_payment_reduction(player, rent_amount)
				var owner: Node2D = players[space.owner_id]
				if rent_amount > player.money:
					dice_label.text += "\nLanded on %s (owned by %s)! Owes $%d rent." % [property_name, PLAYER_NAMES[space.owner_id], rent_amount]
					await _collect_debt(player, rent_amount, owner)
					return player.is_bankrupt
				player.money -= rent_amount
				owner.money += rent_amount
				dice_label.text += "\nLanded on %s (owned by %s)! Paid $%d rent%s." % [property_name, PLAYER_NAMES[space.owner_id], rent_amount, note]
				_log_payment(player.player_id, rent_amount, PLAYER_NAMES[space.owner_id])

	return false


# Counterfeit Currency: cuts `amount` by `payer`'s active buffer (if any),
# floored at $0, consuming the buffer -- it only ever covers one payment.
# Called wherever a player is forced to pay an opponent (rent, a spell like
# T1 Burn Spell), *before* checking whether they can even afford it, since
# the reduction changes how much is actually owed in the first place. Not
# applied to tax (paid to Free Parking, not an opponent) or to trades
# (a negotiated exchange, not something "you would pay").
func _apply_payment_reduction(payer: Node2D, amount: int) -> int:
	if payer.payment_reduction_buffer <= 0:
		return amount
	var reduced: int = maxi(0, amount - payer.payment_reduction_buffer)
	dice_label.text += "\n%s's Counterfeit Currency buffer cuts the payment by $%d." % [_player_display_name(payer.player_id), amount - reduced]
	payer.payment_reduction_buffer = 0
	return reduced


# Charges `payer` `amount` on a spell's behalf, crediting `creditor` (or
# Free Parking if null). If they can't afford it, this opens the exact same
# debt-collection screen as unpayable rent or tax -- sell houses/mortgage,
# trade, cast spells, or declare bankruptcy -- so a spell can now bankrupt a
# player, same as landing on a property they can't cover. `resolve_message`
# is shown on immediate success; `debt_message` is shown (attributing the
# debt to the spell) right before the debt screen takes over.
# `append`: false (default) replaces dice_label's text outright, matching
# every single-payment spell. A spell that charges several different payers
# in a loop (Line of Fire, Sinkhole) passes true instead, so each payment's
# message adds a new line rather than erasing the previous one -- otherwise
# only the very last payment would ever be visible, even though every
# payment still actually happened.
func _charge_spell_payment(payer: Node2D, amount: int, creditor: Node2D, resolve_message: String, debt_message: String, append: bool = false) -> void:
	if amount > payer.money:
		if append:
			dice_label.text += "\n" + debt_message
		else:
			dice_label.text = debt_message
		await _collect_debt(payer, amount, creditor)
		return
	payer.money -= amount
	if creditor:
		creditor.money += amount
	_log_payment(payer.player_id, amount, PLAYER_NAMES[creditor.player_id] if creditor else "Free Parking")
	if append:
		dice_label.text += "\n" + resolve_message
	else:
		dice_label.text = resolve_message
	_update_player_panels()


# Haggling: cuts `price` by `buyer`'s active discount (if any), consuming it
# -- covers one property or house purchase only. Level 3's bank bonus is
# paid out immediately here too, on the *full* price (not what was actually
# spent, which after a 100% discount is $0) -- a straight profit, not just
# netting the purchase to free. Scoped to the two "ordinary" purchase paths
# -- landing on an unowned property, and the Buy House button -- not
# spell-driven acquisitions like Impossible Architecture or Promised Land,
# which already set their own prices.
func _apply_haggling_discount(buyer: Node2D, price: int) -> int:
	if buyer.haggling_discount_percent <= 0:
		return price
	var discounted: int = maxi(0, price - (price * buyer.haggling_discount_percent / 100))
	dice_label.text += "\n%s's Haggling discount cuts the price by $%d." % [_player_display_name(buyer.player_id), price - discounted]
	if buyer.haggling_bank_bonus:
		# Level 3: paid for by the bank, not a refund of what was actually
		# spent -- the full (undiscounted) price, on top of the purchase
		# already being free (100% discount), nets to a straight profit.
		buyer.money += price
		dice_label.text += " The bank also pays them $%d!" % price
	buyer.haggling_discount_percent = 0
	buyer.haggling_bank_bonus = false
	return discounted


# Magic Forest: draw 2 spells, then must discard 1 card from hand -- an AI
# just discards a random card (no strategy yet); a human picks via
# player_picker, locked behind _casting_spell like a real cast so a
# response-window click from someone else can't collide with it (there's no
# response window of its own here, this isn't an Instant Timing).
func _visit_magic_forest(player: Node2D) -> void:
	var drawn: Array[String] = []
	for i in 2:
		var spell_name: String = _draw_spell(player)
		if spell_name != "":
			drawn.append(spell_name)
	if drawn.is_empty():
		dice_label.text += " The Spell Deck is empty."
	else:
		dice_label.text += " Drew %s." % ", ".join(drawn)
	_update_player_panels()

	if player.spell_hand.is_empty():
		return

	_casting_spell = true
	_refresh_action_buttons()

	var hand_index: int
	if player.is_ai:
		hand_index = randi_range(0, player.spell_hand.size() - 1)
	else:
		var entries: Array = []
		for i in player.spell_hand.size():
			var spell_name: String = player.spell_hand[i]
			var spell_info: Dictionary = SpellData.SPELLS.get(spell_name, {})
			entries.append({"index": i, "name": spell_name, "icon": load(spell_info.get("icon", ""))})
		_cp_open("Magic Forest: choose a spell to discard.", entries, true, "", -2, true)
		hand_index = await _cp_result()

	var discarded: String = player.spell_hand[hand_index]
	_spell_remove_at(player, hand_index)
	_return_spell_to_deck(discarded)
	dice_label.text += "\n%s discarded %s." % [_player_display_name(player.player_id), discarded]

	_casting_spell = false
	_refresh_action_buttons()
	_update_player_panels()


# Spell Shop: look at the top 4 cards of the deck; pick one for $100 (to
# Free Parking) or Skip. One of the shown spells, chosen at random, is on
# sale for $50 instead. Either way, whatever isn't taken shuffles back in.
# An AI always skips for now (no purchasing strategy yet).
func _visit_spell_shop(player: Node2D) -> void:
	var top_cards: Array[String] = []
	for i in 4:
		if _spell_deck.is_empty():
			break
		top_cards.append(_spell_deck.pop_back())
	if top_cards.is_empty():
		dice_label.text += " The Spell Deck is empty."
		return

	_casting_spell = true
	_refresh_action_buttons()

	var sale_index: int = randi_range(0, top_cards.size() - 1)

	var choice: int = SPELL_SHOP_SKIP_INDEX
	if not player.is_ai:
		var entries: Array = []
		for i in top_cards.size():
			var spell_info: Dictionary = SpellData.SPELLS.get(top_cards[i], {})
			var caption: String = "[color=#e23c3c]$50[/color]" if i == sale_index else "$100"
			entries.append({"index": i, "name": top_cards[i], "icon": load(spell_info.get("icon", "")), "caption": caption})
		while true:
			_cp_open("Spell Shop: buy a spell ($100, one on sale for $50), or Skip.", entries, true, "Skip", SPELL_SHOP_SKIP_INDEX, true)
			choice = await _cp_result()
			if choice < 0 or choice >= top_cards.size():
				choice = SPELL_SHOP_SKIP_INDEX
				break
			var want_price: int = 50 if choice == sale_index else 100
			if player.money >= want_price:
				break
			# Picked one they can't afford -- raise the money, or Cancel back
			# to the shop. _casting_spell is dropped so a money spell can be cast.
			_casting_spell = false
			var outcome: String = await _raise_money(player, want_price, null, true, false)
			_casting_spell = true
			_refresh_action_buttons()
			if outcome == "paid" and player.money >= want_price:
				break

	if choice >= 0 and choice < top_cards.size():
		var price: int = 50 if choice == sale_index else 100
		if player.money < price:
			dice_label.text += "\n%s can't afford the Spell Shop's $%d price and skips." % [_player_display_name(player.player_id), price]
		else:
			var chosen_spell: String = top_cards[choice]
			top_cards.remove_at(choice)
			player.money -= price
			free_parking_amount += price
			_spell_add(player, chosen_spell)
			dice_label.text += "\n%s bought %s from the Spell Shop for $%d!" % [_player_display_name(player.player_id), chosen_spell, price]
	else:
		dice_label.text += "\n%s skipped the Spell Shop." % _player_display_name(player.player_id)

	for spell_name in top_cards:
		_spell_deck.append(spell_name)
	_spell_deck.shuffle()

	_casting_spell = false
	_refresh_action_buttons()
	_update_player_panels()


# Mortgage/house/trade/spell/bankruptcy actions, and the button-enablement
# logic in _refresh_action_buttons(), all need to operate on whoever's
# actually acting right now -- which is current_player normally, but while a
# debt (the Raise Money window, see _raise_money()) is outstanding it's
# specifically whoever the debt is on, since a spell can force *any* player
# into debt regardless of whose turn it is (e.g. P2's AI casting T1 Burn
# Spell against P1 on P2's own turn).
func _acting_player_id() -> int:
	return _debt_player_id if _in_debt else current_player


# Forced debt: an opponent (or the bank) must be paid `amount` and the
# player is short. They raise money or go bankrupt.
func _collect_debt(player: Node2D, amount: int, creditor: Node2D) -> void:
	await _raise_money(player, amount, creditor, false, true)


# Point the _debt_* mirror vars at the top of _debt_stack (or clear them if
# it's empty). Call after every push/pop.
func _sync_current_debt() -> void:
	if _debt_stack.is_empty():
		_in_debt = false
		_debt_amount = 0
		_debt_creditor = null
		_debt_player_id = -1
		_debt_cancellable = false
		_debt_auto_pay = true
		_debt_outcome = ""
		return
	var d: Dictionary = _debt_stack.back()
	_in_debt = true
	_debt_amount = int(d["amount"])
	_debt_creditor = d["creditor"]
	_debt_player_id = int(d["player_id"])
	_debt_cancellable = bool(d["cancellable"])
	_debt_auto_pay = bool(d["auto_pay"])
	_debt_outcome = String(d["outcome"])


# Mark the current (top) debt finished with `outcome`, pop it, re-point the
# mirror at whatever's underneath, and wake the _raise_money() awaiting it.
func _finish_current_debt(outcome: String) -> void:
	if _debt_stack.is_empty():
		return
	_debt_stack.back()["outcome"] = outcome  # the awaiting _raise_money reads this
	_debt_stack.pop_back()
	_sync_current_debt()
	_update_player_panels()
	debt_resolved.emit()


# A player left the game (bankrupt / disconnected-and-forfeited): resolve
# EVERY debt they owe -- the one being raised now and any suspended deeper in
# the stack -- so no _raise_money() is left waiting on them.
func _fail_all_debts_for(player_id: int, outcome: String) -> void:
	var changed: bool = false
	for i in range(_debt_stack.size() - 1, -1, -1):
		if int(_debt_stack[i]["player_id"]) == player_id:
			_debt_stack[i]["outcome"] = outcome
			_debt_stack.remove_at(i)
			changed = true
	if changed:
		_sync_current_debt()
		_update_player_panels()
		debt_resolved.emit()


# The "Raise Money" window. Restricts the acting player to the money-raising
# actions -- Sell Houses / Mortgage, Trade, and casting a turn spell (to earn
# their way out) -- plus either Declare Bankruptcy (forced debt) or Cancel
# (an optional purchase they can't afford). Returns "paid", "cancelled" or
# "bankrupt". `auto_pay` false means reaching the amount just ends the
# window; whoever opened it does the actual charge.
#
# Re-entrant: a spell cast to raise money can charge someone who can't pay,
# stacking a new debt on top -- that one is settled first, then this one
# resumes (see the _debt_stack note up top).
func _raise_money(player: Node2D, amount: int, creditor: Node2D, cancellable: bool, auto_pay: bool) -> String:
	var entry: Dictionary = {
		"player_id": player.player_id, "amount": amount, "creditor": creditor,
		"cancellable": cancellable, "auto_pay": auto_pay, "outcome": "",
	}
	_debt_stack.push_back(entry)
	_sync_current_debt()
	_log("%s needs to raise $%d." % [PLAYER_NAMES[player.player_id], amount])
	dice_label.text += "\n%s: raise $%d (sell houses / mortgage, trade, or cast a spell)." % [_player_display_name(player.player_id), amount]

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
		if entry["outcome"] == "":  # a mid-loop _maybe_resolve_debt may have paid it
			if player.money >= int(entry["amount"]):
				_maybe_resolve_debt()
			elif cancellable:
				_finish_current_debt("cancelled")
			else:
				dice_label.text += "\n%s can't raise the money and forfeits the game." % _player_display_name(player.player_id)
				_forfeit_to_bankruptcy(player, creditor)
				_fail_all_debts_for(player.player_id, "bankrupt")
		return String(entry["outcome"])

	_refresh_action_buttons()
	while entry["outcome"] == "":
		await debt_resolved
		if _returning_to_menu or not is_inside_tree():
			return "cancelled"
	return String(entry["outcome"])


# Cancel button in a cancellable raise-money window (an optional purchase the
# player decided against once they saw the price). Only ever the top debt.
func _cancel_raise_money() -> void:
	if _debt_stack.is_empty() or not bool(_debt_stack.back()["cancellable"]):
		return
	dice_label.text += "\n%s cancelled the purchase." % _player_display_name(int(_debt_stack.back()["player_id"]))
	_finish_current_debt("cancelled")


# Called after every action that can change a debtor's money while a
# raise-money window is open (sell house, mortgage, trade, a spell resolving).
# Once the top debt's owner has enough, pays it (unless auto_pay is off -- an
# optional purchase pays itself) and lets that _raise_money() continue.
func _maybe_resolve_debt() -> void:
	if _debt_stack.is_empty():
		return
	var d: Dictionary = _debt_stack.back()
	var player: Node2D = players[int(d["player_id"])]
	var owed: int = int(d["amount"])
	if player.money < owed:
		return
	var creditor: Node2D = d["creditor"]
	if bool(d["auto_pay"]):
		player.money -= owed
		if creditor != null and not creditor.is_bankrupt:
			creditor.money += owed
			_log_payment(player.player_id, owed, PLAYER_NAMES[creditor.player_id])
		else:
			free_parking_amount += owed
			_log_payment(player.player_id, owed, "Free Parking")
		dice_label.text += "\n%s raised enough money and paid the $%d owed." % [_player_display_name(player.player_id), owed]
	else:
		dice_label.text += "\n%s raised the $%d." % [_player_display_name(player.player_id), owed]

	_finish_current_debt("paid")


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
	# Online: only the machine that controls the acting seat gets live action
	# buttons -- the host on a remote player's turn, and every client on
	# someone else's turn, stay locked. (Local hotseat: is_slot_local() is
	# always true, so this is never set.)
	var not_my_seat: bool = GameState.online and not GameState.is_slot_local(_acting_player_id())
	# Admin buttons are a host-side testing aid -- never offered to a client.
	var host_only: bool = not GameState.is_authority()
	# A Computer player's turn plays itself -- lock every button so the human
	# at the keyboard can't act (or trade) on its behalf while it's "thinking".
	# Uses _acting_player_id() so a human forced into debt on an AI's turn
	# still gets Sell Houses / Mortgage / Declare Bankruptcy / Trade.
	var ai_turn: bool = players[_acting_player_id()].is_ai
	var lock: bool = _trading or _casting_spell or _response_window_open or ai_turn or not_my_seat
	# The sticky Sell / Buy Houses modes: while one is on, everything else is
	# locked and the two toggle buttons stay live so it can be switched or
	# turned off (see _on_buy/sell_house_*_pressed).
	var house_mode: bool = _buying_house_or_unmortgaging or _selling_house_or_mortgaging

	roll_button.disabled = limited_to_selling or lock or house_mode
	roll_button.text = "End Turn" if _awaiting_end_turn else "Roll"
	admin_button.disabled = limited_to_selling or lock or _awaiting_end_turn or host_only or house_mode
	admin_properties_button.disabled = limited_to_selling or lock or host_only or house_mode
	admin_spells_button.disabled = limited_to_selling or lock or host_only or house_mode
	buy_house_unmortgage_button.disabled = limited_to_selling or lock
	sell_house_mortgage_button.disabled = lock
	trade_button.disabled = _awaiting_buy_decision or lock or house_mode

	buy_house_mode_outline.visible = _buying_house_or_unmortgaging and not not_my_seat
	sell_house_mode_outline.visible = _selling_house_or_mortgaging and not not_my_seat

	# While raising money for something optional, Declare Bankruptcy is
	# replaced by a Cancel that drops the purchase (see _cancel_raise_money).
	if _in_debt and _debt_cancellable:
		declare_bankruptcy_button.text = "Cancel purchase"
		declare_bankruptcy_button.disabled = lock
	else:
		declare_bankruptcy_button.text = "Declare Bankruptcy"
		declare_bankruptcy_button.disabled = _awaiting_buy_decision or lock

	if _trading:
		# During a trade only the current proposer's machine has controls;
		# everyone else watches. (Hotseat: is_slot_local() is always true.)
		var can_propose: bool = not GameState.online or GameState.is_slot_local(_trade_proposer)
		offer_trade_button.disabled = not can_propose
		decline_trade_button.disabled = not can_propose
		trader1_money_edit.editable = can_propose
		trader2_money_edit.editable = can_propose
		offer_trade_button.text = "Accept Trade" if _trade_can_accept else "Offer Trade"


func _on_trade_pressed() -> void:
	if _tutorial_blocks("trade"):
		return
	if GameState.online and not GameState.is_authority():
		_net_action_intent.rpc_id(1, "trade")
		return
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	admin_spells_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true
	declare_bankruptcy_button.disabled = true
	trade_button.disabled = true

	var acting_player_id: int = _acting_player_id()
	var entries: Array = []
	for i in players.size():
		if i != acting_player_id and not players[i].is_bankrupt:
			entries.append({"index": i, "name": PLAYER_NAMES[i], "color": PLAYER_COLORS[i]})

	if entries.is_empty():
		dice_label.text += "\nThere's no one left to trade with."
		_refresh_action_buttons()
		return

	_pp_open("Trade with which player?", entries)
	var chosen: int = await _pp_result()
	if chosen == -1:
		_refresh_action_buttons()
		return

	_start_trade(acting_player_id, chosen)


func _start_trade(p1_index: int, p2_index: int) -> void:
	_trading = true
	_trade_current_player = current_player
	_trader1 = p1_index
	_trader2 = p2_index
	_trade1_offered.clear()
	_trade2_offered.clear()
	_trade1_spells_offered.clear()
	_trade2_spells_offered.clear()
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

	dice_label.text += "\n%s is trading with %s. Click properties or spells to offer them; houses can't be traded." % [PLAYER_NAMES[p1_index], PLAYER_NAMES[p2_index]]
	_update_trade_action_button()
	_update_player_panels()
	_refresh_action_buttons()


# Toggles a property in or out of whichever trader's offer it belongs to.
# Reused for clicks both on a player's normal mini cards (offering it) and
# on the trade display's own mini cards (taking it back).
func _handle_trade_click(index: int) -> void:
	# Only the proposer's machine acts; a client sends it to the host, which
	# runs _apply_trade_click via _net_trade_click_intent (already validated).
	if GameState.online:
		if not GameState.is_slot_local(_trade_proposer):
			return
		if not GameState.is_authority():
			_net_trade_click_intent.rpc_id(1, index)
			return
	_apply_trade_click(index)


func _apply_trade_click(index: int) -> void:
	var space: Node2D = board.spaces[index]
	if space.owner_id != _trader1 and space.owner_id != _trader2:
		_toast("That property isn't part of this trade.")
		return
	var color_name: String = board.get_space_info(index).get("color", "")
	if _max_houses_in_group(color_name, space.owner_id) > 0:
		_toast("That property can't be traded while its owner has houses on another property in its color set.")
		return

	var offered: Array[int] = _trade1_offered if space.owner_id == _trader1 else _trade2_offered
	if offered.has(index):
		offered.erase(index)
	else:
		offered.append(index)
	_mark_trade_modified()
	_update_player_panels()


# Spell equivalent of _handle_trade_click() above -- toggles a spell in or
# out of whichever trader's offer it belongs to. Reused for clicks both on a
# player's normal hand (offering it) and on the trade display's own mini
# cards (taking it back), same as the property version. Unlike a board-space
# index, a spell's hand_index only makes sense together with which player's
# hand it's from, so that has to be passed in rather than looked up.
func _handle_trade_spell_click(hand_index: int, player_index: int) -> void:
	if GameState.online:
		if not GameState.is_slot_local(_trade_proposer):
			return
		if not GameState.is_authority():
			_net_trade_spell_click_intent.rpc_id(1, hand_index, player_index)
			return
	_apply_trade_spell_click(hand_index, player_index)


func _apply_trade_spell_click(hand_index: int, player_index: int) -> void:
	if player_index != _trader1 and player_index != _trader2:
		_toast("That spell isn't part of this trade.")
		return
	var offered: Array[int] = _trade1_spells_offered if player_index == _trader1 else _trade2_spells_offered
	if offered.has(hand_index):
		offered.erase(hand_index)
	else:
		offered.append(hand_index)
	_mark_trade_modified()
	_update_player_panels()


func _on_trade_money_changed(_new_text: String) -> void:
	# A snapshot writing the box (client) isn't a local edit.
	if _applying_snapshot:
		return
	if GameState.online and not GameState.is_authority():
		if _trading and GameState.is_slot_local(_trade_proposer):
			_net_trade_money_intent.rpc_id(1,
				_trade_money_int(trader1_money_edit.text),
				_trade_money_int(trader2_money_edit.text))
		return
	if not GameState.is_authority():
		return
	_mark_trade_modified()


func _trade_money_int(text: String) -> int:
	return maxi(0, int(text))


# Any change to the terms -- a property clicked, a money box edited -- means
# the current proposer's screen no longer matches what the other side last
# sent, so it has to be offered again before it can be accepted.
func _mark_trade_modified() -> void:
	if _trade_can_accept:
		_trade_can_accept = false
		_update_trade_action_button()
		_refresh_action_buttons()


func _update_trade_action_button() -> void:
	offer_trade_button.text = "Accept Trade" if _trade_can_accept else "Offer Trade"


# The single action button does double duty: it sends the current terms to
# the other side for a decision, or -- once they've sent back exactly what's
# already on screen -- finalizes the trade.
func _on_offer_trade_pressed() -> void:
	if GameState.online and not GameState.is_authority():
		if _trading and GameState.is_slot_local(_trade_proposer):
			_net_trade_offer_intent.rpc_id(1)
		return
	if not GameState.is_authority():
		return
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
	# The proposer just changed hands -- online, that moves the live trade
	# controls to the other player's machine (and off this one).
	_refresh_action_buttons()
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
		_toast("%s doesn't have enough money to offer $%d." % [PLAYER_NAMES[_trader1], p1_money])
		return
	if p2_money > p2.money:
		_toast("%s doesn't have enough money to offer $%d." % [PLAYER_NAMES[_trader2], p2_money])
		return

	for index in _trade1_offered:
		p1.owned_property_indices.erase(index)
		p2.owned_property_indices.append(index)
		board.spaces[index].owner_id = _trader2
		_note_ownership(index)
	for index in _trade2_offered:
		p2.owned_property_indices.erase(index)
		p1.owned_property_indices.append(index)
		board.spaces[index].owner_id = _trader1
		_note_ownership(index)

	# Read every offered spell's name out by its (still-valid, since nothing
	# has been removed yet) hand_index *before* removing any of them --
	# removing by index one at a time within a single pass would shift the
	# remaining indices out from under this same array, same risk Art of the
	# Deal's giveaway hit earlier. Removing by name afterward sidesteps that,
	# and correctly handles offering multiple copies of the same spell too
	# (each erase() removes one copy).
	var p1_spell_names: Array[String] = []
	for hand_index in _trade1_spells_offered:
		if hand_index >= 0 and hand_index < p1.spell_hand.size():
			p1_spell_names.append(p1.spell_hand[hand_index])
	for spell_name in p1_spell_names:
		_spell_remove_first(p1, spell_name)
		_spell_add(p2, spell_name)

	var p2_spell_names: Array[String] = []
	for hand_index in _trade2_spells_offered:
		if hand_index >= 0 and hand_index < p2.spell_hand.size():
			p2_spell_names.append(p2.spell_hand[hand_index])
	for spell_name in p2_spell_names:
		_spell_remove_first(p2, spell_name)
		_spell_add(p1, spell_name)

	p1.money -= p1_money
	p2.money += p1_money
	p2.money -= p2_money
	p1.money += p2_money
	_sort_owned_properties(p1)
	_sort_owned_properties(p2)
	dice_label.text = "%s and %s completed a trade!" % [PLAYER_NAMES[_trader1], PLAYER_NAMES[_trader2]]
	_log("%s and %s completed a trade." % [PLAYER_NAMES[_trader1], PLAYER_NAMES[_trader2]])
	var gave1: Array[String] = []
	for i in _trade1_offered:
		gave1.append(_property_name(i))
	if p1_spell_names.size() > 0:
		gave1.append("%d spell%s" % [p1_spell_names.size(), "" if p1_spell_names.size() == 1 else "s"])
	if p1_money > 0:
		gave1.append("$%d" % p1_money)
	var gave2: Array[String] = []
	for i in _trade2_offered:
		gave2.append(_property_name(i))
	if p2_spell_names.size() > 0:
		gave2.append("%d spell%s" % [p2_spell_names.size(), "" if p2_spell_names.size() == 1 else "s"])
	if p2_money > 0:
		gave2.append("$%d" % p2_money)
	if not gave1.is_empty():
		_log("  %s gave %s." % [PLAYER_NAMES[_trader1], ", ".join(gave1)])
	if not gave2.is_empty():
		_log("  %s gave %s." % [PLAYER_NAMES[_trader2], ", ".join(gave2)])
	_end_trade()


func _on_decline_trade_pressed() -> void:
	if GameState.online and not GameState.is_authority():
		if _trading and GameState.is_slot_local(_trade_proposer):
			_net_trade_decline_intent.rpc_id(1)
		return
	if not GameState.is_authority():
		return
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
		if _max_houses_in_group(color_name, player.player_id) > 0:
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
	# No spell-negotiation logic yet -- a counter-offer that touches spells
	# at all (either side) is always declined, same as one with extra
	# properties or money attached.
	var acceptable: bool = ai_offered.size() == 1 and other_offered.size() == 1 and money1 == 0 and money2 == 0 and _trade1_spells_offered.is_empty() and _trade2_spells_offered.is_empty()
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
	_trade1_spells_offered.clear()
	_trade2_spells_offered.clear()
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
		mini_card.setup(space_index, _property_name(space_index), color, board.spaces[space_index].house_count, board.spaces[space_index].is_mortgaged)
		mini_card.card_clicked.connect(_on_space_clicked)
		mini_card.card_right_clicked.connect(_show_property_details)


# Spell equivalent of _populate_trade_flow() above -- appended into the same
# flow right after it (which already cleared and repopulated with that
# trader's offered properties), so offered properties and spells sit
# together in one row, same as a player's own hand shows both side by side.
# Unlike the property version, this needs `player_index` explicitly since a
# hand_index alone doesn't say whose hand it's from.
func _populate_trade_spell_flow(flow: HFlowContainer, player_index: int, indices: Array[int]) -> void:
	var hand: Array[String] = players[player_index].spell_hand
	for hand_index in indices:
		if hand_index < 0 or hand_index >= hand.size():
			continue
		var spell_name: String = hand[hand_index]
		var spell_info: Dictionary = SpellData.SPELLS.get(spell_name, {})
		var face_up: bool = _spell_face_up(player_index, hand_index)
		var mini_spell: Control = MINI_SPELL_CARD_SCENE.instantiate()
		flow.add_child(mini_spell)
		mini_spell.setup(hand_index, load(spell_info.get("icon", "")) if face_up else CARDBACK_TEXTURE, face_up)
		mini_spell.card_clicked.connect(_handle_trade_spell_click.bind(player_index))
		mini_spell.card_right_clicked.connect(_on_spell_right_clicked.bind(player_index))


# Whether the local viewer sees `player_id`'s spell hand face-up by default.
# Own hand always; in a local game every human's hand (AI hands stay
# face-down); online, only this machine's own seats.
func _hand_face_up(player_id: int) -> bool:
	if GameState.online:
		return GameState.is_slot_local(player_id)
	return not players[player_id].is_ai


# Whether one specific spell card shows face-up here: the owner's default
# visibility, or an explicit reveal to one of this machine's seats.
func _spell_face_up(owner_id: int, hand_index: int) -> bool:
	if _hand_face_up(owner_id):
		return true
	var owner: Node2D = players[owner_id]
	if hand_index < 0 or hand_index >= owner.spell_revealed_to.size():
		return false
	var revealed: Array = owner.spell_revealed_to[hand_index]
	for viewer in _local_viewer_ids():
		if revealed.has(viewer):
			return true
	return false


# The player ids "sitting at" this screen -- local seats online, every human
# in a hotseat game.
func _local_viewer_ids() -> Array:
	if GameState.online:
		return GameState.local_slots()
	var out: Array = []
	for p in players:
		if not p.is_ai:
			out.append(p.player_id)
	return out


# --- spell_hand mutations (keep spell_revealed_to in lockstep) ----------

func _spell_add(player: Node2D, spell_name: String) -> void:
	player.spell_hand.append(spell_name)
	player.spell_revealed_to.append([])


func _spell_remove_at(player: Node2D, index: int) -> void:
	player.spell_hand.remove_at(index)
	if index >= 0 and index < player.spell_revealed_to.size():
		player.spell_revealed_to.remove_at(index)


func _spell_remove_first(player: Node2D, spell_name: String) -> void:
	var i: int = player.spell_hand.find(spell_name)
	if i != -1:
		_spell_remove_at(player, i)


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

	# Every spell still in the eliminated player's hand goes back to the deck
	# (not to the creditor) -- revealed status is dropped with it.
	for spell_name in player.spell_hand:
		_return_spell_to_deck(spell_name)
	player.spell_hand.clear()
	player.spell_revealed_to.clear()

	player.money = 0
	player.owned_property_indices.clear()
	player.is_bankrupt = true
	player.visible = false

	if creditor:
		_log("%s went bankrupt; everything passes to %s." % [PLAYER_NAMES[player.player_id], PLAYER_NAMES[creditor.player_id]])
	else:
		_log("%s went bankrupt." % PLAYER_NAMES[player.player_id])


# Shared tail of every bankruptcy path (voluntary or debt-forced, human or
# AI): liquidate, check for a winner, and refresh the panels. Callers are
# responsible for the dice_label message, since its wording differs and has
# to be set before this runs -- _check_for_winner() appends to it.
func _forfeit_to_bankruptcy(player: Node2D, creditor: Node2D) -> void:
	_bankrupt_player(player, creditor)
	_check_for_winner()
	_update_player_panels()


# Called after a bankruptcy resolves. If it left exactly one player still in
# the game, that player wins and the game ends -- everyone is shown the
# result and returned to the Main Menu.
func _check_for_winner() -> void:
	var remaining: Array[Node2D] = []
	for player in players:
		if not player.is_bankrupt:
			remaining.append(player)
	if remaining.size() != 1:
		return
	var winner_id: int = remaining[0].player_id
	dice_label.text += "\n%s wins!" % PLAYER_NAMES[winner_id]
	_log("%s wins!" % PLAYER_NAMES[winner_id], PLAYER_COLORS[winner_id])
	# Runs on the authority; tell every client too (call_local covers the host).
	if GameState.online:
		_net_game_over.rpc(winner_id)
	else:
		_end_game(winner_id)


@rpc("authority", "call_local", "reliable")
func _net_game_over(winner_id: int) -> void:
	_end_game(winner_id)


func _end_game(winner_id: int) -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	if GameState.online:
		Net.leave()
	info_prompt.open("%s wins! Returning to the menu." % PLAYER_NAMES[winner_id])
	await info_prompt.closed
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")


func _on_declare_bankruptcy_pressed() -> void:
	if _tutorial_blocks("bankruptcy"):
		return
	if GameState.online and not GameState.is_authority():
		_net_action_intent.rpc_id(1, "declare_bankruptcy")
		return
	# Same button, relabelled "Cancel purchase" while raising money for an
	# optional buy -- no confirmation, just drop it and go back to the prompt.
	if _in_debt and _debt_cancellable:
		_cancel_raise_money()
		_refresh_action_buttons()
		return
	roll_button.disabled = true
	admin_button.disabled = true
	admin_properties_button.disabled = true
	admin_spells_button.disabled = true
	buy_house_unmortgage_button.disabled = true
	sell_house_mortgage_button.disabled = true
	declare_bankruptcy_button.disabled = true
	trade_button.disabled = true

	_cf_open("Are you sure you want to declare bankruptcy?")
	var yes: bool = await _cf_result()
	if yes:
		var player: Node2D = players[_acting_player_id()]
		var forfeiting_name: String = _player_display_name(player.player_id)
		# If this happened while trying to raise money for a specific debt,
		# that creditor gets everything, per the debt-collection rules;
		# otherwise this is a plain voluntary forfeit with no one to credit.
		var creditor: Node2D = _debt_creditor if _in_debt else null
		dice_label.text = "%s declared bankruptcy and forfeits the game." % forfeiting_name
		_forfeit_to_bankruptcy(player, creditor)
		if _in_debt:
			_fail_all_debts_for(player.player_id, "bankrupt")
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
# Saying yes without enough money doesn't end the decision -- the player
# drops into a raise-money window (sell houses / mortgage / trade / cast a
# spell) with a Cancel that comes back here. Only an explicit "No", or a
# "Yes" they can afford (already, or after raising it), returns.
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
		_cf_open("Buy %s for $%d?" % [property_name, price])
		var yes: bool = await _cf_result()
		if not yes:
			break
		if player.money >= price:
			result = true
			break
		# Said yes but can't afford it -- raise the money, or Cancel back here.
		_awaiting_buy_decision = false
		var outcome: String = await _raise_money(player, price, null, true, false)
		_awaiting_buy_decision = true
		_refresh_action_buttons()
		if outcome == "paid" and player.money >= price:
			result = true
			break
		# "cancelled" (or somehow still short) -- loop back to the buy prompt.
	confirm_prompt.suppress_auto_decline = false
	_awaiting_buy_decision = false
	_refresh_action_buttons()
	return result


func _reassert_buy_prompt_if_needed() -> void:
	# Only meaningful for a prompt shown locally -- a buy decision routed to a
	# remote player lives on their screen, not behind a host board click.
	if _awaiting_buy_decision and _prompt_is_local() and not confirm_prompt.visible:
		_cf_open("Buy %s for $%d?" % [_pending_buy_property_name, _pending_buy_price])


# Completes a spell-driven property purchase (Promised Land, The Cult of
# Terminus L3) the same way a normal purchase would: if `buyer` is short of
# `price`, they drop into the Raise Money window (sell houses / mortgage /
# trade / cast a spell) with a Cancel that abandons the buy. `seller_id` -1
# means the bank; otherwise that player is paid and loses the property.
# Returns true if the property actually changed hands.
func _buy_property_via_spell(buyer: Node2D, space_index: int, price: int, seller_id: int) -> bool:
	var space: Node2D = board.spaces[space_index]
	if buyer.money < price:
		_prompt_slot = buyer.player_id
		var outcome: String = await _raise_money(buyer, price, null, true, false)
		_prompt_slot = -1
		if outcome != "paid" or buyer.money < price:
			return false
	# Time may have passed raising the money -- make sure the target is still
	# up for grabs / still owned by the same seller.
	if seller_id == -1:
		if space.owner_id != -1:
			return false
	elif space.owner_id != seller_id:
		return false
	buyer.money -= price
	if seller_id != -1:
		players[seller_id].owned_property_indices.erase(space_index)
		players[seller_id].money += price
	space.owner_id = buyer.player_id
	buyer.owned_property_indices.append(space_index)
	_sort_owned_properties(buyer)
	_update_player_panels()
	return true


func _sort_owned_properties(player: Node2D) -> void:
	player.owned_property_indices.sort_custom(_compare_property_order)


# Orders by color group (per PROPERTY_COLOR_ORDER), then by board index
# within a group. Unlisted colors (shouldn't happen -- only owned property
# spaces get sorted) fall to the end rather than crashing on find()'s -1.
func _compare_property_order(a: int, b: int) -> bool:
	# Space 0 in a hand is Terminus -- a railroad card, so it sorts with the
	# other railroads (its SPACE_DATA has no "color").
	var color_a: String = "railroad" if a == 0 else board.get_space_info(a).get("color", "")
	var color_b: String = "railroad" if b == 0 else board.get_space_info(b).get("color", "")
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


# Like _count_owned_in_group but ignores mortgaged spaces -- used for
# railroad / utility rent tiers, where a mortgaged railroad or utility
# doesn't count towards "how many you own" (mortgaging one drops an
# opponent's rent on the others).
func _count_unmortgaged_in_group(player_id: int, color_name: String) -> int:
	var group: Array = board.get_color_group(color_name)
	var count: int = 0
	for space_index in group:
		var s: Node2D = board.spaces[space_index]
		if s.owner_id == player_id and not s.is_mortgaged:
			count += 1
	return count


# Terminus Station (index 0, once summoned) isn't part of board.gd's static
# "railroad" color group -- it's an overlay on Go, not a real SPACE_DATA
# property -- so it has to be added on top of the normal count by hand
# everywhere railroad ownership matters for The Cult of Terminus.
func _owned_railroad_count(player_id: int) -> int:
	var count: int = _count_owned_in_group(player_id, "railroad")
	if board.spaces[0].owner_id == player_id:
		count += 1
	return count


# Unmortgaged railroads only (Terminus Station included), for rent tiers.
func _unmortgaged_railroad_count(player_id: int) -> int:
	var count: int = _count_unmortgaged_in_group(player_id, "railroad")
	if board.spaces[0].owner_id == player_id and not board.spaces[0].is_mortgaged:
		count += 1
	return count


# The rent a railroad (or Terminus Station itself) charges for `owned`
# railroads total. Once Terminus exists, owning all 5 unlocks a rent tier
# beyond any single railroad's own 4-tier "rents" array -- see "How Terminus
# Works" -- so that has to be special-cased rather than just indexing in.
func _railroad_rent(owned: int, base_rents: Array) -> int:
	if board.spaces[0].owner_id != -1 and owned >= 5:
		return TERMINUS_FIVE_RAILROAD_RENT
	return base_rents[clampi(owned, 1, base_rents.size()) - 1]


# Terminus Station shares a normal railroad's $200 price for mortgage/
# unmortgage value purposes ($100/$110) -- SPACE_DATA itself has no "price"
# for Go, since it isn't a purchasable space in the normal sense.
func _terminus_aware_price(index: int) -> int:
	if index == 0:
		return 200
	return board.get_space_info(index).get("price", 0)


func _railroad_space_indices() -> Array[int]:
	var result: Array[int] = []
	for space_index in board.TOTAL_SPACES:
		if board.get_space_info(space_index).get("color", "") == "railroad":
			result.append(space_index)
	if board.spaces[0].owner_id != -1:
		result.append(0)
	return result


# Attunement to a color: how many UNMORTGAGED properties of that color the
# player owns, plus any Temporary Attunement from burning spells of that
# color this turn. A mortgaged property provides no Attunement.
func _color_attunement(player: Node2D, color_name: String) -> int:
	if color_name == "":
		return 0
	var attunement: int = _count_unmortgaged_in_group(player.player_id, color_name) + player.temp_attunement.get(color_name, 0)
	if color_name == "black":
		# Railroads provide Black Attunement too, on top of any owned "black"
		# properties (there are none) or burned/granted Temp Attunement --
		# includes Terminus Station, which counts as a railroad once summoned.
		attunement += _unmortgaged_railroad_count(player.player_id)
	return attunement


func _on_space_clicked(index: int) -> void:
	# Tutorial: board / mini-card clicks are never part of the script. (On a
	# "click anywhere" step _input() has already swallowed the click; this
	# only bites on an action step.)
	if _tutorial_active:
		_toast("Follow the instructions!")
		return
	if GameState.online and not GameState.is_authority():
		# During a trade, a property click toggles it in/out of the offer
		# (routed if this machine is the proposer, otherwise ignored).
		if _trading:
			_handle_trade_click(index)
			return
		# A board click only means something while this machine's own seat is
		# in a pick mode (house/mortgage, or a Promised Land target) -- then
		# it's sent to the host. Otherwise it's just inspecting the tile.
		if GameState.is_slot_local(_acting_player_id()) and (_buying_house_or_unmortgaging
				or _selling_house_or_mortgaging or _picking_promised_land_property):
			if info_prompt.visible:
				info_prompt.hide()
			_net_board_click_intent.rpc_id(1, index)
		else:
			_show_property_details(index)
		return
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

	# These are sticky modes -- the click acts, the mode stays on until the
	# player turns it off (see _on_buy/sell_house_*_pressed).
	if _buying_house_or_unmortgaging:
		_buy_house_or_unmortgage(index)
		return

	if _selling_house_or_mortgaging:
		_sell_house_or_mortgage(index)
		return

	if _admin_picking_property:
		_admin_picking_property = false
		if info_prompt.visible:
			info_prompt.hide()
		_admin_assign_property(index)
		return

	if _picking_promised_land_property:
		_picking_promised_land_property = false
		if info_prompt.visible:
			info_prompt.hide()
		board_space_picked.emit(index)
		return

	_show_property_details(index)


# Shows the full property/asset card (or, for spaces without one, the plain
# text popup) for a space. Used both for the normal left-click-on-a-tile
# fallback above, and for right-clicking a mini card to inspect it without
# disturbing whatever picking mode (e.g. a trade) is currently active.
func _show_property_details(index: int) -> void:
	# Tutorial: inspecting properties isn't part of the script.
	if _tutorial_active:
		_toast("Follow the instructions!")
		return
	# Terminus Station -- the GO overlay, once summoned -- is a railroad card
	# in everything but its name.
	if index == 0 and board.spaces[0].owner_id != -1:
		_show_railroad_card("Terminus", TERMINUS_RAILROAD_RENTS, _terminus_aware_price(0),
			load("res://Magopoly Assets/Railroad.png"))
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
		_show_railroad_card(info.get("name", ""), info["rents"], price, load(info.get("icon", "")))
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
	var description: String = _space_description(index, info)
	if description != "":
		lines.append(description)
	# Local inspection popup -- never routed to another player.
	info_prompt.open("\n".join(lines))


# The asset card for a railroad (or Terminus Station, which is one in all but
# name). `base_rents` is the 4-tier [1,2,3,4]-railroad rent array; the 5th
# tier is always TERMINUS_FIVE_RAILROAD_RENT.
func _show_railroad_card(title: String, base_rents: Array, price: int, icon: Texture2D) -> void:
	var lines: Array[String] = [
		"Rent: $%d" % base_rents[0],
		"If 2 Railroads are owned: $%d" % base_rents[1],
		"If 3 Railroads are owned: $%d" % base_rents[2],
		"If 4 Railroads are owned: $%d" % base_rents[3],
		"If 5 Railroads are owned: $%d" % TERMINUS_FIVE_RAILROAD_RENT,
		"Mortgage Value: $%d" % _mortgage_value(price),
		"Unmortgage Value: $%d" % _unmortgage_value(price),
	]
	asset_card.show_card(title, icon, lines)


# What a non-property tile does, for its inspection popup. "" for tiles with
# no special behavior text to add.
func _space_description(index: int, info: Dictionary) -> String:
	match info.get("type", ""):
		"free_parking":
			return "Gain $%d" % free_parking_amount
		"go_to_jail":
			return "Go directly to Jail. Do not pass Go."
		"magic_forest":
			return "Draw 2 spell cards, then discard a spell card from your hand."
		"spell_shop":
			return "Look at 4 spell cards from the deck. You may buy one for $100 -- and one of the four, chosen at random, is 50% off ($50)."
		"tax":
			return "Pay $%d" % info.get("value", 0)
	if index == 0:
		return "When you pass this tile, gain $200 and draw a spell card."
	if index == JAIL_SPACE_INDEX:
		return "Does nothing."
	return ""


# Shows the full card art for a spell, regardless of whose turn it is -- same
# as right-clicking a property mini card, this is just for looking, so it's
# never gated (in the tutorial too: inspecting a card is always allowed). If
# it happens to be the card an "inspect" step named, that step advances.
func _on_spell_right_clicked(hand_index: int, player_index: int) -> void:
	if hand_index < 0 or hand_index >= players[player_index].spell_hand.size():
		return
	var spell_name: String = players[player_index].spell_hand[hand_index]
	var spell_info: Dictionary = SpellData.SPELLS.get(spell_name, {})
	# A "Reveal / Hide…" button rides on the zoom for one of your own cards
	# (online: your local seat; hotseat: any human's, where it's a harmless
	# no-op since every human hand is already visible) -- not mid-trade or
	# mid-tutorial, which have their own spell-card semantics.
	var can_reveal: bool = GameState.is_slot_local(player_index) and not players[player_index].is_ai \
		and not _trading and not _tutorial_active
	if can_reveal:
		spell_card.show_card(load(spell_info.get("icon", "")), player_index, hand_index)
	else:
		spell_card.show_card(load(spell_info.get("icon", "")))
	if _tutorial_active:
		var want: String = _tutorial_right_click_spell()
		if want != "" and _tutorial_hand_spell_is(player_index, hand_index, want):
			_tutorial_advance()  # -> the matching "left click / cast it" step


# Kicks off interacting with a spell from `player_index`'s hand: pick a
# level, or Burn for Attunement instead. Only one such interaction at a
# time, per _casting_spell, and only the card's owner (obviously) -- neither
# of those depend on timing. Burning is Instant Speed for every spell, not
# just ones marked Instant (see _burn_spell_for_attunement()) -- except a
# Utility-colored spell, which can't be burned at all, since Temporary
# Attunement to Utilities is never possible by any means. Actually casting a
# level checks _level_timing_allowed() (most spells are turn-only; some
# levels are only usable responding to a roll or another spell) and then
# Attunement (_color_attunement() must be >= the level).
func _on_spell_clicked(hand_index: int, player_index: int) -> void:
	# Tutorial: only the card the current step names, and only before any pick
	# has been made for it. Migraine and Reclaimed by Nature advance the bubble
	# now (their picker steps have their own text); Manastone / Adrenaline /
	# Sinkhole keep the same bubble through their picks, tracked by pick_phase.
	if _tutorial_active:
		var want: String = _tutorial_left_click_spell()
		if want == "" or _tutorial_pick_phase != 0 or not _tutorial_hand_spell_is(player_index, hand_index, want):
			_toast("Follow the instructions!")
			return
		if spell_card.visible:
			spell_card.hide()
		if _tutorial_expected_action in ["cast_migraine", "cast_rbn"]:
			_tutorial_advance()
		else:
			_tutorial_pick_phase = 1
		_begin_spell_cast(hand_index, player_index)
		return
	# During a trade a spell-card click toggles that spell in/out of the
	# offer -- _handle_trade_spell_click self-routes to the host if this
	# machine is the proposer.
	if _trading:
		_handle_trade_spell_click(hand_index, player_index)
		return
	# Online: you may only cast from your own hand. A client sends the click
	# to the host, which runs it for that seat exactly as a hotseat player
	# would (turn spells on your turn, Instant spells once you've paused a
	# response window). Intents arriving via _net_spell_click_intent skip
	# this and call _begin_spell_cast directly, already validated.
	if GameState.online and not GameState.is_slot_local(player_index):
		return
	if GameState.online and not GameState.is_authority():
		_net_spell_click_intent.rpc_id(1, hand_index, player_index)
		return
	_begin_spell_cast(hand_index, player_index)


func _begin_spell_cast(hand_index: int, player_index: int) -> void:
	if _trading:
		_handle_trade_spell_click(hand_index, player_index)
		return
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
	# The caster -- not necessarily whoever's turn it is -- owns every prompt
	# this cast raises (level, then targets). Matters once a remote player can
	# cast during someone else's response window (Phase 5); harmless now.
	_prompt_slot = player_index
	_refresh_action_buttons()

	var level_entries: Array = []
	for level in levels.keys():
		level_entries.append({"index": level, "name": "Level %d: %s" % [level, levels[level].get("description", "")], "color": Color.WHITE})
	level_entries.sort_custom(func(a, b): return a["index"] < b["index"])
	# Temporary Attunement to Utilities is never possible, by any means --
	# so a Utility-colored spell (currently just Manastone) can't be burned
	# for it at all; the option simply isn't offered.
	if color_name != "utility":
		level_entries.append({"index": BURN_FOR_ATTUNEMENT_INDEX, "name": "Burn for Attunement (+1 %s Attunement)" % color_name.capitalize(), "color": Color.WHITE})

	_pp_open("Cast %s at what level?" % spell_name, level_entries)
	var choice: int = await _pp_result()

	# Only actually push a cast onto the stack -- and open/extend the
	# response window for it -- once _casting_spell is released below, so
	# other players' clicks (e.g. a response to this very cast) aren't
	# locked out for the window's whole 2+ seconds.
	var post_cast: Callable = Callable()
	if choice == BURN_FOR_ATTUNEMENT_INDEX:
		_burn_spell_for_attunement(caster, hand_index, spell_name, color_name)
	elif choice != -1:
		var extra_rejection: String = _spell_extra_validation(caster, spell_name, choice)
		if not _level_timing_allowed(caster, spell_name, choice):
			_toast("%s can't cast %s at Level %d right now -- wrong timing." % [_player_display_name(caster.player_id), spell_name, choice])
		elif extra_rejection != "":
			_toast(extra_rejection)
		else:
			var attunement: int = _color_attunement(caster, color_name)
			if attunement < choice:
				_toast("%s doesn't have enough %s Attunement to cast %s at Level %d (has %d, needs %d)." % [_player_display_name(caster.player_id), color_name.capitalize(), spell_name, choice, attunement, choice])
			else:
				var resolve: Callable = await _prepare_spell_cast(caster, hand_index, spell_name, choice)
				if resolve.is_valid():
					post_cast = _finish_cast.bind(caster, spell_name, choice, resolve)

	_casting_spell = false
	_prompt_slot = -1
	_refresh_action_buttons()

	if post_cast.is_valid():
		await post_cast.call()


# True while a _reveal_spell() picker loop is running for the local player, so
# a second right-click / button press can't stack another one on top.
var _reveal_in_progress: bool = false


# The "Reveal / Hide…" button on the zoomed-in card was pressed. Runs the
# reveal picker for `owner_id`'s card `hand_index` -- locally on the host / in
# a hotseat game, or forwarded to the host by a client.
func _on_zoom_reveal_pressed(owner_id: int, hand_index: int) -> void:
	if owner_id < 0 or owner_id >= players.size():
		return
	if not GameState.is_slot_local(owner_id) or players[owner_id].is_ai:
		return
	if _reveal_in_progress or _casting_spell or _trading:
		return
	if GameState.online and not GameState.is_authority():
		_net_reveal_intent.rpc_id(1, hand_index, owner_id)
		return
	await _run_reveal(owner_id, hand_index)


# A remote player pressed the reveal button on one of their own cards.
@rpc("any_peer", "call_remote", "reliable")
func _net_reveal_intent(hand_index: int, slot: int) -> void:
	if not GameState.is_authority():
		return
	if _peer_for_slot(slot) != multiplayer.get_remote_sender_id():
		return
	if _reveal_in_progress or _casting_spell or _trading:
		return
	await _run_reveal(slot, hand_index)


func _run_reveal(owner_id: int, hand_index: int) -> void:
	_reveal_in_progress = true
	_prompt_slot = owner_id
	await _reveal_spell(players[owner_id], hand_index)
	_prompt_slot = -1
	_reveal_in_progress = false


# Reveal / hide a spell in `owner`'s hand, one player at a time. A player the
# card is already revealed to is shown with "(hide)" -- picking them un-reveals
# it. Loops until the owner cancels, so several can be toggled in one go. The
# card stays revealed only as long as it's in this hand. The public game log
# never names the spell (that would defeat a selective reveal).
func _reveal_spell(owner: Node2D, hand_index: int) -> void:
	if hand_index < 0 or hand_index >= owner.spell_hand.size():
		return
	var spell_name: String = owner.spell_hand[hand_index]
	while true:
		if hand_index >= owner.spell_revealed_to.size():
			return
		var revealed: Array = owner.spell_revealed_to[hand_index]
		var entries: Array = []
		for i in players.size():
			if i == owner.player_id or players[i].is_bankrupt or players[i].is_ai:
				continue
			var suffix: String = " (hide)" if revealed.has(i) else ""
			entries.append({"index": i, "name": PLAYER_NAMES[i] + suffix, "color": PLAYER_COLORS[i]})
		if entries.is_empty():
			_toast("There's no one to reveal it to.")
			return
		_pp_open("%s: reveal to / hide from a player (Cancel when done)." % spell_name, entries)
		var target: int = await _pp_result()
		if target < 0 or hand_index >= owner.spell_revealed_to.size():
			return
		revealed = owner.spell_revealed_to[hand_index]
		if revealed.has(target):
			revealed.erase(target)
			_log("%s hid a spell from %s." % [PLAYER_NAMES[owner.player_id], PLAYER_NAMES[target]])
		else:
			revealed.append(target)
			_log("%s revealed a spell to %s." % [PLAYER_NAMES[owner.player_id], PLAYER_NAMES[target]])
		_update_player_panels()


# Discards a spell without its effect in exchange for +1 Temporary
# Attunement of its color, lasting until the start of this player's next
# turn (see _advance_to_next_active_player()). Always legal regardless of
# timing or whether the spell itself is Instant -- burning for Attunement is
# Instant Speed for every spell. Shuffled back into the deck like any other
# used spell.
func _burn_spell_for_attunement(caster: Node2D, hand_index: int, spell_name: String, color_name: String) -> void:
	_spell_remove_at(caster, hand_index)
	if color_name != "":
		caster.temp_attunement[color_name] = caster.temp_attunement.get(color_name, 0) + 1
	dice_label.text = "%s burned %s for +1 %s Attunement." % [_player_display_name(caster.player_id), spell_name, color_name.capitalize()]
	_return_spell_to_deck(spell_name)
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
# "requires_not_yet_rolled" only matters for "turn": it additionally requires
# the current player not have already rolled this turn (see
# _awaiting_end_turn) -- used by Hasty Exit's Level 1, which is explicitly
# "before rolling" rather than usable any time on your own turn.
func _level_timing_allowed(caster: Node2D, spell_name: String, level: int) -> bool:
	var level_info: Dictionary = SpellData.SPELLS[spell_name]["levels"][level]
	var timings: Array = level_info.get("timings", ["turn"])
	var is_caster_current: bool = caster.player_id == current_player
	var excludes_caster: bool = level_info.get("exclude_current_player", false) and is_caster_current
	var requires_caster: bool = level_info.get("requires_current_player", false) and not is_caster_current
	var caster_has_paused: bool = _response_window_paused_by[caster.player_id]

	if timings.has("turn") and not _response_window_open:
		var already_rolled: bool = level_info.get("requires_not_yet_rolled", false) and _awaiting_end_turn
		if is_caster_current and not _trading and not _in_debt and not _awaiting_buy_decision and not already_rolled:
			return true
		# Raise Money Mode: the player being made to raise money may cast a
		# turn spell to try to earn their way out of it.
		if _in_debt and caster.player_id == _debt_player_id and not _trading:
			return true
	if timings.has("spell_response") and caster_has_paused and not _spell_stack.is_empty() and not excludes_caster and not requires_caster:
		return true
	if timings.has("roll_response") and caster_has_paused and _roll_in_flight and not excludes_caster and not requires_caster:
		return true
	return false


# A handful of spells have a castability condition beyond timing/Attunement
# that depends on live game state -- currently just Divine Protection's
# Levels 1-2, which require the roll actually in flight to be about to land
# the caster on an opponent's property. Returns "" if there's nothing extra
# to block on, or the rejection message to show instead.
func _spell_extra_validation(caster: Node2D, spell_name: String, level: int) -> String:
	if spell_name == "Divine Protection" and level != 3:
		var landing_index: int = (caster.current_space + _current_roll) % board.TOTAL_SPACES
		var info: Dictionary = board.get_space_info(landing_index)
		if info.get("type", "") != "property":
			return "%s's current roll wouldn't land them on a property." % _player_display_name(caster.player_id)
		var space: Node2D = board.spaces[landing_index]
		if space.owner_id == -1 or space.owner_id == caster.player_id:
			return "%s's current roll wouldn't land them on an opponent's property." % _player_display_name(caster.player_id)
	if spell_name == "Escape Plan":
		# "Ensure there is at least one space on the board that satisfies
		# the condition" -- searched across the whole board, not just
		# forward from the current landing spot, since _prepare_escape_plan()
		# itself is guaranteed to find *a* match once this passes (the board
		# is a loop, so anything forward-reachable includes everything).
		var condition: Callable = _escape_plan_condition(caster, level)
		var found: bool = false
		for i in board.TOTAL_SPACES:
			if condition.call(i):
				found = true
				break
		if not found:
			return "There's no valid property for %s's Escape Plan (Level %d) to target." % [_player_display_name(caster.player_id), level]
	if spell_name == "Tax Haven":
		var tax_index: int = LUXURY_TAX_INDEX if level == 1 else INCOME_TAX_INDEX
		if board.spaces[tax_index].owner_id != -1:
			return "%s is already owned." % board.get_space_info(tax_index).get("name", "")
	if spell_name == "The Cult of Terminus" and level == 4:
		# Temporary Attunement doesn't help here -- this checks actual owned
		# railroads, same idea as Escape Plan's board-state preconditions.
		if board.spaces[0].owner_id != -1:
			return "Terminus has already been summoned."
		if _owned_railroad_count(caster.player_id) < 4:
			return "%s doesn't own all 4 railroads." % _player_display_name(caster.player_id)
	return ""


# Gathers whatever targets `spell_name` at `level` needs (which may fail or
# be cancelled, e.g. an empty opponent-picker or a target picker the caster
# backs out of) and returns a zero-arg Callable that applies the effect --
# or an invalid Callable if nothing was actually cast, in which case the
# caller must leave the card in the caster's hand untouched.
func _prepare_spell_cast(caster: Node2D, hand_index: int, spell_name: String, level: int) -> Callable:
	# Any targets a previous (cancelled) prepare picked are stale now.
	_pending_spell_target_marks = []
	_pending_spell_target_label = ""
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
		"Counterfeit Currency":
			return _prepare_counterfeit_currency(caster, level)
		"Snatch Purse":
			return await _prepare_snatch_purse(caster, level)
		"Hasty Exit":
			if level == 1:
				return _prepare_hasty_exit_before_rolling(caster)
			elif level == 2:
				return _prepare_hasty_exit_current_roll(caster)
		"Price Gouging":
			return _prepare_price_gouging(caster, level)
		"Divination":
			return _prepare_divination(caster, level)
		"Migraine":
			return await _prepare_migraine(caster, level)
		"Counterbalance":
			return await _prepare_counterbalance(caster, level)
		"Impossible Architecture":
			return await _prepare_impossible_architecture(caster, level)
		"Promised Land":
			return await _prepare_promised_land(caster, level)
		"Break Bread":
			return _prepare_break_bread(caster, level)
		"Smite":
			return _prepare_smite(caster, level)
		"Divine Protection":
			return await _prepare_divine_protection(caster, level)
		"Art of the Deal":
			return await _prepare_art_of_the_deal(caster, hand_index, level)
		"Escape Plan":
			return _prepare_escape_plan(caster, level)
		"Offer You Can't Refuse":
			return await _prepare_offer_you_cant_refuse(caster, level)
		"Haggling":
			return _prepare_haggling(caster, level)
		"Burn to the Ground":
			return await _prepare_burn_to_the_ground(caster, level)
		"Line of Fire":
			return await _prepare_line_of_fire(caster, level)
		"Unstable Portal":
			return _prepare_unstable_portal(caster, level)
		"Threaten":
			return await _prepare_threaten(caster, level)
		"Royal Aid":
			return await _prepare_royal_aid(caster, level)
		"Taxes":
			return await _prepare_taxes(caster, level)
		"Far-Reaching Empire":
			return await _prepare_far_reaching_empire(caster, level)
		"Annexation":
			return await _prepare_annexation(caster, level)
		"Adrenaline":
			return _prepare_adrenaline(caster, level)
		"Overflowing Bounty":
			return _prepare_overflowing_bounty(caster, level)
		"Sinkhole":
			return await _prepare_sinkhole(caster, level)
		"Reclaimed by Nature":
			return await _prepare_reclaimed_by_nature(caster, level)
		"Sanity Grinding":
			return await _prepare_sanity_grinding(caster, level)
		"Spell Mastery":
			return await _prepare_spell_mastery(caster, level)
		"Tax Haven":
			return _prepare_tax_haven(caster, level)
		"Step Forward":
			return _prepare_step_forward(caster, level)
		"Manastone":
			return await _prepare_manastone(caster, level)
		"The Cult of Terminus":
			match level:
				1:
					return _prepare_cult_of_terminus_free_railroad(caster)
				2:
					return _prepare_cult_of_terminus_advance(caster)
				3:
					return await _prepare_cult_of_terminus_buy_railroad(caster)
				4:
					return _prepare_cult_of_terminus_summon_terminus(caster)
	return Callable()


# Removes one copy of `spell_name` from `caster`'s hand (by name, not
# position -- a prepare step for a spell like Art of the Deal may have
# already shifted the hand around by giving a *different* card away before
# this runs, which would leave a captured index stale), pushes `resolve`
# onto the stack, and opens (or, if one's already running, just extends and
# re-arms) the response window for it -- see _ensure_response_window().
func _finish_cast(caster: Node2D, spell_name: String, level: int, resolve: Callable) -> void:
	_spell_remove_first(caster, spell_name)
	var stack_id: int = _next_stack_id
	_next_stack_id += 1
	var display_name: String = "%s (Level %d)" % [spell_name, level]
	# Whether the caster was paused (i.e. cast this as a reaction during a
	# response window) -- if so, they auto-pause again once it resolves, so a
	# player who's actively engaging keeps their say regardless of Pause
	# Options. Captured now, before the un-pause below.
	var caster_was_paused: bool = caster.player_id >= 0 \
		and caster.player_id < _response_window_paused_by.size() \
		and _response_window_paused_by[caster.player_id]
	_spell_stack.append({
		"id": stack_id, "caster_id": caster.player_id, "spell_name": spell_name,
		"level": level, "display_name": display_name, "resolve": resolve,
		"target_marks": _pending_spell_target_marks.duplicate(true),
		"caster_was_paused": caster_was_paused,
	})
	dice_label.text += "\n%s casts %s!" % [_player_display_name(caster.player_id), display_name]
	var target_suffix: String = ""
	var target_text: String = _pending_spell_target_label
	if target_text == "":
		target_text = _spell_target_names(_pending_spell_target_marks)
	if target_text != "":
		target_suffix = " targeting %s" % target_text
	_pending_spell_target_marks = []
	_pending_spell_target_label = ""
	_log("%s cast %s at Level %d%s." % [PLAYER_NAMES[caster.player_id], spell_name, level, target_suffix])
	# The caster's reaction is spent -- un-pause them so the fresh window that
	# opens now is a clean chance for anyone (them included) to answer this
	# cast. The tutorial keeps its player paused and steps the stack by hand.
	if not _tutorial_active and caster.player_id >= 0 and caster.player_id < _response_window_paused_by.size():
		_response_window_paused_by[caster.player_id] = false
	_update_player_panels()
	await _ensure_response_window("cast", caster.player_id)
	if _tutorial_active:
		await _tutorial_on_spell_finished(spell_name)


# --- Spell targeting: outlines + "targeting X" log suffix -------------------
# A _prepare_* step calls these as it picks each player / property target.
# _pending_spell_target_marks is consumed by _finish_cast (above).

func _spell_target_player(player_id: int) -> void:
	_pending_spell_target_marks.append({"kind": "player", "id": player_id})


func _spell_target_property(space_index: int) -> void:
	_pending_spell_target_marks.append({"kind": "property", "id": space_index})


# A counter spell (Counterbalance, T2 Response Spell L1, Spell Mastery)
# "targets" another spell on the stack -- name it in the log line, but there's
# no token / tile to outline.
func _spell_target_spell(stack_id: int) -> void:
	for entry in _spell_stack:
		if entry["id"] == stack_id:
			_pending_spell_target_label = "%s's %s" % [_player_display_name(entry["caster_id"]), entry["display_name"]]
			return


# Human-readable name(s) for a list of target marks, e.g. "Player 2" or
# "Park Place and Boardwalk". Empty string for no targets.
func _spell_target_names(marks: Array) -> String:
	var names: Array[String] = []
	for mark in marks:
		match mark.get("kind", ""):
			"player":
				names.append(_player_display_name(int(mark["id"])))
			"property":
				names.append(_property_name(int(mark["id"])))
	if names.is_empty():
		return ""
	if names.size() == 1:
		return names[0]
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[-1]]


# Every live stack entry's target marks, flattened -- host-authoritative
# source for _refresh_spell_target_highlights() and the snapshot.
func _all_stack_target_marks() -> Array:
	var out: Array = []
	for entry in _spell_stack:
		for mark in entry.get("target_marks", []):
			out.append({"kind": mark["kind"], "id": int(mark["id"])})
	return out


# Player ids a spell on the pending stack currently targets -- read by
# _update_player_panels() to show a target symbol next to the name.
var _targeted_player_ids: Dictionary = {}


# Marks every board space a pending spell targets with a red outline, and
# records which players are targeted (shown as a symbol by the name, not a
# token highlight). Called from _update_player_panels() and
# _update_spell_stack_display(), so it re-runs on every cast, resolution,
# counter, and client snapshot.
func _refresh_spell_target_highlights() -> void:
	var marks: Array = _net_spell_target_marks if (GameState.online and not GameState.is_authority()) else _all_stack_target_marks()
	_targeted_player_ids = {}
	var targeted_spaces: Dictionary = {}
	for mark in marks:
		match mark.get("kind", ""):
			"player":
				_targeted_player_ids[int(mark["id"])] = true
			"property":
				targeted_spaces[int(mark["id"])] = true
	for i in board.spaces.size():
		board.spaces[i].set_targeted(targeted_spaces.has(i))


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

	_pp_open("T1 Burn Spell: choose an opponent to pay you.", entries)
	var target_index: int = await _pp_result()
	if target_index == -1:
		return Callable()
	_spell_target_player(target_index)

	var amount: int = SpellData.SPELLS["T1 Burn Spell"]["levels"][level].get("amount", 0)
	return _resolve_t1_burn_spell.bind(caster, level, target_index, amount)


# If the target's already gone bankrupt entirely (e.g. forfeited while this
# was pending), the spell just fizzles. Otherwise, an opponent who can't
# afford it goes into the same debt-collection screen as unpayable rent or
# tax -- see _charge_spell_payment().
func _resolve_t1_burn_spell(caster: Node2D, level: int, target_index: int, amount: int) -> void:
	var opponent: Node2D = players[target_index]
	if opponent.is_bankrupt:
		dice_label.text = "%s's T1 Burn Spell (Level %d) fizzles -- %s is already out of the game." % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index]]
		return
	amount = _apply_payment_reduction(opponent, amount)
	var resolve_message: String = "%s's T1 Burn Spell (Level %d) resolves on %s for $%d!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index], amount]
	var debt_message: String = "%s's T1 Burn Spell (Level %d) resolves on %s, who owes $%d!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index], amount]
	await _charge_spell_payment(opponent, amount, caster, resolve_message, debt_message)


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
	_log("%s's T3 Escape Spell modified the dice roll." % PLAYER_NAMES[caster.player_id])
	_update_player_panels()


# T2 Response Spell, Level 1 (Instant, spell_response only): the caster
# picks which pending spell on the stack to counter.
func _prepare_t2_counter(caster: Node2D) -> Callable:
	var entries: Array = _counter_target_entries(func(entry): return true)
	if entries.is_empty():
		dice_label.text += "\nThere's no spell on the stack to counter."
		return Callable()

	_pp_open("T2 Response Spell: choose a spell to counter.", entries)
	var target_id: int = await _pp_result()
	if target_id == -1:
		return Callable()
	_spell_target_spell(target_id)
	return _resolve_counter_spell.bind(caster, "T2 Response Spell (Level 1)", target_id)


# Counterbalance: same idea as T2 Response Spell's counter, but restricted
# to stack entries that were themselves cast at this exact level.
func _prepare_counterbalance(caster: Node2D, level: int) -> Callable:
	var entries: Array = _counter_target_entries(func(entry): return entry["level"] == level)
	if entries.is_empty():
		dice_label.text += "\nThere's no Level %d spell on the stack to counter." % level
		return Callable()

	_pp_open("Counterbalance: choose a Level %d spell to counter." % level, entries)
	var target_id: int = await _pp_result()
	if target_id == -1:
		return Callable()
	_spell_target_spell(target_id)
	return _resolve_counter_spell.bind(caster, "Counterbalance (Level %d)" % level, target_id)


# Builds player_picker entries for every _spell_stack entry `filter` accepts,
# most recently cast (top of stack) first.
func _counter_target_entries(filter: Callable) -> Array:
	var entries: Array = []
	for entry in _spell_stack:
		if filter.call(entry):
			entries.append({"index": entry["id"], "name": "%s's %s" % [_player_display_name(entry["caster_id"]), entry["display_name"]], "color": PLAYER_COLORS[entry["caster_id"]]})
	entries.reverse()
	return entries


# Removes the targeted entry from the stack before it's ever popped -- per
# "countering negates the effect and discards it" -- but, like any other
# used spell, the countered card still gets shuffled back into the deck.
# `counter_display` is how the countering spell itself should read in the
# message, e.g. "T2 Response Spell (Level 1)" or "Counterbalance (Level 2)".
# If the target's already gone (resolved or countered by someone else in
# the meantime), this just fizzles.
func _resolve_counter_spell(caster: Node2D, counter_display: String, target_id: int) -> void:
	for i in _spell_stack.size():
		if _spell_stack[i]["id"] == target_id:
			var countered: Dictionary = _spell_stack[i]
			_spell_stack.remove_at(i)
			_update_spell_stack_display()
			dice_label.text = "%s's %s counters %s's %s!" % [_player_display_name(caster.player_id), counter_display, _player_display_name(countered["caster_id"]), countered["display_name"]]
			_return_spell_to_deck(countered["spell_name"])
			return
	dice_label.text = "%s's %s had nothing left to counter." % [_player_display_name(caster.player_id), counter_display]


# T2 Response Spell, Level 2 (Instant, roll_response only, opponent's roll
# only): no target to pick -- there's only ever one roll in flight, and
# exclude_current_player already keeps the caster from targeting their own.
func _prepare_t2_decrease_roll(caster: Node2D) -> Callable:
	return _resolve_t2_decrease_roll.bind(caster)


func _resolve_t2_decrease_roll(caster: Node2D) -> void:
	_current_roll = maxi(0, _current_roll - 1)
	dice_label.text = "%s's T2 Response Spell (Level 2) resolves! %s's roll decreased by 1 (now %d)." % [_player_display_name(caster.player_id), _player_display_name(current_player), _current_roll]
	_log("%s's T2 Response Spell modified the dice roll." % PLAYER_NAMES[caster.player_id])
	_update_player_panels()


# Counterfeit Currency: no target to pick -- just sets up the buffer that
# _apply_payment_reduction() reads from next time this caster owes an
# opponent money. A second cast this turn (before the first triggers) just
# overwrites the buffer rather than stacking, matching "the next time you
# would pay" reading as a single standing effect, not an accumulating one.
func _prepare_counterfeit_currency(caster: Node2D, level: int) -> Callable:
	var reduction: int = SpellData.SPELLS["Counterfeit Currency"]["levels"][level].get("reduction", 0)
	return _resolve_counterfeit_currency.bind(caster, level, reduction)


func _resolve_counterfeit_currency(caster: Node2D, level: int, reduction: int) -> void:
	# Cast while raising money to pay an opponent: that debt *is* "the next
	# payment", so cut it directly instead of arming a buffer for later. (A
	# tax / Free Parking debt has no creditor and isn't a payment "to an
	# opponent", so it still gets the buffer.)
	if not _debt_stack.is_empty() and int(_debt_stack.back()["player_id"]) == caster.player_id and _debt_stack.back()["creditor"] != null:
		var owed_before: int = int(_debt_stack.back()["amount"])
		var cut: int = mini(reduction, owed_before)
		_debt_stack.back()["amount"] = owed_before - cut
		_sync_current_debt()
		dice_label.text = "%s's Counterfeit Currency (Level %d) resolves! The $%d owed to %s is cut by $%d (now $%d)." % [_player_display_name(caster.player_id), level, owed_before, _player_display_name(_debt_creditor.player_id), cut, _debt_amount]
		_update_player_panels()
		return
	caster.payment_reduction_buffer = reduction
	dice_label.text = "%s's Counterfeit Currency (Level %d) resolves! Their next payment to an opponent this turn is $%d less." % [_player_display_name(caster.player_id), level, reduction]
	_update_player_panels()


# Snatch Purse: the caster picks an opponent now; which spells get taken is
# randomized at resolution.
func _prepare_snatch_purse(caster: Node2D, level: int) -> Callable:
	var entries: Array = []
	for i in players.size():
		if i != caster.player_id and not players[i].is_bankrupt:
			entries.append({"index": i, "name": PLAYER_NAMES[i], "color": PLAYER_COLORS[i]})
	if entries.is_empty():
		dice_label.text += "\nThere's no opponent to snatch from."
		return Callable()

	_pp_open("Snatch Purse: choose an opponent.", entries)
	var target_index: int = await _pp_result()
	if target_index == -1:
		return Callable()
	_spell_target_player(target_index)

	var count: int = SpellData.SPELLS["Snatch Purse"]["levels"][level].get("count", 1)
	return _resolve_snatch_purse.bind(caster, level, target_index, count)


# Takes up to `count` random cards -- fewer if the opponent doesn't have
# that many (per the card's own text). If they've since gone bankrupt (hand
# cleared) or already emptied their hand some other way, this just fizzles.
func _resolve_snatch_purse(caster: Node2D, level: int, target_index: int, count: int) -> void:
	var opponent: Node2D = players[target_index]
	var taken: Array[String] = []
	var actual_count: int = mini(count, opponent.spell_hand.size())
	for i in actual_count:
		var idx: int = randi_range(0, opponent.spell_hand.size() - 1)
		var spell_name: String = opponent.spell_hand[idx]
		_spell_remove_at(opponent, idx)
		_spell_add(caster, spell_name)
		taken.append(spell_name)

	if taken.is_empty():
		dice_label.text = "%s's Snatch Purse (Level %d) resolves, but %s has no spells to take!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index]]
	else:
		dice_label.text = "%s's Snatch Purse (Level %d) resolves! Took %s from %s." % [_player_display_name(caster.player_id), level, ", ".join(taken), PLAYER_NAMES[target_index]]
	_update_player_panels()


# Hasty Exit, Level 1 (Before Rolling -- see "requires_not_yet_rolled" in
# _level_timing_allowed()): no target to pick, just queues the bonus for
# this player's next roll (see _perform_roll()).
func _prepare_hasty_exit_before_rolling(caster: Node2D) -> Callable:
	var bonus: int = SpellData.SPELLS["Hasty Exit"]["levels"][1].get("roll_bonus", 0)
	return _resolve_hasty_exit_before_rolling.bind(caster, bonus)


func _resolve_hasty_exit_before_rolling(caster: Node2D, bonus: int) -> void:
	caster.next_roll_bonus += bonus
	dice_label.text = "%s's Hasty Exit (Level 1) resolves! Their next roll this turn is +%d." % [_player_display_name(caster.player_id), caster.next_roll_bonus]
	_log("%s's Hasty Exit modified the dice roll." % PLAYER_NAMES[caster.player_id])
	_update_player_panels()


# Hasty Exit, Level 2 (roll_response only -- there has to be a "current
# roll" to increase): same shape as T3 Escape Spell's roll_bonus.
func _prepare_hasty_exit_current_roll(caster: Node2D) -> Callable:
	var bonus: int = SpellData.SPELLS["Hasty Exit"]["levels"][2].get("roll_bonus", 0)
	return _resolve_hasty_exit_current_roll.bind(caster, bonus)


func _resolve_hasty_exit_current_roll(caster: Node2D, bonus: int) -> void:
	_current_roll += bonus
	dice_label.text = "%s's Hasty Exit (Level 2) resolves! Roll increased by %d (now %d)." % [_player_display_name(caster.player_id), bonus, _current_roll]
	_log("%s's Hasty Exit modified the dice roll." % PLAYER_NAMES[caster.player_id])
	_update_player_panels()


# Price Gouging: no target to pick -- boosts this caster's own properties'
# effective house count (see _move_player()'s rent calculation) for the
# rest of the current turn. Stacks with itself if cast more than once (e.g.
# Level 1 then Level 1 again), same reasoning as Price Gouging being a
# standing "+N houses" rather than a single-use buffer.
func _prepare_price_gouging(caster: Node2D, level: int) -> Callable:
	var bonus: int = SpellData.SPELLS["Price Gouging"]["levels"][level].get("bonus_houses", 0)
	return _resolve_price_gouging.bind(caster, level, bonus)


func _resolve_price_gouging(caster: Node2D, level: int, bonus: int) -> void:
	caster.price_gouging_bonus_houses += bonus
	dice_label.text = "%s's Price Gouging (Level %d) resolves! Their properties charge as if +%d houses this turn." % [_player_display_name(caster.player_id), level, caster.price_gouging_bonus_houses]
	_update_player_panels()


# Divination: no target to pick, just draws.
func _prepare_divination(caster: Node2D, level: int) -> Callable:
	var count: int = SpellData.SPELLS["Divination"]["levels"][level].get("draw_count", 0)
	return _resolve_divination.bind(caster, level, count)


func _resolve_divination(caster: Node2D, level: int, count: int) -> void:
	var drawn: Array[String] = []
	for i in count:
		var spell_name: String = _draw_spell(caster)
		if spell_name != "":
			drawn.append(spell_name)
	if drawn.is_empty():
		dice_label.text = "%s's Divination (Level %d) resolves, but the Spell Deck is empty!" % [_player_display_name(caster.player_id), level]
	else:
		dice_label.text = "%s's Divination (Level %d) resolves! Drew %s." % [_player_display_name(caster.player_id), level, ", ".join(drawn)]
	_update_player_panels()


# Migraine: the caster picks an opponent now, and per the card's own text
# ("for each spell in their hand *as you cast this spell*"), the card count
# is snapshotted right now too, at cast time -- not re-counted at
# resolution, in case their hand changes in between (e.g. they burn or cast
# something in response).
func _prepare_migraine(caster: Node2D, level: int) -> Callable:
	var entries: Array = []
	for i in players.size():
		if i != caster.player_id and not players[i].is_bankrupt:
			entries.append({"index": i, "name": PLAYER_NAMES[i], "color": PLAYER_COLORS[i]})
	if entries.is_empty():
		dice_label.text += "\nThere's no opponent to target."
		return Callable()

	_pp_open("Migraine: choose an opponent.", entries)
	var target_index: int = await _pp_result()
	if target_index == -1:
		return Callable()
	_spell_target_player(target_index)

	var pay_per_card: int = SpellData.SPELLS["Migraine"]["levels"][level].get("pay_per_card", 0)
	var card_count: int = players[target_index].spell_hand.size()
	var amount: int = pay_per_card * card_count
	return _resolve_migraine.bind(caster, level, target_index, amount)


func _resolve_migraine(caster: Node2D, level: int, target_index: int, amount: int) -> void:
	var opponent: Node2D = players[target_index]
	if opponent.is_bankrupt or amount <= 0:
		dice_label.text = "%s's Migraine (Level %d) resolves, but there's nothing to collect from %s." % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index]]
		return
	amount = _apply_payment_reduction(opponent, amount)
	var resolve_message: String = "%s's Migraine (Level %d) resolves on %s for $%d!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index], amount]
	var debt_message: String = "%s's Migraine (Level %d) resolves on %s, who owes $%d!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index], amount]
	await _charge_spell_payment(opponent, amount, caster, resolve_message, debt_message)


# Impossible Architecture: overrides the usual house-building rules (owning
# the full color set, building evenly across it) -- the chosen property just
# needs to not be mortgaged. Affordability is checked here, at cast time --
# "if the player tries to cast it without enough money... the game won't
# let them" -- so an unaffordable choice cancels the whole cast rather than
# fizzling later.
func _prepare_impossible_architecture(caster: Node2D, level: int) -> Callable:
	var entries: Array = []
	for space_index in caster.owned_property_indices:
		var color_name: String = board.get_space_info(space_index).get("color", "")
		if board.HOUSE_COSTS_BY_COLOR.has(color_name):
			entries.append({"index": space_index, "name": _property_name(space_index), "color": board.COLOR_GROUP_COLORS.get(color_name, Color.WHITE)})
	if entries.is_empty():
		dice_label.text += "\nThere's no property to build on."
		return Callable()

	_pp_open("Impossible Architecture: choose a property to build on.", entries)
	var space_index: int = await _pp_result()
	if space_index == -1:
		return Callable()
	_spell_target_property(space_index)

	var property_name: String = _property_name(space_index)
	var space: Node2D = board.spaces[space_index]
	if space.is_mortgaged:
		dice_label.text += "\n%s is mortgaged and can't be built on." % property_name
		return Callable()

	var level_info: Dictionary = SpellData.SPELLS["Impossible Architecture"]["levels"][level]
	var houses_to_build: int = mini(level_info.get("houses", 0), 5 - space.house_count)
	if houses_to_build <= 0:
		dice_label.text += "\n%s already has the maximum of 5 houses." % property_name
		return Callable()

	var color_name: String = board.get_space_info(space_index).get("color", "")
	var house_cost: int = board.HOUSE_COSTS_BY_COLOR.get(color_name, 0)
	var cost_per_house: int = (house_cost / 2) if level_info.get("half_price", false) else house_cost
	var total_cost: int = cost_per_house * houses_to_build
	if caster.money < total_cost:
		dice_label.text += "\n%s can't afford to build %d house%s on %s ($%d)." % [_player_display_name(caster.player_id), houses_to_build, "" if houses_to_build == 1 else "s", property_name, total_cost]
		return Callable()

	return _resolve_impossible_architecture.bind(caster, level, space_index, houses_to_build, total_cost)


func _resolve_impossible_architecture(caster: Node2D, level: int, space_index: int, houses: int, total_cost: int) -> void:
	var space: Node2D = board.spaces[space_index]
	var property_name: String = _property_name(space_index)
	space.house_count = mini(5, space.house_count + houses)
	caster.money -= total_cost
	var house_word: String = "house" if houses == 1 else "houses"
	dice_label.text = "%s's Impossible Architecture (Level %d) resolves! Built %d %s on %s for $%d." % [_player_display_name(caster.player_id), level, houses, house_word, property_name, total_cost]
	_update_player_panels()


# Promised Land: gathers a target property (randomly, randomly-from-a-side,
# or a direct board click, depending on level) and a "may buy" decision, all
# at cast time. Cancels the whole cast (leaves the card in hand) if there's
# nothing eligible to offer, or (Level 3 only) the clicked space isn't
# actually a valid unowned property.
func _prepare_promised_land(caster: Node2D, level: int) -> Callable:
	var space_index: int = -1
	match level:
		1:
			var pool: Array[int] = _unowned_property_indices()
			if pool.is_empty():
				dice_label.text += "\nThere are no unowned properties left."
				return Callable()
			space_index = pool[randi_range(0, pool.size() - 1)]
		2:
			var side_entries: Array = [
				{"index": 0, "name": "Bottom Side", "color": Color.WHITE},
				{"index": 1, "name": "Left Side", "color": Color.WHITE},
				{"index": 2, "name": "Top Side", "color": Color.WHITE},
				{"index": 3, "name": "Right Side", "color": Color.WHITE},
			]
			_pp_open("Promised Land: choose a side of the board.", side_entries)
			var side: int = await _pp_result()
			if side == -1:
				return Callable()
			var pool: Array[int] = _unowned_property_indices_on_side(side)
			if pool.is_empty():
				dice_label.text += "\nThere are no unowned properties on that side."
				return Callable()
			space_index = pool[randi_range(0, pool.size() - 1)]
		3:
			_picking_promised_land_property = true
			_info_open("Promised Land: click an unowned property to (maybe) buy.")
			var clicked: int = await board_space_picked
			if info_prompt.visible:
				info_prompt.hide()
			var clicked_info: Dictionary = board.get_space_info(clicked)
			if clicked_info.get("type", "") != "property" or board.spaces[clicked].owner_id != -1:
				dice_label.text += "\nThat wasn't an unowned property -- the spell fizzles."
				return Callable()
			space_index = clicked

	var price: int = board.get_space_info(space_index).get("price", 0)
	_cf_open("Promised Land: buy %s for $%d?" % [_property_name(space_index), price])
	var yes: bool = await _cf_result()
	if not yes:
		return Callable()
	_spell_target_property(space_index)
	return _resolve_promised_land.bind(caster, level, space_index, price)


# Resolves like a normal purchase (see _buy_property_via_spell): re-checks the
# property is still unowned, then buys it -- dropping the caster into Raise
# Money if they're short (an opposing response like Migraine may have drained
# them since the "yes"), with a Cancel that just abandons the buy.
func _resolve_promised_land(caster: Node2D, level: int, space_index: int, price: int) -> void:
	var property_name: String = _property_name(space_index)
	if board.spaces[space_index].owner_id != -1:
		dice_label.text = "%s's Promised Land (Level %d) fizzles -- %s was already bought." % [_player_display_name(caster.player_id), level, property_name]
		return
	if await _buy_property_via_spell(caster, space_index, price, -1):
		dice_label.text = "%s's Promised Land (Level %d) resolves! Bought %s for $%d." % [_player_display_name(caster.player_id), level, property_name, price]
	else:
		dice_label.text = "%s's Promised Land (Level %d): %s wasn't bought." % [_player_display_name(caster.player_id), level, property_name]


# Every currently-unowned property-type space (color groups, railroads, and
# utilities alike).
func _unowned_property_indices() -> Array[int]:
	var result: Array[int] = []
	for i in board.TOTAL_SPACES:
		if board.get_space_info(i).get("type", "") == "property" and board.spaces[i].owner_id == -1:
			result.append(i)
	return result


# Same, restricted to one side of the board (0 = bottom, 1 = left, 2 = top,
# 3 = right -- matching board.gd's own side numbering).
func _unowned_property_indices_on_side(side: int) -> Array[int]:
	var result: Array[int] = []
	for i in _unowned_property_indices():
		if i / board.SPACES_PER_SIDE == side:
			result.append(i)
	return result


# Break Bread: the random opponent who also gains is rolled here, at cast time
# -- from then on it behaves like any normally-picked target (red outline,
# "targeting X" in the log). If that player is bankrupt by the time it
# resolves, only the caster gains, same as a normally-picked target that's
# since left the game.
func _prepare_break_bread(caster: Node2D, level: int) -> Callable:
	var amount: int = SpellData.SPELLS["Break Bread"]["levels"][level].get("amount", 0)
	var others: Array[int] = []
	for i in players.size():
		if i != caster.player_id and not players[i].is_bankrupt:
			others.append(i)
	var lucky_index: int = -1
	if not others.is_empty():
		lucky_index = others[randi_range(0, others.size() - 1)]
		_spell_target_player(lucky_index)
	return _resolve_break_bread.bind(caster, level, amount, lucky_index)


func _resolve_break_bread(caster: Node2D, level: int, amount: int, lucky_index: int) -> void:
	caster.money += amount
	if lucky_index == -1 or players[lucky_index].is_bankrupt:
		dice_label.text = "%s's Break Bread (Level %d) resolves! They gain $%d (no one else around to share with)." % [_player_display_name(caster.player_id), level, amount]
	else:
		players[lucky_index].money += amount
		dice_label.text = "%s's Break Bread (Level %d) resolves! %s and %s each gain $%d." % [_player_display_name(caster.player_id), level, _player_display_name(caster.player_id), PLAYER_NAMES[lucky_index], amount]
	_update_player_panels()


# Smite: no target to pick -- "the opponent who currently has the most
# money" is resolved fresh at resolution. Ties just go to whoever's found
# first.
func _prepare_smite(caster: Node2D, level: int) -> Callable:
	var amount: int = SpellData.SPELLS["Smite"]["levels"][level].get("amount", 0)
	return _resolve_smite.bind(caster, level, amount)


func _resolve_smite(caster: Node2D, level: int, amount: int) -> void:
	var richest_index: int = -1
	var richest_money: int = -1
	for i in players.size():
		if i != caster.player_id and not players[i].is_bankrupt and players[i].money > richest_money:
			richest_money = players[i].money
			richest_index = i
	if richest_index == -1:
		dice_label.text = "%s's Smite (Level %d) resolves, but there's no opponent to target." % [_player_display_name(caster.player_id), level]
		return
	var opponent: Node2D = players[richest_index]
	amount = _apply_payment_reduction(opponent, amount)
	var resolve_message: String = "%s's Smite (Level %d) resolves on %s (richest opponent) for $%d!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[richest_index], amount]
	var debt_message: String = "%s's Smite (Level %d) resolves on %s (richest opponent), who owes $%d!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[richest_index], amount]
	await _charge_spell_payment(opponent, amount, caster, resolve_message, debt_message)


# Divine Protection: Levels 1-2 already had their "would land on an
# opponent's property" precondition checked in _spell_extra_validation()
# before this ever runs, so preparing them is just reading the level's fixed
# penalty. Level 3 has no such precondition, but asks a follow-up "1 or 2?"
# instead.
func _prepare_divine_protection(caster: Node2D, level: int) -> Callable:
	if level == 3:
		var entries: Array = [
			{"index": 1, "name": "Subtract 1 from your roll", "color": Color.WHITE},
			{"index": 2, "name": "Subtract 2 from your roll", "color": Color.WHITE},
		]
		_pp_open("Divine Protection: subtract how much from your roll?", entries)
		var amount: int = await _pp_result()
		if amount == -1:
			return Callable()
		return _resolve_divine_protection.bind(caster, level, amount)

	var amount: int = SpellData.SPELLS["Divine Protection"]["levels"][level].get("roll_penalty", 0)
	return _resolve_divine_protection.bind(caster, level, amount)


func _resolve_divine_protection(caster: Node2D, level: int, amount: int) -> void:
	_current_roll = maxi(0, _current_roll - amount)
	dice_label.text = "%s's Divine Protection (Level %d) resolves! Roll decreased by %d (now %d)." % [_player_display_name(caster.player_id), level, amount, _current_roll]
	_log("%s's Divine Protection modified the dice roll." % PLAYER_NAMES[caster.player_id])
	_update_player_panels()


# Art of the Deal: the giveaway is "an additional cost", paid immediately
# here in prepare (not deferred to resolve, so it isn't undone even if this
# gets countered) -- `hand_index` (the copy of Art of the Deal currently
# being cast, still in hand at this point) is only used to exclude that
# specific card from what can be given away.
func _prepare_art_of_the_deal(caster: Node2D, hand_index: int, level: int) -> Callable:
	var giveable_indices: Array[int] = []
	for i in caster.spell_hand.size():
		if i != hand_index:
			giveable_indices.append(i)
	if giveable_indices.is_empty():
		dice_label.text += "\nThere's no extra spell to give away."
		return Callable()

	var opponent_entries: Array = []
	for i in players.size():
		if i != caster.player_id and not players[i].is_bankrupt:
			opponent_entries.append({"index": i, "name": PLAYER_NAMES[i], "color": PLAYER_COLORS[i]})
	if opponent_entries.is_empty():
		dice_label.text += "\nThere's no opponent to target."
		return Callable()

	_pp_open("Art of the Deal: choose an opponent.", opponent_entries)
	var target_index: int = await _pp_result()
	if target_index == -1:
		return Callable()
	_spell_target_player(target_index)

	var give_entries: Array = []
	for i in giveable_indices:
		give_entries.append({"index": i, "name": caster.spell_hand[i], "color": Color.WHITE})
	_pp_open("Art of the Deal: choose a spell to give away.", give_entries)
	var give_index: int = await _pp_result()
	if give_index == -1:
		return Callable()

	var given_spell: String = caster.spell_hand[give_index]
	_spell_remove_at(caster, give_index)
	_spell_add(players[target_index], given_spell)
	dice_label.text += "\n%s gives %s to %s as an additional cost." % [_player_display_name(caster.player_id), given_spell, PLAYER_NAMES[target_index]]
	_update_player_panels()

	var amount: int = SpellData.SPELLS["Art of the Deal"]["levels"][level].get("amount", 0)
	return _resolve_art_of_the_deal.bind(caster, level, target_index, amount)


func _resolve_art_of_the_deal(caster: Node2D, level: int, target_index: int, amount: int) -> void:
	var opponent: Node2D = players[target_index]
	if opponent.is_bankrupt:
		dice_label.text = "%s's Art of the Deal (Level %d) fizzles -- %s is already out of the game." % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index]]
		return
	amount = _apply_payment_reduction(opponent, amount)
	var resolve_message: String = "%s's Art of the Deal (Level %d) resolves on %s for $%d!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index], amount]
	var debt_message: String = "%s's Art of the Deal (Level %d) resolves on %s, who owes $%d!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index], amount]
	await _charge_spell_payment(opponent, amount, caster, resolve_message, debt_message)


# Escape Plan: per level, whether a space qualifies as where the spell wants
# the caster to land. Level 1 additionally excludes whatever color the
# caster's *original*, unmodified roll would have landed them on (if any).
func _escape_plan_condition(caster: Node2D, level: int) -> Callable:
	var original_landing: int = (caster.current_space + _current_roll) % board.TOTAL_SPACES
	var original_color: String = board.get_space_info(original_landing).get("color", "")
	match level:
		1:
			return func(space_index: int) -> bool:
				var info: Dictionary = board.get_space_info(space_index)
				if info.get("type", "") != "property":
					return false
				var owner: int = board.spaces[space_index].owner_id
				if owner == -1 or owner == caster.player_id:
					return false
				return original_color == "" or info.get("color", "") != original_color
		2:
			return func(space_index: int) -> bool:
				return board.get_space_info(space_index).get("type", "") == "property" and board.spaces[space_index].owner_id == caster.player_id
		3:
			return func(space_index: int) -> bool:
				return board.get_space_info(space_index).get("type", "") == "property" and board.spaces[space_index].owner_id == -1
	return func(space_index: int) -> bool: return false


# No target to pick -- _spell_extra_validation() already guaranteed a
# qualifying space exists somewhere on the board, so this just walks forward
# from the original landing spot to find the nearest one (bounded by
# TOTAL_SPACES as a safety net, though it's never actually expected to run
# out given that guarantee).
func _prepare_escape_plan(caster: Node2D, level: int) -> Callable:
	var condition: Callable = _escape_plan_condition(caster, level)
	var landing: int = (caster.current_space + _current_roll) % board.TOTAL_SPACES
	var steps: int = 0
	for i in board.TOTAL_SPACES:
		steps += 1
		landing = (landing + 1) % board.TOTAL_SPACES
		if condition.call(landing):
			break
	_spell_target_property(landing)
	return _resolve_escape_plan.bind(caster, level, steps, landing)


func _resolve_escape_plan(caster: Node2D, level: int, steps: int, landing_index: int) -> void:
	_current_roll += steps
	var destination: String = _property_name(landing_index)
	dice_label.text = "%s's Escape Plan (Level %d) resolves! Roll increased by %d to land on %s (now %d)." % [_player_display_name(caster.player_id), level, steps, destination, _current_roll]
	_log("%s's Escape Plan modified the dice roll." % PLAYER_NAMES[caster.player_id])
	_update_player_panels()


# Offer You Can't Refuse: a forced property-for-property swap (no money any
# more). The caster takes one houseless property from an opponent and must
# hand property back in return -- Level 1 gives two of their properties,
# Level 3 gives one, Level 2 gives one worth at least as much as what's taken.
# Properties offered back exclude anything whose color group currently has
# houses, matching the normal trade UI's own restriction. Running out of
# eligible properties (or backing out of any pick) cancels the whole cast,
# since the "in return" side is mandatory, not optional.
func _prepare_offer_you_cant_refuse(caster: Node2D, level: int) -> Callable:
	var level_info: Dictionary = SpellData.SPELLS["Offer You Can't Refuse"]["levels"][level]
	var give_count: int = level_info.get("give_count", 1)
	var min_value: bool = level_info.get("min_value", false)

	var target_entries: Array = []
	for space_index in board.TOTAL_SPACES:
		var space: Node2D = board.spaces[space_index]
		if space.owner_id != -1 and space.owner_id != caster.player_id and space.house_count == 0 and board.get_space_info(space_index).get("type", "") == "property":
			target_entries.append({"index": space_index, "name": "%s (%s)" % [_property_name(space_index), PLAYER_NAMES[space.owner_id]], "color": PLAYER_COLORS[space.owner_id]})
	if target_entries.is_empty():
		dice_label.text += "\nThere's no eligible property to take."
		return Callable()

	_pp_open("Offer You Can't Refuse: choose an opponent's property without houses.", target_entries)
	var target_space_index: int = await _pp_result()
	if target_space_index == -1:
		return Callable()
	_spell_target_property(target_space_index)

	var target_price: int = board.get_space_info(target_space_index).get("price", 0)
	var target_owner_id: int = board.spaces[target_space_index].owner_id

	var given: Array[int] = []
	while given.size() < give_count:
		var entries: Array = []
		for space_index in caster.owned_property_indices:
			if space_index in given:
				continue
			var color_name: String = board.get_space_info(space_index).get("color", "")
			if _max_houses_in_group(color_name, caster.player_id) > 0:
				continue
			var price: int = board.get_space_info(space_index).get("price", 0)
			if min_value and price < target_price:
				continue
			entries.append({"index": space_index, "name": "%s ($%d)" % [_property_name(space_index), price], "color": board.COLOR_GROUP_COLORS.get(color_name, Color.WHITE)})
		if entries.is_empty():
			if min_value:
				dice_label.text += "\n%s has no property worth $%d or more to give in return." % [_player_display_name(caster.player_id), target_price]
			else:
				dice_label.text += "\n%s doesn't have %d propert%s to give in return." % [_player_display_name(caster.player_id), give_count, "y" if give_count == 1 else "ies"]
			return Callable()
		var prompt: String
		if min_value:
			prompt = "Offer You Can't Refuse: give a property worth $%d or more in return." % target_price
		elif give_count == 1:
			prompt = "Offer You Can't Refuse: choose a property to give in return."
		else:
			prompt = "Offer You Can't Refuse: choose %d properties to give in return (%d picked)." % [give_count, given.size()]
		_pp_open(prompt, entries)
		var picked: int = await _pp_result()
		if picked == -1:
			return Callable()
		given.append(picked)
	return _resolve_offer_you_cant_refuse.bind(caster, level, target_space_index, target_owner_id, given)


func _resolve_offer_you_cant_refuse(caster: Node2D, level: int, target_space_index: int, target_owner_id: int, given_properties: Array[int]) -> void:
	var target_space: Node2D = board.spaces[target_space_index]
	var property_name: String = _property_name(target_space_index)
	if target_space.owner_id != target_owner_id:
		dice_label.text = "%s's Offer You Can't Refuse (Level %d) fizzles -- %s is no longer owned by them." % [_player_display_name(caster.player_id), level, property_name]
		return
	var target: Node2D = players[target_owner_id]

	target.owned_property_indices.erase(target_space_index)
	caster.owned_property_indices.append(target_space_index)
	target_space.owner_id = caster.player_id
	_sort_owned_properties(caster)

	var given_names: Array[String] = []
	for space_index in given_properties:
		caster.owned_property_indices.erase(space_index)
		target.owned_property_indices.append(space_index)
		board.spaces[space_index].owner_id = target_owner_id
		given_names.append(_property_name(space_index))
	if not given_properties.is_empty():
		_sort_owned_properties(target)

	var swap_note: String = ", gave back %s" % ", ".join(given_names) if not given_names.is_empty() else ""
	dice_label.text = "%s's Offer You Can't Refuse (Level %d) resolves! Took %s from %s%s." % [_player_display_name(caster.player_id), level, property_name, PLAYER_NAMES[target_owner_id], swap_note]
	_update_player_panels()


# Haggling: no target to pick -- just arms the discount, consumed by
# _apply_haggling_discount() next time this caster buys a house or property.
func _prepare_haggling(caster: Node2D, level: int) -> Callable:
	return _resolve_haggling.bind(caster, level)


func _resolve_haggling(caster: Node2D, level: int) -> void:
	var level_info: Dictionary = SpellData.SPELLS["Haggling"]["levels"][level]
	caster.haggling_discount_percent = level_info.get("discount_percent", 0)
	caster.haggling_bank_bonus = level_info.get("bank_bonus", false)
	var bonus_note: String = " The bank will also pay them its price!" if caster.haggling_bank_bonus else ""
	dice_label.text = "%s's Haggling (Level %d) resolves! Their next property or house purchase this turn is %d%% off.%s" % [_player_display_name(caster.player_id), level, caster.haggling_discount_percent, bonus_note]
	_update_player_panels()


# Burn to the Ground: any property with houses is a valid target, regardless
# of owner (not restricted to opponents).
func _prepare_burn_to_the_ground(caster: Node2D, level: int) -> Callable:
	var entries: Array = []
	for i in board.TOTAL_SPACES:
		if board.spaces[i].house_count > 0:
			var color_name: String = board.get_space_info(i).get("color", "")
			entries.append({"index": i, "name": _property_name(i), "color": board.COLOR_GROUP_COLORS.get(color_name, Color.WHITE)})
	if entries.is_empty():
		dice_label.text += "\nThere are no houses to destroy."
		return Callable()

	_pp_open("Burn to the Ground: choose a property.", entries)
	var space_index: int = await _pp_result()
	if space_index == -1:
		return Callable()
	_spell_target_property(space_index)
	var houses: int = SpellData.SPELLS["Burn to the Ground"]["levels"][level].get("houses", 0)
	return _resolve_burn_to_the_ground.bind(caster, level, space_index, houses)


func _resolve_burn_to_the_ground(caster: Node2D, level: int, space_index: int, houses: int) -> void:
	var space: Node2D = board.spaces[space_index]
	var property_name: String = _property_name(space_index)
	var destroyed: int = mini(houses, space.house_count)
	space.house_count -= destroyed
	var house_word: String = "house" if destroyed == 1 else "houses"
	dice_label.text = "%s's Burn to the Ground (Level %d) resolves! Destroyed %d %s on %s." % [_player_display_name(caster.player_id), level, destroyed, house_word, property_name]
	_update_player_panels()


# Line of Fire: picks a side of the board now; who owns what there (and
# thus who pays) is evaluated at resolution.
func _prepare_line_of_fire(caster: Node2D, level: int) -> Callable:
	var side_entries: Array = [
		{"index": 0, "name": "Bottom Side", "color": Color.WHITE},
		{"index": 1, "name": "Left Side", "color": Color.WHITE},
		{"index": 2, "name": "Top Side", "color": Color.WHITE},
		{"index": 3, "name": "Right Side", "color": Color.WHITE},
	]
	_pp_open("Line of Fire: choose a side of the board.", side_entries)
	var side: int = await _pp_result()
	if side == -1:
		return Callable()
	# Outline every opponent-owned property on the chosen side (what the spell
	# will actually charge for); the log just names the side.
	_pending_spell_target_label = "the %s Side" % BOARD_SIDE_NAMES[side]
	for i in board.TOTAL_SPACES:
		if i / board.SPACES_PER_SIDE != side:
			continue
		if board.get_space_info(i).get("type", "") != "property":
			continue
		var owner_id: int = board.spaces[i].owner_id
		if owner_id != -1 and owner_id != caster.player_id:
			_spell_target_property(i)
	var amount: int = SpellData.SPELLS["Line of Fire"]["levels"][level].get("amount", 0)
	return _resolve_line_of_fire.bind(caster, level, side, amount)


# "For each property... its owner pays you" -- charged as a separate payment
# per qualifying property (not lumped into one payment per owner, so a
# Counterfeit Currency buffer only ever covers the first of several),
# processed one at a time so a debt-collection screen (see
# _charge_spell_payment()) for one property's owner doesn't block the rest.
# Every payment gets its own line in dice_label (append=true below) --
# otherwise, on more than one qualifying property, only the very last
# payment's message would ever be visible, even though every property was
# actually charged. Ownership is re-checked at payment time, not just during
# the initial scan, since an earlier property's owner going bankrupt from
# this same spell can hand their remaining properties (including a later one
# on this side) to the caster mid-loop.
func _resolve_line_of_fire(caster: Node2D, level: int, side: int, amount: int) -> void:
	var property_indices: Array[int] = []
	for i in board.TOTAL_SPACES:
		if i / board.SPACES_PER_SIDE != side:
			continue
		if board.get_space_info(i).get("type", "") != "property":
			continue
		var owner_id: int = board.spaces[i].owner_id
		if owner_id == -1 or owner_id == caster.player_id:
			continue
		property_indices.append(i)
	if property_indices.is_empty():
		dice_label.text = "%s's Line of Fire (Level %d) resolves, but no opponent-owned properties were on that side." % [_player_display_name(caster.player_id), level]
		return
	dice_label.text = "%s's Line of Fire (Level %d) resolves!" % [_player_display_name(caster.player_id), level]
	for space_index in property_indices:
		var owner_id: int = board.spaces[space_index].owner_id
		if owner_id == -1 or owner_id == caster.player_id:
			continue
		var owner: Node2D = players[owner_id]
		var property_name: String = _property_name(space_index)
		var owed: int = _apply_payment_reduction(owner, amount)
		var resolve_message: String = "%s's Line of Fire (Level %d) collects $%d from %s (%s)!" % [_player_display_name(caster.player_id), level, owed, PLAYER_NAMES[owner_id], property_name]
		var debt_message: String = "%s's Line of Fire (Level %d) charges %s $%d for %s, who owes it!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[owner_id], owed, property_name]
		await _charge_spell_payment(owner, owed, caster, resolve_message, debt_message, true)


# Unstable Portal: no target to pick -- just arms the multiplier, consumed
# by _perform_roll() next time this caster rolls.
func _prepare_unstable_portal(caster: Node2D, level: int) -> Callable:
	var multiplier: int = SpellData.SPELLS["Unstable Portal"]["levels"][level].get("multiplier", 1)
	return _resolve_unstable_portal.bind(caster, level, multiplier)


func _resolve_unstable_portal(caster: Node2D, level: int, multiplier: int) -> void:
	caster.next_roll_multiplier = multiplier
	dice_label.text = "%s's Unstable Portal (Level %d) resolves! Their next roll this turn is multiplied by %d." % [_player_display_name(caster.player_id), level, multiplier]
	_log("%s's Unstable Portal modified the dice roll." % PLAYER_NAMES[caster.player_id])
	_update_player_panels()


# Threaten: the caster targets a property; its OWNER is the one who then
# decides -- give it up, or pay the caster. A human owner picks via
# player_picker, routed to them (_prompt_slot), as a mandatory choice; an AI
# owner just pays if it can afford to, otherwise gives up the property (no
# real strategy, just a reasonable default). If a human chooses to pay but
# can't actually cover it, they get the same debt-collection screen as anyone
# else short on cash -- see _charge_spell_payment() and _acting_player_id().
func _prepare_threaten(caster: Node2D, level: int) -> Callable:
	var entries: Array = []
	for space_index in board.TOTAL_SPACES:
		var space: Node2D = board.spaces[space_index]
		if space.owner_id != -1 and space.owner_id != caster.player_id and space.house_count == 0 and board.get_space_info(space_index).get("type", "") == "property":
			entries.append({"index": space_index, "name": "%s (%s)" % [_property_name(space_index), PLAYER_NAMES[space.owner_id]], "color": PLAYER_COLORS[space.owner_id]})
	if entries.is_empty():
		dice_label.text += "\nThere's no eligible property to threaten."
		return Callable()

	_pp_open("Threaten: choose an opponent's property without houses.", entries)
	var space_index: int = await _pp_result()
	if space_index == -1:
		return Callable()
	_spell_target_property(space_index)
	var amount: int = SpellData.SPELLS["Threaten"]["levels"][level].get("amount", 0)
	return _resolve_threaten.bind(caster, level, space_index, amount)


func _resolve_threaten(caster: Node2D, level: int, space_index: int, amount: int) -> void:
	var space: Node2D = board.spaces[space_index]
	var property_name: String = _property_name(space_index)
	if space.owner_id == -1 or space.owner_id == caster.player_id:
		dice_label.text = "%s's Threaten (Level %d) fizzles -- %s is no longer a valid target." % [_player_display_name(caster.player_id), level, property_name]
		return
	var target: Node2D = players[space.owner_id]

	var give_up_property: bool
	if target.is_ai:
		give_up_property = target.money < amount
	else:
		var entries: Array = [
			{"index": 0, "name": "Give up %s" % property_name, "color": Color.WHITE},
			{"index": 1, "name": "Pay $%d" % amount, "color": Color.WHITE},
		]
		# The property's owner decides -- route the picker to them, not the
		# caster / current player. Mandatory: the effect is forced, and this
		# shouldn't resolve itself if their window loses focus.
		_prompt_slot = target.player_id
		_pp_open("%s's Threaten (Level %d): give up %s, or pay $%d?" % [_player_display_name(caster.player_id), level, property_name, amount], entries, true)
		var choice: int = await _pp_result()
		_prompt_slot = -1
		give_up_property = choice != 1

	if give_up_property:
		target.owned_property_indices.erase(space_index)
		caster.owned_property_indices.append(space_index)
		space.owner_id = caster.player_id
		_sort_owned_properties(caster)
		dice_label.text = "%s's Threaten (Level %d) resolves! %s gives up %s." % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target.player_id], property_name]
		_update_player_panels()
	else:
		var owed: int = _apply_payment_reduction(target, amount)
		var resolve_message: String = "%s's Threaten (Level %d) resolves! %s pays $%d." % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target.player_id], owed]
		var debt_message: String = "%s's Threaten (Level %d) resolves! %s owes $%d." % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target.player_id], owed]
		await _charge_spell_payment(target, owed, caster, resolve_message, debt_message)


# Royal Aid: picks up to `count` mortgaged properties (interactively,
# stopping early if there's nothing left eligible, or the caster backs out of
# a pick). Unmortgaging is FREE -- no payment, at pick time or resolution --
# and is deferred to resolution like any other spell effect.
func _prepare_royal_aid(caster: Node2D, level: int) -> Callable:
	var count: int = SpellData.SPELLS["Royal Aid"]["levels"][level].get("count", 1)
	var chosen: Array[int] = []
	for i in count:
		var entries: Array = []
		for space_index in caster.owned_property_indices:
			if space_index in chosen:
				continue
			if not board.spaces[space_index].is_mortgaged:
				continue
			var display_name: String = _property_name(space_index)
			entries.append({"index": space_index, "name": display_name, "color": Color.WHITE})
		if entries.is_empty():
			break
		_pp_open("Royal Aid: choose a mortgaged property to unmortgage for free (%d/%d)." % [chosen.size() + 1, count], entries)
		var picked: int = await _pp_result()
		if picked == -1:
			break
		chosen.append(picked)

	if chosen.is_empty():
		dice_label.text += "\nThere's nothing to unmortgage."
		return Callable()
	for space_index in chosen:
		_spell_target_property(space_index)
	return _resolve_royal_aid.bind(caster, level, chosen)


func _resolve_royal_aid(caster: Node2D, level: int, chosen: Array[int]) -> void:
	var names: Array[String] = []
	for space_index in chosen:
		var space: Node2D = board.spaces[space_index]
		if not space.is_mortgaged:
			continue
		space.is_mortgaged = false  # free -- Royal Aid pays nothing
		names.append(_property_name(space_index))
	if names.is_empty():
		dice_label.text = "%s's Royal Aid (Level %d) resolves, but nothing was unmortgaged." % [_player_display_name(caster.player_id), level]
	else:
		dice_label.text = "%s's Royal Aid (Level %d) resolves! Unmortgaged %s." % [_player_display_name(caster.player_id), level, ", ".join(names)]
	_update_player_panels()


# Taxes: the fraction is evaluated fresh at resolution, off the opponent's
# money *then* -- not snapshotted at cast time (unlike Migraine, which the
# card explicitly ties to "as you cast this spell").
func _prepare_taxes(caster: Node2D, level: int) -> Callable:
	var entries: Array = []
	for i in players.size():
		if i != caster.player_id and not players[i].is_bankrupt:
			entries.append({"index": i, "name": PLAYER_NAMES[i], "color": PLAYER_COLORS[i]})
	if entries.is_empty():
		dice_label.text += "\nThere's no opponent to target."
		return Callable()
	_pp_open("Taxes: choose an opponent.", entries)
	var target_index: int = await _pp_result()
	if target_index == -1:
		return Callable()
	_spell_target_player(target_index)
	var divisor: int = SpellData.SPELLS["Taxes"]["levels"][level].get("divisor", 1)
	return _resolve_taxes.bind(caster, level, target_index, divisor)


func _resolve_taxes(caster: Node2D, level: int, target_index: int, divisor: int) -> void:
	var opponent: Node2D = players[target_index]
	if opponent.is_bankrupt:
		dice_label.text = "%s's Taxes (Level %d) fizzles -- %s is already out of the game." % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index]]
		return
	var amount: int = opponent.money / divisor
	amount = _apply_payment_reduction(opponent, amount)
	var payment: int = mini(amount, opponent.money)
	opponent.money -= payment
	caster.money += payment
	_log_payment(target_index, payment, PLAYER_NAMES[caster.player_id])
	dice_label.text = "%s's Taxes (Level %d) resolves on %s for $%d!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index], payment]
	_update_player_panels()


# Far-Reaching Empire: the opponent is picked now; how many different
# colors the caster owns is counted fresh at resolution.
func _prepare_far_reaching_empire(caster: Node2D, level: int) -> Callable:
	var entries: Array = []
	for i in players.size():
		if i != caster.player_id and not players[i].is_bankrupt:
			entries.append({"index": i, "name": PLAYER_NAMES[i], "color": PLAYER_COLORS[i]})
	if entries.is_empty():
		dice_label.text += "\nThere's no opponent to target."
		return Callable()
	_pp_open("Far-Reaching Empire: choose an opponent.", entries)
	var target_index: int = await _pp_result()
	if target_index == -1:
		return Callable()
	_spell_target_player(target_index)
	var amount: int = SpellData.SPELLS["Far-Reaching Empire"]["levels"][level].get("amount", 0)
	return _resolve_far_reaching_empire.bind(caster, level, target_index, amount)


func _resolve_far_reaching_empire(caster: Node2D, level: int, target_index: int, amount: int) -> void:
	var opponent: Node2D = players[target_index]
	if opponent.is_bankrupt:
		dice_label.text = "%s's Far-Reaching Empire (Level %d) fizzles -- %s is already out of the game." % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index]]
		return
	var colors_owned: Dictionary = {}
	for space_index in caster.owned_property_indices:
		var color_name: String = board.get_space_info(space_index).get("color", "")
		if color_name in REAL_PROPERTY_COLORS:
			colors_owned[color_name] = true
	var total: int = colors_owned.size() * amount
	total = _apply_payment_reduction(opponent, total)
	var resolve_message: String = "%s's Far-Reaching Empire (Level %d) resolves on %s for $%d (%d colors)!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index], total, colors_owned.size()]
	var debt_message: String = "%s's Far-Reaching Empire (Level %d) resolves on %s (%d colors), who owes $%d!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index], colors_owned.size(), total]
	await _charge_spell_payment(opponent, total, caster, resolve_message, debt_message)


# Annexation: the caster BUYS an opponent's houseless property at its listed
# price -- Cult of Terminus L3's pattern (Raise Money if short, Cancel
# abandons the buy). Never targets the bank. The colour-count gate is EXACT
# and reversed: own 0 of that colour needs L1, exactly 1 needs L2, exactly 2
# needs L3 -- so the closer a buy gets to completing the caster's own
# monopoly, the higher the level required. The picker only lists currently-
# eligible properties.
func _prepare_annexation(caster: Node2D, level: int) -> Callable:
	var level_info: Dictionary = SpellData.SPELLS["Annexation"]["levels"][level]
	var owned_in_group: int = level_info.get("owned_in_group", 0)
	var entries: Array = []
	for space_index in board.TOTAL_SPACES:
		if board.get_space_info(space_index).get("type", "") != "property":
			continue
		var space: Node2D = board.spaces[space_index]
		if space.house_count > 0:
			continue
		if space.owner_id == -1 or space.owner_id == caster.player_id:
			continue
		var color_name: String = board.get_space_info(space_index).get("color", "")
		if _count_owned_in_group(caster.player_id, color_name) != owned_in_group:
			continue
		var price: int = board.get_space_info(space_index).get("price", 0)
		entries.append({"index": space_index, "name": "%s (%s, $%d)" % [_property_name(space_index), PLAYER_NAMES[space.owner_id], price], "color": board.COLOR_GROUP_COLORS.get(color_name, Color.WHITE)})
	if entries.is_empty():
		dice_label.text += "\nThere's no eligible property to annex."
		return Callable()

	_pp_open("Annexation: choose an opponent's property without houses to buy.", entries)
	var target_space_index: int = await _pp_result()
	if target_space_index == -1:
		return Callable()
	_spell_target_property(target_space_index)
	var target_owner_id: int = board.spaces[target_space_index].owner_id
	var target_price: int = board.get_space_info(target_space_index).get("price", 0)
	return _resolve_annexation.bind(caster, level, target_space_index, target_owner_id, target_price)


func _resolve_annexation(caster: Node2D, level: int, target_space_index: int, target_owner_id: int, price: int) -> void:
	var space: Node2D = board.spaces[target_space_index]
	var property_name: String = _property_name(target_space_index)
	if space.owner_id != target_owner_id or target_owner_id == -1 or space.house_count > 0:
		dice_label.text = "%s's Annexation (Level %d) fizzles -- %s is no longer eligible." % [_player_display_name(caster.player_id), level, property_name]
		return
	# Resolves like a normal purchase -- Raise Money (mortgage / sell / trade)
	# if the caster is short, with a Cancel that abandons the buy.
	if not await _buy_property_via_spell(caster, target_space_index, price, target_owner_id):
		dice_label.text = "%s's Annexation (Level %d): %s wasn't bought." % [_player_display_name(caster.player_id), level, property_name]
		return
	dice_label.text = "%s's Annexation (Level %d) resolves! Bought %s from %s for $%d." % [_player_display_name(caster.player_id), level, property_name, PLAYER_NAMES[target_owner_id], price]


# Adrenaline: same shape as T3 Escape Spell.
func _prepare_adrenaline(caster: Node2D, level: int) -> Callable:
	var bonus: int = SpellData.SPELLS["Adrenaline"]["levels"][level].get("roll_bonus", 0)
	return _resolve_adrenaline.bind(caster, level, bonus)


func _resolve_adrenaline(caster: Node2D, level: int, bonus: int) -> void:
	_current_roll += bonus
	dice_label.text = "%s's Adrenaline (Level %d) resolves! Roll increased by %d (now %d)." % [_player_display_name(caster.player_id), level, bonus, _current_roll]
	_log("%s's Adrenaline modified the dice roll." % PLAYER_NAMES[caster.player_id])
	_update_player_panels()


# Overflowing Bounty: no target to pick -- grants Temporary Attunement to
# every real color at once.
func _prepare_overflowing_bounty(caster: Node2D, level: int) -> Callable:
	var amount: int = SpellData.SPELLS["Overflowing Bounty"]["levels"][level].get("amount", 0)
	return _resolve_overflowing_bounty.bind(caster, level, amount)


func _resolve_overflowing_bounty(caster: Node2D, level: int, amount: int) -> void:
	for color_name in ATTUNABLE_COLORS:
		caster.temp_attunement[color_name] = caster.temp_attunement.get(color_name, 0) + amount
	dice_label.text = "%s's Overflowing Bounty (Level %d) resolves! +%d Temporary Attunement to every color." % [_player_display_name(caster.player_id), level, amount]
	_update_player_panels()


# Sinkhole: the caster picks an opponent now; the space they're on then --
# and everyone else (besides the caster) sharing it -- is resolved fresh at
# resolution, per the card's "all other opponents on the same space" wording.
func _prepare_sinkhole(caster: Node2D, level: int) -> Callable:
	var entries: Array = []
	for i in players.size():
		if i != caster.player_id and not players[i].is_bankrupt:
			entries.append({"index": i, "name": PLAYER_NAMES[i], "color": PLAYER_COLORS[i]})
	if entries.is_empty():
		dice_label.text += "\nThere's no opponent to target."
		return Callable()
	_pp_open("Sinkhole: choose an opponent.", entries)
	var target_index: int = await _pp_result()
	if target_index == -1:
		return Callable()
	_spell_target_player(target_index)
	var amount: int = SpellData.SPELLS["Sinkhole"]["levels"][level].get("amount", 0)
	return _resolve_sinkhole.bind(caster, level, target_index, amount)


func _resolve_sinkhole(caster: Node2D, level: int, target_index: int, amount: int) -> void:
	var target: Node2D = players[target_index]
	if target.is_bankrupt:
		dice_label.text = "%s's Sinkhole (Level %d) fizzles -- %s is already out of the game." % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index]]
		return
	var space_index: int = target.current_space
	var hit_indices: Array[int] = []
	for i in players.size():
		if i == caster.player_id or players[i].is_bankrupt or players[i].current_space != space_index:
			continue
		hit_indices.append(i)
	if hit_indices.is_empty():
		dice_label.text = "%s's Sinkhole (Level %d) resolves, but no opponents were on that space." % [_player_display_name(caster.player_id), level]
		return
	# Processed one at a time, same reasoning as Line of Fire: a debt-
	# collection screen for one opponent shouldn't block charging the rest.
	# Every payment gets its own line (append=true), so all of them stay
	# visible instead of only the last one overwriting the others.
	dice_label.text = "%s's Sinkhole (Level %d) resolves!" % [_player_display_name(caster.player_id), level]
	for i in hit_indices:
		if players[i].is_bankrupt:
			continue
		var opponent: Node2D = players[i]
		var owed: int = _apply_payment_reduction(opponent, amount)
		var resolve_message: String = "%s's Sinkhole (Level %d) collects $%d from %s!" % [_player_display_name(caster.player_id), level, owed, PLAYER_NAMES[i]]
		var debt_message: String = "%s's Sinkhole (Level %d) charges %s $%d, who owes it!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[i], owed]
		await _charge_spell_payment(opponent, owed, caster, resolve_message, debt_message, true)


# Reclaimed by Nature: loops picking up to `count` distinct mortgaged
# properties (any player's, including the caster's own) to return to the bank.
func _prepare_reclaimed_by_nature(caster: Node2D, level: int) -> Callable:
	var count: int = SpellData.SPELLS["Reclaimed by Nature"]["levels"][level].get("count", 1)
	var chosen: Array[int] = []
	for i in count:
		var entries: Array = []
		for space_index in board.TOTAL_SPACES:
			if space_index in chosen:
				continue
			var space: Node2D = board.spaces[space_index]
			if not space.is_mortgaged:
				continue
			entries.append({"index": space_index, "name": "%s (%s)" % [_property_name(space_index), PLAYER_NAMES[space.owner_id]], "color": PLAYER_COLORS[space.owner_id]})
		if entries.is_empty():
			break
		_pp_open("Reclaimed by Nature: choose a mortgaged property to return to the bank (%d/%d)." % [chosen.size() + 1, count], entries)
		var picked: int = await _pp_result()
		if picked == -1:
			break
		chosen.append(picked)

	if chosen.is_empty():
		dice_label.text += "\nThere's nothing mortgaged to return to the bank."
		return Callable()
	for space_index in chosen:
		_spell_target_property(space_index)
	return _resolve_reclaimed_by_nature.bind(caster, level, chosen)


func _resolve_reclaimed_by_nature(caster: Node2D, level: int, chosen: Array[int]) -> void:
	var names: Array[String] = []
	for space_index in chosen:
		var space: Node2D = board.spaces[space_index]
		if not space.is_mortgaged:
			continue
		if space.owner_id != -1:
			players[space.owner_id].owned_property_indices.erase(space_index)
		space.owner_id = -1
		space.is_mortgaged = false
		names.append(_property_name(space_index))
	if names.is_empty():
		dice_label.text = "%s's Reclaimed by Nature (Level %d) resolves, but nothing was returned." % [_player_display_name(caster.player_id), level]
	else:
		dice_label.text = "%s's Reclaimed by Nature (Level %d) resolves! Returned %s to the bank." % [_player_display_name(caster.player_id), level, ", ".join(names)]
	_update_player_panels()


# Sanity Grinding: same target-picker/payment shape as T1 Burn Spell; the
# only difference is queuing the card to come back to hand at end of turn,
# which happens as soon as this reaches resolution (whether or not the
# target's still around to actually pay) -- only being countered skips it.
func _prepare_sanity_grinding(caster: Node2D, level: int) -> Callable:
	var entries: Array = []
	for i in players.size():
		if i != caster.player_id and not players[i].is_bankrupt:
			entries.append({"index": i, "name": PLAYER_NAMES[i], "color": PLAYER_COLORS[i]})
	if entries.is_empty():
		dice_label.text += "\nThere's no opponent to target."
		return Callable()
	_pp_open("Sanity Grinding: choose an opponent.", entries)
	var target_index: int = await _pp_result()
	if target_index == -1:
		return Callable()
	_spell_target_player(target_index)
	var amount: int = SpellData.SPELLS["Sanity Grinding"]["levels"][level].get("amount", 0)
	return _resolve_sanity_grinding.bind(caster, level, target_index, amount)


func _resolve_sanity_grinding(caster: Node2D, level: int, target_index: int, amount: int) -> void:
	_queue_spell_return_to_hand(caster, "Sanity Grinding")
	var opponent: Node2D = players[target_index]
	if opponent.is_bankrupt:
		dice_label.text = "%s's Sanity Grinding (Level %d) fizzles -- %s is already out of the game." % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index]]
		return
	amount = _apply_payment_reduction(opponent, amount)
	var resolve_message: String = "%s's Sanity Grinding (Level %d) resolves on %s for $%d!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index], amount]
	var debt_message: String = "%s's Sanity Grinding (Level %d) resolves on %s, who owes $%d!" % [_player_display_name(caster.player_id), level, PLAYER_NAMES[target_index], amount]
	await _charge_spell_payment(opponent, amount, caster, resolve_message, debt_message)


# Spell Mastery: same target-picker as T2 Response Spell's counter (any
# level, any spell on the stack) -- the only difference is Level 2 adds the
# countered spell straight to the caster's hand instead of the deck.
func _prepare_spell_mastery(caster: Node2D, level: int) -> Callable:
	var entries: Array = _counter_target_entries(func(entry): return true)
	if entries.is_empty():
		dice_label.text += "\nThere's no spell on the stack to counter."
		return Callable()
	_pp_open("Spell Mastery: choose a spell to counter.", entries)
	var target_id: int = await _pp_result()
	if target_id == -1:
		return Callable()
	_spell_target_spell(target_id)
	return _resolve_spell_mastery.bind(caster, level, target_id)


func _resolve_spell_mastery(caster: Node2D, level: int, target_id: int) -> void:
	for i in _spell_stack.size():
		if _spell_stack[i]["id"] == target_id:
			var countered: Dictionary = _spell_stack[i]
			_spell_stack.remove_at(i)
			if level == 2:
				_spell_add(caster, countered["spell_name"])
				dice_label.text = "%s's Spell Mastery (Level %d) counters %s's %s and keeps it!" % [_player_display_name(caster.player_id), level, _player_display_name(countered["caster_id"]), countered["display_name"]]
			else:
				_return_spell_to_deck(countered["spell_name"])
				dice_label.text = "%s's Spell Mastery (Level %d) counters %s's %s!" % [_player_display_name(caster.player_id), level, _player_display_name(countered["caster_id"]), countered["display_name"]]
			_update_player_panels()
			return
	dice_label.text = "%s's Spell Mastery (Level %d) had nothing left to counter." % [_player_display_name(caster.player_id), level]


# Tax Haven: the chosen tax space is claimed via the same owner_id /
# owned_property_indices bookkeeping as a normal property. board.gd's own
# "type" == "property" checks already keep it un-mortgageable
# (_mortgage_property()) and un-house-buildable (_buy_house()), and trading
# already works generically off owner_id -- so the only new logic needed is
# _move_player()'s tax branch, which redirects payment once it's claimed.
# _spell_extra_validation() already blocks casting a level whose tax space
# is already claimed; this re-checks at resolution in case that changed
# while the cast was pending on the stack.
func _prepare_tax_haven(caster: Node2D, level: int) -> Callable:
	var tax_index: int = LUXURY_TAX_INDEX if level == 1 else INCOME_TAX_INDEX
	if board.spaces[tax_index].owner_id != -1:
		dice_label.text += "\n%s is already owned." % board.get_space_info(tax_index).get("name", "")
		return Callable()
	return _resolve_tax_haven.bind(caster, level, tax_index)


func _resolve_tax_haven(caster: Node2D, level: int, tax_index: int) -> void:
	var space: Node2D = board.spaces[tax_index]
	var tax_name: String = board.get_space_info(tax_index).get("name", "")
	if space.owner_id != -1:
		dice_label.text = "%s's Tax Haven (Level %d) fizzles -- %s was already claimed." % [_player_display_name(caster.player_id), level, tax_name]
		return
	space.owner_id = caster.player_id
	caster.owned_property_indices.append(tax_index)
	_sort_owned_properties(caster)
	dice_label.text = "%s's Tax Haven (Level %d) resolves! They now own %s." % [_player_display_name(caster.player_id), level, tax_name]
	_update_player_panels()


# Step Forward: like Hasty Exit's Level 1, but also queues the card to
# return to the caster's hand at the end of the turn once it resolves.
func _prepare_step_forward(caster: Node2D, level: int) -> Callable:
	var bonus: int = SpellData.SPELLS["Step Forward"]["levels"][level].get("roll_bonus", 0)
	return _resolve_step_forward.bind(caster, level, bonus)


func _resolve_step_forward(caster: Node2D, level: int, bonus: int) -> void:
	caster.next_roll_bonus += bonus
	_queue_spell_return_to_hand(caster, "Step Forward")
	dice_label.text = "%s's Step Forward (Level %d) resolves! Their next roll this turn is +%d." % [_player_display_name(caster.player_id), level, caster.next_roll_bonus]
	_log("%s's Step Forward modified the dice roll." % PLAYER_NAMES[caster.player_id])
	_update_player_panels()


# Manastone: the caster picks which color to attune, encoded as an index
# into ATTUNABLE_COLORS since player_picker's entries return an int. Black
# is a valid choice (it can only ever be attuned via Manastone/Overflowing
# Bounty, never by owning a property), but Utility is deliberately absent --
# Utility Attunement can never be gained temporarily, by any means.
func _prepare_manastone(caster: Node2D, level: int) -> Callable:
	var color_entries: Array = []
	for i in ATTUNABLE_COLORS.size():
		var color_name: String = ATTUNABLE_COLORS[i]
		color_entries.append({"index": i, "name": color_name.capitalize(), "color": board.COLOR_GROUP_COLORS.get(color_name, Color.WHITE)})
	_pp_open("Manastone: choose a color to gain Temporary Attunement for.", color_entries)
	var chosen_index: int = await _pp_result()
	if chosen_index == -1:
		return Callable()
	var color_name: String = ATTUNABLE_COLORS[chosen_index]
	var amount: int = SpellData.SPELLS["Manastone"]["levels"][level].get("amount", 0)
	return _resolve_manastone.bind(caster, level, color_name, amount)


func _resolve_manastone(caster: Node2D, level: int, color_name: String, amount: int) -> void:
	caster.temp_attunement[color_name] = caster.temp_attunement.get(color_name, 0) + amount
	dice_label.text = "%s's Manastone (Level %d) resolves! +%d %s Temporary Attunement." % [_player_display_name(caster.player_id), level, amount, color_name.capitalize()]
	_update_player_panels()


# The Cult of Terminus, Level 1: arms a discount consumed only by the normal
# landing-purchase flow (see _move_player()) -- deliberately independent of
# Level 3's forced buy, which always pays full price, to avoid the two
# levels compounding into a free forced steal from another player.
func _prepare_cult_of_terminus_free_railroad(caster: Node2D) -> Callable:
	return _resolve_cult_of_terminus_free_railroad.bind(caster)


func _resolve_cult_of_terminus_free_railroad(caster: Node2D) -> void:
	caster.free_railroad_purchase = true
	dice_label.text = "%s's The Cult of Terminus (Level 1) resolves! Their next railroad purchase this turn costs $0." % _player_display_name(caster.player_id)
	_update_player_panels()


# The Cult of Terminus, Level 2: matches any of the 4 real railroads, plus
# Terminus Station itself once it exists.
func _cult_of_terminus_railroad_condition(space_index: int) -> bool:
	if board.get_space_info(space_index).get("color", "") == "railroad":
		return true
	return space_index == 0 and board.spaces[0].owner_id != -1


# No target to pick, and no _spell_extra_validation() guarantee needed --
# unlike Escape Plan's conditions, there are always at least 4 real
# railroads permanently on the board, so a match is always reachable.
func _prepare_cult_of_terminus_advance(caster: Node2D) -> Callable:
	var landing: int = (caster.current_space + _current_roll) % board.TOTAL_SPACES
	var steps: int = 0
	for i in board.TOTAL_SPACES:
		steps += 1
		landing = (landing + 1) % board.TOTAL_SPACES
		if _cult_of_terminus_railroad_condition(landing):
			break
	_spell_target_property(landing)
	return _resolve_cult_of_terminus_advance.bind(caster, steps, landing)


func _resolve_cult_of_terminus_advance(caster: Node2D, steps: int, landing_index: int) -> void:
	_current_roll += steps
	var destination: String = _property_name(landing_index)
	dice_label.text = "%s's The Cult of Terminus (Level 2) resolves! Roll increased by %d to land on %s (now %d)." % [_player_display_name(caster.player_id), steps, destination, _current_roll]
	_log("%s's The Cult of Terminus modified the dice roll." % PLAYER_NAMES[caster.player_id])
	_update_player_panels()


# The Cult of Terminus, Level 3: always the standard $200 railroad price
# (independent of Level 1's discount -- see above), paid to whoever
# currently owns the chosen railroad, or the bank if it's unowned. Includes
# Terminus Station itself in the eligible list once it exists.
func _prepare_cult_of_terminus_buy_railroad(caster: Node2D) -> Callable:
	var price: int = 200
	var entries: Array = []
	for space_index in _railroad_space_indices():
		if board.spaces[space_index].owner_id == caster.player_id:
			continue
		var owner_id: int = board.spaces[space_index].owner_id
		var owner_note: String = "bank" if owner_id == -1 else PLAYER_NAMES[owner_id]
		var display_name: String = _property_name(space_index)
		entries.append({"index": space_index, "name": "%s (%s)" % [display_name, owner_note], "color": Color.WHITE})
	if entries.is_empty():
		dice_label.text += "\nThere's no railroad left to buy."
		return Callable()

	_pp_open("The Cult of Terminus: choose a railroad to buy for $%d." % price, entries)
	var target_space_index: int = await _pp_result()
	if target_space_index == -1:
		return Callable()
	_spell_target_property(target_space_index)
	var target_owner_id: int = board.spaces[target_space_index].owner_id
	return _resolve_cult_of_terminus_buy_railroad.bind(caster, target_space_index, target_owner_id, price)


func _resolve_cult_of_terminus_buy_railroad(caster: Node2D, target_space_index: int, target_owner_id: int, price: int) -> void:
	var space: Node2D = board.spaces[target_space_index]
	var display_name: String = _property_name(target_space_index)
	if space.owner_id != target_owner_id or space.owner_id == caster.player_id:
		dice_label.text = "%s's The Cult of Terminus (Level 3) fizzles -- %s is no longer available." % [_player_display_name(caster.player_id), display_name]
		return
	# Resolves like a normal purchase -- Raise Money (mortgage / sell / trade)
	# if the caster is short of the $200, with a Cancel that abandons the buy.
	if not await _buy_property_via_spell(caster, target_space_index, price, target_owner_id):
		dice_label.text = "%s's The Cult of Terminus (Level 3): %s wasn't bought." % [_player_display_name(caster.player_id), display_name]
		return
	if target_owner_id == -1:
		dice_label.text = "%s's The Cult of Terminus (Level 3) resolves! Bought %s from the bank for $%d." % [_player_display_name(caster.player_id), display_name, price]
	else:
		dice_label.text = "%s's The Cult of Terminus (Level 3) resolves! Bought %s from %s for $%d." % [_player_display_name(caster.player_id), display_name, PLAYER_NAMES[target_owner_id], price]


# The Cult of Terminus, Level 4: _spell_extra_validation() already gated
# casting this on owning all 4 real railroads and Terminus not yet existing;
# this re-checks both at resolution in case that changed while the cast was
# pending on the stack.
func _prepare_cult_of_terminus_summon_terminus(caster: Node2D) -> Callable:
	return _resolve_cult_of_terminus_summon_terminus.bind(caster)


func _resolve_cult_of_terminus_summon_terminus(caster: Node2D) -> void:
	if board.spaces[0].owner_id != -1:
		dice_label.text = "%s's The Cult of Terminus (Level 4) fizzles -- Terminus already exists." % _player_display_name(caster.player_id)
		return
	if _owned_railroad_count(caster.player_id) < 4:
		dice_label.text = "%s's The Cult of Terminus (Level 4) fizzles -- they no longer own all 4 railroads." % _player_display_name(caster.player_id)
		return
	board.spaces[0].owner_id = caster.player_id
	caster.owned_property_indices.append(0)
	_sort_owned_properties(caster)
	dice_label.text = "%s's The Cult of Terminus (Level 4) resolves! Terminus has been summoned." % _player_display_name(caster.player_id)
	_update_player_panels()


func _send_to_jail(player: Node2D) -> void:
	player.current_space = JAIL_SPACE_INDEX
	player.position = board.get_space_center(JAIL_SPACE_INDEX) + MARKER_OFFSETS[player.player_id]
	player.in_jail = true
	player.jail_turns_left = JAIL_SENTENCE_TURNS
	player.consecutive_doubles = 0
	_log("%s was sent to Jail." % PLAYER_NAMES[player.player_id])


# Skips bankrupt players, who no longer take turns. Bounded by players.size()
# so a table where every player is bankrupt can't spin forever.
func _advance_to_next_active_player() -> void:
	# Sanity Grinding / Step Forward: pull any spells the outgoing player
	# queued back out of the shared deck and into their hand, now that their
	# turn (the one they were cast on -- both are turn-only) is ending.
	_process_pending_spell_returns(players[current_player])

	# Every "this turn" spell buff -- Counterfeit Currency's payment
	# reduction, Hasty Exit's next-roll bonus, Price Gouging's bonus houses
	# -- expires the moment the turn it was set on ends, regardless of
	# whose buff it is (e.g. Price Gouging is normally cast reacting to an
	# *opponent's* roll, so it's tied to their turn, not the caster's own).
	for player in players:
		player.payment_reduction_buffer = 0
		player.next_roll_bonus = 0
		player.price_gouging_bonus_houses = 0
		player.next_roll_multiplier = 1
		player.haggling_discount_percent = 0
		player.haggling_bank_bonus = false
		player.free_railroad_purchase = false

	for i in players.size():
		current_player = (current_player + 1) % players.size()
		if not players[current_player].is_bankrupt:
			# Temporary Attunement (from burning spells) only lasts until the
			# start of the turn it was gained on.
			players[current_player].temp_attunement.clear()
			_log_turn_start(current_player)
			return


func _update_turn_label() -> void:
	turn_label.text = "%s's turn" % _player_display_name(current_player)


func _player_display_name(index: int) -> String:
	var player: Node2D = players[index]
	if player.is_bankrupt:
		return "%s (bankrupt)" % PLAYER_NAMES[index]
	if player.is_placeholder_ai:
		return "%s (Disconnected)" % PLAYER_NAMES[index]
	if not player.in_jail:
		return PLAYER_NAMES[index]
	var turn_word: String = "turn" if player.jail_turns_left == 1 else "turns"
	return "%s (In Jail, %d %s left)" % [PLAYER_NAMES[index], player.jail_turns_left, turn_word]


func _update_player_panels() -> void:
	free_parking_label.text = "Free Parking: $%d" % free_parking_amount
	_log_ownership_changes()
	# Ownership banners: re-synced for every space on every panel refresh
	# rather than tracked at each of the many places ownership can change
	# (purchases, trades, bankruptcy, a dozen-plus spells) -- simpler and
	# cheap enough at 40 spaces.
	for space_index in board.TOTAL_SPACES:
		var space: Node2D = board.spaces[space_index]
		var owner_color: Color = PLAYER_COLORS[space.owner_id] if space.owner_id != -1 else Color.WHITE
		space.set_owner_banner(space.owner_id, owner_color)
	# GO shows the Go asset, or Terminus 2 while Terminus Station is in play.
	board.refresh_go_tile()
	_refresh_spell_target_highlights()
	for i in players.size():
		var pause_marker: String = " (Paused)" if _response_window_paused_by[i] else ""
		# Small target symbol next to the name while a pending spell targets them.
		var target_marker: String = " %s" % SPELL_TARGET_SYMBOL if _targeted_player_ids.has(i) else ""
		player_header_labels[i].text = "%s%s%s -- $%d" % [_player_display_name(i), target_marker, pause_marker, players[i].money]

		var flow: HFlowContainer = player_properties_flows[i]
		for child in flow.get_children():
			child.queue_free()
		for space_index in players[i].owned_property_indices:
			# Properties currently staged in the trade display have "moved"
			# there visually, so they're left out of the normal row.
			if _trading and (_trade1_offered.has(space_index) or _trade2_offered.has(space_index)):
				continue
			var info: Dictionary = board.get_space_info(space_index)
			# Space 0 held as a property = Terminus Station (a railroad card).
			var is_terminus: bool = space_index == 0
			var color_name: String = "railroad" if is_terminus else info.get("color", "")
			var color: Color = board.COLOR_GROUP_COLORS.get(color_name, Color.GRAY)
			var mc_name: String = "Terminus" if is_terminus else info.get("name", "")
			var mini_card: Control = MINI_CARD_SCENE.instantiate()
			flow.add_child(mini_card)
			mini_card.setup(space_index, mc_name, color, board.spaces[space_index].house_count, board.spaces[space_index].is_mortgaged)
			mini_card.card_clicked.connect(_on_space_clicked)
			mini_card.card_right_clicked.connect(_show_property_details)

		var spell_flow: HFlowContainer = player_spells_flows[i]
		for child in spell_flow.get_children():
			child.queue_free()
		for hand_index in players[i].spell_hand.size():
			# Same reasoning as the property filter above -- a spell staged
			# in the trade display has "moved" there visually.
			if _trading and ((i == _trader1 and _trade1_spells_offered.has(hand_index)) or (i == _trader2 and _trade2_spells_offered.has(hand_index))):
				continue
			var spell_name: String = players[i].spell_hand[hand_index]
			var spell_info: Dictionary = SpellData.SPELLS.get(spell_name, {})
			var face_up: bool = _spell_face_up(i, hand_index)
			var mini_spell: Control = MINI_SPELL_CARD_SCENE.instantiate()
			spell_flow.add_child(mini_spell)
			mini_spell.setup(hand_index, load(spell_info.get("icon", "")) if face_up else CARDBACK_TEXTURE, face_up)
			mini_spell.card_clicked.connect(_on_spell_clicked.bind(i))
			mini_spell.card_right_clicked.connect(_on_spell_right_clicked.bind(i))
			if _tutorial_active and _tutorial_focus_spells.has(spell_name):
				mini_spell.set_highlight(true)

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
		_populate_trade_spell_flow(trader1_flow, _trader1, _trade1_spells_offered)
		_populate_trade_flow(trader2_flow, _trade2_offered)
		_populate_trade_spell_flow(trader2_flow, _trader2, _trade2_spells_offered)

	_update_spell_stack_display()


# ============================================================================
# Online multiplayer -- state replication (Phase 2)
#
# The host runs the only real simulation. Once per frame it builds a snapshot
# of everything a client needs to render and, if anything changed since the
# last one, broadcasts it. Clients apply snapshots and reuse the existing
# _update_player_panels() / _refresh_action_buttons() to draw them; they never
# mutate game state (see the GameState.is_authority() guards on the input
# handlers). Player-driven input over the network arrives in Phase 3.
# ============================================================================

# Host: the last snapshot broadcast. Client: the last snapshot applied. Either
# way, "the last state we know about" -- an empty dict means "nothing yet".
var _net_last_snapshot: Dictionary = {}
# True only while _apply_snapshot() is running, so signal handlers fired by
# programmatic widget updates (LineEdit.text -> text_changed) can tell a
# snapshot apart from a real local edit.
var _applying_snapshot: bool = false


# Host: peers whose Main scene has come up and asked for state. Snapshots go
# only to these (broadcasting to a peer mid-scene-load just logs "node not
# found" and drops the packet).
var _net_ready_peers: Dictionary = {}


func _process(_delta: float) -> void:
	if not (GameState.online and GameState.is_authority()):
		return
	_net_ai_takeover_watchdog()
	var snap: Dictionary = _build_snapshot()
	if snap == _net_last_snapshot:
		return
	_net_last_snapshot = snap
	for peer in _net_ready_peers.keys():
		if multiplayer.get_peers().has(peer):
			_recv_snapshot.rpc_id(peer, snap)
		else:
			_net_ready_peers.erase(peer)


func _build_snapshot() -> Dictionary:
	var player_states: Array = []
	for p in players:
		player_states.append({
			"money": p.money,
			"space": p.current_space,
			"in_jail": p.in_jail,
			"jail_turns": p.jail_turns_left,
			"doubles": p.consecutive_doubles,
			"bankrupt": p.is_bankrupt,
			"is_ai": p.is_ai,
			"is_placeholder": p.is_placeholder_ai,
			"visible": p.visible,
			"owned": p.owned_property_indices.duplicate(),
			"hand": p.spell_hand.duplicate(),
			"revealed": p.spell_revealed_to.duplicate(true),
			"attunement": p.temp_attunement.duplicate(),
		})
	var space_states: Array = []
	for s in board.spaces:
		space_states.append({
			"owner": s.owner_id,
			"houses": s.house_count,
			"mortgaged": s.is_mortgaged,
		})
	return {
		"players": player_states,
		"spaces": space_states,
		"current_player": current_player,
		"slot_peer": GameState.slot_peer.duplicate(),
		"free_parking": free_parking_amount,
		"awaiting_end_turn": _awaiting_end_turn,
		"in_debt": _in_debt,
		"debt_player": _debt_player_id,
		"debt_amount": _debt_amount,
		"debt_cancellable": _debt_cancellable,
		"spell_stack": _spell_stack_names(),
		"spell_target_marks": _all_stack_target_marks(),
		"awaiting_buy": _awaiting_buy_decision,
		"casting_spell": _casting_spell,
		"buying_ho": _buying_house_or_unmortgaging,
		"selling_hm": _selling_house_or_mortgaging,
		"picking_pl": _picking_promised_land_property,
		"turn_text": turn_label.text,
		"response_window_open": _response_window_open,
		"paused_by": _response_window_paused_by.duplicate(),
		"roll_in_flight": _roll_in_flight,
		"current_roll": _current_roll,
		"die1": _die1,
		"die2": _die2,
		"roll_seq": _roll_seq,
		"trading": _trading,
		"trader1": _trader1,
		"trader2": _trader2,
		"trade_proposer": _trade_proposer,
		"trade1_offered": _trade1_offered.duplicate(),
		"trade2_offered": _trade2_offered.duplicate(),
		"trade1_spells": _trade1_spells_offered.duplicate(),
		"trade2_spells": _trade2_spells_offered.duplicate(),
		"trade1_money": trader1_money_edit.text,
		"trade2_money": trader2_money_edit.text,
		"trade_can_accept": _trade_can_accept,
	}


@rpc("authority", "call_remote", "reliable")
func _recv_snapshot(snap: Dictionary) -> void:
	_apply_snapshot(snap)


# Client -> host, on load: pull the current state right away instead of
# waiting for the host's next change to be broadcast.
@rpc("any_peer", "call_remote", "reliable")
func _request_snapshot() -> void:
	if not GameState.is_authority() or players.is_empty():
		return
	var who: int = multiplayer.get_remote_sender_id()
	_net_ready_peers[who] = true
	_net_log_history.rpc_id(who, _log_buffer)
	_recv_snapshot.rpc_id(who, _build_snapshot())


func _net_request_initial_snapshot() -> void:
	# Both peers swap into main.tscn from _recv_start on the same tick; give
	# the host a moment to finish attaching its Main node before the first
	# request, so the RPC doesn't arrive at an empty /root.
	await get_tree().create_timer(0.3).timeout
	for _attempt in 12:
		if not _net_last_snapshot.is_empty() or _returning_to_menu or not is_inside_tree():
			return
		_request_snapshot.rpc_id(1)
		await get_tree().create_timer(0.5).timeout


func _apply_snapshot(snap: Dictionary) -> void:
	_net_last_snapshot = snap
	# Setting LineEdit.text below fires text_changed; this flag keeps
	# _on_trade_money_changed from treating a snapshot as a local edit.
	_applying_snapshot = true

	var player_states: Array = snap.get("players", [])
	for i in mini(player_states.size(), players.size()):
		var ps: Dictionary = player_states[i]
		var p: Node2D = players[i]
		p.money = ps.get("money", p.money)
		p.current_space = ps.get("space", p.current_space)
		p.in_jail = ps.get("in_jail", false)
		p.jail_turns_left = ps.get("jail_turns", 0)
		p.consecutive_doubles = ps.get("doubles", 0)
		p.is_bankrupt = ps.get("bankrupt", false)
		p.is_ai = ps.get("is_ai", p.is_ai)
		p.is_placeholder_ai = ps.get("is_placeholder", false)
		p.visible = ps.get("visible", true)
		p.owned_property_indices = _net_int_array(ps.get("owned", []))
		p.spell_hand = _net_string_array(ps.get("hand", []))
		p.spell_revealed_to = _net_revealed(ps.get("revealed", []))
		p.temp_attunement = (ps.get("attunement", {}) as Dictionary).duplicate()
		p.position = board.get_space_center(p.current_space) + MARKER_OFFSETS[i]

	var space_states: Array = snap.get("spaces", [])
	for i in mini(space_states.size(), board.spaces.size()):
		var ss: Dictionary = space_states[i]
		var s: Node2D = board.spaces[i]
		s.owner_id = ss.get("owner", -1)
		s.house_count = ss.get("houses", 0)
		s.is_mortgaged = ss.get("mortgaged", false)

	current_player = snap.get("current_player", 0)
	if snap.has("slot_peer"):
		GameState.slot_peer = _net_int_array(snap["slot_peer"])
	free_parking_amount = snap.get("free_parking", 0)
	_awaiting_end_turn = snap.get("awaiting_end_turn", false)
	_in_debt = snap.get("in_debt", false)
	_debt_player_id = snap.get("debt_player", -1)
	_debt_amount = snap.get("debt_amount", 0)
	_debt_cancellable = snap.get("debt_cancellable", false)
	_net_spell_stack_names = snap.get("spell_stack", [])
	_net_spell_target_marks = snap.get("spell_target_marks", [])
	_awaiting_buy_decision = snap.get("awaiting_buy", false)
	_casting_spell = snap.get("casting_spell", false)
	_buying_house_or_unmortgaging = snap.get("buying_ho", false)
	_selling_house_or_mortgaging = snap.get("selling_hm", false)
	_picking_promised_land_property = snap.get("picking_pl", false)
	_response_window_open = snap.get("response_window_open", false)
	_response_window_paused_by = _net_bool_array(snap.get("paused_by", []))
	_trading = snap.get("trading", false)
	_trader1 = snap.get("trader1", -1)
	_trader2 = snap.get("trader2", -1)
	_trade1_offered = _net_int_array(snap.get("trade1_offered", []))
	_trade2_offered = _net_int_array(snap.get("trade2_offered", []))
	_trade1_spells_offered = _net_int_array(snap.get("trade1_spells", []))
	_trade2_spells_offered = _net_int_array(snap.get("trade2_spells", []))
	_trade_can_accept = snap.get("trade_can_accept", false)
	_trade_proposer = snap.get("trade_proposer", -1)

	turn_label.text = snap.get("turn_text", "")

	trade_hseparator.visible = _trading
	trade_display.visible = _trading
	if _trading:
		trader1_label.text = PLAYER_NAMES[_trader1]
		trader1_label.add_theme_color_override("font_color", PLAYER_COLORS[_trader1])
		trader2_label.text = PLAYER_NAMES[_trader2]
		trader2_label.add_theme_color_override("font_color", PLAYER_COLORS[_trader2])
		# Don't stomp a box this player is actively editing (see
		# _refresh_action_buttons for who that is); otherwise mirror the host.
		if not trader1_money_edit.has_focus():
			trader1_money_edit.text = snap.get("trade1_money", "")
		if not trader2_money_edit.has_focus():
			trader2_money_edit.text = snap.get("trade2_money", "")
	else:
		for child in trader1_flow.get_children():
			child.queue_free()
		for child in trader2_flow.get_children():
			child.queue_free()

	# These two have setters that redraw the wizard-vision line.
	_current_roll = snap.get("current_roll", 0)
	_roll_in_flight = snap.get("roll_in_flight", false)

	_apply_dice_animation(snap.get("die1", 0), snap.get("die2", 0), snap.get("roll_seq", 0))

	_update_player_panels()
	_refresh_action_buttons()
	_applying_snapshot = false


# Client: mirror the host's dice-rolling animation from the snapshot.
func _apply_dice_animation(d1: int, d2: int, seq: int) -> void:
	if d1 == 0:
		dice_roller.clear_dice()
		_roll_seq = seq
		return
	if seq != _roll_seq:
		_roll_seq = seq
		dice_roller.roll(d1, d2, _response_window_seconds() * 0.5)
	if not _roll_in_flight or _response_window_paused_by.has(true):
		dice_roller.finish_now()


func _net_int_array(a) -> Array[int]:
	var out: Array[int] = []
	for v in a:
		out.append(int(v))
	return out


func _net_string_array(a) -> Array[String]:
	var out: Array[String] = []
	for v in a:
		out.append(str(v))
	return out


# spell_revealed_to: an untyped Array of Array[int] (one per card in hand).
func _net_revealed(a) -> Array:
	var out: Array = []
	for entry in a:
		out.append(_net_int_array(entry))
	return out


func _net_bool_array(a) -> Array[bool]:
	var out: Array[bool] = []
	out.resize(GameState.MAX_PLAYERS)
	out.fill(false)
	for i in mini(a.size(), out.size()):
		out[i] = bool(a[i])
	return out


# ============================================================================
# Online multiplayer -- prompt router (Phase 4)
#
# The host runs all game logic, but a question meant for a specific player
# (buy this property? which spell to discard?) must be answered on THAT
# player's machine. Every popup the host would open now goes through an
# _xx_open / _xx_result wrapper: if the target player is local -- or it's a
# local game -- the real popup opens here exactly as before; otherwise the
# host asks that player's client over RPC and awaits the reply.
#
# Pickers are used strictly one-at-a-time (each caller awaits its result
# before opening the next), so a single pending-request slot suffices.
# ============================================================================

# Which player should see prompts right now. -1 == "derive it" (whoever is
# acting). Reserved for Phase 5, when a remote player can cast spells and the
# caster -- not the current player -- owns the follow-up prompts.
var _prompt_slot: int = -1
var _net_prompt_seq: int = 0
var _net_prompt_replies: Dictionary = {}
var _net_pending_req: int = 0
var _net_pending_peer: int = 0
var _net_pending_kind: String = ""


func _prompt_target() -> int:
	return _prompt_slot if _prompt_slot >= 0 else _acting_player_id()


func _prompt_is_local() -> bool:
	return not GameState.online or GameState.is_slot_local(_prompt_target())


func _peer_for_slot(slot: int) -> int:
	return GameState.slot_peer[slot] if slot >= 0 and slot < GameState.slot_peer.size() else 1


# --- confirm_prompt (yes / no) ----------------------------------------

func _cf_open(text: String) -> void:
	if _prompt_is_local():
		# Sticky: a yes/no the game is actively waiting on must never be
		# resolved by the app losing focus (Godot auto-hides popups on
		# alt-tab, which would otherwise fire popup_hide -> "No").
		confirm_prompt.sticky = true
		confirm_prompt.open(text, _tutorial_confirm_gate())
	else:
		_net_open_remote("confirm", {"text": text})


func _cf_result() -> bool:
	if _prompt_is_local():
		return await confirm_prompt.answered
	return bool(await _net_await_reply())


# --- player_picker (choice list) ------------------------------------

func _pp_open(text: String, entries: Array, mandatory: bool = false) -> void:
	if _prompt_is_local():
		player_picker.open(text, entries, mandatory, false, _tutorial_picker_gate())
	else:
		_net_open_remote("pick", {
			"text": text, "entries": _net_pack_entries(entries), "mandatory": mandatory,
		})


func _pp_result() -> int:
	if _prompt_is_local():
		return await player_picker.player_chosen
	return int(await _net_await_reply())


# --- card_picker --------------------------------------------------

func _cp_open(text: String, entries: Array, mandatory: bool = false, skip_text: String = "", skip_index: int = -2, large: bool = false) -> void:
	if _prompt_is_local():
		card_picker.open(text, entries, mandatory, skip_text, skip_index, false, large)
	else:
		_net_open_remote("card", {
			"text": text, "entries": _net_pack_card_entries(entries),
			"mandatory": mandatory, "skip_text": skip_text, "skip_index": skip_index,
			"large": large,
		})


func _cp_result() -> int:
	if _prompt_is_local():
		return await card_picker.card_chosen
	return int(await _net_await_reply())


# --- info_prompt (no reply) --------------------------------------

func _info_open(text: String) -> void:
	if _prompt_is_local():
		info_prompt.open(text)
	else:
		_net_show_info.rpc_id(_peer_for_slot(_prompt_target()), text)


# --- host side: dispatch + await ----------------------------------

func _net_open_remote(kind: String, payload: Dictionary) -> void:
	_net_prompt_seq += 1
	_net_pending_req = _net_prompt_seq
	_net_pending_peer = _peer_for_slot(_prompt_target())
	_net_pending_kind = kind
	_net_prompt_replies.erase(_net_pending_req)
	_net_show_prompt.rpc_id(_net_pending_peer, _net_pending_req, kind, payload)


func _net_await_reply() -> Variant:
	var req: int = _net_pending_req
	var peer: int = _net_pending_peer
	while not _net_prompt_replies.has(req):
		if not multiplayer.get_peers().has(peer):
			# The player we were waiting on is gone -- resolve to a safe
			# default so host logic never hangs. (Phase 6 handles this
			# properly; for now the turn just proceeds as a decline.)
			return false if _net_pending_kind == "confirm" else -1
		# Scene torn down (quit to menu) -- stop before get_tree() goes null.
		if _returning_to_menu or not is_inside_tree():
			return false if _net_pending_kind == "confirm" else -1
		await get_tree().process_frame
	var value: Variant = _net_prompt_replies[req]
	_net_prompt_replies.erase(req)
	return value


@rpc("any_peer", "call_remote", "reliable")
func _net_prompt_reply(req_id: int, value: Variant) -> void:
	if not GameState.is_authority():
		return
	_net_prompt_replies[req_id] = value


# --- client side: show the popup, send the answer back --------------

@rpc("authority", "call_remote", "reliable")
func _net_show_prompt(req_id: int, kind: String, payload: Dictionary) -> void:
	var result: Variant = await _net_client_run_prompt(kind, payload)
	_net_prompt_reply.rpc_id(1, req_id, result)


# Every prompt shown here is driven by the host over the network, so the
# player it belongs to might be looking at a different window when it
# arrives (in particular a second game instance on the same machine). All
# three popups are opened "sticky" -- Godot auto-hides popups when the app
# loses focus, and without this that would fire popup_hide and resolve the
# prompt (a buy decision declined, a picker cancelled) behind the player's
# back. Sticky makes any non-button dismissal reopen once the window has
# focus again instead.
func _net_client_run_prompt(kind: String, payload: Dictionary) -> Variant:
	match kind:
		"confirm":
			confirm_prompt.sticky = true
			confirm_prompt.open(str(payload.get("text", "")))
			return await confirm_prompt.answered
		"pick":
			player_picker.open(str(payload.get("text", "")),
				_net_unpack_entries(payload.get("entries", [])),
				bool(payload.get("mandatory", false)), true)
			return await player_picker.player_chosen
		"card":
			card_picker.open(str(payload.get("text", "")),
				_net_unpack_card_entries(payload.get("entries", [])),
				bool(payload.get("mandatory", false)),
				str(payload.get("skip_text", "")),
				int(payload.get("skip_index", -2)), true,
				bool(payload.get("large", false)))
			return await card_picker.card_chosen
	return -1


@rpc("authority", "call_remote", "reliable")
func _net_show_info(text: String) -> void:
	info_prompt.open(text)


# --- entry (de)serialization ------------------------------------

func _net_pack_entries(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		out.append({
			"index": int(e["index"]), "name": str(e["name"]),
			"color": e.get("color", Color.WHITE),
		})
	return out


func _net_unpack_entries(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		out.append({
			"index": int(e["index"]), "name": str(e["name"]),
			"color": e.get("color", Color.WHITE),
		})
	return out


func _net_pack_card_entries(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		var icon: Variant = e.get("icon", null)
		out.append({
			"index": int(e["index"]), "name": str(e.get("name", "")),
			"icon_path": icon.resource_path if icon != null else "",
			"caption": str(e.get("caption", "")),
		})
	return out


func _net_unpack_card_entries(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		var path: String = str(e.get("icon_path", ""))
		out.append({
			"index": int(e["index"]), "name": str(e.get("name", "")),
			"icon": load(path) if path != "" else null,
			"caption": str(e.get("caption", "")),
		})
	return out


# ============================================================================
# Toasts -- a brief centred banner for "you can't do that" feedback, shown to
# the player who attempted the action (routed like the prompts online).
# ============================================================================

var _toast_tween: Tween


func _toast(msg: String) -> void:
	if msg == "":
		return
	if GameState.online and GameState.is_authority():
		var slot: int = _prompt_target()
		if not GameState.is_slot_local(slot):
			_net_toast.rpc_id(_peer_for_slot(slot), msg)
			return
	_show_toast(msg)


@rpc("authority", "call_remote", "reliable")
func _net_toast(msg: String) -> void:
	_show_toast(msg)


func _show_toast(msg: String) -> void:
	toast_label.text = msg
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_panel.modulate.a = 1.0
	toast_panel.visible = true
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(toast_panel.hide)


# ============================================================================
# Game log -- the permanent, scrollable record in the bottom panel. Only the
# events listed below get logged; everything else stays transient (toasts).
# Turn-start lines are drawn in the player's colour, everything else in black.
# ============================================================================

var _log_buffer: String = ""    # full bbcode text, for a client catching up

# [{ "name": String, "bbcode": String }] for every spell and property name,
# longest name first so "Baltic Avenue" wins over "Baltic". _markup_names()
# swaps each occurrence in a log line for its coloured (and, for spells,
# clickable) BBCode. Built once in _ready() -- SPELL_DATA and the board are
# constant for the game's life.
var _log_markup: Array = []


func _build_log_markup() -> void:
	_log_markup.clear()
	for spell_name in SpellData.SPELLS:
		var sc: Color = _log_name_color(board.COLOR_GROUP_COLORS.get(SpellData.SPELLS[spell_name].get("color", ""), Color.BLACK))
		# [url] carries the meta clicked handlers see; colour goes inside it
		# so the link text itself is the spell's colour.
		_log_markup.append({
			"name": spell_name,
			"bbcode": "[url=spell:%s][color=#%s]%s[/color][/url]" % [spell_name, sc.to_html(false), spell_name],
		})
	for i in board.SPACE_DATA:
		var info: Dictionary = board.SPACE_DATA[i]
		if info.get("type", "") != "property":
			continue
		var pc: Color = _log_name_color(board.COLOR_GROUP_COLORS.get(info.get("color", ""), Color.BLACK))
		_log_markup.append({
			"name": info["name"],
			"bbcode": "[color=#%s]%s[/color]" % [pc.to_html(false), info["name"]],
		})
	var rc: Color = _log_name_color(board.COLOR_GROUP_COLORS["railroad"])
	_log_markup.append({"name": "Terminus", "bbcode": "[color=#%s]Terminus[/color]" % rc.to_html(false)})
	_log_markup.sort_custom(func(a, b): return a["name"].length() > b["name"].length())


# Nudges a colour dark enough to read on the light log background.
func _log_name_color(c: Color) -> Color:
	while c.get_luminance() > 0.42:
		c = c.darkened(0.28)
	return c


# Replaces every spell / property name in `text` with its BBCode fragment,
# scanning left to right so an inserted fragment is never re-scanned.
func _markup_names(text: String) -> String:
	var out: String = ""
	var i: int = 0
	while i < text.length():
		var hit: Dictionary = {}
		for entry in _log_markup:
			if text.substr(i, entry["name"].length()) == entry["name"]:
				hit = entry
				break
		if hit.is_empty():
			out += text[i]
			i += 1
		else:
			out += hit["bbcode"]
			i += hit["name"].length()
	return out


func _on_log_meta_clicked(meta: Variant) -> void:
	var m: String = str(meta)
	if m.begins_with("spell:"):
		var spell_name: String = m.substr(6)
		var info: Dictionary = SpellData.SPELLS.get(spell_name, {})
		if info.has("icon"):
			spell_card.show_card(load(info["icon"]))


func _log_line_bbcode(msg: String, color: Color) -> String:
	return "[color=#%s]%s[/color]\n" % [color.to_html(false), _markup_names(msg)]


func _log(msg: String, color: Color = Color.BLACK) -> void:
	var line: String = _log_line_bbcode(msg, color)
	_log_buffer += line
	game_log.append_text(line)
	if GameState.online and GameState.is_authority():
		for peer in _net_ready_peers.keys():
			if multiplayer.get_peers().has(peer):
				_net_log_line.rpc_id(peer, msg, color)


func _log_turn_start(player_id: int) -> void:
	_log("%s's turn." % PLAYER_NAMES[player_id], PLAYER_COLORS[player_id])


# Player X paid $Y to <recipient> ("Free Parking", or another player's name).
func _log_payment(payer_id: int, amount: int, recipient: String) -> void:
	if amount <= 0:
		return
	_log("%s paid $%d to %s." % [PLAYER_NAMES[payer_id], amount, recipient])


# Owner id per space at the last _log_ownership_changes() -- empty until the
# first call (which just records the baseline without logging).
var _logged_owners: Array[int] = []


# Host-only: log any property whose owner changed since the last panel
# refresh. One place instead of the ~12 scattered owner_id assignments.
# Clients get these lines pushed from the host via _net_log_line.
func _log_ownership_changes() -> void:
	if not GameState.is_authority():
		return
	if _logged_owners.size() != board.spaces.size():
		_logged_owners.clear()
		for s in board.spaces:
			_logged_owners.append(s.owner_id)
		return
	for i in board.spaces.size():
		var now: int = board.spaces[i].owner_id
		if now == _logged_owners[i]:
			continue
		_logged_owners[i] = now
		if now == -1:
			_log("%s returned to the bank." % _property_name(i))
		else:
			_log("%s is now owned by %s." % [_property_name(i), PLAYER_NAMES[now]])


# Suppress the next _log_ownership_changes() line for `space_index` -- used
# right after a change that's already been logged with more detail (a
# purchase, with its price).
func _note_ownership(space_index: int) -> void:
	if _logged_owners.size() == board.spaces.size():
		_logged_owners[space_index] = board.spaces[space_index].owner_id


# The display name for a space -- the SPACE_DATA name, except space 0 once it's
# been claimed as Terminus (the GO overlay from The Cult of Terminus L4), which
# shows as "Terminus" rather than "GO". Use this everywhere a property is named
# in a picker / prompt / log line.
func _property_name(space_index: int) -> String:
	if space_index == 0 and board.spaces[0].owner_id != -1:
		return "Terminus"
	return board.get_space_info(space_index).get("name", "Space %d" % space_index)


@rpc("authority", "call_remote", "reliable")
func _net_log_line(msg: String, color: Color) -> void:
	var line: String = _log_line_bbcode(msg, color)
	_log_buffer += line
	game_log.append_text(line)


@rpc("authority", "call_remote", "reliable")
func _net_log_history(buffer: String) -> void:
	_log_buffer = buffer
	game_log.clear()
	game_log.append_text(buffer)


# Throwaway target for `dice_label.text = ...` / `+= ...`. The on-screen
# status line was removed in favour of the scrollable log; keeping this sink
# means those ~200 call sites don't all have to be edited away.
class DiceSink:
	extends RefCounted
	var text: String = ""
