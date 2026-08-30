extends Node

# Set by the Start Menu before loading main.tscn. Admin Mode keeps the
# Admin / Admin Properties buttons (dice/property overrides used for
# testing); NonAdmin Mode hides them for normal play.
var admin_mode: bool = false

enum PlayerType { HUMAN, DISABLED, COMPUTER }

# The most player slots the game supports. All the per-player containers
# (player_types, slot_peer, main.gd's colour/name/marker tables) are sized to
# this; a game with fewer real players just fills the rest with Disabled.
const MAX_PLAYERS: int = 8

# One entry per player slot (always MAX_PLAYERS, regardless of how many are
# actually in play) -- Disabled slots are spawned but immediately treated as
# if they'd already gone bankrupt, and Computer slots play themselves. The
# Start Menu overwrites this before loading main.tscn; this default only
# matters if main.tscn is ever run directly (P1 Human, P2 Computer, rest
# Disabled).
var player_types: Array[PlayerType] = [
	PlayerType.HUMAN, PlayerType.COMPUTER, PlayerType.DISABLED, PlayerType.DISABLED,
	PlayerType.DISABLED, PlayerType.DISABLED, PlayerType.DISABLED, PlayerType.DISABLED,
]

# If true, every active player starts with 3 random properties and 2 random
# spells instead of the normal empty-handed, property-less start. Set by the
# Start Menu's Quickstart Mode checkbox.
var quickstart_mode: bool = false

# Like Quickstart but bigger: every active player starts with 6 random
# properties and 4 random spells. If both this and quickstart_mode are set,
# BlitzStart wins.
var blitzstart_mode: bool = false

# Tutorial mode (Main Menu > Tutorial): a one-human, one-Computer game that
# walks the player through a fixed script of moves. See main.gd's
# TUTORIAL_STEPS. Overrides the Quickstart / BlitzStart toggles.
var tutorial_mode: bool = false

# --- Online play (set by Net._recv_start; see net.gd) ------------------
# True when this session was launched from the online lobby rather than the
# local Start Menu. Local games leave all of these at their defaults, and
# is_slot_local() then reports every slot as local (the existing
# single-machine behavior).
var online: bool = false
# player_id -> the multiplayer peer id controlling that slot (1 = host,
# >1 = a client, 0 = an AI / disabled slot). Mirrors Net.slot_peer at the
# moment the game started.
var slot_peer: Array[int] = [1, 0, 0, 0, 0, 0, 0, 0]
# This machine's own multiplayer peer id (1 on the host).
var local_peer_id: int = 1


# Whether the given player slot is controlled from this machine. In a local
# game every human slot is at this one keyboard, so this is always true;
# online, only the slots whose controlling peer is us.
func is_slot_local(player_id: int) -> bool:
	if not online:
		return true
	return player_id >= 0 and player_id < slot_peer.size() and slot_peer[player_id] == local_peer_id


# Whether this machine runs the authoritative simulation. Always true for a
# local game; online, true only on the host (peer id 1).
func is_authority() -> bool:
	return not online or local_peer_id == 1


# The player slots this machine controls (online only; empty for a local
# game, where "local" isn't slot-specific).
func local_slots() -> Array[int]:
	var out: Array[int] = []
	if not online:
		return out
	for i in slot_peer.size():
		if slot_peer[i] == local_peer_id:
			out.append(i)
	return out
