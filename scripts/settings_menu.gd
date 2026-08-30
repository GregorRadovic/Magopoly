extends PopupPanel

# Small settings window opened from the Start Menu. For now it holds a single
# control: a Resolution dropdown. The picked resolution is applied immediately,
# saved to user://settings.cfg, and re-applied on the next launch via
# apply_saved() (called from start_menu.gd's _ready).
#
# "Resolution" here is the game's render resolution, not the window size: the
# window stays fullscreen and we set Window.content_scale_size (the project's
# stretch mode is "canvas_items", so the whole game is drawn at this reference
# size and scaled to fill the screen). A smaller value zooms everything in; a
# larger value shows more and looks sharper on a high-DPI display.

const CONFIG_PATH: String = "user://settings.cfg"
const POPUP_SIZE: Vector2i = Vector2i(520, 240)

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
@onready var close_button: Button = $VBox/CloseButton


func _ready() -> void:
	for res in RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [res.x, res.y])
	resolution_option.selected = _index_of(_load_resolution())
	resolution_option.item_selected.connect(_on_resolution_selected)
	close_button.pressed.connect(hide)


func open() -> void:
	popup_centered(POPUP_SIZE)


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


# Restore the saved resolution at startup. No saved value means leave the
# project default (1920x1080 render size) untouched.
static func apply_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	if not cfg.has_section_key("display", "resolution"):
		return
	_apply_resolution(cfg.get_value("display", "resolution"))
