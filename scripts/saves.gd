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
#   profile.save  -- the player profile: name, level / experience, lifetime
#                    stats and recent matches.
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

# Experience is kept in half-levels (an int, so it never drifts): a win is
# worth a full level (2), a loss half a level (1). Level = half-levels / 2.
const XP_WIN: int = 2
const XP_LOSS: int = 1
# A hotseat game with several humans on this machine has no single winner
# to credit; it's worth the same as a loss (still a finished game).
const XP_SHARED: int = 1
const NAME_MAX_LENGTH: int = 16

# Features unlocked by level. Each entry:
#   {"level": int, "id": String, "name": String, "description": String}
# Expansions and heroes don't go here -- each one's unlock comes from its
# own entry in expansions.gd / heroes.gd (see all_unlocks()). Check any unlock with
# Saves.is_unlocked("id"); the Player Profile lists them all and the
# end-of-game popup announces any newly reached.
const UNLOCKS: Array[Dictionary] = []


# UNLOCKS plus one per expansion and per hero, sorted by level.
func all_unlocks() -> Array[Dictionary]:
	var out: Array[Dictionary] = UNLOCKS.duplicate()
	for e in Expansions.LIST:
		out.append({
			"level": int(e["unlock_level"]),
			"id": Expansions.unlock_id(e["id"]),
			"name": e["name"],
			"description": "%d new cards you can add to the Spell Deck when starting a game." % Expansions.card_total(e["cards"]),
		})
	for h in Heroes.LIST:
		out.append({
			"level": int(h["unlock_level"]),
			"id": Heroes.unlock_id(h["id"]),
			"name": "Hero: %s" % h["name"],
			"description": str(h["description"]),
		})
	out.sort_custom(func(a, b): return int(a["level"]) < int(b["level"]))
	return out


func is_hero_unlocked(hero_id: String) -> bool:
	return is_unlocked(Heroes.unlock_id(hero_id))


func is_expansion_unlocked(expansion_id: String) -> bool:
	return is_unlocked(Expansions.unlock_id(expansion_id))


# The expansions this player can switch on, in release order.
func unlocked_expansions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in Expansions.LIST:
		if is_expansion_unlocked(e["id"]):
			out.append(e)
	return out

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
	data["xp"] = maxi(0, int(data.get("xp", 0)))
	data["name"] = str(data.get("name", ""))
	return data


func get_level() -> int:
	return level_of(load_profile()["xp"])


static func level_of(xp_halves: int) -> int:
	return xp_halves / 2


# 0.0 .. <1.0: how far into the current level.
static func level_progress(xp_halves: int) -> float:
	return (xp_halves % 2) / 2.0


func is_unlocked(feature_id: String) -> bool:
	var level: int = get_level()
	for u in all_unlocks():
		if u["id"] == feature_id:
			return level >= int(u["level"])
	return true


# The unlocks reached by going from one level to a higher one.
func unlocks_between(old_level: int, new_level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in all_unlocks():
		if int(u["level"]) > old_level and int(u["level"]) <= new_level:
			out.append(u)
	return out


# The name typed in the profile, or "" if none was set.
func get_player_name() -> String:
	return load_profile()["name"]


func set_player_name(new_name: String) -> String:
	# No [ ] -- names go into the BBCode game log.
	var clean: String = new_name.replace("[", "").replace("]", "").strip_edges().left(NAME_MAX_LENGTH)
	var profile: Dictionary = load_profile()
	profile["name"] = clean
	_write(PROFILE_PATH, profile)
	return clean


# entry: {"won": bool or null (null = several local players, no single
# result), "mode": String, "players": int, "winner": String, "turns": int,
# "spells_cast": int, "properties_bought": int}. "date" is filled in here.
# Returns the experience change, for the end-of-game bar:
# {"xp_before": int, "xp_after": int} (both in half-levels).
func record_game(entry: Dictionary) -> Dictionary:
	var profile: Dictionary = load_profile()
	var stats: Dictionary = profile["stats"]
	stats["games_played"] += 1
	if entry.get("won") == true:
		stats["games_won"] += 1
	elif entry.get("won") == false:
		stats["games_lost"] += 1
	stats["spells_cast"] += int(entry.get("spells_cast", 0))
	stats["properties_bought"] += int(entry.get("properties_bought", 0))
	var xp_before: int = profile["xp"]
	var gained: int = XP_SHARED
	if entry.get("won") == true:
		gained = XP_WIN
	elif entry.get("won") == false:
		gained = XP_LOSS
	profile["xp"] = xp_before + gained
	entry["xp_gained"] = gained
	entry["date"] = int(Time.get_unix_time_from_system())
	var history: Array = profile["history"]
	history.push_front(entry)
	while history.size() > HISTORY_LIMIT:
		history.pop_back()
	_write(PROFILE_PATH, profile)
	return {"xp_before": xp_before, "xp_after": profile["xp"]}
