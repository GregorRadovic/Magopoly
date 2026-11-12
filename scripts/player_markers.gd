class_name PlayerMarkers
extends RefCounted

# The playing pieces a player can choose to move around the board (like the
# original Monopoly tokens). Each is line art on a transparent background,
# drawn tinted toward the player's colour (see player.gd). Every seat has a
# different one -- the setup screens never allow repeats.

const DIR: String = "res://Magopoly Assets/Player Markers/"
const LIST: Array[String] = [
	"Top Hat", "Race Car", "Scottie Dog", "Battleship",
	"Boot", "Thimble", "Iron", "Wheelbarrow",
]


# Seat i's marker if nobody has chosen one.
static func defaults() -> Array[String]:
	return LIST.duplicate()


static func icon_path(marker: String) -> String:
	return DIR + marker + ".png"


static func icon(marker: String) -> Texture2D:
	if not LIST.has(marker):
		return null
	return load(icon_path(marker))


# `picks` with any blank, unknown or repeated entry replaced by the first
# marker no other seat is using -- so every seat ends up with its own.
static func make_unique(picks: Array) -> Array[String]:
	var out: Array[String] = []
	var used: Dictionary = {}
	for i in picks.size():
		var m: String = str(picks[i])
		if not LIST.has(m) or used.has(m):
			m = ""
		out.append(m)
		if m != "":
			used[m] = true
	for i in out.size():
		if out[i] == "":
			for m in LIST:
				if not used.has(m):
					out[i] = m
					used[m] = true
					break
	return out


# --- Setup-screen dropdown ----------------------------------------------

# A dropdown of every marker (icon + name), with `marker` selected.
static func make_option(marker: String) -> OptionButton:
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(230, 44)
	opt.add_theme_font_size_override("font_size", 20)
	opt.add_theme_constant_override("icon_max_width", 34)
	opt.tooltip_text = "Your playing piece. Each player needs a different one."
	var popup: PopupMenu = opt.get_popup()
	popup.add_theme_font_size_override("font_size", 20)
	for i in LIST.size():
		opt.add_icon_item(icon(LIST[i]), LIST[i], i)
		popup.set_item_icon_max_width(i, 34)
	select(opt, marker)
	return opt


static func selected(opt: OptionButton) -> String:
	return LIST[opt.selected] if opt.selected >= 0 and opt.selected < LIST.size() else ""


static func select(opt: OptionButton, marker: String) -> void:
	var i: int = LIST.find(marker)
	if i != -1:
		opt.select(i)


# Grey out the markers in `taken` (other seats' picks) -- except this
# dropdown's own current choice.
static func set_taken(opt: OptionButton, taken: Array) -> void:
	var mine: String = selected(opt)
	for i in LIST.size():
		opt.set_item_disabled(i, LIST[i] != mine and taken.has(LIST[i]))
