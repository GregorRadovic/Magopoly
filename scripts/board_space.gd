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

# Which side of the board this space is on (0 = bottom, 1 = left, 2 = top,
# 3 = right -- matches board.gd's own side numbering, i / SPACES_PER_SIDE).
# Determines which direction the ownership banner juts toward the board's
# center. Set once by board.gd right after instancing.
@export var board_side: int = 0:
	set(value):
		board_side = value
		_position_owner_banner()

const MAGIC_FOREST_COLOR: Color = Color(0.6, 0.2, 0.85)
const SPELL_SHOP_COIN_COLOR: Color = Color(0.9, 0.75, 0.15)

@onready var label: Label = $IndexLabel
@onready var click_area: Control = $ClickArea
@onready var banner: ColorRect = $ColorBanner
@onready var house_icon: TextureRect = $ColorBanner/HouseIcon
@onready var house_count_label: Label = $ColorBanner/HouseCountLabel
@onready var special_marker_label: Label = $SpecialMarker
@onready var owner_banner: ColorRect = $OwnerBanner
@onready var owner_banner_label: Label = $OwnerBanner/OwnerBannerLabel

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
	_position_owner_banner()
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


# Positions the ownership banner just outside this tile's edge, jutting
# toward the board's center -- which direction that is depends entirely on
# which side of the board this space is on. The left/right column banners
# end up tall and narrow (16x74) rather than wide and short (74x16), so the
# label inside has to rotate to actually fit within it -- see
# _reset_owner_banner_label()/_rotate_owner_banner_label().
func _position_owner_banner() -> void:
	if not owner_banner:
		return
	match board_side:
		0:  # bottom row -- jut up
			owner_banner.offset_left = 2.0
			owner_banner.offset_top = -18.0
			owner_banner.offset_right = 76.0
			owner_banner.offset_bottom = -2.0
			_reset_owner_banner_label()
		1:  # left column -- jut right
			owner_banner.offset_left = 80.0
			owner_banner.offset_top = 2.0
			owner_banner.offset_right = 96.0
			owner_banner.offset_bottom = 76.0
			_rotate_owner_banner_label()
		2:  # top row -- jut down
			owner_banner.offset_left = 2.0
			owner_banner.offset_top = 80.0
			owner_banner.offset_right = 76.0
			owner_banner.offset_bottom = 96.0
			_reset_owner_banner_label()
		_:  # right column -- jut left
			owner_banner.offset_left = -18.0
			owner_banner.offset_top = 2.0
			owner_banner.offset_right = -2.0
			owner_banner.offset_bottom = 76.0
			_rotate_owner_banner_label()


# Bottom/top rows: the banner is wide and short (74x16), matching the
# label's natural (unrotated) layout exactly, so it just fills it directly.
func _reset_owner_banner_label() -> void:
	if not owner_banner_label:
		return
	owner_banner_label.rotation = 0.0
	owner_banner_label.pivot_offset = Vector2.ZERO
	owner_banner_label.offset_left = 0.0
	owner_banner_label.offset_top = 0.0
	owner_banner_label.offset_right = 74.0
	owner_banner_label.offset_bottom = 16.0


# Left/right columns: the banner is tall and narrow (16x74) -- the opposite
# aspect ratio from the label's natural 74x16 layout. Rather than cramming
# "P1" into a 16px-wide box (where it wouldn't fit), the label keeps its
# normal 74x16 size (so the text lays out exactly as it does everywhere
# else) and rotates 90 degrees around its own center; with that center
# aligned to the parent banner's center (8, 37 in the banner's own 16x74
# local space), the rotated 16x74 footprint exactly fills the banner.
func _rotate_owner_banner_label() -> void:
	if not owner_banner_label:
		return
	owner_banner_label.offset_left = -29.0
	owner_banner_label.offset_top = 29.0
	owner_banner_label.offset_right = 45.0
	owner_banner_label.offset_bottom = 45.0
	owner_banner_label.pivot_offset = Vector2(37.0, 8.0)
	owner_banner_label.rotation = PI / 2.0


# `new_owner_id` of -1 hides the banner (unowned/returned to the bank).
# `owner_color` is the owning player's color, passed in rather than looked
# up here -- this script has no knowledge of main.gd's PLAYER_COLORS.
func set_owner_banner(new_owner_id: int, owner_color: Color) -> void:
	if not owner_banner:
		return
	if new_owner_id == -1:
		owner_banner.visible = false
		return
	owner_banner.visible = true
	owner_banner.color = owner_color
	owner_banner_label.text = "P%d" % (new_owner_id + 1)


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
