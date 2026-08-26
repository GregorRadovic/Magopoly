extends Node2D
class_name BoardSpace

signal clicked(index: int)

@export var index: int = 0:
	set(value):
		index = value
		_update_label()

@export var label_text: String = "":
	set(value):
		label_text = value
		_update_label()

@export var banner_color: Color = Color(0, 0, 0, 0):
	set(value):
		banner_color = value
		_update_banner()

# "", "magic_forest" (purple star), or "spell_shop" (coin).
@export var special_marker: String = "":
	set(value):
		special_marker = value
		_update_special_marker()

const MAGIC_FOREST_COLOR: Color = Color(0.6, 0.2, 0.85)
const SPELL_SHOP_COIN_COLOR: Color = Color(0.9, 0.75, 0.15)

@onready var label: Label = $IndexLabel
@onready var click_area: Control = $ClickArea
@onready var banner: ColorRect = $ColorBanner
@onready var house_icon: TextureRect = $ColorBanner/HouseIcon
@onready var house_count_label: Label = $ColorBanner/HouseCountLabel
@onready var special_marker_label: Label = $SpecialMarker

# Index into main.gd's `players` array; -1 means the property is unowned.
# Only meaningful for spaces whose SPACE_DATA type is "property".
# (Named owner_id, not "owner" -- that name collides with Node.owner.)
var owner_id: int = -1

# Only meaningful for color-group properties (not railroads/utilities).
var house_count: int = 0:
	set(value):
		house_count = value
		_update_house_display()

var is_mortgaged: bool = false


func _ready() -> void:
	_update_label()
	_update_banner()
	_update_house_display()
	_update_special_marker()
	click_area.gui_input.connect(_on_click_area_gui_input)


func _on_click_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)


func _update_label() -> void:
	if label:
		label.text = label_text if label_text != "" else str(index)


func _update_banner() -> void:
	if banner:
		banner.color = banner_color


func _update_house_display() -> void:
	if house_icon:
		house_icon.visible = house_count > 0
	if house_count_label:
		house_count_label.visible = house_count > 0
		house_count_label.text = str(house_count)


func _update_special_marker() -> void:
	if not special_marker_label:
		return
	match special_marker:
		"magic_forest":
			special_marker_label.visible = true
			special_marker_label.text = "★"  # star
			special_marker_label.remove_theme_stylebox_override("normal")
			special_marker_label.add_theme_color_override("font_color", MAGIC_FOREST_COLOR)
		"spell_shop":
			special_marker_label.visible = true
			special_marker_label.text = "$"
			special_marker_label.add_theme_color_override("font_color", Color.BLACK)
			var coin_style := StyleBoxFlat.new()
			coin_style.bg_color = SPELL_SHOP_COIN_COLOR
			coin_style.corner_radius_top_left = 20
			coin_style.corner_radius_top_right = 20
			coin_style.corner_radius_bottom_left = 20
			coin_style.corner_radius_bottom_right = 20
			special_marker_label.add_theme_stylebox_override("normal", coin_style)
		_:
			special_marker_label.visible = false
