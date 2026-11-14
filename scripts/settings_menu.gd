extends PopupPanel

# Small settings window opened from the Start Menu and the in-game pause menu.
# Controls: Resolution, Music Volume, Pause Options, Wizard Vision and the
# Roll / Spell Response Windows. All are applied
# immediately, saved to user://settings.cfg, and restored on the next launch
# (resolution via apply_saved() from start_menu.gd; music volume by the Music
# autoload; pause option read by main.gd, live via pause_option_changed).
#
# "Resolution" here is the game's render resolution, not the window size: the
# window stays fullscreen and we set Window.content_scale_size (the project's
# stretch mode is "canvas_items", so the whole game is drawn at this reference
# size and scaled to fill the screen). A smaller value zooms everything in; a
# larger value shows more and looks sharper on a high-DPI display.
#
# The "Host tools" section is hidden by default and only revealed in-game, for
# the host of a multiplayer match (main.gd calls enable_host_tools()). Each
# button just fires a signal main.gd acts on -- see there.

signal kick_player_requested
signal take_player_turn_requested
signal unpause_player_requested
# Fired when the Pause Options dropdown changes (in-game so main.gd can react
# live). MANUAL = 0, HALF_CONTROL = 1, FULL_CONTROL = 2.
signal pause_option_changed(option: int)
# Fired when the Wizard Vision checkbox is toggled (main.gd reacts live).
signal wizard_vision_changed(on: bool)
# Fired when the Roll Response Window changes (main.gd reacts live).
signal response_time_changed(seconds: float)
# Fired when the Spell Response Window changes (main.gd reacts live).
signal spell_response_time_changed(seconds: float)

# Roll Response Window ("response_time" in the config): how long a rolled
# piece walks -- and so how long everyone has to pause and react -- after the
# dice's fixed 0.5 s tumble.
const RESPONSE_TIMES: Array[float] = [0.0, 0.5, 1.0, 1.5]
const DEFAULT_RESPONSE_TIME: float = 1.5
# Spell Response Window: how long everyone has to react to a spell being
# cast (and to each one resolving).
const SPELL_RESPONSE_TIMES: Array[float] = [1.0, 2.0, 3.0]
const DEFAULT_SPELL_RESPONSE_TIME: float = 2.0
# In an online game both windows are the host's to set: a client's dropdowns
# show the host's values and are locked (set_host_controlled()).
const HOST_CONTROLLED_TIP: String = "Set by the host in an online game."

enum PauseOption { MANUAL, HALF_CONTROL, FULL_CONTROL }
const PAUSE_OPTION_LABELS: Array[String] = ["Manual", "Half-Control", "Full Control"]

const CONFIG_PATH: String = "user://settings.cfg"
const POPUP_SIZE: Vector2i = Vector2i(600, 554)
# Extra height when the Host tools section is showing.
const HOST_TOOLS_EXTRA_HEIGHT: int = 270

# Ordered list shown in the dropdown. The first entry is the project default
# (see project.godot's window/size/viewport_*).
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1280, 800),
	Vector2i(1920, 1200),
	Vector2i(2560, 1600),
]

@onready var resolution_option: OptionButton = $VBox/ResolutionRow/ResolutionOption
@onready var music_volume_slider: HSlider = $VBox/MusicVolumeRow/MusicVolumeSlider
@onready var music_volume_value: Label = $VBox/MusicVolumeRow/MusicVolumeValue
@onready var pause_option_button: OptionButton = $VBox/PauseOptionsRow/PauseOptionButton
@onready var wizard_vision_check: CheckBox = $VBox/WizardVisionRow/WizardVisionCheck
@onready var response_time_option: OptionButton = $VBox/ResponseTimeRow/ResponseTimeOption
@onready var spell_response_option: OptionButton = $VBox/SpellResponseRow/SpellResponseOption
@onready var host_tools: VBoxContainer = $VBox/HostTools
@onready var kick_player_button: Button = $VBox/HostTools/KickPlayerButton
@onready var take_player_turn_button: Button = $VBox/HostTools/TakePlayerTurnButton
@onready var unpause_player_button: Button = $VBox/HostTools/UnpausePlayerButton
@onready var close_button: Button = $VBox/CloseButton

# The current Pause Options selection (mirrors the dropdown; read by main.gd).
var pause_option: int = PauseOption.MANUAL
# Wizard Vision on/off (the roll-prediction arrow + landing highlight). Read
# by main.gd, kept live via wizard_vision_changed. Default on.
var wizard_vision_on: bool = true


func _ready() -> void:
	for res in RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [res.x, res.y])
	resolution_option.selected = _index_of(_load_resolution())
	resolution_option.item_selected.connect(_on_resolution_selected)

	var volume: int = Music.get_volume_percent()
	music_volume_slider.value = volume
	_update_volume_label(volume)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)

	for label in PAUSE_OPTION_LABELS:
		pause_option_button.add_item(label)
	pause_option = load_pause_option()
	pause_option_button.selected = pause_option
	pause_option_button.item_selected.connect(_on_pause_option_selected)

	wizard_vision_on = load_wizard_vision()
	wizard_vision_check.button_pressed = wizard_vision_on
	wizard_vision_check.toggled.connect(_on_wizard_vision_toggled)

	for sec in RESPONSE_TIMES:
		response_time_option.add_item((String.num(sec) + "s") if sec > 0.0 else "0s (dice only)")
	response_time_option.selected = maxi(0, RESPONSE_TIMES.find(load_response_time()))
	response_time_option.tooltip_text = ROLL_TIP
	response_time_option.item_selected.connect(func(i: int) -> void:
		var sec: float = RESPONSE_TIMES[i]
		_save_response_time(sec)
		response_time_changed.emit(sec))

	for sec in SPELL_RESPONSE_TIMES:
		spell_response_option.add_item(String.num(sec) + "s")
	spell_response_option.selected = maxi(0, SPELL_RESPONSE_TIMES.find(load_spell_response_time()))
	spell_response_option.tooltip_text = SPELL_TIP
	spell_response_option.item_selected.connect(func(i: int) -> void:
		var sec: float = SPELL_RESPONSE_TIMES[i]
		_save_spell_response_time(sec)
		spell_response_time_changed.emit(sec))

	host_tools.visible = false
	kick_player_button.pressed.connect(func() -> void:
		hide()
		kick_player_requested.emit())
	take_player_turn_button.pressed.connect(func() -> void:
		hide()
		take_player_turn_requested.emit())
	unpause_player_button.pressed.connect(func() -> void:
		hide()
		unpause_player_requested.emit())

	close_button.pressed.connect(hide)


const ROLL_TIP: String = "How long the piece walks after the dice land -- the time everyone has to pause and react. (The dice always take 0.5 s on top.)"
const SPELL_TIP: String = "How long everyone has to pause and react when a spell is cast, and again as each one resolves."


# Called by main.gd in a multiplayer game, on the host only.
func enable_host_tools() -> void:
	host_tools.visible = true


# Online client: both response windows belong to the host -- lock the
# dropdowns. Their selections then follow show_host_values().
func set_host_controlled(locked: bool) -> void:
	response_time_option.disabled = locked
	spell_response_option.disabled = locked
	response_time_option.tooltip_text = HOST_CONTROLLED_TIP if locked else ROLL_TIP
	spell_response_option.tooltip_text = HOST_CONTROLLED_TIP if locked else SPELL_TIP


# Shows the host's values on a client (not saved -- the client's own saved
# choices come back once it plays offline or hosts).
func show_host_values(roll_seconds: float, spell_seconds: float) -> void:
	var r: int = RESPONSE_TIMES.find(roll_seconds)
	if r != -1:
		response_time_option.selected = r
	var s: int = SPELL_RESPONSE_TIMES.find(spell_seconds)
	if s != -1:
		spell_response_option.selected = s


func _on_music_volume_changed(value: float) -> void:
	var percent: int = int(round(value))
	Music.set_volume_percent(percent)
	_update_volume_label(percent)


func _on_pause_option_selected(index: int) -> void:
	pause_option = index
	_save_pause_option(index)
	pause_option_changed.emit(index)


func _on_wizard_vision_toggled(on: bool) -> void:
	wizard_vision_on = on
	_save_wizard_vision(on)
	wizard_vision_changed.emit(on)


func _update_volume_label(percent: int) -> void:
	music_volume_value.text = "%d%%" % percent


func open() -> void:
	var size: Vector2i = POPUP_SIZE
	if host_tools.visible:
		size.y += HOST_TOOLS_EXTRA_HEIGHT
	popup_centered(size)


func _on_resolution_selected(index: int) -> void:
	var res: Vector2i = RESOLUTIONS[index]
	_apply_resolution(res)
	_save_resolution(res)


func _index_of(res: Vector2i) -> int:
	var i: int = RESOLUTIONS.find(res)
	return i if i != -1 else 0


# Set the game's render resolution. The window is left as-is (fullscreen); the
# "canvas_items" stretch mode scales this reference size to fill the screen.
static func _apply_resolution(res: Vector2i) -> void:
	var win: Window = (Engine.get_main_loop() as SceneTree).root
	win.content_scale_size = res


static func _load_resolution() -> Vector2i:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return RESOLUTIONS[0]
	return cfg.get_value("display", "resolution", RESOLUTIONS[0])


static func _save_resolution(res: Vector2i) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)  # keep any other keys; a missing file just starts fresh
	cfg.set_value("display", "resolution", res)
	cfg.save(CONFIG_PATH)


# Pause Options: MANUAL / HALF_CONTROL / FULL_CONTROL (see PauseOption).
# Defaults to MANUAL when nothing is saved yet.
static func load_pause_option() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return PauseOption.MANUAL
	return clampi(int(cfg.get_value("gameplay", "pause_option", PauseOption.MANUAL)), 0, 2)


static func _save_pause_option(option: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("gameplay", "pause_option", option)
	cfg.save(CONFIG_PATH)


static func load_response_time() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return DEFAULT_RESPONSE_TIME
	var sec: float = float(cfg.get_value("gameplay", "response_time", DEFAULT_RESPONSE_TIME))
	return sec if RESPONSE_TIMES.has(sec) else DEFAULT_RESPONSE_TIME


static func _save_response_time(sec: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("gameplay", "response_time", sec)
	cfg.save(CONFIG_PATH)


static func load_spell_response_time() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return DEFAULT_SPELL_RESPONSE_TIME
	var sec: float = float(cfg.get_value("gameplay", "spell_response_time", DEFAULT_SPELL_RESPONSE_TIME))
	return sec if SPELL_RESPONSE_TIMES.has(sec) else DEFAULT_SPELL_RESPONSE_TIME


static func _save_spell_response_time(sec: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("gameplay", "spell_response_time", sec)
	cfg.save(CONFIG_PATH)


# Wizard Vision on/off. Defaults on when nothing is saved yet.
static func load_wizard_vision() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return true
	return bool(cfg.get_value("gameplay", "wizard_vision", true))


static func _save_wizard_vision(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("gameplay", "wizard_vision", on)
	cfg.save(CONFIG_PATH)


# Restore the saved resolution at startup. No saved value means leave the
# project default (1920x1080 render size) untouched.
static func apply_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	if not cfg.has_section_key("display", "resolution"):
		return
	_apply_resolution(cfg.get_value("display", "resolution"))
