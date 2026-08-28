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
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return false
	multiplayer.multiplayer_peer = peer
	online = true
	hosting = false
	return true


func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	online = false
	hosting = false
	game_started = false
	_reset_slots()
	peer_names = {1: my_name}
	lobby_updated.emit()


func _reset_slots() -> void:
	slots = [Slot.HOST, Slot.OPEN, Slot.COMPUTER, Slot.DISABLED]
	slot_peer = [1, 0, 0, 0]


# --- Host: slot management ----------------------------------------------

# Client -> host, right after it finishes connecting: claim the first open
# slot and register a display name.
@rpc("any_peer", "reliable")
func _register_client(client_name: String) -> void:
	if not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	peer_names[id] = client_name
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
	if not hosting or game_started:
		return
	for i in SLOT_COUNT:
		if slot_peer[i] == id:
			slot_peer[i] = 0
			slots[i] = Slot.OPEN
	peer_names.erase(id)
	_broadcast_lobby()
	lobby_updated.emit()


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
	_register_client.rpc_id(1, my_name)
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

func start_game(admin_mode: bool, quickstart: bool) -> void:
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
	_recv_start.rpc(types, slot_peer, admin_mode, quickstart)


@rpc("authority", "call_local", "reliable")
func _recv_start(types: Array, peer_map: Array, admin_mode: bool, quickstart: bool) -> void:
	var player_types: Array[GameState.PlayerType] = []
	for t in types:
		player_types.append(t)
	GameState.player_types = player_types
	GameState.admin_mode = admin_mode
	GameState.quickstart_mode = quickstart
	GameState.online = true
	GameState.slot_peer = _to_int_array(peer_map)
	GameState.local_peer_id = multiplayer.get_unique_id()
	game_started = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --- Helpers ----------------------------------------------------------

# Arrays that arrive over RPC come back untyped; the game code expects
# Array[int].
func _to_int_array(a: Array) -> Array[int]:
	var out: Array[int] = []
	for v in a:
		out.append(int(v))
	return out
