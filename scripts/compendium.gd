extends Control

# Every spell card in the game, opened from the Start Menu's "Compendium"
# button: the base game's cards first, then one section per expansion (see
# expansions.gd), each set off by a separator. Expansions the player hasn't
# unlocked yet are still shown with the level that unlocks them: each card's
# name and art stay visible, but its text is under a blurred grey "Locked"
# cover (and it can't be zoomed in on).
# Cards with more than one copy in their set say how many. Right-click a card
# to see it full size (the same spell_card popup used in-game). Back / Escape
# returns to the Start Menu.

const MINI_CARD_SCENE: PackedScene = preload("res://scenes/mini_spell_card.tscn")
# Matches the card art's aspect (mini_spell_card.tscn is 70 x 98).
const CARD_SIZE: Vector2 = Vector2(200, 280)
const LOCKED_BLUR: Shader = preload("res://scripts/locked_blur.gdshader")
# Where a locked card's cover starts, as a fraction of the card's height --
# the top of the rules text box, so the name, art and type line show.
const LOCKED_COVER_FROM: float = 0.62
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
		total += _add_section(e["name"], note, e["cards"], locked, e.get("tokens", {}))
	count_label.text = "%d cards  ·  Right-click a card to zoom in" % total


# A heading plus a grid of the set's cards (one per distinct spell), then any
# tokens it creates. In an expansion, a card from the base deck is captioned
# as an extra copy. Returns how many new distinct cards it showed.
func _add_section(title: String, note: String, cards: Dictionary, locked: bool, tokens: Dictionary = {}) -> int:
	var is_expansion: bool = cards != Expansions.BASE_CARDS
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
	sections.add_child(grid)

	var shown: int = 0
	var distinct: int = 0
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
		mini.setup(shown, icon, not locked)
		if locked:
			_add_locked_cover(mini, icon)
		else:
			mini.card_right_clicked.connect(func(_i: int) -> void: spell_card.show_card(icon))
		var copies: int = int(cards[spell_name])
		var caption_text: String = "×%d" % copies if copies > 1 else ""
		var is_base_extra: bool = is_expansion and Expansions.BASE_CARDS.has(spell_name)
		if is_base_extra:
			caption_text = "+%d extra base card" % copies if copies == 1 else "+%d extra base cards" % copies
		if caption_text != "":
			box.add_child(_caption(caption_text))
		shown += 1
		# The header's total counts distinct cards, so an extra copy of a base
		# card isn't counted again.
		if not is_base_extra:
			distinct += 1
	for token_name in tokens:
		var token_path: String = str(tokens[token_name])
		if not ResourceLoader.exists(token_path):
			continue
		var token_icon: Texture2D = load(token_path)
		var token_box := VBoxContainer.new()
		token_box.add_theme_constant_override("separation", 4)
		grid.add_child(token_box)
		var token_mini: Control = MINI_CARD_SCENE.instantiate()
		token_mini.custom_minimum_size = CARD_SIZE
		token_mini.tooltip_text = "%s (token)" % token_name
		token_box.add_child(token_mini)
		token_mini.setup(shown, token_icon, not locked)
		if locked:
			_add_locked_cover(token_mini, token_icon)
		else:
			token_mini.card_right_clicked.connect(func(_i: int) -> void: spell_card.show_card(token_icon))
		token_box.add_child(_caption("Token -- not in the deck"))
	return distinct


# A blurred grey panel over the bottom of a locked card (from the top of
# its rules text down), reading "Locked". The blur is the card's own text
# area shrunk right down and stretched back up, so nothing is readable.
func _add_locked_cover(card: Control, icon: Texture2D) -> void:
	var cover := TextureRect.new()
	cover.name = "LockedCover"
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The art is fitted inside the card slot keeping its shape (a token can
	# be a different shape from a spell card), so match the cover to the
	# picture actually drawn, not the slot.
	var art: Vector2 = icon.get_size()
	var fit: float = minf(CARD_SIZE.x / art.x, CARD_SIZE.y / art.y)
	var drawn: Vector2 = art * fit / CARD_SIZE
	var margin: Vector2 = (Vector2.ONE - drawn) / 2.0
	cover.anchor_left = margin.x
	cover.anchor_right = 1.0 - margin.x
	cover.anchor_top = margin.y + drawn.y * LOCKED_COVER_FROM
	cover.anchor_bottom = 1.0 - margin.y
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_SCALE
	cover.texture = _blurred_text_area(icon)
	var mat := ShaderMaterial.new()
	mat.shader = LOCKED_BLUR
	cover.material = mat
	card.add_child(cover)
	var label := Label.new()
	label.text = "Locked"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
	label.add_theme_constant_override("outline_size", 6)
	cover.add_child(label)


func _blurred_text_area(icon: Texture2D) -> Texture2D:
	var img: Image = icon.get_image()
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var top: int = int(h * LOCKED_COVER_FROM)
	var area: Image = img.get_region(Rect2i(0, top, w, h - top))
	var aw: int = area.get_width()
	var ah: int = area.get_height()
	# Down in steps, then back up in steps: a soft blur, not blocky pixels.
	for div in [3, 6, 12]:
		area.resize(maxi(1, aw / div), maxi(1, ah / div), Image.INTERPOLATE_BILINEAR)
	for div in [6, 3, 1]:
		area.resize(maxi(1, aw / div), maxi(1, ah / div), Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(area)


func _caption(text: String) -> Label:
	var caption := Label.new()
	caption.text = text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_color", MUTED)
	return caption


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
