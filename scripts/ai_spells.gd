class_name AiSpells
extends RefCounted

# How Computer players use spells: when to cast, at what level, on whom,
# when to pause and react, and how to answer every prompt a spell raises.
# The same strategy in plain English is AI_STRATEGY.md (repo root) -- keep
# the two in step when changing anything here.
#
# Everything is scored in DOLLARS. A spell's score is what the bot expects
# to gain from casting it now: money in, money an opponent loses (weighted --
# see _harm_weight), property worth, and a rough price on things like a
# better landing square or a lost turn. A bot casts the best-scoring option
# if the score clears a threshold; otherwise it keeps the card.
#
# Casting goes through main.gd's real pipeline (_ai_cast_spell ->
# _prepare_spell_cast -> _finish_cast), with every target prompt answered
# by answer() below, so bots obey exactly the same rules as people do.
#
# `main` is deliberately untyped: this file is shared by branches whose
# main.gd differ (spells from later expansions just never show up on the
# branches that don't have them).

var main

# --- Tuning --------------------------------------------------------------
# A turn spell is cast only if it's worth at least this much now...
const TURN_CAST_MIN: float = 70.0
# ...less once the hand is crowded (cards sitting unused are worth little).
const TURN_CAST_MIN_5_CARDS: float = 40.0
const TURN_CAST_MIN_7_CARDS: float = 15.0
# Spells that come straight back to the hand (Sanity Grinding, Step
# Forward) are nearly free to cast.
const RETURNING_CAST_MIN: float = 5.0
# A reaction (pausing someone's roll or spell to answer it).
const REACT_MIN: float = 50.0
# Only spend a counter on something that would cost the bot this much.
const COUNTER_MIN: float = 120.0
# Burning cards for Attunement must beat the burned cards' worth by this.
const BURN_MARGIN: float = 40.0
const MAX_BURNS: int = 2
const MAX_TURN_CASTS: int = 4
# A card in hand with nothing better to do is worth about this much.
const CARD_WORTH: float = 60.0
# Money the bot tries to keep when a spell asks it to spend.
const CASH_RESERVE: int = 150
# How often one opponent lands on a given square, per opponent turn (~1/35),
# times how many more turns a typical game has left: used to price a rent
# increase that will sit on the board for a while.
const LANDINGS_PER_OPPONENT: float = 0.45

# Card worth for cards that only make sense as reactions (their worth while
# held is the insurance they provide).
const HELD_WORTH: Dictionary = {
	"Counterbalance": 110.0, "Spell Mastery": 130.0, "Deny Rights": 100.0,
	"T2 Response Spell": 100.0,
	"Adrenaline": 70.0, "T3 Escape Spell": 70.0, "Divine Protection": 80.0,
	"Escape Plan": 80.0, "King's Escape Tunnel": 70.0, "Escape Into Custody": 60.0,
	"Rocket Boost": 60.0, "Hasty Exit": 70.0, "Dodge": 70.0, "Veto": 60.0,
	"Price Gouging": 70.0, "Seize the Opportunity": 90.0,
	"Counterfeit Currency": 90.0, "Misplaced Payment": 50.0, "Haggling": 90.0,
	"Manastone": 50.0, "Overflowing Bounty": 60.0, "Sanity Grinding": 80.0,
	"Step Forward": 60.0, "Go For the Kill": 70.0,
}

const COUNTER_SPELLS: Array[String] = ["Counterbalance", "Spell Mastery", "Deny Rights", "T2 Response Spell"]

# --- State ----------------------------------------------------------------
var _plan: Dictionary = {}
var _planning: bool = false
# seat -> {event key: true}: what each bot has already reacted to.
var _reacted: Dictionary = {}
# stack id -> what the bot thought its own cast was worth (so it knows how
# much a counter aimed at it would cost).
var _stack_values: Dictionary = {}
# Master Plan Level 3 picks both faces at once; the second is remembered.
var _master_plan_second: int = 0
# Bonus Attunement assumed while scoring (Manastone / Overflowing Bounty
# ask "what would one more Attunement let me cast?").
var _att_bonus: Dictionary = {}
var _att_bonus_all: int = 0


func _init(m) -> void:
	main = m


# ============================================================================
# Entry points called by main.gd
# ============================================================================

# Own turn, before rolling ("pre_roll") and after the roll has resolved
# ("post_roll"): cast the best spell while one clears the bar.
func play_turn_spells(p: Node2D, phase: String) -> void:
	if not _active():
		return
	var failed: Dictionary = {}
	for _i in MAX_TURN_CASTS:
		if not _still_my_turn(p):
			return
		var best: Dictionary = _best_option(p, phase, failed)
		if best.is_empty() or best["score"] < _turn_threshold(p, best):
			return
		var ok: bool = await _execute(p, best, false)
		if not ok:
			failed[best["spell"]] = true


# Raise Money mode: a spell that brings money in, before mortgaging.
func raise_money_with_spells(p: Node2D, amount: int) -> void:
	if not _active():
		return
	var failed: Dictionary = {}
	for _i in 3:
		if p.is_bankrupt or p.money >= amount or main._returning_to_menu:
			return
		var best: Dictionary = _best_option(p, "debt", failed)
		if best.is_empty() or best.get("cash", 0.0) < 40.0:
			return
		var ok: bool = await _execute(p, best, false)
		if not ok:
			failed[best["spell"]] = true


# Called from the response-window loop whenever something new is in it. At
# most one bot reacts per call; the cast itself re-arms the window, so the
# others (and this one) get another look afterwards.
func consider_reactions() -> void:
	if not _active() or main._casting_spell or main._resolving_stack or not main._response_window_open:
		return
	var best: Dictionary = {}
	var best_seat: int = -1
	var best_key: String = ""
	for seat in main.players.size():
		var p: Node2D = main.players[seat]
		if not p.is_ai or p.is_bankrupt or p.is_placeholder_ai:
			continue
		var phases: Array[String] = []
		if not main._spell_stack.is_empty():
			phases.append("spell")
		if main._roll_in_flight and not main.players[main.current_player].is_bankrupt:
			phases.append("roll_self" if seat == main.current_player else "roll_opp")
		for phase in phases:
			var key: String = _event_key(phase)
			if _reacted.get(seat, {}).has(key):
				continue
			var option: Dictionary = _best_option(p, phase, {})
			if option.is_empty() or option["score"] < _react_threshold(option):
				continue
			if best.is_empty() or option["score"] > best["score"]:
				best = option
				best_seat = seat
				best_key = key
	if best.is_empty():
		return
	if not _reacted.has(best_seat):
		_reacted[best_seat] = {}
	_reacted[best_seat][best_key] = true
	await _execute(main.players[best_seat], best, true)


# Magic Forest: discard the card it values least.
func pick_discard(p: Node2D) -> int:
	var worst: int = 0
	var worst_worth: float = INF
	for i in p.spell_hand.size():
		var w: float = card_worth(p, p.spell_hand[i])
		if w < worst_worth:
			worst_worth = w
			worst = i
	return worst


# Spell Shop: the card it values most, if that beats the price by a margin
# and it can spare the money. Returns the index, or main.SPELL_SHOP_SKIP_INDEX.
func pick_shop_buy(p: Node2D, cards: Array, sale_index: int) -> int:
	var best: int = main.SPELL_SHOP_SKIP_INDEX
	var best_margin: float = 0.0
	for i in cards.size():
		var price: int = 50 if i == sale_index else 100
		if p.money - price < 250:
			continue
		var margin: float = card_worth(p, cards[i]) - price - 30.0
		if margin > best_margin:
			best_margin = margin
			best = i
	if best != main.SPELL_SHOP_SKIP_INDEX:
		_explain(p, "buys %s at the Spell Shop -- rates it about $%d more than its price." % [cards[best], int(best_margin + 30.0)])
	return best


# --- Prompt answering --------------------------------------------------------

func begin_plan(plan: Dictionary) -> void:
	_plan = plan.duplicate(true)
	_planning = true


func end_plan() -> void:
	_plan = {}
	_planning = false


# A cast that's going through (called just before it goes on the stack):
# remember what it was worth, and say why in the log.
func note_cast(p: Node2D, spell: String, level: int, stack_id: int, plan: Dictionary) -> void:
	_stack_values[stack_id] = float(plan.get("value", 0.0))
	var why: String = str(plan.get("why", ""))
	if why != "":
		_explain(p, "%s at Level %d, worth about $%d: %s" % [spell, level, int(plan.get("score", plan.get("value", 0.0))), why])


# Answers one routed prompt (see main.gd's _prompt_is_ai). q: {"kind":
# "confirm" | "pick" | "board" | "card" | "die" | "face", "seat", "text",
# plus that kind's entries / spaces}. During a planned cast the plan's
# answers are used in order; anything else falls back to sensible defaults.
func answer(q: Dictionary) -> Variant:
	var kind: String = q.get("kind", "")
	if _planning:
		var queue: Array = _plan.get("answers", {}).get(kind, [])
		while not queue.is_empty():
			var v = queue.pop_front()
			if _answer_valid(q, v):
				return _answer_value(q, v)
	return _default_answer(q)


func _answer_valid(q: Dictionary, v) -> bool:
	match q.get("kind", ""):
		"confirm":
			return typeof(v) == TYPE_BOOL
		"pick", "card":
			for e in q.get("entries", []):
				if typeof(v) == TYPE_STRING:
					if _norm(str(e.get("name", ""))).contains(_norm(v)):
						return true
				elif int(e.get("index", -999)) == int(v):
					return true
			return false
		"board":
			return int(v) in q.get("spaces", [])
		"die":
			return int(v) == 1 or int(v) == 2
		"face":
			return int(v) >= 1 and int(v) <= 6
	return false


func _answer_value(q: Dictionary, v) -> Variant:
	if typeof(v) == TYPE_STRING and q.get("kind", "") in ["pick", "card"]:
		for e in q.get("entries", []):
			if _norm(str(e.get("name", ""))).contains(_norm(v)):
				return int(e.get("index", -1))
	if typeof(v) == TYPE_BOOL:
		return v
	return int(v)


func _norm(s: String) -> String:
	return s.to_lower().replace("_", " ")


func _default_answer(q: Dictionary) -> Variant:
	var seat: int = int(q.get("seat", -1))
	var p: Node2D = main.players[seat] if seat >= 0 and seat < main.players.size() else null
	var text: String = str(q.get("text", ""))
	match q.get("kind", ""):
		"confirm":
			if p == null:
				return false
			if text.begins_with("Dodge:"):
				return _dodge_reroll_other(p, text)
			if text.to_lower().contains("buy "):
				return _confirm_buy(p, text)
			return false
		"die":
			if text.begins_with("Dodge:") and p != null:
				return _dodge_pick_die(p)
			if text.contains("Fated Ending"):
				return _fated_ending_pick(seat, text)
			return 1
		"face":
			if p != null and text.begins_with("Master Plan"):
				return _master_plan_face(p, text)
			return 6
		"pick":
			var entries: Array = q.get("entries", [])
			if q.get("mandatory", false) and not entries.is_empty():
				return int(entries[0].get("index", -1))
			return -1
		"board":
			var spaces: Array = q.get("spaces", [])
			if not q.get("cancellable", true) and not spaces.is_empty():
				return int(spaces[0])
			return -1
		"card":
			var entries: Array = q.get("entries", [])
			if q.get("mandatory", false) and not entries.is_empty():
				return int(entries[0].get("index", -1))
			return int(q.get("skip_index", -2))
	return -1


# ============================================================================
# Choosing what to cast
# ============================================================================

# Bots only think on the host, and never during a tutorial (it scripts its
# own opponents).
func _active() -> bool:
	return GameState.is_authority() and not main._tutorial_active and not main._returning_to_menu


func _still_my_turn(p: Node2D) -> bool:
	return not p.is_bankrupt and main.current_player == p.player_id and not main._returning_to_menu and main.is_inside_tree()


func _turn_threshold(p: Node2D, option: Dictionary) -> float:
	if option.get("returns", false):
		return RETURNING_CAST_MIN
	var cards: int = p.spell_hand.size()
	if cards >= 7:
		return TURN_CAST_MIN_7_CARDS
	# Patience with spells whose payoff swings a lot (Taxes on a broke
	# opponent): wait until it's worth a fair share of what it usually is.
	var typical: float = _typical_value(option["spell"], option["level"])
	if cards >= 5:
		return maxf(TURN_CAST_MIN_5_CARDS, 0.3 * typical)
	return maxf(TURN_CAST_MIN, 0.5 * typical)


# Roughly what a spell whose payoff depends on the board is worth on a
# typical turn.
func _typical_value(spell: String, level: int) -> float:
	var li: Dictionary = SpellData.SPELLS.get(spell, {}).get("levels", {}).get(level, {})
	var amount: float = float(li.get("amount", 0))
	match spell:
		"Taxes":
			return 1200.0 / float(li.get("divisor", 5))
		"Migraine":
			return float(li.get("pay_per_card", 0)) * 4.0
		"Far-Reaching Empire", "Line of Fire":
			return amount * 4.0
		"Sinkhole":
			return amount * 1.3
		"Snatch Purse":
			return float(li.get("count", 1)) * 70.0
	return 0.0


# A reaction has to beat the card's worth as insurance too (no point spending
# Counterfeit Currency on a $20 rent).
func _react_threshold(option: Dictionary) -> float:
	if option["spell"] in COUNTER_SPELLS:
		return COUNTER_MIN
	return maxf(REACT_MIN, HELD_WORTH.get(option["spell"], 0.0))


func _event_key(phase: String) -> String:
	if phase == "spell":
		var top: Dictionary = main._spell_stack.back()
		return "spell:%d" % int(top["id"])
	var roller: Node2D = main.players[main.current_player]
	return "roll:%d:%d:%d" % [main._roll_seq, main.current_player, _current_landing(roller)]


# Every castable (spell, level) in p's hand for `phase`, scored; the best one
# (or {} if nothing is worth anything). An option may burn other cards of the
# same color first, to reach a higher level.
func _best_option(p: Node2D, phase: String, failed: Dictionary) -> Dictionary:
	var reaction: bool = phase in ["roll_self", "roll_opp", "spell"]
	var best: Dictionary = {}
	var seen: Dictionary = {}
	for hand_index in p.spell_hand.size():
		var spell: String = p.spell_hand[hand_index]
		if seen.has(spell) or failed.has(spell):
			continue
		seen[spell] = true
		var info: Dictionary = SpellData.SPELLS.get(spell, {})
		var color: String = info.get("color", "")
		var levels: Array = info.get("levels", {}).keys()
		levels.sort()
		var burnable: Array[int] = _burnable_cards(p, color, hand_index)
		var attune: int = main._color_attunement(p, color)
		for level in levels:
			if not _timing_ok(p, spell, level, reaction):
				continue
			if main._spell_extra_validation(p, spell, level) != "":
				continue
			var burns_needed: int = maxi(0, level - attune)
			if burns_needed > 0 and main._spell_free_cast_allowed(p, spell, level):
				burns_needed = 0
			if burns_needed > mini(MAX_BURNS, burnable.size()):
				continue
			var ev: Dictionary = evaluate(p, spell, level, phase)
			if ev.is_empty():
				continue
			var score: float = float(ev.get("value", 0.0))
			var burn_list: Array[int] = []
			if burns_needed > 0:
				# Burn the least useful cards of that color.
				var ranked: Array = burnable.duplicate()
				ranked.sort_custom(func(a, b): return card_worth(p, p.spell_hand[a]) < card_worth(p, p.spell_hand[b]))
				for k in burns_needed:
					burn_list.append(ranked[k])
					score -= card_worth(p, p.spell_hand[ranked[k]]) + BURN_MARGIN
			if phase == "debt":
				score = float(ev.get("cash", 0.0))
			if best.is_empty() or score > best["score"]:
				best = ev.duplicate(true)
				best["score"] = score
				best["spell"] = spell
				best["level"] = level
				best["burns"] = burn_list
	return best


func _burnable_cards(p: Node2D, color: String, except_index: int) -> Array[int]:
	var out: Array[int] = []
	if color == "" or color == "utility":
		return out
	for i in p.spell_hand.size():
		if i == except_index:
			continue
		if SpellData.SPELLS.get(p.spell_hand[i], {}).get("color", "") == color:
			out.append(i)
	return out


# Timing as main.gd's _level_timing_allowed sees it; for a reaction, as if
# the bot had already paused (pausing is part of casting it).
func _timing_ok(p: Node2D, spell: String, level: int, reaction: bool) -> bool:
	if not reaction:
		return main._level_timing_allowed(p, spell, level)
	var seat: int = p.player_id
	if seat >= main._response_window_paused_by.size():
		return false
	var was: bool = main._response_window_paused_by[seat]
	main._response_window_paused_by[seat] = true
	var ok: bool = main._level_timing_allowed(p, spell, level)
	main._response_window_paused_by[seat] = was
	return ok


func _execute(p: Node2D, option: Dictionary, reaction: bool) -> bool:
	var spell: String = option["spell"]
	var level: int = option["level"]
	# Burn first (highest index first, so the others don't shift).
	var burns: Array = option.get("burns", []).duplicate()
	burns.sort()
	burns.reverse()
	for idx in burns:
		if idx < p.spell_hand.size():
			var burned: String = p.spell_hand[idx]
			var color: String = SpellData.SPELLS.get(burned, {}).get("color", "")
			main._burn_spell_for_attunement(p, idx, burned, color)
			main._log("%s burned %s for +1 %s Attunement." % [main.PLAYER_NAMES[p.player_id], burned, color.capitalize().replace("_", " ")])
	var hand_index: int = p.spell_hand.find(spell)
	if hand_index == -1:
		return false
	return await main._ai_cast_spell(p, hand_index, level, option, reaction)


func _explain(p: Node2D, text: String) -> void:
	main._log("  (%s's reasoning: %s)" % [main.PLAYER_NAMES[p.player_id], text], Color(0.45, 0.45, 0.5))


# ============================================================================
# Card worth (for discarding, buying, burning, giving away)
# ============================================================================

func card_worth(p: Node2D, spell: String) -> float:
	var held: float = HELD_WORTH.get(spell, CARD_WORTH)
	var info: Dictionary = SpellData.SPELLS.get(spell, {})
	var attune: int = main._color_attunement(p, info.get("color", "")) + 1
	var best: float = 0.0
	for level in info.get("levels", {}).keys():
		if level > attune:
			continue
		var ev: Dictionary = evaluate(p, spell, level, "worth")
		if not ev.is_empty():
			best = maxf(best, float(ev.get("value", 0.0)))
	return maxf(held, best * 0.8)


# ============================================================================
# The model of the board: what money, squares and properties are worth
# ============================================================================

func _info(i: int) -> Dictionary:
	return main.board.get_space_info(i)


func _space(i: int) -> Node2D:
	return main.board.spaces[i]


func _total_spaces() -> int:
	return main.board.TOTAL_SPACES


func _opponents(p: Node2D, targetable_only: bool = true) -> Array:
	var out: Array = []
	for o in main.players:
		if o == p or o.is_bankrupt:
			continue
		if targetable_only and not _targetable(p, o.player_id):
			continue
		out.append(o)
	return out


func _targetable(p: Node2D, target_id: int) -> bool:
	if main.has_method("_can_target_player"):
		return main._can_target_player(p, target_id)
	return true


func _prop_targetable(p: Node2D, i: int) -> bool:
	if main.has_method("_can_target_property"):
		return main._can_target_property(p, i)
	return true


func net_worth(o: Node2D) -> float:
	var w: float = float(o.money)
	for i in o.owned_property_indices:
		var info: Dictionary = _info(i)
		var price: float = float(info.get("price", 0))
		w += price * (0.5 if _space(i).is_mortgaged else 1.0)
		w += _space(i).house_count * float(main.board.HOUSE_COSTS_BY_COLOR.get(info.get("color", ""), 0))
	return w


# What the bot could squeeze out of `o` if it had to: cash, mortgages, and
# houses sold at half price.
func _liquid(o: Node2D) -> float:
	var total: float = float(o.money)
	for i in o.owned_property_indices:
		var info: Dictionary = _info(i)
		if not _space(i).is_mortgaged:
			total += float(main._mortgage_value(int(info.get("price", 0))))
		total += _space(i).house_count * float(main.board.HOUSE_COSTS_BY_COLOR.get(info.get("color", ""), 0)) * 0.5
	return total


func _leader(p: Node2D) -> Node2D:
	var best: Node2D = null
	for o in _opponents(p, false):
		if best == null or net_worth(o) > net_worth(best):
			best = o
	return best


# How much the bot cares about `o` losing a dollar, relative to gaining one
# itself: split across the opponents still in the game (hurting one of three
# helps less than hurting your only rival), more for whoever's leading, less
# for someone already far behind.
func _harm_weight(p: Node2D, o: Node2D) -> float:
	if o == null or o == p:
		return 0.0
	var opps: Array = _opponents(p, false)
	if opps.is_empty():
		return 0.0
	var w: float = 1.0 / opps.size()
	if o == _leader(p):
		w *= 1.5
	elif net_worth(o) < 0.5 * net_worth(p):
		w *= 0.6
	return w


# Worth to p of `o` paying p `amount` (capped at what o could actually raise).
func _pay_value(p: Node2D, o: Node2D, amount: float) -> float:
	if amount <= 0.0 or o == null:
		return 0.0
	var paid: float = minf(amount, _liquid(o))
	return paid * (1.0 + _harm_weight(p, o))


# --- Property worth ---------------------------------------------------------
# A color group is worth more than the sum of its parts: partial sets get a
# modest bump, a complete set (where rent doubles and houses can go up) is
# worth 2.5x its price. Railroads and utilities scale with how many you have.

func _group_worth(color: String, owned: Array) -> float:
	var k: int = owned.size()
	if k == 0:
		return 0.0
	var total: float = 0.0
	for i in owned:
		total += float(_info(i).get("price", 0))
	var n: int = main.board.get_color_group(color).size()
	var mult: float = 1.0
	match color:
		"railroad":
			mult = [1.0, 1.0, 1.3, 1.7, 2.2, 2.4][mini(k, 5)]
		"utility":
			mult = 1.0 if k < 2 else 1.4
		_:
			if k >= n:
				mult = 2.5
			elif n > 1:
				mult = 1.0 + 0.6 * float(k - 1) / float(n - 1)
	return total * mult


func _owned_in_group(pid: int, color: String) -> Array:
	var out: Array = []
	for i in main.board.get_color_group(color):
		if _space(i).owner_id == pid:
			out.append(i)
	return out


# Worth `pid` gains by getting property i.
func prop_gain(pid: int, i: int) -> float:
	var color: String = _info(i).get("color", "")
	var now: Array = _owned_in_group(pid, color)
	var after: Array = now.duplicate()
	if not after.has(i):
		after.append(i)
	return _group_worth(color, after) - _group_worth(color, now)


# Worth `pid` loses by giving property i up.
func prop_loss(pid: int, i: int) -> float:
	var color: String = _info(i).get("color", "")
	var now: Array = _owned_in_group(pid, color)
	var after: Array = now.duplicate()
	after.erase(i)
	return _group_worth(color, now) - _group_worth(color, after)


# Net worth to p of buying unowned property i for `price`: the property
# (with its set bonus), minus the money, plus a little for the rent it'll
# collect, plus a bonus for stopping an opponent from completing that set.
func buy_value(p: Node2D, i: int, price: int = -1) -> float:
	var info: Dictionary = _info(i)
	var list_price: float = float(info.get("price", 0))
	var cost: float = list_price if price < 0 else float(price)
	var v: float = prop_gain(p.player_id, i) - cost + 0.3 * list_price
	var color: String = info.get("color", "")
	var n: int = main.board.get_color_group(color).size()
	if n > 1:
		for o in _opponents(p, false):
			if _owned_in_group(o.player_id, color).size() == n - 1:
				v += 0.6 * list_price
				break
	return v


func _can_spend(p: Node2D, cost: float) -> bool:
	return float(p.money) - cost >= float(CASH_RESERVE)


# --- Squares and moves ------------------------------------------------------

# Being in Jail is good once the board is dangerous (you skip paying rent),
# bad before that (you can't buy anything).
func jail_value(p: Node2D) -> float:
	var danger: int = 0
	for i in _total_spaces():
		var s: Node2D = _space(i)
		if s.owner_id != -1 and s.owner_id != p.player_id:
			danger = maxi(danger, main._hypothetical_rent(i))
	return 40.0 if danger >= 300 else -50.0


# What landing on square i is worth to p right now.
func space_value(p: Node2D, i: int) -> float:
	var info: Dictionary = _info(i)
	var s: Node2D = _space(i)
	match info.get("type", ""):
		"property":
			if s.owner_id == -1:
				var price: int = int(info.get("price", 0))
				if p.money >= price:
					return maxf(0.0, buy_value(p, i))
				return 0.0
			if s.owner_id == p.player_id or main.players[s.owner_id].is_bankrupt:
				return 0.0
			var rent: float = float(main._hypothetical_rent(i))
			return -rent * (1.0 + _harm_weight(p, main.players[s.owner_id]))
		"tax":
			if s.owner_id == p.player_id:
				return 0.0
			var tax: float = float(info.get("value", 0))
			if s.owner_id != -1:
				return -tax * (1.0 + _harm_weight(p, main.players[s.owner_id]))
			return -tax
		"go_to_jail":
			return jail_value(p)
		"free_parking":
			return float(main.free_parking_amount)
		"magic_forest":
			return 50.0
		"spell_shop":
			return 20.0 if p.money > 250 else 0.0
	return 0.0


# What moving `steps` forward from where p is now is worth: the square it
# ends on, plus $200 for each time it passes Go.
func move_value(p: Node2D, steps: int) -> float:
	if steps <= 0:
		return 0.0
	var start: int = p.current_space
	var dest: int = (start + steps) % _total_spaces()
	var v: float = space_value(p, dest)
	v += 200.0 * floori(float(start + steps) / _total_spaces())
	return v


# The steps p's next roll will take for dice (d1, d2), counting any
# before-rolling spell already cast this turn (multiplier, then flat bonus).
func _planned_steps(p: Node2D, d1: int, d2: int, extra_mult: int = 1, extra_bonus: int = 0) -> int:
	var roll: int = d1 + d2
	var mult = p.get("next_roll_multiplier")
	if mult != null and int(mult) != 1:
		roll *= int(mult)
	roll *= extra_mult
	var bonus = p.get("next_roll_bonus")
	if bonus != null:
		roll += int(bonus)
	return roll + extra_bonus


# Average move_value over all 36 dice outcomes.
func roll_ev(p: Node2D, extra_mult: int = 1, extra_bonus: int = 0) -> float:
	var total: float = 0.0
	for d1 in range(1, 7):
		for d2 in range(1, 7):
			total += move_value(p, _planned_steps(p, d1, d2, extra_mult, extra_bonus))
	return total / 36.0


# A before-rolling movement spell is pointless in Jail (the roll is a jail
# roll) or once Siren's Song has already picked the destination.
func _pre_roll_movement_ok(p: Node2D) -> bool:
	if p.in_jail:
		return false
	return not _flag(p, "siren_song_active")


# A player field that only some branches have (false when it's missing).
func _flag(o: Object, field: String) -> bool:
	var v = o.get(field)
	return v != null and bool(v)


func _current_steps(roller: Node2D) -> int:
	return int(main._roll_walk_steps(roller))


func _current_landing(roller: Node2D) -> int:
	return (roller.current_space + _current_steps(roller)) % _total_spaces()


# How much a change to the bot's own roll (from `steps` to `new_steps`) is
# worth.
func _move_gain(p: Node2D, new_steps: int) -> float:
	return move_value(p, new_steps) - move_value(p, _current_steps(p))


# Rent on property i if it had `bonus` more houses (Price Gouging).
func _rent_with_bonus_houses(i: int, bonus: int) -> float:
	var info: Dictionary = _info(i)
	var rents: Array = info.get("rents", [])
	if rents.size() < 6:
		return float(main._hypothetical_rent(i))
	return float(rents[mini(5, _space(i).house_count + bonus)])


# --- Targets ---------------------------------------------------------------

# The opponent who would pay p the most worth for `amount_of` (a Callable
# o -> dollars), or null.
func _best_payer(p: Node2D, amount_of: Callable) -> Dictionary:
	var best: Dictionary = {}
	for o in _opponents(p):
		var amt: float = float(amount_of.call(o))
		var v: float = _pay_value(p, o, amt)
		if v > 0.0 and (best.is_empty() or v > best["value"]):
			best = {"target": o, "value": v, "amount": minf(amt, _liquid(o))}
	return best


func _colors_owned(p: Node2D) -> int:
	var colors: Dictionary = {}
	for i in p.owned_property_indices:
		var c: String = _info(i).get("color", "")
		if c in main.REAL_PROPERTY_COLORS:
			colors[c] = true
	return colors.size()


func _properties() -> Array:
	var out: Array = []
	for i in _total_spaces():
		if _info(i).get("type", "") == "property":
			out.append(i)
	return out


func _richest_opponent(p: Node2D) -> Node2D:
	var best: Node2D = null
	for o in _opponents(p, false):
		if best == null or o.money > best.money:
			best = o
	return best


# Probability that a 2d6 roll is exactly d (2..12).
func _roll_prob(d: int) -> float:
	if d < 2 or d > 12:
		return 0.0
	return float(6 - absi(7 - d)) / 36.0


# ============================================================================
# Scoring each spell
#
# evaluate() returns {} when the spell has no good use right now, else:
#   "value":   dollars it's worth to cast now
#   "cash":    money it brings in right away (used in Raise Money mode)
#   "answers": {prompt kind -> [answers in order]} for the cast's prompts
#   "why":     one line for the game log
#   "returns": true for cards that come back to the hand
# phase: "pre_roll" / "post_roll" / "debt" (own turn), "roll_self" (own roll
# in flight), "roll_opp" (an opponent's roll), "spell" (a spell on the
# stack), "worth" (just rating the card).
# ============================================================================

func evaluate(p: Node2D, spell: String, level: int, phase: String) -> Dictionary:
	var li: Dictionary = SpellData.SPELLS[spell]["levels"][level]
	var amount: float = float(li.get("amount", 0))
	var turn: bool = phase in ["pre_roll", "post_roll", "debt", "worth"]
	var pre: bool = phase == "pre_roll" or phase == "worth"
	match spell:
		# --- An opponent pays you --------------------------------------
		"T1 Burn Spell", "The Cult of Terminus", "Critical Hit":
			if spell == "The Cult of Terminus" and level == 4:
				return {"value": 700.0, "why": "owns every railroad: summons Terminus."} if turn else {}
			if not turn:
				return {}
			var amt: float = amount
			if spell == "Critical Hit" and _flag(p, "rolled_doubles_this_turn"):
				amt += 100.0
			return _money_from_opponent(p, func(_o): return amt, "{o} pays ${amt}")
		"Taxes":
			if not turn:
				return {}
			var divisor: int = int(li.get("divisor", 5))
			return _money_from_opponent(p, func(o): return float(o.money / divisor), "{o} pays ${amt}, 1/%d of their money" % divisor)
		"Migraine":
			if not turn:
				return {}
			var per: float = float(li.get("pay_per_card", 0))
			return _money_from_opponent(p, func(o): return per * o.spell_hand.size(), "{o} pays ${amt}, $%d per card in their hand" % int(per))
		"Far-Reaching Empire":
			if not turn:
				return {}
			var total: float = amount * _colors_owned(p)
			return _money_from_opponent(p, func(_o): return total, "{o} pays ${amt} -- it owns %d colors" % _colors_owned(p))
		"Sanity Grinding":
			if not turn:
				return {}
			var r: Dictionary = _money_from_opponent(p, func(_o): return amount, "{o} pays ${amt}, and the card comes back")
			if not r.is_empty():
				r["returns"] = true
			return r
		"Smite":
			if not turn:
				return {}
			var o: Node2D = _richest_opponent(p)
			var v: float = _pay_value(p, o, amount)
			if v <= 0.0:
				return {}
			return {"value": v, "cash": minf(amount, _liquid(o)), "why": "%s has the most money." % main.PLAYER_NAMES[o.player_id]}
		"Sinkhole":
			if not turn:
				return {}
			var best: Dictionary = {}
			for o in _opponents(p):
				var v: float = 0.0
				var cash: float = 0.0
				for q in _opponents(p, false):
					if q.current_space == o.current_space:
						v += _pay_value(p, q, amount)
						cash += minf(amount, _liquid(q))
				if best.is_empty() or v > best["value"]:
					best = {"value": v, "cash": cash, "answers": {"pick": [o.player_id]}, "why": "hits everyone on %s's square." % main.PLAYER_NAMES[o.player_id]}
			return best
		"Line of Fire":
			if not turn:
				return {}
			var best_side: int = -1
			var best_v: float = 0.0
			var best_cash: float = 0.0
			for side in 4:
				var v: float = 0.0
				var cash: float = 0.0
				for i in _properties():
					if i / main.board.SPACES_PER_SIDE != side:
						continue
					var owner: int = _space(i).owner_id
					if owner != -1 and owner != p.player_id and not main.players[owner].is_bankrupt:
						v += _pay_value(p, main.players[owner], amount)
						cash += amount
				if v > best_v:
					best_v = v
					best_side = side
					best_cash = cash
			if best_side == -1:
				return {}
			return {"value": best_v, "cash": best_cash, "answers": {"pick": [best_side]}, "why": "the %s side has the most opponent properties." % main.BOARD_SIDE_NAMES[best_side]}
		"Penance":
			if not turn:
				return {}
			var v: float = 0.0
			var cash: float = 0.0
			for id in main._jailed_opponent_ids(p):
				v += _pay_value(p, main.players[id], amount)
				cash += amount
			return {"value": v, "cash": cash, "why": "opponents are in Jail."} if v > 0.0 else {}
		"Threaten":
			if not turn:
				return {}
			# They choose: pay, or hand the property over. Aim at a property
			# that would help the bot most, in case they give it up.
			var best: Dictionary = {}
			for i in _properties():
				var s: Node2D = _space(i)
				if s.owner_id == -1 or s.owner_id == p.player_id or s.house_count > 0 or not _prop_targetable(p, i):
					continue
				var o: Node2D = main.players[s.owner_id]
				var v: float = maxf(_pay_value(p, o, amount), 0.0) + 0.2 * prop_gain(p.player_id, i)
				if best.is_empty() or v > best["value"]:
					best = {"value": v, "cash": minf(amount, float(o.money)), "answers": {"board": [i]}, "why": "%s pays $%d or gives up %s." % [main.PLAYER_NAMES[o.player_id], int(amount), main._property_name(i)]}
			return best
		"Knockout Punch":
			var r: Dictionary = {}
			if turn:
				r = _money_from_opponent(p, func(_o): return amount, "{o} pays ${amt} and goes to Jail")
				if not r.is_empty():
					var o: Node2D = main.players[r["answers"]["pick"][0]]
					r["value"] += -jail_value(o) * _harm_weight(p, o)
				return r
			if phase == "roll_opp":
				var roller: Node2D = main.players[main.current_player]
				if not _targetable(p, roller.player_id):
					return {}
				var v: float = _pay_value(p, roller, amount) + _cancel_roll_value(p, roller) - jail_value(roller) * _harm_weight(p, roller)
				return {"value": v, "cash": minf(amount, _liquid(roller)), "answers": {"pick": [roller.player_id]}, "why": "stops %s's roll and charges them $%d." % [main.PLAYER_NAMES[roller.player_id], int(amount)]}
			return {}
		"Spiteful Destruction":
			if not turn:
				return {}
			var best: Dictionary = {}
			for o in _opponents(p):
				var v: float = minf(amount, _liquid(o)) * _harm_weight(p, o) - 100.0
				if best.is_empty() or v > best["value"]:
					best = {"value": v, "cash": -100.0, "answers": {"pick": [o.player_id]}, "why": "%s pays $%d into Free Parking." % [main.PLAYER_NAMES[o.player_id], int(amount)]}
			return best
		"Bomb Shelter":
			if not turn:
				return {}
			var v: float = 0.0
			for o in _opponents(p, false):
				if not o.in_jail:
					v += minf(amount, _liquid(o)) * _harm_weight(p, o)
			if not p.in_jail:
				v -= amount
			return {"value": v, "cash": 0.0 if p.in_jail else -amount, "why": "everyone outside Jail pays (the bot %s)." % ("is in Jail" if p.in_jail else "pays too")}
		"Art of the Deal":
			if not turn:
				return {}
			var give: int = _cheapest_other_card(p, spell)
			if give == -1:
				return {}
			var give_worth: float = card_worth(p, p.spell_hand[give])
			var r: Dictionary = _money_from_opponent(p, func(_o): return amount, "{o} pays ${amt} for one of its cards")
			if r.is_empty():
				return {}
			var o: Node2D = main.players[r["answers"]["pick"][0]]
			r["value"] -= give_worth * (1.0 + _harm_weight(p, o))
			r["answers"]["pick"].append(give)
			r["why"] += " (gives away %s)" % p.spell_hand[give]
			return r
		# --- Money from the bank / Free Parking ---------------------------
		"Break Bread":
			if not turn:
				return {}
			var opps: Array = _opponents(p)
			if opps.is_empty():
				return {}
			var avg: float = 0.0
			for o in opps:
				avg += _harm_weight(p, o)
			avg /= opps.size()
			return {"value": amount * (1.0 - avg), "cash": amount, "why": "both gain $%d, the bot gains more from it." % int(amount)}
		"Gemstone Mine":
			return {"value": amount * 0.8, "cash": amount, "why": "+$%d (Free Parking grows too)." % int(amount)} if turn else {}
		"Steal From the Future":
			if not turn:
				return {}
			var take: float = minf(amount, float(main.free_parking_amount))
			return {"value": take * 0.9, "cash": take, "why": "takes $%d from Free Parking." % int(take)} if take > 0.0 else {}
		"Burn Bright":
			if not turn:
				return {}
			var rot: float = float(li.get("rotations", 5))
			return {"value": amount - 20.0 * rot, "cash": amount, "why": "$500 now, $20 a turn for %d turns." % int(rot)}
		"Divination":
			if not turn or p.spell_hand.size() >= 6:
				return {}
			var n: float = float(li.get("draw_count", 1))
			return {"value": n * 55.0, "why": "draws %d card%s." % [int(n), "" if n == 1 else "s"]}
		"Snatch Purse":
			if not turn:
				return {}
			var count: int = int(li.get("count", 1))
			var best: Dictionary = {}
			for o in _opponents(p):
				var take: int = mini(count, o.spell_hand.size())
				var v: float = take * 70.0 * (1.0 + _harm_weight(p, o))
				if take > 0 and (best.is_empty() or v > best["value"]):
					best = {"value": v, "answers": {"pick": [o.player_id]}, "why": "%s holds %d cards." % [main.PLAYER_NAMES[o.player_id], o.spell_hand.size()]}
			return best
		# --- Properties and houses --------------------------------------
		"Impossible Architecture":
			if not turn:
				return {}
			return _eval_build_houses(p, int(li.get("houses", 1)), true)
		"Promised Land":
			if not turn:
				return {}
			return _eval_promised_land(p, level)
		"Annexation":
			if not turn:
				return {}
			var k: int = int(li.get("owned_in_group", 0))
			var best: Dictionary = {}
			for i in _properties():
				var s: Node2D = _space(i)
				if s.owner_id == -1 or s.owner_id == p.player_id or s.house_count > 0 or not _prop_targetable(p, i):
					continue
				var color: String = _info(i).get("color", "")
				if _owned_in_group(p.player_id, color).size() != k:
					continue
				var price: float = float(_info(i).get("price", 0))
				if not _can_spend(p, price):
					continue
				var o: Node2D = main.players[s.owner_id]
				var v: float = prop_gain(p.player_id, i) - price + 0.3 * price + prop_loss(o.player_id, i) * _harm_weight(p, o)
				if best.is_empty() or v > best["value"]:
					best = {"value": v, "cash": -price, "answers": {"board": [i]}, "why": "buys %s from %s." % [main._property_name(i), main.PLAYER_NAMES[o.player_id]]}
			return best
		"Offer You Can't Refuse":
			if not turn:
				return {}
			return _eval_offer(p, int(li.get("give_count", 1)), bool(li.get("min_value", false)))
		"Market Manipulation":
			if not turn:
				return {}
			var best: Dictionary = {}
			for i in main._market_manipulation_targets(p, level):
				var o: Node2D = main.players[_space(i).owner_id]
				var v: float = prop_gain(p.player_id, i) + prop_loss(o.player_id, i) * _harm_weight(p, o)
				if best.is_empty() or v > best["value"]:
					best = {"value": v, "answers": {"board": [i]}, "why": "takes %s from %s for free." % [main._property_name(i), main.PLAYER_NAMES[o.player_id]]}
			return best
		"Contested Battlefield":
			if not turn:
				return {}
			var best: Dictionary = {}
			for i in _properties():
				if not main._contested_battlefield_ok(p, i):
					continue
				var o: Node2D = main.players[_space(i).owner_id]
				var v: float = (prop_gain(p.player_id, i) + prop_loss(o.player_id, i) * _harm_weight(p, o)) * 0.5
				if best.is_empty() or v > best["value"]:
					best = {"value": v, "answers": {"board": [i]}, "why": "borrows %s from %s." % [main._property_name(i), main.PLAYER_NAMES[o.player_id]]}
			return best
		"Royal Aid":
			if not turn:
				return {}
			var mortgaged: Array = []
			for i in p.owned_property_indices:
				if _space(i).is_mortgaged:
					mortgaged.append(i)
			if mortgaged.is_empty():
				return {}
			mortgaged.sort_custom(func(a, b): return int(_info(a).get("price", 0)) > int(_info(b).get("price", 0)))
			var count: int = int(li.get("count", 1))
			var v: float = 0.0
			var picks: Array = []
			for k in mini(count, mortgaged.size()):
				picks.append(mortgaged[k])
				v += float(main._unmortgage_value(int(_info(mortgaged[k]).get("price", 0))))
			return {"value": v, "answers": {"board": picks}, "why": "unmortgages $%d of property for free." % int(v)}
		"Reclaimed by Nature":
			if not turn:
				return {}
			var scored: Array = []
			for i in _properties():
				var s: Node2D = _space(i)
				if not s.is_mortgaged or s.owner_id == -1 or s.owner_id == p.player_id or not _prop_targetable(p, i):
					continue
				var o: Node2D = main.players[s.owner_id]
				scored.append({"i": i, "v": prop_loss(o.player_id, i) * _harm_weight(p, o) + 0.2 * float(_info(i).get("price", 0))})
			if scored.is_empty():
				return {}
			scored.sort_custom(func(a, b): return a["v"] > b["v"])
			var count: int = int(li.get("count", 1))
			var v: float = 0.0
			var picks: Array = []
			for k in mini(count, scored.size()):
				picks.append(scored[k]["i"])
				v += scored[k]["v"]
			return {"value": v, "answers": {"board": picks}, "why": "returns opponents' mortgaged property to the bank."}
		"Burn to the Ground":
			if not turn:
				return {}
			var destroy: int = int(li.get("houses", 1))
			var best: Dictionary = {}
			for i in _properties():
				var s: Node2D = _space(i)
				if s.house_count == 0 or s.owner_id == -1 or s.owner_id == p.player_id or not _prop_targetable(p, i):
					continue
				var o: Node2D = main.players[s.owner_id]
				var gone: int = mini(destroy, s.house_count)
				var rents: Array = _info(i).get("rents", [])
				var rent_drop: float = 0.0
				if rents.size() >= 6:
					rent_drop = float(rents[s.house_count]) - float(rents[s.house_count - gone])
				var house_cost: float = float(main.board.HOUSE_COSTS_BY_COLOR.get(_info(i).get("color", ""), 0))
				var v: float = rent_drop * LANDINGS_PER_OPPONENT + gone * house_cost * _harm_weight(p, o)
				if best.is_empty() or v > best["value"]:
					best = {"value": v, "answers": {"board": [i]}, "why": "knocks %d house%s off %s." % [gone, "" if gone == 1 else "s", main._property_name(i)]}
			return best
		"Tax Haven":
			return {"value": 150.0 if level == 1 else 250.0, "why": "opponents pay the bot instead of Free Parking."} if turn else {}
		# --- Movement before rolling -------------------------------------
		"Unstable Portal":
			if not pre or not _pre_roll_movement_ok(p):
				return {}
			var m: int = int(li.get("multiplier", 3))
			var gain: float = roll_ev(p, m) - roll_ev(p)
			return {"value": gain, "why": "multiplying the roll by %d moves it somewhere better on average (+$%d)." % [m, int(gain)]}
		"Hasty Exit":
			if level == 1:
				if not pre or not _pre_roll_movement_ok(p):
					return {}
				var gain: float = roll_ev(p, 1, 10) - roll_ev(p)
				return {"value": gain, "why": "+10 to the roll averages out better (+$%d)." % int(gain)}
			if phase == "roll_self":
				var g: float = _move_gain(p, _current_steps(p) + 10)
				return {"value": g, "why": "+10 lands somewhere better (+$%d)." % int(g)}
			return {}
		"Step Forward":
			if not pre or not _pre_roll_movement_ok(p):
				return {}
			var b: int = int(li.get("roll_bonus", 1))
			var gain: float = roll_ev(p, 1, b) - roll_ev(p)
			return {"value": gain, "returns": true, "why": "+%d to the roll averages out better (and the card comes back)." % b} if gain > 0.0 else {}
		"Siren's Song":
			if not pre or not _pre_roll_movement_ok(p):
				return {}
			var worst: float = 0.0
			for i in main._siren_song_candidates(p):
				worst = minf(worst, space_value(p, i))
			return {"value": amount + worst, "cash": amount, "why": "+$%d is worth more than the square it lands on costs." % int(amount)}
		"Unclaimed Wilderness":
			if not pre:
				return {}
			var values: Array = []
			for i in main._unowned_property_indices():
				var price: float = float(_info(i).get("price", 0))
				if _can_spend(p, price):
					values.append(buy_value(p, i))
			if values.is_empty():
				return {}
			values.sort()
			values.reverse()
			var count: int = mini(int(li.get("count", 1)), values.size())
			var avg: float = 0.0
			for v in values:
				avg += maxf(0.0, v)
			avg /= values.size()
			# The best of `count` random picks, roughly.
			var v: float = avg * (1.0 + 0.5 * (count - 1))
			return {"value": v, "why": "a chance at an unowned property it wants."}
		"Pilgrimage":
			if not pre or not _pre_roll_movement_ok(p):
				return {}
			var count: int = int(li.get("count", 1))
			var scored: Array = []
			for i in main._unowned_property_indices():
				var d: int = posmod(i - p.current_space, _total_spaces())
				if d < 1 or d > 12:
					continue
				var pass_prob: float = 0.0
				for r in range(d, 13):
					pass_prob += _roll_prob(r)
				if not _can_spend(p, float(_info(i).get("price", 0))):
					continue
				scored.append({"i": i, "v": pass_prob * maxf(0.0, buy_value(p, i)), "color": _info(i).get("color", "")})
			if scored.is_empty():
				return {}
			scored.sort_custom(func(a, b): return a["v"] > b["v"])
			var picks: Array = []
			var colors: Dictionary = {}
			var v: float = 0.0
			for e in scored:
				if picks.size() >= count:
					break
				if li.get("distinct_colors", false) and colors.has(e["color"]):
					continue
				picks.append(e["i"])
				colors[e["color"]] = true
				v += e["v"]
			return {"value": v, "answers": {"board": picks}, "why": "may buy unowned property it's likely to pass."}
		"Master Plan":
			if not pre:
				return {}
			return _eval_master_plan(p, level)
		# --- Changing your own roll (in flight) --------------------------
		"Adrenaline", "T3 Escape Spell":
			if phase != "roll_self":
				return {}
			var b: int = int(li.get("roll_bonus", 1))
			var g: float = _move_gain(p, _current_steps(p) + b)
			return {"value": g, "why": "+%d lands somewhere better (+$%d)." % [b, int(g)]}
		"Rocket Boost":
			if phase != "roll_self":
				return {}
			var b: int = int(li.get("roll_bonus", 4))
			var g: float = _move_gain(p, _current_steps(p) + b) - float(li.get("extra_cost", 100))
			return {"value": g, "why": "+%d dodges a bad square, worth the $100." % b}
		"Divine Protection":
			if phase != "roll_self":
				return {}
			if level == 3:
				var g1: float = _move_gain(p, _current_steps(p) - 1)
				var g2: float = _move_gain(p, _current_steps(p) - 2)
				var pick: int = 1 if g1 >= g2 else 2
				return {"value": maxf(g1, g2), "answers": {"pick": [pick]}, "why": "stepping back %d avoids a bad square." % pick}
			var pen: int = int(li.get("roll_penalty", 1))
			var g: float = _move_gain(p, _current_steps(p) - pen)
			return {"value": g, "why": "stepping back %d avoids an opponent's rent." % pen}
		"Escape Into Custody":
			if phase != "roll_self":
				return {}
			var pen: int = int(li.get("roll_penalty", 1))
			var g: float = _move_gain(p, _current_steps(p) - pen)
			return {"value": g, "why": "-%d lands somewhere better." % pen}
		"Escape Plan":
			if phase != "roll_self":
				return {}
			var cond: Callable = main._escape_plan_condition(p, level)
			var steps: int = _current_steps(p)
			for k in range(1, _total_spaces() + 1):
				if cond.call((p.current_space + steps + k) % _total_spaces()):
					var g: float = _move_gain(p, steps + k)
					return {"value": g, "why": "moves on %d to a better square (+$%d)." % [k, int(g)]}
			return {}
		"King's Escape Tunnel":
			if phase != "roll_self":
				return {}
			var landing: int = _current_landing(p)
			var extra: int = posmod(20 - landing, _total_spaces())
			var g: float = _move_gain(p, _current_steps(p) + extra)
			return {"value": g, "why": "goes to Free Parking ($%d) instead." % main.free_parking_amount}
		"Veto":
			if phase != "roll_self":
				return {}
			var d1: int = maxi(0, main._die1)
			var d2: int = maxi(0, main._die2)
			var cut: int = d1 + d2
			if level == 2:
				cut = mini(d1, d2)
			elif level == 3:
				cut = maxi(d1, d2)
			var g: float = _move_gain(p, _current_steps(p) - cut)
			return {"value": g, "why": "zeroing dice keeps it off a bad square."}
		"Dodge":
			if phase != "roll_self":
				return {}
			return _eval_dodge(p, level)
		"Go For the Kill":
			if phase != "roll_self":
				return {}
			var steps: int = _current_steps(p)
			var v: float = 0.0
			for o in _opponents(p, false):
				var d: int = posmod(o.current_space - p.current_space, _total_spaces())
				if d > 0 and d < steps:
					v += _pay_value(p, o, amount)
			return {"value": v, "why": "it's about to pass opponents."} if v > 0.0 else {}
		# --- Money-saving shields ---------------------------------------
		"Counterfeit Currency", "Misplaced Payment":
			var owed: Dictionary = _about_to_pay(p, phase)
			if owed.is_empty():
				return {}
			var o: Node2D = owed["to"]
			var amt: float = owed["amount"]
			if spell == "Counterfeit Currency":
				var saved: float = minf(float(li.get("reduction", 200)), amt)
				return {"value": saved * (1.0 + _harm_weight(p, o)), "why": "cuts a $%d payment to %s." % [int(amt), main.PLAYER_NAMES[o.player_id]]}
			var pct: float = float(li.get("percent", 100)) / 100.0
			return {"value": amt * pct * _harm_weight(p, o), "why": "sends a $%d payment to Free Parking instead of %s." % [int(amt), main.PLAYER_NAMES[o.player_id]]}
		"Haggling":
			var pct: float = float(li.get("discount_percent", 50)) / 100.0
			if phase == "roll_self":
				var landing: int = _current_landing(p)
				var info: Dictionary = _info(landing)
				if info.get("type", "") == "property" and _space(landing).owner_id == -1 and space_value(p, landing) > 0.0:
					var price: float = float(info.get("price", 0))
					var v: float = price * pct + (price if li.get("bank_bonus", false) else 0.0)
					return {"value": v, "why": "about to buy %s." % main._property_name(landing)}
				return {}
			if phase == "post_roll":
				var house: float = _next_house_cost(p)
				if house > 0.0:
					return {"value": house * pct + (house if li.get("bank_bonus", false) else 0.0), "why": "about to build a house."}
			return {}
		# --- An opponent's roll -------------------------------------------
		"Price Gouging":
			if phase != "roll_opp":
				return {}
			var roller: Node2D = main.players[main.current_player]
			var landing: int = _current_landing(roller)
			if _space(landing).owner_id != p.player_id or _space(landing).is_mortgaged:
				return {}
			var extra: float = _rent_with_bonus_houses(landing, int(li.get("bonus_houses", 1))) - float(main._hypothetical_rent(landing))
			return {"value": extra * (1.0 + _harm_weight(p, roller)), "why": "%s is about to land on %s." % [main.PLAYER_NAMES[roller.player_id], main._property_name(landing)]} if extra > 0.0 else {}
		"Seize the Opportunity":
			if phase != "roll_opp":
				return {}
			var roller: Node2D = main.players[main.current_player]
			var d1: int = maxi(0, main._die1)
			var d2: int = maxi(0, main._die2)
			var base: int = [0, mini(d1, d2), maxi(d1, d2), d1 + d2][level]
			return {"value": _pay_value(p, roller, base * 30.0), "cash": base * 30.0, "why": "%s rolled %d + %d." % [main.PLAYER_NAMES[roller.player_id], d1, d2]}
		"Bribe the Guards":
			if level == 1:
				if not turn or not p.in_jail or jail_value(p) > 0.0:
					return {}
				return {"value": 50.0 - jail_value(p), "answers": {"pick": [p.player_id]}, "why": "gets out of Jail early."}
			if phase == "roll_opp":
				var roller: Node2D = main.players[main.current_player]
				if roller.in_jail or not _targetable(p, roller.player_id):
					return {}
				var v: float = _cancel_roll_value(p, roller) - jail_value(roller) * _harm_weight(p, roller)
				return {"value": v, "answers": {"pick": [roller.player_id]}, "why": "jails %s before a good landing." % main.PLAYER_NAMES[roller.player_id]}
			return {}
		# --- Jail -----------------------------------------------------------
		"Cramped Cell":
			if not turn:
				return {}
			var turns: int = int(li.get("jail_turns", 2))
			var expected: float = 0.0
			for k in turns:
				expected += pow(5.0 / 6.0, k)
			var best: Dictionary = {}
			for o in _opponents(p):
				var v: float = _pay_value(p, o, 50.0 * expected) - jail_value(o) * _harm_weight(p, o)
				if best.is_empty() or v > best["value"]:
					best = {"value": v, "answers": {"pick": [o.player_id]}, "why": "%s pays $50 a turn while stuck in Jail." % main.PLAYER_NAMES[o.player_id]}
			return best
		# --- Attunement --------------------------------------------------
		"Manastone":
			if not turn or phase == "worth":
				return {}
			var amt: int = int(li.get("amount", 1))
			var best: Dictionary = {}
			for color in main.ATTUNABLE_COLORS:
				var gain: float = _upgrade_gain(p, {color: amt}, 0, spell)
				if gain > 0.0 and (best.is_empty() or gain > best["value"]):
					best = {"value": gain, "answers": {"pick": [main.ATTUNABLE_COLORS.find(color)]}, "why": "+%d %s Attunement lets a better spell go off." % [amt, color.capitalize().replace("_", " ")]}
			return best
		"Overflowing Bounty":
			if not turn or phase == "worth":
				return {}
			var gain: float = _upgrade_gain(p, {}, int(li.get("amount", 1)), spell)
			return {"value": gain, "why": "the extra Attunement lets a better spell go off."} if gain > 0.0 else {}
		"Natural Magician":
			if not turn:
				return {}
			var rot: float = float(li.get("rotations", 1))
			var gain: float = 0.0 if phase == "worth" else _upgrade_gain(p, {}, 1, spell)
			return {"value": 60.0 * rot + gain, "why": "+1 Attunement and can't be targeted for %d rotation%s." % [int(rot), "" if rot == 1 else "s"]}
		# --- Lingering effects ---------------------------------------------
		"Shielded From Harm":
			if not turn:
				return {}
			return {"value": 90.0 * float(li.get("rotations", 1)), "why": "cuts rent it pays by $300 for a while."}
		"Fragile Goods":
			return {"value": amount * 0.8, "why": "extra money each time it passes Go."} if turn else {}
		"Parasite":
			if not turn:
				return {}
			var rot: float = float(li.get("rotations", 2))
			return _money_from_opponent(p, func(_o): return amount * rot, "{o} pays $%d a turn for %d turns" % [int(amount), int(rot)])
		"Anti-Magic Law":
			if not turn:
				return {}
			var triggers: int = int(li.get("triggers", 1))
			var best: Dictionary = {}
			for o in _opponents(p):
				var v: float = 70.0 * mini(triggers, o.spell_hand.size()) * (1.0 + _harm_weight(p, o))
				if v > 0.0 and (best.is_empty() or v > best["value"]):
					best = {"value": v, "answers": {"pick": [o.player_id]}, "why": "%s's next spells get countered." % main.PLAYER_NAMES[o.player_id]}
			return best
		"Lethargy", "Fated Ending":
			if not turn:
				return {}
			var o: Node2D = _leader(p)
			if o == null or not _targetable(p, o.player_id):
				return {}
			var v: float = (40.0 * float(li.get("roll_penalty", 1)) * 2.0) if spell == "Lethargy" else (50.0 if level == 1 else 110.0)
			return {"value": v * (1.0 + _harm_weight(p, o)), "answers": {"pick": [o.player_id]}, "why": "slows down the leader, %s." % main.PLAYER_NAMES[o.player_id]}
		"Word of Binding":
			if not turn:
				return {}
			return _eval_word_of_binding(p, level)
		# --- Landmarks ---------------------------------------------------------
		"Landmine", "Toll Road", "Ensnaring Roots", "Treasure Map", "Power Sink", "Outland Settlements", "Stabilized Portal":
			if not turn:
				return {}
			return _eval_landmark(p, spell, level, li)
		# --- Counters -------------------------------------------------------
		"Counterbalance", "Deny Rights", "Spell Mastery", "T2 Response Spell":
			if phase != "spell" or (spell == "T2 Response Spell" and level != 1):
				return {}
			return _eval_counter(p, spell, level)
	return {}


# --- Shared pieces -------------------------------------------------------------

func _money_from_opponent(p: Node2D, amount_of: Callable, why: String) -> Dictionary:
	var best: Dictionary = _best_payer(p, amount_of)
	if best.is_empty():
		return {}
	var o: Node2D = best["target"]
	var text: String = why.replace("{o}", main.PLAYER_NAMES[o.player_id]).replace("{amt}", str(int(best["amount"])))
	return {"value": best["value"], "cash": best["amount"], "answers": {"pick": [o.player_id]}, "why": text + "."}


func _cheapest_other_card(p: Node2D, spell: String) -> int:
	var skip: int = p.spell_hand.find(spell)
	var best: int = -1
	var best_w: float = INF
	for i in p.spell_hand.size():
		if i == skip:
			continue
		var w: float = card_worth(p, p.spell_hand[i])
		if w < best_w:
			best_w = w
			best = i
	return best


# Worth to p of an opponent's roll being cancelled: good if they were about to
# land somewhere great, bad if they were about to pay p rent.
func _cancel_roll_value(p: Node2D, roller: Node2D) -> float:
	var landing: int = _current_landing(roller)
	var v: float = space_value(roller, landing) * _harm_weight(p, roller)
	if _space(landing).owner_id == p.player_id and _info(landing).get("type", "") == "property":
		v -= float(main._hypothetical_rent(landing)) * (1.0 + _harm_weight(p, roller))
	return v


# The payment p is about to make to an opponent: its own roll landing on
# their property, or a spell on the stack charging it.
func _about_to_pay(p: Node2D, phase: String) -> Dictionary:
	if phase == "roll_self":
		var landing: int = _current_landing(p)
		var s: Node2D = _space(landing)
		if _info(landing).get("type", "") == "property" and s.owner_id != -1 and s.owner_id != p.player_id:
			var rent: float = float(main._hypothetical_rent(landing))
			if rent > 0.0:
				return {"to": main.players[s.owner_id], "amount": rent}
	elif phase == "spell":
		var entry: Dictionary = main._spell_stack.back()
		var caster: Node2D = main.players[int(entry["caster_id"])]
		if caster != p:
			var hit: float = -_spell_effect_on(p, entry)
			if hit > 0.0 and _charges_money(str(entry["spell_name"])):
				return {"to": caster, "amount": hit / (1.0 + _harm_weight(p, caster))}
	return {}


func _charges_money(spell: String) -> bool:
	return spell in ["The Cult of Terminus", "Critical Hit", "Taxes", "Migraine", "Far-Reaching Empire", "Sinkhole", "Smite", "Line of Fire", "Penance", "Knockout Punch", "Sanity Grinding", "Threaten", "Art of the Deal", "T1 Burn Spell"]


func _next_house_cost(p: Node2D) -> float:
	for i in p.owned_property_indices:
		var color: String = _info(i).get("color", "")
		if main.board.HOUSE_COSTS_BY_COLOR.has(color) and main._owns_full_color_group(p.player_id, color) and _space(i).house_count < 5:
			var cost: float = float(main.board.HOUSE_COSTS_BY_COLOR[color])
			if _can_spend(p, cost):
				return cost
	return 0.0


# Impossible Architecture: build on the property where the extra houses add
# the most rent (it needn't be a full set), if the bot can spare the money.
func _eval_build_houses(p: Node2D, houses: int, half_price: bool) -> Dictionary:
	var n_opp: int = _opponents(p, false).size()
	var best: Dictionary = {}
	for i in p.owned_property_indices:
		var info: Dictionary = _info(i)
		var color: String = info.get("color", "")
		var s: Node2D = _space(i)
		if not main.board.HOUSE_COSTS_BY_COLOR.has(color) or s.is_mortgaged or s.house_count >= 5:
			continue
		var build: int = mini(houses, 5 - s.house_count)
		var each: float = float(main.board.HOUSE_COSTS_BY_COLOR[color]) * (0.5 if half_price else 1.0)
		var cost: float = each * build
		if not _can_spend(p, cost):
			continue
		var rents: Array = info.get("rents", [])
		if rents.size() < 6:
			continue
		var gain: float = float(rents[s.house_count + build]) - float(main._hypothetical_rent(i))
		var v: float = gain * LANDINGS_PER_OPPONENT * n_opp - cost * 0.3
		if best.is_empty() or v > best["value"]:
			best = {"value": v, "cash": -cost, "answers": {"board": [i]}, "why": "%d house%s on %s raise its rent by $%d." % [build, "" if build == 1 else "s", main._property_name(i), int(gain)]}
	return best


func _eval_promised_land(p: Node2D, level: int) -> Dictionary:
	var pool: Array = main._unowned_property_indices()
	var scored: Array = []
	for i in pool:
		var price: float = float(_info(i).get("price", 0))
		scored.append({"i": i, "v": buy_value(p, i) if _can_spend(p, price) else -999.0})
	if scored.is_empty():
		return {}
	match level:
		3:
			scored.sort_custom(func(a, b): return a["v"] > b["v"])
			if scored[0]["v"] <= 0.0:
				return {}
			return {"value": scored[0]["v"], "answers": {"board": [scored[0]["i"]], "confirm": [true]}, "why": "buys %s." % main._property_name(scored[0]["i"])}
		2:
			var best_side: int = -1
			var best_v: float = 0.0
			for side in 4:
				var total: float = 0.0
				var n: int = 0
				for e in scored:
					if e["i"] / main.board.SPACES_PER_SIDE == side:
						total += maxf(0.0, e["v"])
						n += 1
				if n > 0 and total / n > best_v:
					best_v = total / n
					best_side = side
			if best_side == -1:
				return {}
			return {"value": best_v, "answers": {"pick": [best_side]}, "why": "the %s side has property it wants." % main.BOARD_SIDE_NAMES[best_side]}
		_:
			var total: float = 0.0
			for e in scored:
				total += maxf(0.0, e["v"])
			return {"value": total / scored.size(), "why": "a random unowned property is usually worth having."}


# Offer You Can't Refuse: take the opponent's property the bot gains most
# from, and give back whatever costs it least (and helps them least).
func _eval_offer(p: Node2D, give_count: int, min_value: bool) -> Dictionary:
	var best: Dictionary = {}
	for t in _properties():
		var s: Node2D = _space(t)
		if s.owner_id == -1 or s.owner_id == p.player_id or s.house_count > 0 or not _prop_targetable(p, t):
			continue
		var o: Node2D = main.players[s.owner_id]
		var target_price: int = int(_info(t).get("price", 0))
		var gives: Array = []
		for g in p.owned_property_indices:
			var color: String = _info(g).get("color", "")
			if main._max_houses_in_group(color, p.player_id) > 0:
				continue
			if min_value and int(_info(g).get("price", 0)) < target_price:
				continue
			gives.append({"i": g, "cost": prop_loss(p.player_id, g) + prop_gain(o.player_id, g) * _harm_weight(p, o)})
		if gives.size() < give_count:
			continue
		gives.sort_custom(func(a, b): return a["cost"] < b["cost"])
		var v: float = prop_gain(p.player_id, t) + prop_loss(o.player_id, t) * _harm_weight(p, o)
		var picks: Array = [t]
		for k in give_count:
			v -= gives[k]["cost"]
			picks.append(gives[k]["i"])
		if best.is_empty() or v > best["value"]:
			best = {"value": v, "answers": {"board": picks}, "why": "swaps for %s, which it needs more." % main._property_name(t)}
	return best


func _eval_master_plan(p: Node2D, level: int) -> Dictionary:
	if p.in_jail:
		# Doubles get it out and moving.
		var best: float = -INF
		for d in range(1, 7):
			best = maxf(best, move_value(p, _planned_steps(p, d, d)))
		var esc: float = best - jail_value(p) - roll_ev(p) / 6.0
		return {"value": esc, "why": "picks doubles to leave Jail."} if level == 3 else {}
	var base: float = roll_ev(p)
	var v: float = 0.0
	match level:
		3:
			for a in range(1, 7):
				for b in range(1, 7):
					v = maxf(v, move_value(p, _planned_steps(p, a, b)))
		_:
			for a in range(1, 7):
				var avg: float = 0.0
				for b in range(1, 7):
					avg += move_value(p, _planned_steps(p, a, b))
				v = maxf(v, avg / 6.0)
	return {"value": v - base, "why": "chooses its dice for a better square (+$%d)." % int(v - base)}


func _eval_dodge(p: Node2D, level: int) -> Dictionary:
	var d1: int = maxi(0, main._die1)
	var d2: int = maxi(0, main._die2)
	var steps: int = _current_steps(p)
	var now: float = move_value(p, steps)
	var ev: float = 0.0
	if level == 1:
		for a in range(1, 7):
			for b in range(1, 7):
				ev += move_value(p, steps - d1 - d2 + a + b)
		ev /= 36.0
	else:
		for die in [d1, d2]:
			var other: int = d2 if die == d1 else d1
			var avg: float = 0.0
			for a in range(1, 7):
				var kept: float = move_value(p, steps - die + a)
				var again: float = 0.0
				for b in range(1, 7):
					again += move_value(p, steps - die + a - other + b)
				avg += maxf(kept, again / 6.0)
			ev = maxf(ev, avg / 6.0)
	return {"value": ev - now, "why": "a reroll beats where it's heading (+$%d on average)." % int(ev - now)}


func _eval_word_of_binding(p: Node2D, level: int) -> Dictionary:
	if level == 1:
		var best_i: int = -1
		var best_r: float = 0.0
		for i in _properties():
			var s: Node2D = _space(i)
			if s.owner_id != -1 and s.owner_id != p.player_id:
				var r: float = float(main._hypothetical_rent(i))
				if r > best_r:
					best_r = r
					best_i = i
		if best_i == -1:
			return {}
		return {"value": best_r * 0.3, "answers": {"board": [best_i]}, "why": "%s's rent is the one it most fears." % main._property_name(best_i)}
	var best_color: String = ""
	var best_total: float = 0.0
	for color in main.board.HOUSE_COSTS_BY_COLOR.keys() + ["railroad", "utility"]:
		var total: float = 0.0
		for i in main.board.get_color_group(color):
			var s: Node2D = _space(i)
			if s.owner_id != -1 and s.owner_id != p.player_id:
				total = maxf(total, float(main._hypothetical_rent(i)))
		if total > best_total:
			best_total = total
			best_color = color
	if best_color == "":
		return {}
	return {"value": best_total * 0.4, "answers": {"pick": [best_color.replace("_", " ")]}, "why": "the %s set is where rent hurts most." % best_color.replace("_", " ")}


# Landmarks sit on a square and fire when opponents reach it, so the bot
# places them a few squares ahead of the opponents (where they're likeliest
# to land), or on its own property where that's what the card wants.
func _eval_landmark(p: Node2D, spell: String, _level: int, li: Dictionary) -> Dictionary:
	var opps: Array = _opponents(p, false)
	if opps.is_empty():
		return {}
	var land_chance: Dictionary = {}
	for i in _total_spaces():
		var c: float = 0.0
		for o in opps:
			c += _roll_prob(posmod(i - o.current_space, _total_spaces()))
		land_chance[i] = c
	var amount: float = float(li.get("amount", 0))
	var triggers: float = float(li.get("triggers", 1))
	match spell:
		"Landmine":
			var best_i: int = -1
			var best_c: float = -1.0
			for i in _properties():
				if land_chance[i] > best_c:
					best_c = land_chance[i]
					best_i = i
			return {"value": amount * maxf(0.3, best_c) * 1.3, "answers": {"board": [best_i]}, "why": "opponents are likely to land on %s soon." % main._property_name(best_i)}
		"Toll Road", "Ensnaring Roots":
			# Opponents pass a square a few steps ahead of them on most rolls.
			var best_i: int = -1
			var best_c: float = -1.0
			for i in _properties():
				var c: float = 0.0
				for o in opps:
					var d: int = posmod(i - o.current_space, _total_spaces())
					if d >= 1 and d <= 6:
						c += 1.0
				if c > best_c:
					best_c = c
					best_i = i
			var v: float = (20.0 * minf(triggers, 6.0 * opps.size())) if spell == "Toll Road" else 40.0 * float(li.get("roll_penalty", 2)) / 2.0
			return {"value": v, "answers": {"board": [best_i]}, "why": "right in front of the opponents."}
		"Treasure Map":
			return {"value": 25.0 * float(li.get("count", 3)), "why": "buried treasure to collect later."}
		"Power Sink":
			var best_i: int = -1
			for i in _properties():
				var owner: int = _space(i).owner_id
				if owner != -1 and owner != p.player_id and _prop_targetable(p, i):
					best_i = i
					break
			if best_i == -1:
				return {}
			return {"value": 50.0 * float(li.get("amount", 1)), "answers": {"board": [best_i]}, "why": "drains an opponent's Attunement."}
		"Outland Settlements":
			var best_i: int = -1
			var best_gain: float = 0.0
			for i in p.owned_property_indices:
				var rents: Array = _info(i).get("rents", [])
				if rents.size() >= 6 and not main._owns_full_color_group(p.player_id, _info(i).get("color", "")):
					var g: float = float(rents[1]) - float(rents[0])
					if g > best_gain:
						best_gain = g
						best_i = i
			if best_i == -1:
				return {}
			return {"value": 50.0 * triggers, "answers": {"board": [best_i]}, "why": "lets it build without the full set."}
		"Stabilized Portal":
			var dest: int = -1
			var dest_rent: float = 0.0
			for i in p.owned_property_indices:
				var r: float = float(main._hypothetical_rent(i))
				if r > dest_rent:
					dest_rent = r
					dest = i
			if dest == -1:
				return {}
			var src: int = -1
			var best_c: float = -1.0
			for i in _properties():
				if i != dest and land_chance[i] > best_c:
					best_c = land_chance[i]
					src = i
			return {"value": dest_rent * triggers * 0.3, "answers": {"board": [src, dest]}, "why": "sends opponents to %s." % main._property_name(dest)}
	return {}


# What one more Attunement (per color in `bonus`, or `all` to every color)
# would add to the best other turn spell in hand.
func _upgrade_gain(p: Node2D, bonus: Dictionary, all: int, except: String) -> float:
	var before: float = _best_other_value(p, except, {}, 0)
	var after: float = _best_other_value(p, except, bonus, all)
	return after - before


func _best_other_value(p: Node2D, except: String, bonus: Dictionary, all: int) -> float:
	var best: float = 0.0
	for spell in p.spell_hand:
		if spell == except or spell in ["Manastone", "Overflowing Bounty", "Natural Magician"]:
			continue
		var info: Dictionary = SpellData.SPELLS.get(spell, {})
		var color: String = info.get("color", "")
		var attune: int = main._color_attunement(p, color) + int(bonus.get(color, 0)) + all
		for level in info.get("levels", {}).keys():
			if level > attune or not main._level_timing_allowed(p, spell, level):
				continue
			var ev: Dictionary = evaluate(p, spell, level, "post_roll")
			if not ev.is_empty():
				best = maxf(best, float(ev.get("value", 0.0)))
	return best


# ============================================================================
# Countering
# ============================================================================

# Counter the top of the stack if it would cost the bot enough, with this
# card at this level (Counterbalance / Deny Rights only hit their own level).
func _eval_counter(p: Node2D, spell: String, level: int) -> Dictionary:
	var entry: Dictionary = main._spell_stack.back()
	if int(entry["caster_id"]) == p.player_id:
		return {}
	if spell in ["Counterbalance", "Deny Rights"] and int(entry["level"]) != level:
		return {}
	var harm: float = -_spell_effect_on(p, entry)
	if harm <= 0.0:
		return {}
	var v: float = harm
	if spell == "Spell Mastery" and level == 2:
		v += 60.0  # and the bot keeps the countered card
	return {"value": v, "answers": {"pick": [int(entry["id"])]}, "why": "%s's %s would cost it about $%d." % [main.PLAYER_NAMES[int(entry["caster_id"])], entry["display_name"], int(harm)]}


# Roughly what a spell on the stack will do to p, in dollars (negative =
# bad for p), from its spell, level, caster and the targets it named.
func _spell_effect_on(p: Node2D, entry: Dictionary) -> float:
	var spell: String = str(entry["spell_name"])
	var level: int = int(entry["level"])
	var caster: Node2D = main.players[int(entry["caster_id"])]
	if caster == p:
		return 0.0
	var li: Dictionary = SpellData.SPELLS.get(spell, {}).get("levels", {}).get(level, {})
	var amount: float = float(li.get("amount", 0))
	var t_players: Array = []
	var t_props: Array = []
	var t_spells: Array = []
	for mark in entry.get("target_marks", []):
		match str(mark.get("kind", "")):
			"player":
				t_players.append(int(mark["id"]))
			"property":
				t_props.append(int(mark["id"]))
			"spell":
				t_spells.append(int(mark["id"]))
	var me: int = p.player_id
	var mine_hit: Array = []
	for i in t_props:
		if _space(i).owner_id == me:
			mine_hit.append(i)
	var w: float = 1.0 + _harm_weight(p, caster)
	match spell:
		"Counterbalance", "Deny Rights", "Spell Mastery", "T2 Response Spell":
			var v: float = 0.0
			for sid in t_spells:
				for e in main._spell_stack:
					if int(e["id"]) != sid:
						continue
					if int(e["caster_id"]) == me:
						v -= float(_stack_values.get(sid, 100.0))
					else:
						# Countering a spell that would have hurt p is good for p.
						v -= _spell_effect_on(p, e)
			return v
		"T1 Burn Spell", "The Cult of Terminus", "Critical Hit", "Knockout Punch", "Sanity Grinding", "Art of the Deal":
			if me in t_players:
				var amt: float = amount
				if spell == "Critical Hit" and _flag(caster, "rolled_doubles_this_turn"):
					amt += 100.0
				return -minf(amt, _liquid(p)) * w - (60.0 if spell == "Knockout Punch" else 0.0)
		"Taxes":
			if me in t_players:
				return -float(p.money / int(li.get("divisor", 5))) * w
		"Migraine":
			if me in t_players:
				return -float(li.get("pay_per_card", 0)) * p.spell_hand.size() * w
		"Far-Reaching Empire":
			if me in t_players:
				return -amount * _colors_owned(caster) * w
		"Sinkhole":
			for id in t_players:
				if main.players[id].current_space == p.current_space:
					return -amount * w
		"Smite":
			var richest: Node2D = null
			for o in main.players:
				if o != caster and not o.is_bankrupt and (richest == null or o.money > richest.money):
					richest = o
			if richest == p:
				return -amount * w
		"Line of Fire":
			return -amount * mine_hit.size() * w
		"Bomb Shelter":
			return 0.0 if p.in_jail else -amount
		"Spiteful Destruction":
			if me in t_players:
				return -amount
		"Penance":
			if p.in_jail:
				return -amount * w
		"Threaten":
			if not mine_hit.is_empty():
				return -minf(amount, prop_loss(me, mine_hit[0])) * w
		"Offer You Can't Refuse", "Annexation", "Market Manipulation", "Contested Battlefield":
			var v: float = 0.0
			for i in mine_hit:
				v -= prop_loss(me, i) * (0.6 if spell == "Offer You Can't Refuse" else 1.2)
			return v
		"Burn to the Ground":
			var v: float = 0.0
			for i in mine_hit:
				var cost: float = float(main.board.HOUSE_COSTS_BY_COLOR.get(_info(i).get("color", ""), 0))
				v -= mini(int(li.get("houses", 1)), _space(i).house_count) * cost * 1.5
			return v
		"Reclaimed by Nature":
			var v: float = 0.0
			for i in mine_hit:
				v -= float(_info(i).get("price", 0))
			return v
		"Snatch Purse":
			if me in t_players:
				return -float(mini(int(li.get("count", 1)), p.spell_hand.size())) * 70.0
		"Cramped Cell", "Bribe the Guards":
			if me in t_players and (spell == "Cramped Cell" or level == 2):
				return -120.0
		"Anti-Magic Law", "Lethargy", "Fated Ending":
			if me in t_players:
				return -100.0
		"Parasite":
			if me in t_players:
				return -amount * float(li.get("rotations", 2))
	return 0.0


# ============================================================================
# Answers to decisions that come up while a spell plays out
# ============================================================================

func _space_in_text(text: String) -> int:
	var best: int = -1
	var best_len: int = 0
	for i in _properties():
		var name: String = main._property_name(i)
		if name.length() > best_len and text.contains(name):
			best = i
			best_len = name.length()
	return best


func _price_in_text(text: String) -> int:
	var re := RegEx.new()
	re.compile("\\$(\\d+)")
	var m := re.search(text)
	return int(m.get_string(1)) if m else -1


# "Buy X for $N?" from Promised Land / Unclaimed Wilderness / Pilgrimage.
func _confirm_buy(p: Node2D, text: String) -> bool:
	var i: int = _space_in_text(text)
	var price: int = _price_in_text(text)
	if i == -1 or price < 0 or p.money < price:
		return false
	return buy_value(p, i, price) >= 0.0 or float(p.money - price) > 600.0


func _dodge_pick_die(p: Node2D) -> int:
	var d1: int = maxi(0, main._die1)
	var d2: int = maxi(0, main._die2)
	var steps: int = _current_steps(p)
	var ev1: float = 0.0
	var ev2: float = 0.0
	for a in range(1, 7):
		ev1 += move_value(p, steps - d1 + a)
		ev2 += move_value(p, steps - d2 + a)
	return 1 if ev1 >= ev2 else 2


func _dodge_reroll_other(p: Node2D, text: String) -> bool:
	var re := RegEx.new()
	re.compile("showing (\\d+)")
	var m := re.search(text)
	if not m:
		return false
	var other: int = int(m.get_string(1))
	var steps: int = _current_steps(p)
	var avg: float = 0.0
	for b in range(1, 7):
		avg += move_value(p, steps - other + b)
	return avg / 6.0 > move_value(p, steps)


# Fated Ending, Level 2: the bot zeroes whichever die leaves the roller worse
# off. Returns 1 to zero the first die, 2 the second.
func _fated_ending_pick(seat: int, text: String) -> int:
	var re := RegEx.new()
	re.compile("rolled (\\d+) \\+ (\\d+)")
	var m := re.search(text)
	if not m:
		return 1
	var a: int = int(m.get_string(1))
	var b: int = int(m.get_string(2))
	var roller: Node2D = main.players[main.current_player]
	var keep_b: float = move_value(roller, _planned_steps(roller, 0, b))
	var keep_a: float = move_value(roller, _planned_steps(roller, a, 0))
	var _bot: Node2D = main.players[seat]
	return 1 if keep_b <= keep_a else 2


func _master_plan_face(p: Node2D, text: String) -> int:
	if text.contains("second die"):
		return _master_plan_second if _master_plan_second > 0 else 6
	var in_jail: bool = p.in_jail
	var score := func(a: int, b: int) -> float:
		if in_jail:
			return move_value(p, _planned_steps(p, a, b)) if a == b else jail_value(p)
		var v: float = move_value(p, _planned_steps(p, a, b))
		if a == b and p.consecutive_doubles < 2:
			v += 40.0  # doubles: another roll
		return v
	if text.contains("first die"):
		var best: Vector2i = Vector2i(6, 6)
		var best_v: float = -INF
		for a in range(1, 7):
			for b in range(1, 7):
				var v: float = score.call(a, b)
				if v > best_v:
					best_v = v
					best = Vector2i(a, b)
		_master_plan_second = best.y
		return best.x
	var re := RegEx.new()
	re.compile("rolled a (\\d+)")
	var m := re.search(text)
	if m:
		# Level 2: one die is already showing.
		var shown: int = int(m.get_string(1))
		var best_face: int = 6
		var best_v: float = -INF
		for b in range(1, 7):
			var v: float = score.call(shown, b)
			if v > best_v:
				best_v = v
				best_face = b
		return best_face
	# Level 1: set one die, the other is random.
	var best_face: int = 6
	var best_v: float = -INF
	for a in range(1, 7):
		var avg: float = 0.0
		for b in range(1, 7):
			avg += score.call(a, b)
		if avg > best_v:
			best_v = avg
			best_face = a
	return best_face
