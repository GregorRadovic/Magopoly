extends PopupPanel

# -1 means no player was chosen (Cancel, or dismissed some other way).
signal player_chosen(index: int)

var _answered: bool = false

@onready var prompt_label: Label = $VBox/PromptLabel
@onready var button_container: VBoxContainer = $VBox/ButtonContainer
@onready var cancel_button: Button = $VBox/CancelButton


func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel)
	popup_hide.connect(_on_popup_hide)


# entries: Array of {"index": int, "name": String, "color": Color}
func open(prompt: String, entries: Array) -> void:
	prompt_label.text = prompt
	_answered = false
	for child in button_container.get_children():
		child.queue_free()
	for entry in entries:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 50)
		btn.text = entry["name"]
		btn.add_theme_color_override("font_color", entry["color"])
		btn.pressed.connect(_on_pick.bind(entry["index"]))
		button_container.add_child(btn)
	popup_centered(Vector2i(420, 320))


func _on_pick(index: int) -> void:
	_answered = true
	hide()
	player_chosen.emit(index)


func _on_cancel() -> void:
	_answered = true
	hide()
	player_chosen.emit(-1)


# Dismissed some other way (e.g. clicking outside it). Treat the same as
# Cancel so callers awaiting `player_chosen` never hang.
func _on_popup_hide() -> void:
	if not _answered:
		player_chosen.emit(-1)
