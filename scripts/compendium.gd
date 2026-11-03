extends Control

# Every spell card in the game, opened from the Start Menu's "Compendium"
# button: the base game's cards first, then one section per expansion (see
# expansions.gd), each set off by a separator. Expansions the player hasn't
# unlocked yet are still shown, dimmed, with the level that unlocks them.
# Cards with more than one copy in their set say how many. Right-click a card
# to see it full size (the same spell_card popup used in-game). Back / Escape
# returns to the Start Menu.

const MINI_CARD_SCENE: PackedScene = preload("res://scenes/mini_spell_card.tscn")
# Matches the card art's aspect (mini_spell_card.tscn is 70 x 98).
const CARD_SIZE: Vector2 = Vector2(200, 280)
const LOCKED_TINT: Color = Color(1, 1, 1, 0.45)
const MUTED: Color = Color(0.65, 0.7, 0.8)

@onready var sections: VBoxContainer = $Margin/VBox/CardScroll/Sections
@onready var count_label: Label = $Margin/VBox/Header/CountLabel
@onready var back_button: Button = $Margin/VBox/Header/BackButton
@onready var spell_card: PopupPanel = $SpellCard


func _ready() -> void:
	back_button.pressed.connect(_go_back)
	var total: int = _add_section("Base Game", "", Expansions.BASE_CARDS, false)
	for e in Expansions.LIST:
		sections.add_child(_separator())
		var locked: bool = not Saves.is_expansion_unlocked(e["id"])
		var note: String = "%d cards" % Expansions.card_total(e["cards"])
		note += "  ·  Unlocks at level %d" % e["unlock_level"] if locked else "  ·  Unlocked"
		total += _add_section(e["name"], note, e["cards"], locked)
	count_label.text = "%d cards  ·  Right-click a card to zoom in" % total


# A heading plus a grid of the set's cards (one per distinct spell). Returns
# how many distinct cards it showed.
func _add_section(title: String, note: String, cards: Dictionary, locked: bool) -> int:
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 20)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 40)
	heading.add_child(title_label)
	if note != "":
		var note_label := Label.new()
		note_label.text = note
		note_label.size_flags_vertical = Control.SIZE_SHRINK_END
		note_label.add_theme_font_size_override("font_size", 22)
		note_label.add_theme_color_override("font_color", MUTED)
		heading.add_child(note_label)
	sections.add_child(heading)

	var grid := HFlowContainer.new()
	grid.alignment = FlowContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	if locked:
		grid.modulate = LOCKED_TINT
	sections.add_child(grid)

	var shown: int = 0
	for spell_name in cards:
		var icon_path: String = str(SpellData.SPELLS.get(spell_name, {}).get("icon", ""))
		if icon_path == "" or not ResourceLoader.exists(icon_path):
			continue
		var icon: Texture2D = load(icon_path)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		grid.add_child(box)
		var mini: Control = MINI_CARD_SCENE.instantiate()
		mini.custom_minimum_size = CARD_SIZE
		mini.tooltip_text = spell_name
		box.add_child(mini)
		# setup() after add_child so the mini's @onready refs are ready.
		mini.setup(shown, icon)
		mini.card_right_clicked.connect(func(_i: int) -> void: spell_card.show_card(icon))
		var copies: int = int(cards[spell_name])
		if copies > 1:
			var caption := Label.new()
			caption.text = "×%d" % copies
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.add_theme_font_size_override("font_size", 20)
			caption.add_theme_color_override("font_color", MUTED)
			box.add_child(caption)
		shown += 1
	return shown


func _separator() -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", 16)
	wrap.add_theme_constant_override("margin_bottom", 4)
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color(0.4, 0.42, 0.5)
	style.thickness = 2
	line.add_theme_stylebox_override("separator", style)
	wrap.add_child(line)
	return wrap


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not spell_card.visible:
		get_viewport().set_input_as_handled()
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")
