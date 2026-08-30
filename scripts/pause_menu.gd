extends Control

# The in-game pause menu (opened with Esc -- see main.gd's _unhandled_input).
# It's a modal overlay, not a real SceneTree pause: the game is turn-based and
# already sitting idle when Esc is pressed, so this just dims the board and
# blocks input until the player picks an option.
#
#   Resume            -- close the menu, back to the game
#   Settings          -- opens the same window as the Start Menu's Settings
#                        button, layered on top; closing it returns here
#   Quit to Main Menu -- main.gd tears down the session and loads start_menu
#   Quit to Desktop   -- main.gd quits the application

signal resumed
signal quit_to_menu_requested
signal quit_to_desktop_requested

@onready var resume_button: Button = $Panel/Margin/VBox/ResumeButton
@onready var settings_button: Button = $Panel/Margin/VBox/SettingsButton
@onready var quit_to_menu_button: Button = $Panel/Margin/VBox/QuitToMenuButton
@onready var quit_to_desktop_button: Button = $Panel/Margin/VBox/QuitToDesktopButton

# The shared SettingsMenu popup (also in main.tscn); handed to us by main.gd.
var _settings_menu: PopupPanel


func _ready() -> void:
	hide()
	resume_button.pressed.connect(close)
	settings_button.pressed.connect(_open_settings)
	quit_to_menu_button.pressed.connect(func() -> void:
		hide()
		quit_to_menu_requested.emit())
	quit_to_desktop_button.pressed.connect(func() -> void:
		hide()
		quit_to_desktop_requested.emit())


func set_settings_menu(menu: PopupPanel) -> void:
	_settings_menu = menu


func open() -> void:
	show()
	resume_button.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	resumed.emit()


func _open_settings() -> void:
	if _settings_menu != null:
		_settings_menu.open()


# Swallow clicks on the dimmed backdrop so they never reach the board beneath.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
