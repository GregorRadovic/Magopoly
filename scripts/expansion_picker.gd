class_name ExpansionPicker
extends VBoxContainer

# The Expansions picker on the Local Game and Host Game setup screens: an
# "Expansions" heading, then one checkbox (with the expansion's icon) per
# expansion this player has unlocked (see expansions.gd /
# Saves.unlocked_expansions()), and a Select All / Unselect All button.
# Checked ones add their cards to the Spell Deck when the game starts. With
# nothing unlocked yet, it says what the next expansion takes instead.

const FONT_SIZE: int = 24
# Icons are drawn about as tall as the text.
const ICON_SIZE: int = 30

# Expansion id -> its icon.
const ICONS: Dictionary = {
	"free_parking": "res://Magopoly Assets/Free Parking.png",
	"jail": "res://Magopoly Assets/In Jail.png",
	"dice": "res://Magopoly Assets/Icons/dice.svg",
	"ongoing": "res://Magopoly Assets/Icons/fire.svg",
	"landmarks": "res://Magopoly Assets/Icons/target.svg",
}

var _boxes: Dictionary = {}  # expansion id -> CheckBox
var _all_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var heading := Label.new()
	heading.text = "Expansions"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", FONT_SIZE)
	add_child(heading)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER  # like the mode checkboxes above
	row.add_theme_constant_override("separation", 30)
	add_child(row)

	var unlocked: Array[Dictionary] = Saves.unlocked_expansions()
	for e in unlocked:
		var box := CheckBox.new()
		box.text = str(e["name"])
		box.tooltip_text = str(e.get("description", ""))
		box.add_theme_font_size_override("font_size", FONT_SIZE)
		var icon_path: String = ICONS.get(e["id"], "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			box.icon = _icon(icon_path)
			box.add_theme_constant_override("h_separation", 8)
		box.toggled.connect(func(_on: bool) -> void: _update_all_button())
		row.add_child(box)
		_boxes[e["id"]] = box

	if unlocked.is_empty():
		var hint := Label.new()
		hint.add_theme_font_size_override("font_size", 20)
		hint.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
		var next: Dictionary = _next_locked()
		hint.text = "Reach level %d to unlock the %s." % [next["unlock_level"], next["name"]] if not next.is_empty() else "None yet."
		row.add_child(hint)
		return

	_all_button = Button.new()
	_all_button.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	_all_button.pressed.connect(_on_all_pressed)
	row.add_child(_all_button)
	_update_all_button()


# The icon shrunk to ICON_SIZE (a corner tile like Free Parking is a big
# picture; the button would otherwise draw it full size).
func _icon(path: String) -> Texture2D:
	var tex: Texture2D = load(path)
	var img: Image = tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


func _all_selected() -> bool:
	for id in _boxes:
		if not (_boxes[id] as CheckBox).button_pressed:
			return false
	return true


func _update_all_button() -> void:
	if _all_button:
		_all_button.text = "Unselect All" if _all_selected() else "Select All"


func _on_all_pressed() -> void:
	var select: bool = not _all_selected()
	for id in _boxes:
		(_boxes[id] as CheckBox).button_pressed = select
	_update_all_button()


# Ids of the checked expansions, in release order.
func selected_ids() -> Array[String]:
	var out: Array[String] = []
	for e in Expansions.LIST:
		if _boxes.has(e["id"]) and (_boxes[e["id"]] as CheckBox).button_pressed:
			out.append(e["id"])
	return out


func _next_locked() -> Dictionary:
	var best: Dictionary = {}
	for e in Expansions.LIST:
		if not Saves.is_expansion_unlocked(e["id"]):
			if best.is_empty() or int(e["unlock_level"]) < int(best["unlock_level"]):
				best = e
	return best
