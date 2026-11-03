class_name ExpansionPicker
extends HBoxContainer

# The "Expansions:" row on the Local Game and Host Game setup screens: one
# checkbox per expansion this player has unlocked (see expansions.gd /
# Saves.unlocked_expansions()). Checked ones add their cards to the Spell
# Deck when the game starts. With nothing unlocked yet, it says what the
# next expansion takes instead.

var _boxes: Dictionary = {}  # expansion id -> CheckBox


func _ready() -> void:
	add_theme_constant_override("separation", 30)
	alignment = BoxContainer.ALIGNMENT_CENTER  # like the mode checkboxes above
	var heading := Label.new()
	heading.text = "Expansions:"
	heading.add_theme_font_size_override("font_size", 24)
	add_child(heading)

	var unlocked: Array[Dictionary] = Saves.unlocked_expansions()
	for e in unlocked:
		var box := CheckBox.new()
		box.text = "%s (%d cards)" % [e["name"], Expansions.card_total(e["cards"])]
		box.tooltip_text = str(e.get("description", ""))
		box.add_theme_font_size_override("font_size", 24)
		add_child(box)
		_boxes[e["id"]] = box

	if unlocked.is_empty():
		var hint := Label.new()
		hint.add_theme_font_size_override("font_size", 20)
		hint.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
		var next: Dictionary = _next_locked()
		hint.text = "Reach level %d to unlock the %s." % [next["unlock_level"], next["name"]] if not next.is_empty() else "None yet."
		add_child(hint)


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
