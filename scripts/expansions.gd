class_name Expansions
extends RefCounted

# The game's card sets: the base deck every game uses, plus expansions a
# player unlocks by levelling up and can then switch on when starting a game.
# Each expansion is 10 cards (copies counted). This is the one place card
# sets are defined -- the deck builder (main.gd), the Compendium, the game
# setup screens and the profile's unlock list all read from here.

# Spell name -> copies in the base Spell Deck. Only real, finished cards.
const BASE_CARDS: Dictionary = {
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

# In release order. Each: {"id": String (stable -- it's stored in saves),
# "name": String, "unlock_level": int, "description": String,
# "cards": {spell name -> copies}, 10 copies in total, optional "tokens":
# {token name -> card image} for the compendium}.
const LIST: Array[Dictionary] = [
	# The two halves of the "AB" card set: one copy of each of its 8 cards,
	# plus an extra Manastone and The Cult of Terminus from the base deck.
	{
		"id": "free_parking",
		"name": "Free Parking",
		"unlock_level": 5,
		"description": "Spells that pay into, take from, and play around the Free Parking pot.",
		"cards": {
			"Misplaced Payment": 1,
			"Steal From the Future": 1,
			"Gemstone Mine": 1,
			"Market Manipulation": 1,
			"Rocket Boost": 1,
			"King's Escape Tunnel": 1,
			"Unclaimed Wilderness": 1,
			"Spiteful Destruction": 1,
			"Manastone": 1,
			"The Cult of Terminus": 1,
		},
	},
	{
		"id": "jail",
		"name": "Jail",
		"unlock_level": 10,
		"description": "Spells that send players to Jail, free them, and punish them while they're inside.",
		"cards": {
			"Bribe the Guards": 1,
			"Cramped Cell": 1,
			"Penance": 1,
			"Deny Rights": 1,
			"Bomb Shelter": 1,
			"Escape Into Custody": 1,
			"Knockout Punch": 1,
			"Siren's Song": 1,
			"Manastone": 1,
			"The Cult of Terminus": 1,
		},
	},
	{
		"id": "dice",
		"name": "Loaded Dice",
		"unlock_level": 15,
		"description": "Spells that reroll, fix, zero and punish dice.",
		"cards": {
			"Dodge": 1,
			"Master Plan": 1,
			"Pilgrimage": 1,
			"Seize the Opportunity": 1,
			"Critical Hit": 1,
			"Veto": 1,
			"Go For the Kill": 1,
			"Fated Ending": 1,
			"Manastone": 1,
			"The Cult of Terminus": 1,
		},
	},
	{
		"id": "ongoing",
		"name": "Lingering Magic",
		"unlock_level": 20,
		"description": "Ongoing spells that stay in play for several rotations around the board.",
		"cards": {
			"Word of Binding": 1,
			"Natural Magician": 1,
			"Shielded From Harm": 1,
			"Fragile Goods": 1,
			"Burn Bright": 1,
			"Anti-Magic Law": 1,
			"Curse of Stalked Prey": 1,
			"Miasma": 1,
			"Manastone": 1,
			"The Cult of Terminus": 1,
		},
	},
	{
		"id": "landmarks",
		"name": "Landmarks",
		"unlock_level": 25,
		"description": "Landmarks placed on properties that trigger as players pass and land.",
		# Not deck cards -- shown in the compendium only. Treasure Map
		# creates Buried Treasure landmarks (see main.gd).
		"tokens": {
			"Buried Treasure": "res://Magopoly Assets/Magopoly Expansions/D 4 1t Buried Treasure.png",
		},
		"cards": {
			"Landmine": 1,
			"Power Sink": 1,
			"Outland Settlements": 1,
			"Treasure Map": 1,
			"Contested Battlefield": 1,
			"Toll Road": 1,
			"Ensnaring Roots": 1,
			"Stabilized Portal": 1,
			"Manastone": 1,
			"The Cult of Terminus": 1,
		},
	},
]


static func get_expansion(id: String) -> Dictionary:
	for e in LIST:
		if e["id"] == id:
			return e
	return {}


# The unlock id an expansion is registered under in Saves' unlock list.
static func unlock_id(id: String) -> String:
	return "expansion_" + id


static func card_total(cards: Dictionary) -> int:
	var n: int = 0
	for k in cards:
		n += int(cards[k])
	return n


# Spell name -> copies for a game using the base deck plus `expansion_ids`.
static func deck_counts(expansion_ids: Array) -> Dictionary:
	var counts: Dictionary = BASE_CARDS.duplicate()
	for id in expansion_ids:
		var cards: Dictionary = get_expansion(str(id)).get("cards", {})
		for spell_name in cards:
			counts[spell_name] = int(counts.get(spell_name, 0)) + int(cards[spell_name])
	return counts
