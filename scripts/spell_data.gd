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
# boost your own roll, not an opponent's), "requires_not_yet_rolled": bool
# (only for a "turn" timing -- this level can't be cast once the current
# player has already rolled this turn, e.g. Hasty Exit's Level 1 is
# explicitly "before rolling") -- see _level_timing_allowed()),
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
	"Counterfeit Currency": {
		"color": "brown",
		"icon": "res://Magopoly Assets/Cards/1 1 Counterfeit Currency.png",
		"levels": {
			1: {"description": "The next time you would pay money to an opponent this turn, decrease the amount by $200.", "reduction": 200, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "The next time you would pay money to an opponent this turn, decrease the amount by $400.", "reduction": 400, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	"Snatch Purse": {
		"color": "brown",
		"icon": "res://Magopoly Assets/Cards/1 2 Snatch Purse.png",
		"levels": {
			1: {"description": "Take 1 random spell from an opponent's hand.", "count": 1, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "Take 2 random spells from an opponent's hand.", "count": 2, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	"Hasty Exit": {
		"color": "brown",
		"icon": "res://Magopoly Assets/Cards/1 3 Hasty Exit.png",
		"levels": {
			1: {"description": "Before Rolling: Increase your next roll this turn by 10.", "roll_bonus": 10, "timings": ["turn"], "requires_current_player": true, "requires_not_yet_rolled": true},
			2: {"description": "Increase your current roll by 10.", "roll_bonus": 10, "timings": ["roll_response"], "requires_current_player": true},
		},
	},
	"Price Gouging": {
		"color": "brown",
		"icon": "res://Magopoly Assets/Cards/1 4 Price Gouging.png",
		"levels": {
			1: {"description": "When an opponent lands on your property this turn, they pay you as if it had 1 additional house.", "bonus_houses": 1, "timings": ["roll_response"], "exclude_current_player": true},
			2: {"description": "When an opponent lands on your property this turn, they pay you as if it had 2 additional houses.", "bonus_houses": 2, "timings": ["roll_response"], "exclude_current_player": true},
		},
	},
	"Divination": {
		"color": "sky_blue",
		"icon": "res://Magopoly Assets/Cards/2 1 Divination.png",
		"levels": {
			1: {"description": "Draw 1 spell card.", "draw_count": 1, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "Draw 2 spell cards.", "draw_count": 2, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "Draw 3 spell cards.", "draw_count": 3, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	"Migraine": {
		"color": "sky_blue",
		"icon": "res://Magopoly Assets/Cards/2 2 Migraine.png",
		"levels": {
			1: {"description": "Choose an opponent. For each spell in their hand as you cast this spell, they pay you $20.", "pay_per_card": 20, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "Choose an opponent. For each spell in their hand as you cast this spell, they pay you $40.", "pay_per_card": 40, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "Choose an opponent. For each spell in their hand as you cast this spell, they pay you $60.", "pay_per_card": 60, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	"Counterbalance": {
		"color": "sky_blue",
		"icon": "res://Magopoly Assets/Cards/2 3 Counterbalance.png",
		"levels": {
			1: {"description": "Counter a spell being cast at Level 1.", "timings": ["spell_response"]},
			2: {"description": "Counter a spell being cast at Level 2.", "timings": ["spell_response"]},
			3: {"description": "Counter a spell being cast at Level 3.", "timings": ["spell_response"]},
		},
	},
	"Impossible Architecture": {
		"color": "sky_blue",
		"icon": "res://Magopoly Assets/Cards/2 4 Impossible Architecture.png",
		"levels": {
			1: {"description": "Choose a property you own. Even if you don't own the entire color set, build 2 houses, paying full price.", "houses": 2, "half_price": false},
			2: {"description": "Choose a property you own. Even if you don't own the entire color set, build 3 houses, paying half price.", "houses": 3, "half_price": true},
			3: {"description": "Choose a property you own. Even if you don't own the entire color set, build 5 houses, paying half price.", "houses": 5, "half_price": true},
		},
	},
	"Promised Land": {
		"color": "pink",
		"icon": "res://Magopoly Assets/Cards/3 1 Promised Land.png",
		"levels": {
			1: {"description": "You may buy a random unowned property."},
			2: {"description": "Choose a side of the board. You may buy a random unowned property from that side of the board."},
			3: {"description": "Choose an unowned property. You may buy it."},
		},
	},
	"Share the Wealth": {
		"color": "pink",
		"icon": "res://Magopoly Assets/Cards/3 2 Share the Wealth.png",
		"levels": {
			1: {"description": "You and another random player gain $150.", "amount": 150, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "You and another random player gain $300.", "amount": 300, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "You and another random player gain $400.", "amount": 400, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	"Smite": {
		"color": "pink",
		"icon": "res://Magopoly Assets/Cards/3 3 Smite.png",
		"levels": {
			1: {"description": "The opponent who currently has the most money pays you $100.", "amount": 100, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "The opponent who currently has the most money pays you $200.", "amount": 200, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "The opponent who currently has the most money pays you $300.", "amount": 300, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	"Divine Protection": {
		"color": "pink",
		"icon": "res://Magopoly Assets/Cards/3 4 Divine Protection.png",
		"levels": {
			1: {"description": "If you would land on an opponent's property, subtract 1 from your roll.", "roll_penalty": 1, "timings": ["roll_response"], "requires_current_player": true},
			2: {"description": "If you would land on an opponent's property, subtract 2 from your roll.", "roll_penalty": 2, "timings": ["roll_response"], "requires_current_player": true},
			3: {"description": "Subtract 1 or 2 from your roll.", "timings": ["roll_response"], "requires_current_player": true},
		},
	},
	"Art of the Deal": {
		"color": "orange",
		"icon": "res://Magopoly Assets/Cards/4 1 Art of the Deal.png",
		"levels": {
			1: {"description": "As an additional cost, give an opponent a spell from your hand. That opponent pays you $200.", "amount": 200, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "As an additional cost, give an opponent a spell from your hand. That opponent pays you $300.", "amount": 300, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "As an additional cost, give an opponent a spell from your hand. That opponent pays you $400.", "amount": 400, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	# "Cancel your roll, advance to X" per the chat description that
	# superseded the card art -- see _prepare_escape_plan() /
	# _escape_plan_condition() / _spell_extra_validation().
	"Escape Plan": {
		"color": "orange",
		"icon": "res://Magopoly Assets/Cards/4 2 Escape Plan.png",
		"levels": {
			1: {"description": "Increase your roll until you land on the nearest property owned by an opponent, excluding the color set you would have landed on.", "timings": ["roll_response"], "requires_current_player": true},
			2: {"description": "Increase your roll until you land on the nearest property you own.", "timings": ["roll_response"], "requires_current_player": true},
			3: {"description": "Increase your roll until you land on the nearest unowned property.", "timings": ["roll_response"], "requires_current_player": true},
		},
	},
	"Offer You Can't Refuse": {
		"color": "orange",
		"icon": "res://Magopoly Assets/Cards/4 3 Offer You Cant Refuse.png",
		"levels": {
			1: {"description": "Take a property without houses from an opponent. In return, give them properties of greater or equal value."},
			2: {"description": "Take a property without houses from an opponent. In return, give them any property you own."},
			3: {"description": "Take a property without houses from an opponent. In return, give them money equal to that property's value."},
		},
	},
	"Haggling": {
		"color": "orange",
		"icon": "res://Magopoly Assets/Cards/4 4 Haggling.png",
		"levels": {
			1: {"description": "When you buy your next property or house this turn, reduce the amount you would pay by 50%.", "discount_percent": 50, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "When you buy your next property or house this turn, reduce the amount you would pay by 100%.", "discount_percent": 100, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "When you buy your next property or house this turn, reduce the amount you would pay by 50%. Then gain money equal to the money you would have spent.", "discount_percent": 50, "refund_on_use": true, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	"Burn to the Ground": {
		"color": "red",
		"icon": "res://Magopoly Assets/Cards/5 1 Burn to the Ground.png",
		"levels": {
			1: {"description": "Choose a property. Destroy 1 house on that property.", "houses": 1, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "Choose a property. Destroy 2 houses on that property.", "houses": 2, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "Choose a property. Destroy 3 houses on that property.", "houses": 3, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	"Line of Fire": {
		"color": "red",
		"icon": "res://Magopoly Assets/Cards/5 2 Line of Fire.png",
		"levels": {
			1: {"description": "Choose a side of the board. For each property on that side owned by an opponent, its owner pays you $20.", "amount": 20, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "Choose a side of the board. For each property on that side owned by an opponent, its owner pays you $40.", "amount": 40, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "Choose a side of the board. For each property on that side owned by an opponent, its owner pays you $60.", "amount": 60, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	"Unstable Portal": {
		"color": "red",
		"icon": "res://Magopoly Assets/Cards/5 3 Unstable Portal.png",
		"levels": {
			1: {"description": "Multiply your next roll this turn by 3.", "multiplier": 3, "timings": ["turn"], "requires_current_player": true, "requires_not_yet_rolled": true},
			2: {"description": "Multiply your next roll this turn by 6.", "multiplier": 6, "timings": ["turn"], "requires_current_player": true, "requires_not_yet_rolled": true},
			3: {"description": "Multiply your next roll this turn by 10.", "multiplier": 10, "timings": ["turn"], "requires_current_player": true, "requires_not_yet_rolled": true},
		},
	},
	"Threaten": {
		"color": "red",
		"icon": "res://Magopoly Assets/Cards/5 4 Threaten.png",
		"levels": {
			1: {"description": "Choose an opponent's property without houses. They must either give you that property or pay you $200.", "amount": 200, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "Choose an opponent's property without houses. They must either give you that property or pay you $300.", "amount": 300, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "Choose an opponent's property without houses. They must either give you that property or pay you $400.", "amount": 400, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	"Royal Aid": {
		"color": "yellow",
		"icon": "res://Magopoly Assets/Cards/6 1 Royal Aid.png",
		"levels": {
			1: {"description": "Unmortgage a property.", "count": 1, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "Unmortgage 2 properties.", "count": 2, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "Unmortgage 3 properties.", "count": 3, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	# The card art gives 1/5, 1/3, 1/2 -- used here since it's the more
	# consistent, deliberately-rendered source (the chat text's "20%/40%/50%"
	# had a level-numbering typo in the same message, so 1/3 for Level 2 is
	# treated as the intended value over "40%").
	"Taxes": {
		"color": "yellow",
		"icon": "res://Magopoly Assets/Cards/6 2 Taxes.png",
		"levels": {
			1: {"description": "An opponent pays you 1/5 of their money.", "divisor": 5, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "An opponent pays you 1/3 of their money.", "divisor": 3, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "An opponent pays you 1/2 of their money.", "divisor": 2, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	"Far-Reaching Empire": {
		"color": "yellow",
		"icon": "res://Magopoly Assets/Cards/6 3 Far-Reaching Empire.png",
		"levels": {
			1: {"description": "For each different color among properties you own, an opponent pays you $20.", "amount": 20, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "For each different color among properties you own, an opponent pays you $40.", "amount": 40, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "For each different color among properties you own, an opponent pays you $60.", "amount": 60, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	# The card restricts the target to a property owned by another player, but
	# chat explicitly widened this to also allow unowned (bank) properties.
	"Annexation": {
		"color": "yellow",
		"icon": "res://Magopoly Assets/Cards/6 4 Annexation.png",
		"levels": {
			1: {"description": "Choose a property without houses. Take it if you own two properties of that color set. The property can be taken from the bank or from another player.", "required_owned": 2},
			2: {"description": "Choose a property without houses. Take it if you own one property of that color set. The property can be taken from the bank or from another player.", "required_owned": 1},
			3: {"description": "Choose a property without houses. Take it. The property can be taken from the bank or from another player.", "required_owned": 0},
		},
	},
	"Adrenaline": {
		"color": "green",
		"icon": "res://Magopoly Assets/Cards/7 1 Adrenaline.png",
		"levels": {
			1: {"description": "Increase your roll by 1.", "roll_bonus": 1, "timings": ["turn", "roll_response"], "requires_current_player": true},
			2: {"description": "Increase your roll by 2.", "roll_bonus": 2, "timings": ["turn", "roll_response"], "requires_current_player": true},
			3: {"description": "Increase your roll by 3.", "roll_bonus": 3, "timings": ["turn", "roll_response"], "requires_current_player": true},
		},
	},
	"Overflowing Bounty": {
		"color": "green",
		"icon": "res://Magopoly Assets/Cards/7 2 Overflowing Bounty.png",
		"levels": {
			1: {"description": "Gain 1 Temporary Attunement to each color.", "amount": 1, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "Gain 2 Temporary Attunement to each color.", "amount": 2, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "Gain 3 Temporary Attunement to each color.", "amount": 3, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	"Sinkhole": {
		"color": "green",
		"icon": "res://Magopoly Assets/Cards/7 3 Sinkhole.png",
		"levels": {
			1: {"description": "Choose an opponent. They and all other opponents on the same space pay you $100.", "amount": 100, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "Choose an opponent. They and all other opponents on the same space pay you $200.", "amount": 200, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "Choose an opponent. They and all other opponents on the same space pay you $300.", "amount": 300, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	"Decompose": {
		"color": "green",
		"icon": "res://Magopoly Assets/Cards/7 4 Decompose.png",
		"levels": {
			1: {"description": "Return a mortgaged property to the bank.", "count": 1, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "Return 2 mortgaged properties to the bank.", "count": 2, "timings": ["turn", "roll_response", "spell_response"]},
			3: {"description": "Return 3 mortgaged properties to the bank.", "count": 3, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	# After resolving, the card is shuffled into the deck like any other spell
	# -- then specifically pulled back out into the caster's hand at the end
	# of the turn it was cast on. See _queue_spell_return_to_hand() in main.gd.
	"Sanity Grinding": {
		"color": "ocean_blue",
		"icon": "res://Magopoly Assets/Cards/8 1 Sanity Grinding.png",
		"levels": {
			1: {"description": "An opponent pays you $10. Return this spell to your hand at the end of your turn.", "amount": 10},
			2: {"description": "An opponent pays you $20. Return this spell to your hand at the end of your turn.", "amount": 20},
		},
	},
	"Spell Mastery": {
		"color": "ocean_blue",
		"icon": "res://Magopoly Assets/Cards/8 2 Spell Mastery.png",
		"levels": {
			1: {"description": "Counter a spell.", "timings": ["spell_response"]},
			2: {"description": "Counter a spell. Then add it to your hand rather than discarding it.", "timings": ["spell_response"]},
		},
	},
	"Tax Haven": {
		"color": "ocean_blue",
		"icon": "res://Magopoly Assets/Cards/8 3 Tax Haven.png",
		"levels": {
			1: {"description": "Gain Luxury Tax as a property. You don't pay when landing on it; opponents who land on it pay you instead of Free Parking. It can be traded, but not mortgaged."},
			2: {"description": "Gain Income Tax as a property. You don't pay when landing on it; opponents who land on it pay you instead of Free Parking. It can be traded, but not mortgaged."},
		},
	},
	"Step Forward": {
		"color": "ocean_blue",
		"icon": "res://Magopoly Assets/Cards/8 4 Step Forward.png",
		"levels": {
			1: {"description": "Increase your next roll this turn by 1. Return this spell to your hand at the end of your turn.", "roll_bonus": 1, "timings": ["turn"], "requires_current_player": true},
			2: {"description": "Increase your next roll this turn by 2. Return this spell to your hand at the end of your turn.", "roll_bonus": 2, "timings": ["turn"], "requires_current_player": true},
		},
	},
	# The card art shows a single flat (non-leveled) effect instead of this
	# 3-level structure -- confirmed with the user, who chose the chat
	# version. Level 0 is deliberately always castable regardless of Utility
	# Attunement: the "attunement >= level" gate is trivially satisfied by
	# level 0 against any non-negative attunement, so no special-casing is
	# needed for that part -- see BURN_FOR_ATTUNEMENT_INDEX in main.gd for
	# the one place Level 0's existence *did* require a change (it used to
	# double as the "Burn for Attunement" sentinel).
	"Manastone": {
		"color": "utility",
		"icon": "res://Magopoly Assets/Cards/10 1 Manastone.png",
		"levels": {
			0: {"description": "Gain 1 Temporary Attunement to a color of your choice.", "amount": 1, "timings": ["turn", "roll_response", "spell_response"]},
			1: {"description": "Gain 2 Temporary Attunement to a color of your choice.", "amount": 2, "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "Gain 3 Temporary Attunement to a color of your choice.", "amount": 3, "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
	# "Black" isn't a real board color group, so Attunement to it can only
	# ever come from burning black spells for it -- there's no property type
	# that grants it naturally. Level 2's card art says "Cancel your roll.
	# Advance to the nearest railroad" (a teleport); confirmed with the user,
	# who chose the chat's "increase your roll" version instead, matching
	# Escape Plan's mechanic.
	"The Cult of Terminus": {
		"color": "black",
		"icon": "res://Magopoly Assets/Cards/9 1 The Cult of Terminus.png",
		"levels": {
			1: {"description": "The next railroad you buy this turn costs $0.", "timings": ["turn", "roll_response", "spell_response"]},
			2: {"description": "Increase your roll until you land on the nearest railroad.", "timings": ["roll_response"], "requires_current_player": true},
			3: {"description": "Buy a railroad from a player or the bank.", "timings": ["turn", "roll_response", "spell_response"]},
			4: {"description": "If you own all 4 railroads, gain Terminus Station.", "timings": ["turn", "roll_response", "spell_response"]},
		},
	},
}
