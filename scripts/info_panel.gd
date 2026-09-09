extends ColorRect

# A plain read-only text panel (Credits, Roadmap) opened from the Start Menu.
# Full-screen dimmed modal overlay, same pattern as rules_viewer.tscn. One
# instance is reused for every section -- open(title, bbcode_text) swaps the
# contents. Purely informational; touches no game state.

@onready var title_label: Label = $Panel/Margin/VBox/TopBar/TitleLabel
@onready var close_button: Button = $Panel/Margin/VBox/TopBar/CloseButton
@onready var body: RichTextLabel = $Panel/Margin/VBox/Scroll/Body


func _ready() -> void:
	hide()
	close_button.pressed.connect(close)
	# Links in the text ([url]...[/url]) open in the player's browser.
	body.meta_clicked.connect(func(meta: Variant) -> void: OS.shell_open(str(meta)))


func open(title: String, bbcode_text: String) -> void:
	title_label.text = title
	body.text = bbcode_text
	$Panel/Margin/VBox/Scroll.scroll_vertical = 0
	show()
	close_button.grab_focus()


func close() -> void:
	hide()


# Swallow clicks on the dimmed backdrop so they never reach the menu behind.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		accept_event()
