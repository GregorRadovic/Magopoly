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
# Price strip, along the tile edge opposite the colour banner.
const PRICE_H: float = 16.0

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

# e.g. "$120" -- shown on the tile edge opposite the colour banner. Empty for
# spaces without a price (GO, Jail, taxes, ...).
@export var price_text: String = "":
	set(value):
		price_text = value
		_update_price()

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
@onready var price_label: Label = $PriceLabel
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
	_update_price()
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
		_set_rect(border, 0.0, 0.0, w, h)
	if background:
		_set_rect(background, BORDER, BORDER, w - BORDER, h - BORDER)
	if special_marker_label:
		_set_rect(special_marker_label, BORDER + 2.0, BORDER + 2.0, BORDER + 20.0, BORDER + 20.0)
	if click_area:
		_set_rect(click_area, 0.0, 0.0, w, h)

	_position_color_banner()
	_position_price_label()
	_position_name_label()
	_position_owner_banner()


func _set_rect(node: Control, l: float, t: float, r: float, b: float) -> void:
	node.offset_left = l
	node.offset_top = t
	node.offset_right = r
	node.offset_bottom = b


# The colour strip runs along the tile edge that faces the board's centre --
# top for the bottom row, bottom for the top row, and vertically down the
# inner edge for the two side columns (same as a real Monopoly board).
func _position_color_banner() -> void:
	if not banner:
		return
	var w: float = tile_size.x
	var h: float = tile_size.y
	match board_side:
		0:  # bottom row -- strip along the top
			_set_rect(banner, BORDER, BORDER, w - BORDER, BORDER + BANNER_H)
		2:  # top row -- strip along the bottom
			_set_rect(banner, BORDER, h - BORDER - BANNER_H, w - BORDER, h - BORDER)
		1:  # left column -- strip down the right edge
			_set_rect(banner, w - BORDER - BANNER_H, BORDER, w - BORDER, h - BORDER)
		_:  # right column -- strip down the left edge
			_set_rect(banner, BORDER, BORDER, BORDER + BANNER_H, h - BORDER)

	# House icon / count sit centred in the strip (banner-local coordinates).
	var bw: float = banner.offset_right - banner.offset_left
	var bh: float = banner.offset_bottom - banner.offset_top
	for node in [house_icon, house_count_label]:
		if node:
			_set_rect(node, bw * 0.5 - 8.0, bh * 0.5 - 8.0, bw * 0.5 + 8.0, bh * 0.5 + 8.0)


# The price sits along the tile edge OPPOSITE the colour banner (its local
# "bottom"): bottom of the bottom row, top of the top row, and down the
# outer vertical edge of each side column (rotated to read along it).
func _position_price_label() -> void:
	if not price_label:
		return
	var w: float = tile_size.x
	var h: float = tile_size.y
	match board_side:
		0:  # bottom row -- price along the bottom
			_flat_strip(price_label, BORDER, h - BORDER - PRICE_H, w - BORDER, h - BORDER)
		2:  # top row -- price along the top (upside-down, like the name)
			_flat_strip(price_label, BORDER, BORDER, w - BORDER, BORDER + PRICE_H)
		1:  # left column -- price down the left (outer) edge
			_rotated_edge_band(price_label, BORDER + PRICE_H * 0.5)
		_:  # right column -- price down the right (outer) edge
			_rotated_edge_band(price_label, w - BORDER - PRICE_H * 0.5)


# A horizontal strip, turned to this side's orientation (0 or PI) about its
# own centre.
func _flat_strip(node: Control, l: float, t: float, r: float, b: float) -> void:
	_set_rect(node, l, t, r, b)
	node.pivot_offset = Vector2((r - l) * 0.5, (b - t) * 0.5)
	node.rotation = _side_rotation()


# Lays `node` as a vertical band centred on x = `center_x`, spanning the
# tile's height: the label keeps its natural (band-length x PRICE_H) shape
# and rotates to that side's orientation about its centre, which is pinned
# to the band centre.
func _rotated_edge_band(node: Control, center_x: float) -> void:
	var h: float = tile_size.y
	var band: float = h - 2.0 * BORDER
	var cy: float = h * 0.5
	node.offset_left = center_x - band * 0.5
	node.offset_top = cy - PRICE_H * 0.5
	node.offset_right = center_x + band * 0.5
	node.offset_bottom = cy + PRICE_H * 0.5
	node.pivot_offset = Vector2(band * 0.5, PRICE_H * 0.5)
	node.rotation = _side_rotation()


# How far to turn text on this side so it reads for a player sitting there:
# bottom upright, top upside-down, and a quarter-turn each way for the
# columns. Board sides: 0 bottom, 1 left, 2 top, 3 right.
func _side_rotation() -> float:
	match board_side:
		1: return PI / 2.0
		2: return PI
		3: return -PI / 2.0
		_: return 0.0


# The tile name occupies the clear rectangle between the colour banner and
# the price strip, turned to this side's orientation.
func _position_name_label() -> void:
	if not label:
		return
	var w: float = tile_size.x
	var h: float = tile_size.y
	var b: float = BORDER + BANNER_H       # colour-banner side inset
	var p: float = BORDER + PRICE_H        # price side inset
	var area: Rect2
	match board_side:
		0: area = Rect2(1.0, b, w - 2.0, h - b - p)
		2: area = Rect2(1.0, p, w - 2.0, h - b - p)
		1: area = Rect2(p, 1.0, w - b - p, h - 2.0)
		_: area = Rect2(b, 1.0, w - b - p, h - 2.0)

	# A quarter-turn swaps the label's own width/height so its rotated
	# footprint still fills `area`; it's then centred and pivoted on centre.
	var swap: bool = board_side == 1 or board_side == 3
	var lw: float = area.size.y if swap else area.size.x
	var lh: float = area.size.x if swap else area.size.y
	var c: Vector2 = area.position + area.size * 0.5
	_set_rect(label, c.x - lw * 0.5, c.y - lh * 0.5, c.x + lw * 0.5, c.y + lh * 0.5)
	label.pivot_offset = Vector2(lw * 0.5, lh * 0.5)
	label.rotation = _side_rotation()


func _update_price() -> void:
	if price_label:
		price_label.text = price_text
		price_label.visible = price_text != ""


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
	var lw: float = tile_size.x - 2.0 * BORDER
	owner_banner_label.offset_left = 0.0
	owner_banner_label.offset_top = 0.0
	owner_banner_label.offset_right = lw
	owner_banner_label.offset_bottom = OWNER_T
	owner_banner_label.pivot_offset = Vector2(lw * 0.5, OWNER_T * 0.5)
	owner_banner_label.rotation = _side_rotation()  # 0 bottom, PI (upside-down) top


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
	owner_banner_label.rotation = _side_rotation()  # PI/2 left, -PI/2 right


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
