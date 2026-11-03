class_name Heroes
extends RefCounted

# Hero Mode's heroes. In Hero Mode every player picks a hero before the game
# starts; a hero adds special effects for that game and is unlocked by
# levelling up. This is the one place heroes are defined -- the selection
# screen, the game setup (main.gd) and the profile's unlock list read it.

# How many boxes the selection screen shows. Slots past the defined heroes
# are drawn as locked "coming soon" portraits.
const ROSTER_SIZE: int = 30

# Each: {"id": String (stable -- it's stored in saves), "name": String,
# "unlock_level": int, "description": String (shown to players),
# "color": Color (portrait), "effects": {...}}.
# Effects understood by apply_start_effects():
#   "starting_money": int -- extra money at the start of the game.
const LIST: Array[Dictionary] = [
	{
		"id": "placeholder",
		"name": "Placeholder Hero",
		"unlock_level": 0,
		"description": "Start with an extra $100.",
		"color": Color(0.35, 0.55, 0.85),
		"effects": {"starting_money": 100},
	},
]


static func get_hero(id: String) -> Dictionary:
	for h in LIST:
		if h["id"] == id:
			return h
	return {}


static func hero_name(id: String) -> String:
	return str(get_hero(id).get("name", ""))


# The unlock id a hero is registered under in Saves' unlock list.
static func unlock_id(id: String) -> String:
	return "hero_" + id


# What a Computer player gets in Hero Mode: the first hero (always
# available, unlock level 0), so AI opponents play by the same rules.
static func default_ai_hero() -> String:
	return LIST[0]["id"]


# Applies a hero's start-of-game effects to `player` (a player.gd node).
# Called once while the game is set up, after starting hands are dealt.
static func apply_start_effects(player: Node, hero_id: String) -> void:
	var effects: Dictionary = get_hero(hero_id).get("effects", {})
	if effects.has("starting_money"):
		player.money += int(effects["starting_money"])
