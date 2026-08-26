class_name SpellData
extends RefCounted

# Spell name -> {"color": String (one of board.gd's COLOR_GROUP_COLORS keys
# -- this is what Attunement is tracked against), "icon": String (res:// path
# to the card image), "levels": {level:int -> {"description": String,
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
}
