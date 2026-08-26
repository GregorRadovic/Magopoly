class_name SpellData
extends RefCounted

# Spell name -> {"color": String (one of board.gd's COLOR_GROUP_COLORS keys
# -- this is what Attunement is tracked against), "icon": String (res:// path
# to the card image), "levels": {level:int -> {"description": String,
# "timings": Array[String] (which of "turn"/"roll_response"/"spell_response"
# this level can be *cast* at -- defaults to ["turn"] if omitted; burning
# for Attunement ignores this entirely, see _burn_spell_for_attunement() in
# main.gd), "exclude_current_player": bool (this level can't be cast by
# whoever's turn/roll it currently is -- e.g. you can't decrease your own
# roll), "requires_current_player": bool (the opposite -- this level can
# ONLY be cast by whoever's turn/roll it currently is, e.g. you can only
# boost your own roll, not an opponent's -- see _level_timing_allowed()),
# ...whatever other fields that spell's cast handler in main.gd needs}}}.
const SPELLS: Dictionary = {
	"T1 Burn Spell": {
		"color": "red",
		"icon": "res://Magopoly Assets/Cards/T1 Burn Spell.png",
		"levels": {
			1: {"description": "An opponent pays you $100.", "amount": 100},
			2: {"description": "An opponent pays you $200.", "amount": 200},
			3: {"description": "An opponent pays you $300.", "amount": 300},
		},
	},
	"T3 Escape Spell": {
		"color": "red",
		"icon": "res://Magopoly Assets/Cards/T3 Escape Spell.png",
		"levels": {
			1: {"description": "Increase your roll by 1.", "roll_bonus": 1, "timings": ["turn", "roll_response"], "requires_current_player": true},
			2: {"description": "Increase your roll by 2.", "roll_bonus": 2, "timings": ["turn", "roll_response"], "requires_current_player": true},
			3: {"description": "Increase your roll by 3.", "roll_bonus": 3, "timings": ["turn", "roll_response"], "requires_current_player": true},
		},
	},
	"T2 Response Spell": {
		"color": "red",
		"icon": "res://Magopoly Assets/Cards/T2 Response Spell.png",
		"levels": {
			1: {"description": "Counter a spell being cast.", "timings": ["spell_response"]},
			2: {"description": "Decrease an opponent's roll by 1.", "roll_penalty": 1, "timings": ["roll_response"], "exclude_current_player": true},
		},
	},
}
