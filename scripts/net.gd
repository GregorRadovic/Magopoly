extends Node

# Networking hub for online multiplayer -- direct-IP ENet, host-authoritative.
#
# Phase 1 (this file's current scope): the lobby. Host opens a server, clients
# connect by IP, the host assigns each connecting peer to an open player slot,
# and pressing Start hands every peer into main.tscn with a matching player
# config. No in-game state is networked yet -- once main.tscn loads, the host's
# game is the only real one (see _is_authority() in main.gd).
#
# Later phases hang the intent RPCs, state snapshots, and the prompt router off
# this same autoload.

signal lobby_updated
signal join_succeeded
signal join_failed(reason: String)
signal kicked(reason: String)
# Host, in-game: a dropped client came back and reclaimed its seat. main.gd
# takes the Placeholder AI off that slot and hands control back.
signal player_reconnected(slot: int, peer_id: int)

const DEFAULT_PORT: int = 27015
# Host + 3 clients = the game's 4 player slots.
const MAX_CLIENTS: int = 3
const SLOT_COUNT: int = 4

# What a lobby slot is currently set to. HOST is always slot 0. TAKEN means a
# remote peer has claimed a slot that was OPEN. The host can freely retype
# OPEN/COMPUTER/DISABLED slots; a TAKEN one is locked until that peer leaves.
enum Slot { HOST, OPEN, TAKEN, COMPUTER, DISABLED }

# Authoritative on the host; mirrored on clients purely for lobby display.
# Index == player_id (0..3).
var slots: Array[int] = [Slot.HOST, Slot.OPEN, Slot.COMPUTER, Slot.DISABLED]
# player_id -> the multiplayer peer id controlling that slot. 1 = host,
# >1 = a client peer, 0 = nobody (an OPEN / COMPUTER / DISABLED slot).
var slot_peer: Array[int] = [1, 0, 0, 0]
# peer id -> display name, for the lobby's per-slot status text.
var peer_names: Dictionary = {1: "Host"}

var online: bool = false
var hosting: bool = false
var my_name: String = "Player"
# True once _recv_start has handed everyone into main.tscn. From then on a
# peer drop is a gameplay event (main.gd handles it), not a lobby change.
var game_started: bool = false

# --- Reconnect support (Phase 1) ---------------------------------------
# This client's stable identity for the current session, unchanged across a
# drop + rejoin (the ENet peer id changes, this doesn't). Deliberately NOT
# cleared by leave() -- a disconnected client keeps it so the host can match
# them back to their seat. Generated lazily on the first join.
var reconnect_token: String = ""
# The last host address this client dialed, so the Join screen can pre-fill it
# for a quick reconnect. Also survives leave().
var last_join_address: String = ""
# Host, lobby: peer id -> that peer's reconnect_token.
var peer_token: Dictionary = {}
# Host, in-game: reconnect_token -> player slot. Built at game start; an entry
# is removed when the host deliberately kicks that seat (note_kick), so a
# kicked player can't wander back in.
var token_slot: Dictionary = {}
# Host: the start-game config, kept so a reconnecting client can be handed
# back into main.tscn with the same setup via _recv_start.
var _started_types: Array = []
var _started_admin: bool = false
var _started_quick: bool = false
var _started_blitz: bool = false


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- Connection lifecycle -------------------------------------------------

func host_game(port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return false
	multiplayer.multiplayer_peer = peer
	online = true
	hosting = true
	_reset_slots()
	peer_names = {1: my_name}
	lobby_updated.emit()
	return true


func join_game(address: String, port: int = DEFAULT_PORT) -> bool:
	_ensure_token()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return false
	multiplayer.multiplayer_peer = peer
	online = true
	hosting = false
	last_join_address = address
	return true


func _ensure_token() -> void:
	if reconnect_token == "":
		reconnect_token = "%d-%d" % [Time.get_ticks_usec(), randi()]


func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	online = false
	hosting = false
	game_started = false
	_reset_slots()
	peer_names = {1: my_name}
	# reconnect_token / last_join_address deliberately survive -- a client that
	# just got dropped needs them to reconnect.
	peer_token.clear()
	token_slot.clear()
	lobby_updated.emit()


func _reset_slots() -> void:
	slots = [Slot.HOST, Slot.OPEN, Slot.COMPUTER, Slot.DISABLED]
	slot_peer = [1, 0, 0, 0]


# --- Host: slot management ----------------------------------------------

# Client -> host, right after it finishes connecting: claim the first open
# slot and register a display name. Once the game is running the same call
# means "I'm a dropped player trying to get back in" -- see _try_reconnect.
@rpc("any_peer", "reliable")
func _register_client(client_name: String, token: String = "") -> void:
	if not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	if game_started:
		_try_reconnect(id, client_name, token)
		return
	peer_names[id] = client_name
	peer_token[id] = token
	var placed := -1
	for i in SLOT_COUNT:
		if slots[i] == Slot.OPEN:
			slots[i] = Slot.TAKEN
			slot_peer[i] = id
			placed = i
			break
	if placed == -1:
		_kick.rpc_id(id, "The lobby is full.")
		peer_names.erase(id)
		return
	_broadcast_lobby()
	lobby_updated.emit()


func _on_peer_disconnected(id: int) -> void:
	# In-game drops are a gameplay event -- main.gd's _on_peer_gone puts a
	# Placeholder AI on the seat and the token_slot entry stays put so the
	# player can reconnect. Nothing to do here.
	if not hosting or game_started:
		return
	for i in SLOT_COUNT:
		if slot_peer[i] == id:
			slot_peer[i] = 0
			slots[i] = Slot.OPEN
	peer_names.erase(id)
	peer_token.erase(id)
	_broadcast_lobby()
	lobby_updated.emit()


# Host, in-game: `id` (a freshly connected peer) is claiming to be a player who
# dropped. If their token still maps to a seat, splice the new peer id in and
# hand them back into main.tscn; main.gd clears the Placeholder AI.
func _try_reconnect(id: int, client_name: String, token: String) -> void:
	if token == "" or not token_slot.has(token):
		_kick.rpc_id(id, "This game is already in progress.")
		return
	var slot: int = token_slot[token]
	var old_id: int = GameState.slot_peer[slot] if slot < GameState.slot_peer.size() else 0
	peer_names.erase(old_id)
	peer_token.erase(old_id)
	peer_names[id] = client_name
	peer_token[id] = token
	GameState.slot_peer[slot] = id
	if old_id > 1 and multiplayer.get_peers().has(old_id):
		multiplayer.multiplayer_peer.disconnect_peer(old_id)
	player_reconnected.emit(slot, id)
	_recv_start.rpc_id(id, _started_types, GameState.slot_peer, _started_admin, _started_quick, _started_blitz)


# Host: called just before deliberately kicking a seat, so that player can't
# use the reconnect path to rejoin.
func note_kick(slot: int) -> void:
	for t in token_slot.keys():
		if token_slot[t] == slot:
			token_slot.erase(t)


func slot_is_reconnectable(slot: int) -> bool:
	return token_slot.values().has(slot)


# Host UI: retype an OPEN/COMPUTER/DISABLED slot. Slot 0 (host) and TAKEN
# slots are immutable here.
func set_slot_kind(slot: int, kind: int) -> void:
	if not hosting or slot <= 0 or slot >= SLOT_COUNT:
		return
	if slots[slot] == Slot.TAKEN or slots[slot] == Slot.HOST:
		return
	slots[slot] = kind
	_broadcast_lobby()
	lobby_updated.emit()


func active_slot_count() -> int:
	var n := 0
	for kind in slots:
		if kind != Slot.DISABLED and kind != Slot.OPEN:
			n += 1
	return n


# --- Client: receiving lobby state ------------------------------------

func _on_connected_to_server() -> void:
	_register_client.rpc_id(1, my_name, reconnect_token)
	join_succeeded.emit()


func _on_connection_failed() -> void:
	online = false
	multiplayer.multiplayer_peer = null
	join_failed.emit("Could not connect to host.")


func _on_server_disconnected() -> void:
	online = false
	hosting = false
	multiplayer.multiplayer_peer = null
	_reset_slots()
	kicked.emit("The host closed the game.")


@rpc("authority", "reliable")
func _kick(reason: String) -> void:
	kicked.emit(reason)
	leave()


func _broadcast_lobby() -> void:
	_recv_lobby.rpc(slots, slot_peer, peer_names)


@rpc("authority", "reliable")
func _recv_lobby(new_slots: Array, new_slot_peer: Array, new_names: Dictionary) -> void:
	slots = _to_int_array(new_slots)
	slot_peer = _to_int_array(new_slot_peer)
	peer_names = new_names.duplicate()
	lobby_updated.emit()


# --- Starting the game -------------------------------------------------

func start_game(admin_mode: bool, quickstart: bool, blitzstart: bool) -> void:
	if not hosting:
		return
	var types: Array[int] = []
	for i in SLOT_COUNT:
		match slots[i]:
			Slot.HOST, Slot.TAKEN:
				types.append(GameState.PlayerType.HUMAN)
			Slot.COMPUTER:
				types.append(GameState.PlayerType.COMPUTER)
			_:
				types.append(GameState.PlayerType.DISABLED)
	# Remember which seat each connected client owns, keyed by their stable
	# token, so a reconnect can find its way back.
	token_slot.clear()
	for i in SLOT_COUNT:
		if slot_peer[i] > 1 and peer_token.has(slot_peer[i]) and peer_token[slot_peer[i]] != "":
			token_slot[peer_token[slot_peer[i]]] = i
	_recv_start.rpc(types, slot_peer, admin_mode, quickstart, blitzstart)


@rpc("authority", "call_local", "reliable")
func _recv_start(types: Array, peer_map: Array, admin_mode: bool, quickstart: bool, blitzstart: bool) -> void:
	var player_types: Array[GameState.PlayerType] = []
	for t in types:
		player_types.append(t)
	GameState.player_types = player_types
	GameState.admin_mode = admin_mode
	GameState.quickstart_mode = quickstart
	GameState.blitzstart_mode = blitzstart
	GameState.tutorial_mode = false
	GameState.online = true
	GameState.slot_peer = _to_int_array(peer_map)
	GameState.local_peer_id = multiplayer.get_unique_id()
	game_started = true
	# Host keeps the config so a reconnecting client can be re-sent this same
	# call (runs locally here too, so the host stashes it on start).
	_started_types = types.duplicate()
	_started_admin = admin_mode
	_started_quick = quickstart
	_started_blitz = blitzstart
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --- Helpers ----------------------------------------------------------

# Arrays that arrive over RPC come back untyped; the game code expects
# Array[int].
func _to_int_array(a: Array) -> Array[int]:
	var out: Array[int] = []
	for v in a:
		out.append(int(v))
	return out
