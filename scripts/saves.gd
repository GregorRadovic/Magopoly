extends Node

# Everything Magopoly remembers between runs, in the user data folder
# (user://, e.g. %APPDATA%/Godot/app_userdata/Magopoly on Windows):
#
#   autosave.save -- the game in progress, written at the start of every turn
#                    by the machine running it (local game, or the online
#                    host). "Continue" on the Start Menu resumes it.
#   session.save  -- an online client's way back into a game: the host
#                    address and the reconnect token the host knows its seat
#                    by. "Rejoin Game" on the Start Menu uses it.
#   profile.save  -- player progression: lifetime stats and recent matches.
#
# Files are written with FileAccess.store_var and read back with objects
# disabled, so types survive exactly (ints stay ints) and a tampered file
# can't smuggle in code. Writes go to a temp file first and then replace the
# old one, so a crash mid-write can't leave a half-written save behind.

const AUTOSAVE_PATH: String = "user://autosave.save"
const SESSION_PATH: String = "user://session.save"
const PROFILE_PATH: String = "user://profile.save"
# Bump when the autosave layout changes incompatibly; older saves are ignored.
const SAVE_VERSION: int = 1
const HISTORY_LIMIT: int = 20

# Set by the Start Menu's Continue just before switching to main.tscn;
# main.gd consumes it in _ready() and clears it.
var pending_load: Dictionary = {}
# Set by the Start Menu's Rejoin just before opening the Join screen, which
# then connects straight away.
var auto_rejoin: bool = false


# --- low-level ---------------------------------------------------------

func _write(path: String, data: Variant) -> bool:
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Couldn't write %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_var(data, false)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = f.get_var(false)
	f.close()
	return data if data is Dictionary else {}


func _delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# --- autosave (game in progress) ---------------------------------------

func write_autosave(data: Dictionary) -> void:
	data["version"] = SAVE_VERSION
	data["saved_at"] = int(Time.get_unix_time_from_system())
	_write(AUTOSAVE_PATH, data)


# The current autosave, or {} if there isn't a usable one.
func load_autosave() -> Dictionary:
	var data: Dictionary = _read(AUTOSAVE_PATH)
	if int(data.get("version", 0)) != SAVE_VERSION or not data.has("state"):
		return {}
	return data


func has_autosave() -> bool:
	return not load_autosave().is_empty()


func delete_autosave() -> void:
	_delete(AUTOSAVE_PATH)


# --- client rejoin session ---------------------------------------------

func save_session(address: String, token: String) -> void:
	_write(SESSION_PATH, {"address": address, "token": token,
		"saved_at": int(Time.get_unix_time_from_system())})


# {"address", "token", "saved_at"} for an unfinished online game, or {}.
func load_session() -> Dictionary:
	var data: Dictionary = _read(SESSION_PATH)
	if str(data.get("address", "")) == "" or str(data.get("token", "")) == "":
		return {}
	return data


func clear_session() -> void:
	_delete(SESSION_PATH)


# --- profile / progression ---------------------------------------------

const STAT_KEYS: Array[String] = [
	"games_played", "games_won", "games_lost", "spells_cast", "properties_bought",
]


func load_profile() -> Dictionary:
	var data: Dictionary = _read(PROFILE_PATH)
	var stats: Dictionary = data.get("stats", {})
	for k in STAT_KEYS:
		stats[k] = int(stats.get(k, 0))
	data["stats"] = stats
	if not (data.get("history", null) is Array):
		data["history"] = []
	return data


# entry: {"won": bool or null (null = several local players, no single
# result), "mode": String, "players": int, "winner": String, "turns": int,
# "spells_cast": int, "properties_bought": int}. "date" is filled in here.
func record_game(entry: Dictionary) -> void:
	var profile: Dictionary = load_profile()
	var stats: Dictionary = profile["stats"]
	stats["games_played"] += 1
	if entry.get("won") == true:
		stats["games_won"] += 1
	elif entry.get("won") == false:
		stats["games_lost"] += 1
	stats["spells_cast"] += int(entry.get("spells_cast", 0))
	stats["properties_bought"] += int(entry.get("properties_bought", 0))
	entry["date"] = int(Time.get_unix_time_from_system())
	var history: Array = profile["history"]
	history.push_front(entry)
	while history.size() > HISTORY_LIMIT:
		history.pop_back()
	_write(PROFILE_PATH, profile)
