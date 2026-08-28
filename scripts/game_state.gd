extends Node

# Set by the Start Menu before loading main.tscn. Admin Mode keeps the
# Admin / Admin Properties buttons (dice/property overrides used for
# testing); NonAdmin Mode hides them for normal play.
var admin_mode: bool = false

enum PlayerType { HUMAN, DISABLED, COMPUTER }

# One entry per player slot (always 4, regardless of how many are actually
# in play) -- Disabled slots are spawned but immediately treated as if
# they'd already gone bankrupt, and Computer slots play themselves. The Start
# Menu overwrites this before loading main.tscn; this default only matters
# if main.tscn is ever run directly. Mirrors start_menu.gd's own default
# (P1 Human, P2 Computer, P3/P4 Disabled).
var player_types: Array[PlayerType] = [
	PlayerType.HUMAN, PlayerType.COMPUTER, PlayerType.DISABLED, PlayerType.DISABLED,
]

# If true, every active player starts with 3 random properties and 2 random
# spells instead of the normal empty-handed, property-less start. Set by the
# Start Menu's Quickstart Mode checkbox.
var quickstart_mode: bool = false
