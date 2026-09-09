extends ColorRect

# A read-only rulebook viewer: six reference images the player pages through.
# Opened from the Start Menu (Rules button) and the in-game pause menu (Rules
# button). Purely cosmetic -- it never touches game state. It's a full-screen
# modal overlay (like pause_menu.tscn) that layers on top of whatever screen
# opened it; closing it just hides it again.

const PAGES: Array[Texture2D] = [
	preload("res://Magopoly Assets/Magopoly Rules/1.png"),
	preload("res://Magopoly Assets/Magopoly Rules/2.png"),
	preload("res://Magopoly Assets/Magopoly Rules/3.png"),
	preload("res://Magopoly Assets/Magopoly Rules/4.png"),
	preload("res://Magopoly Assets/Magopoly Rules/5.png"),
	preload("res://Magopoly Assets/Magopoly Rules/6.png"),
]

@onready var image_rect: TextureRect = $Panel/Margin/VBox/ImageRect
@onready var page_label: Label = $Panel/Margin/VBox/NavRow/PageLabel
@onready var left_button: Button = $Panel/Margin/VBox/NavRow/LeftButton
@onready var right_button: Button = $Panel/Margin/VBox/NavRow/RightButton
@onready var close_button: Button = $Panel/Margin/VBox/TopBar/CloseButton

# 0-based; always starts back at page 1 (index 0) each time it opens.
var _page: int = 0


func _ready() -> void:
	hide()
	left_button.pressed.connect(_prev)
	right_button.pressed.connect(_next)
	close_button.pressed.connect(close)


func open() -> void:
	_page = 0
	_refresh()
	show()
	right_button.grab_focus()


func close() -> void:
	hide()


func _prev() -> void:
	_page = (_page - 1 + PAGES.size()) % PAGES.size()
	_refresh()


func _next() -> void:
	_page = (_page + 1) % PAGES.size()
	_refresh()


func _refresh() -> void:
	image_rect.texture = PAGES[_page]
	page_label.text = "%d / %d" % [_page + 1, PAGES.size()]


# Swallow clicks on the dimmed backdrop so they never reach whatever is behind.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()


# Esc closes the viewer (and, crucially, is consumed here so it doesn't also
# reach main.gd's pause-menu toggle underneath). Runs before _unhandled_input.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		accept_event()
