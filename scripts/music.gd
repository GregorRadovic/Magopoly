extends Node

# Background music. An autoload, so the track keeps playing seamlessly across
# scene changes (Start Menu -> game -> back to the menu). It starts on launch
# and loops forever. Volume is driven by the Settings window's "Music Volume"
# slider and persisted to user://settings.cfg alongside the resolution setting.

const CONFIG_PATH: String = "user://settings.cfg"
const TRACK_PATH: String = "res://Magopoly Assets/Music and Sounds/The Britons.mp3"
const DEFAULT_VOLUME_PERCENT: int = 100

var _player: AudioStreamPlayer
var _volume_percent: int = DEFAULT_VOLUME_PERCENT


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	var stream: AudioStream = load(TRACK_PATH)
	# The .mp3 is imported with loop=false; flip it on so playback repeats
	# forever without a gap.
	if stream is AudioStreamMP3:
		stream.loop = true
	_player.stream = stream
	add_child(_player)

	_volume_percent = _load_volume_percent()
	_apply_volume()
	_player.play()


func get_volume_percent() -> int:
	return _volume_percent


# Called by the Settings slider (0..100). Applies immediately and saves.
func set_volume_percent(percent: int) -> void:
	_volume_percent = clampi(percent, 0, 100)
	_apply_volume()
	_save_volume_percent()


func _apply_volume() -> void:
	if _volume_percent <= 0:
		_player.volume_db = -80.0
	else:
		_player.volume_db = linear_to_db(_volume_percent / 100.0)


func _load_volume_percent() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return DEFAULT_VOLUME_PERCENT
	return int(cfg.get_value("audio", "music_volume_percent", DEFAULT_VOLUME_PERCENT))


func _save_volume_percent() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)  # keep other keys (e.g. the resolution setting)
	cfg.set_value("audio", "music_volume_percent", _volume_percent)
	cfg.save(CONFIG_PATH)
