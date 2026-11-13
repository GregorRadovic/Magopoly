extends PopupPanel

# Shared with asset_card.gd so every card (property, railroad, utility)
# renders at the same normalized size regardless of its own content length.
const CARD_SIZE: Vector2i = Vector2i(440, 660)

@onready var header_panel: ColorRect = $VBox/HeaderPanel
@onready var name_label: Label = $VBox/HeaderPanel/HeaderVBox/NameLabel
@onready var rent_label: Label = $VBox/RentLabel
@onready var rent_color_set_label: Label = $VBox/RentColorSetLabel
@onready var rent1_label: Label = $VBox/Rent1Label
@onready var rent2_label: Label = $VBox/Rent2Label
@onready var rent3_label: Label = $VBox/Rent3Label
@onready var rent4_label: Label = $VBox/Rent4Label
@onready var rent5_label: Label = $VBox/Rent5Label
@onready var price_label: Label = $VBox/PriceLabel
@onready var mortgage_label: Label = $VBox/MortgageLabel
@onready var unmortgage_label: Label = $VBox/UnmortgageLabel
@onready var house_cost_label: Label = $VBox/HouseCostLabel
@onready var close_button: Button = $VBox/CloseButton


func _ready() -> void:
	close_button.pressed.connect(hide)


func show_card(property_name: String, header_color: Color, rents: Array, price: int, house_cost: int, mortgage_value: int, unmortgage_value: int) -> void:
	fill(property_name, header_color, rents, price, house_cost, mortgage_value, unmortgage_value)
	popup_centered(CARD_SIZE)


# Fills in the card without showing it (show_card(), card_view()).
func fill(property_name: String, header_color: Color, rents: Array, price: int, house_cost: int, mortgage_value: int, unmortgage_value: int) -> void:
	name_label.text = property_name
	header_panel.color = header_color
	rent_label.text = "Rent: $%d" % rents[0]
	rent_color_set_label.text = "Rent with Color Set: $%d" % (rents[0] * 2)
	rent1_label.text = "Rent with 1 House: $%d" % rents[1]
	rent2_label.text = "Rent with 2 Houses: $%d" % rents[2]
	rent3_label.text = "Rent with 3 Houses: $%d" % rents[3]
	rent4_label.text = "Rent with 4 Houses: $%d" % rents[4]
	rent5_label.text = "Rent with 5 Houses: $%d" % rents[5]
	price_label.text = "Property Cost: $%d" % price
	mortgage_label.text = "Mortgage Value: $%d" % mortgage_value
	unmortgage_label.text = "Unmortgage Value: $%d" % unmortgage_value
	house_cost_label.text = "Houses cost: $%d each" % house_cost

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

