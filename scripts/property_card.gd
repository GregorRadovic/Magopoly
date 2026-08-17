extends PopupPanel

@onready var header_panel: ColorRect = $VBox/HeaderPanel
@onready var name_label: Label = $VBox/HeaderPanel/HeaderVBox/NameLabel
@onready var rent_label: Label = $VBox/RentLabel
@onready var rent_color_set_label: Label = $VBox/RentColorSetLabel
@onready var rent1_label: Label = $VBox/Rent1Label
@onready var rent2_label: Label = $VBox/Rent2Label
@onready var rent3_label: Label = $VBox/Rent3Label
@onready var rent4_label: Label = $VBox/Rent4Label
@onready var rent5_label: Label = $VBox/Rent5Label
@onready var house_cost_label: Label = $VBox/HouseCostLabel
@onready var close_button: Button = $VBox/CloseButton


func _ready() -> void:
	close_button.pressed.connect(hide)


func show_card(property_name: String, header_color: Color, rents: Array, house_cost: int) -> void:
	name_label.text = property_name
	header_panel.color = header_color
	rent_label.text = "Rent: $%d" % rents[0]
	rent_color_set_label.text = "Rent with Color Set: $%d" % (rents[0] * 2)
	rent1_label.text = "Rent with 1 House: $%d" % rents[1]
	rent2_label.text = "Rent with 2 Houses: $%d" % rents[2]
	rent3_label.text = "Rent with 3 Houses: $%d" % rents[3]
	rent4_label.text = "Rent with 4 Houses: $%d" % rents[4]
	rent5_label.text = "Rent with 5 Houses: $%d" % rents[5]
	house_cost_label.text = "Houses cost: $%d each" % house_cost
	popup_centered(Vector2i(440, 740))
