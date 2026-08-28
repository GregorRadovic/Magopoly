extends Node2D
class_name BoardSpace

signal clicked(index: int)

# Border thickness, colour-banner height (top strip) and ownership-banner
# thickness -- the ownership banner juts OUTSIDE the tile toward the board's
# centre, offset by OWNER_GAP.
const BORDER: float = 2.0
const BANNER_H: float = 18.0
const OWNER_T: float = 16.0
const OWNER_GAP: float = 2.0

const MAGIC_FOREST_COLOR: Color = Color(0.6, 0.2, 0.85)
const SPELL_SHOP_COIN_COLOR: Color = Color(0.9, 0.75, 0.15)

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
# Determines which way the ownership banner juts. Set by board.gd on spawn.
@export var board_side: int = 0:
	set(value):
		board_side = value
		_apply_layout()

# Full pixel size of this tile. Corner tiles are square; edge tiles are
# oblong (see board.gd's _tile_rect). Set by board.gd on spawn.
@export var tile_size: Vector2 = Vector2(72, 72):
	set(value):
		tile_size = value
		_apply_layout()

@onready var border: ColorRect = $Border
@onready var background: ColorRect = $Background
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
	_apply_layout()
	_update_label()
	_update_banner()
	_update_house_display()
	_update_special_marker()
	click_area.gui_input.connect(_on_click_area_gui_input)


func _on_click_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)


# Sizes every child to the current tile_size. A no-op until the @onready
# nodes exist (the setters can fire before _ready during board generation);
# _ready() calls it again once they do.
func _apply_layout() -> void:
	var w: float = tile_size.x
	var h: float = tile_size.y

	if border:
		border.offset_right = w
		border.offset_bottom = h
	if background:
		background.offset_left = BORDER
		background.offset_top = BORDER
		background.offset_right = w - BORDER
		background.offset_bottom = h - BORDER
	if banner:
		banner.offset_left = BORDER
		banner.offset_top = BORDER
		banner.offset_right = w - BORDER
		banner.offset_bottom = BORDER + BANNER_H
	if house_icon:
		_center_in_banner(house_icon, 16.0)
	if house_count_label:
		_center_in_banner(house_count_label, 16.0)
	if label:
		label.offset_left = 1.0
		label.offset_top = 1.0
		label.offset_right = w - 1.0
		label.offset_bottom = h - 1.0
	if special_marker_label:
		special_marker_label.offset_left = BORDER + 1.0
		special_marker_label.offset_top = BORDER + BANNER_H + 1.0
		special_marker_label.offset_right = BORDER + 19.0
		special_marker_label.offset_bottom = BORDER + BANNER_H + 19.0
	if click_area:
		click_area.offset_right = w
		click_area.offset_bottom = h

	_position_owner_banner()


func _center_in_banner(node: Control, sz: float) -> void:
	var cx: float = tile_size.x * 0.5
	node.offset_left = cx - sz * 0.5
	node.offset_top = BORDER + (BANNER_H - sz) * 0.5
	node.offset_right = cx + sz * 0.5
	node.offset_bottom = BORDER + (BANNER_H + sz) * 0.5


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


# Positions the ownership banner just outside the tile edge that faces the
# board's centre. Bottom/top rows get a flat horizontal banner; the left/
# right columns get a tall narrow one, so its label rotates 90 degrees to
# fit (see _layout_owner_label_rotated).
func _position_owner_banner() -> void:
	if not owner_banner:
		return
	var w: float = tile_size.x
	var h: float = tile_size.y
	match board_side:
		0:  # bottom row -- jut up
			owner_banner.offset_left = BORDER
			owner_banner.offset_top = -(OWNER_T + OWNER_GAP)
			owner_banner.offset_right = w - BORDER
			owner_banner.offset_bottom = -OWNER_GAP
			_layout_owner_label_flat()
		2:  # top row -- jut down
			owner_banner.offset_left = BORDER
			owner_banner.offset_top = h + OWNER_GAP
			owner_banner.offset_right = w - BORDER
			owner_banner.offset_bottom = h + OWNER_GAP + OWNER_T
			_layout_owner_label_flat()
		1:  # left column -- jut right
			owner_banner.offset_left = w + OWNER_GAP
			owner_banner.offset_top = BORDER
			owner_banner.offset_right = w + OWNER_GAP + OWNER_T
			owner_banner.offset_bottom = h - BORDER
			_layout_owner_label_rotated()
		_:  # right column -- jut left
			owner_banner.offset_left = -(OWNER_T + OWNER_GAP)
			owner_banner.offset_top = BORDER
			owner_banner.offset_right = -OWNER_GAP
			owner_banner.offset_bottom = h - BORDER
			_layout_owner_label_rotated()


func _layout_owner_label_flat() -> void:
	if not owner_banner_label:
		return
	owner_banner_label.rotation = 0.0
	owner_banner_label.pivot_offset = Vector2.ZERO
	owner_banner_label.offset_left = 0.0
	owner_banner_label.offset_top = 0.0
	owner_banner_label.offset_right = tile_size.x - 2.0 * BORDER
	owner_banner_label.offset_bottom = OWNER_T


# The banner here is OWNER_T wide x `band` tall. The label keeps its natural
# `band` x OWNER_T shape (so text lays out as elsewhere) and rotates 90 deg
# about its own centre, which is pinned to the banner's centre -- the rotated
# footprint then exactly fills the banner.
func _layout_owner_label_rotated() -> void:
	if not owner_banner_label:
		return
	var band: float = tile_size.y - 2.0 * BORDER
	owner_banner_label.offset_left = OWNER_T * 0.5 - band * 0.5
	owner_banner_label.offset_top = band * 0.5 - OWNER_T * 0.5
	owner_banner_label.offset_right = OWNER_T * 0.5 + band * 0.5
	owner_banner_label.offset_bottom = band * 0.5 + OWNER_T * 0.5
	owner_banner_label.pivot_offset = Vector2(band * 0.5, OWNER_T * 0.5)
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
