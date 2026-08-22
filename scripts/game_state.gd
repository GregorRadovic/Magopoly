extends Node

# Set by the Start Menu before loading main.tscn. Admin Mode keeps the
# Admin / Admin Properties buttons (dice/property overrides used for
# testing); NonAdmin Mode hides them for normal play.
var admin_mode: bool = false

enum PlayerType { HUMAN, DISABLED, COMPUTER }

# One entry per player slot (always 4, regardless of how many are actually
# in play) -- Disabled slots are spawned but immediately treated as if
# they'd already gone bankrupt, and Computer slots play themselves.
var player_types: Array[PlayerType] = [
	PlayerType.HUMAN, PlayerType.HUMAN, PlayerType.HUMAN, PlayerType.HUMAN,
]
