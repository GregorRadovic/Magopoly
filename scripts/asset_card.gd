extends PopupPanel

# Shared with property_card.gd so every card (property, railroad, utility)
# renders at the same normalized size regardless of its own content length.
const CARD_SIZE: Vector2i = Vector2i(440, 660)

@onready var icon_rect: TextureRect = $VBox/IconRect
@onready var name_label: Label = $VBox/NameLabel
@onready var body_vbox: VBoxContainer = $VBox/BodyVBox
@onready var close_button: Button = $VBox/CloseButton


func _ready() -> void:
	close_button.pressed.connect(hide)
	# The rules text takes up the slack, so Close always sits at the bottom
	# (a tax card is only one line long).
	body_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL


func show_card(asset_name: String, icon: Texture2D, lines: Array[String]) -> void:
	fill(asset_name, icon, lines)
	popup_centered(CARD_SIZE)


# Fills in the card without showing it (show_card(), card_view()). Lines are
# left-aligned rules text, except a card with a single line (a tax: "Pay
# $200"), which is shown big and centred.
func fill(asset_name: String, icon: Texture2D, lines: Array[String]) -> void:
	name_label.text = asset_name
	icon_rect.texture = icon

	for child in body_vbox.get_children():
		body_vbox.remove_child(child)
		child.queue_free()
	for line in lines:
		var label := Label.new()
		label.text = line
		label.add_theme_color_override("font_color", Color.BLACK)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		# Without an explicit width, Godot computes this label's minimum
		# size assuming a near-zero wrap width, which massively inflates
		# its reported height and forces the popup bigger than CARD_SIZE.
		label.custom_minimum_size.x = 400
		if lines.size() == 1:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 40)
		body_vbox.add_child(label)

# A copy of this card's face (as last filled), without the Close button,
# for showing inside another popup -- the buy prompt. White card panel
# included; `scale` shrinks it, and the returned holder is sized to match.
func card_view(scale_by: float) -> Control:
	var face := PanelContainer.new()
	var style: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	style.set_content_margin_all(20)
	face.add_theme_stylebox_override("panel", style)
	var content: Control = $VBox.duplicate()
	content.remove_child(content.get_node("CloseButton"))
	face.add_child(content)
	face.size = Vector2(CARD_SIZE.x, CARD_SIZE.y - 60)
	face.scale = Vector2(scale_by, scale_by)
	var holder := Control.new()
	holder.custom_minimum_size = face.size * scale_by
	holder.add_child(face)
	return holder

