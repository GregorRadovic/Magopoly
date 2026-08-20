extends PopupPanel

# Shared with property_card.gd so every card (property, railroad, utility)
# renders at the same normalized size regardless of its own content length.
const CARD_SIZE: Vector2i = Vector2i(440, 620)

@onready var icon_rect: TextureRect = $VBox/IconRect
@onready var name_label: Label = $VBox/NameLabel
@onready var body_vbox: VBoxContainer = $VBox/BodyVBox
@onready var close_button: Button = $VBox/CloseButton


func _ready() -> void:
	close_button.pressed.connect(hide)


func show_card(asset_name: String, icon: Texture2D, lines: Array[String]) -> void:
	name_label.text = asset_name
	icon_rect.texture = icon

	for child in body_vbox.get_children():
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
		body_vbox.add_child(label)

	popup_centered(CARD_SIZE)
