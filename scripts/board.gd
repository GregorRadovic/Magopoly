extends Node2D

signal space_clicked(index: int)

const SPACE_SCENE: PackedScene = preload("res://scenes/board_space.tscn")

const SPACES_PER_SIDE: int = 10
const TOTAL_SPACES: int = SPACES_PER_SIDE * 4

# A proper Monopoly-shaped board. Each side is one square 2x2 corner tile
# plus nine edge tiles that are 1 unit wide along the edge and 2 units deep
# into the board -- so the whole board is 2 + 9 + 2 = 13 units on a side.
const UNIT: float = 72.0
const CORNER_SIZE: float = 2.0 * UNIT
const EDGE_DEEP: float = 2.0 * UNIT
const EDGE_THIN: float = UNIT
const BOARD_SIZE: float = 13.0 * UNIT

# Keys are resolved board indices (0..39). "-2" in the design spec counts
# backward from Go, i.e. TOTAL_SPACES - 2 == 38.
const SPACE_DATA: Dictionary = {
	0: {"name": "GO"},
	1: {"name": "Mediterranean Avenue", "type": "property", "price": 60, "rents": [2, 10, 30, 90, 160, 250], "color": "brown"},
	2: {"name": "Spell Shop", "type": "spell_shop"},
	3: {"name": "Baltic Avenue", "type": "property", "price": 60, "rents": [4, 20, 60, 180, 320, 450], "color": "brown"},
	4: {"name": "Income Tax", "type": "tax", "value": 200},
	5: {"name": "Reading Railroad", "type": "property", "price": 200, "rents": [25, 50, 100, 200], "color": "railroad", "icon": "res://Magopoly Assets/Railroad.png"},
	6: {"name": "Oriental Avenue", "type": "property", "price": 100, "rents": [6, 30, 90, 270, 400, 550], "color": "sky_blue"},
	7: {"name": "Magic Forest", "type": "magic_forest"},
	8: {"name": "Vermont Avenue", "type": "property", "price": 100, "rents": [6, 30, 90, 270, 400, 550], "color": "sky_blue"},
	9: {"name": "Connecticut Avenue", "type": "property", "price": 120, "rents": [8, 40, 100, 300, 450, 600], "color": "sky_blue"},
	10: {"name": "Jail"},
	11: {"name": "St. Charles Place", "type": "property", "price": 140, "rents": [10, 50, 150, 450, 625, 750], "color": "pink"},
	12: {"name": "Electric Company", "type": "property", "price": 150, "rent_multipliers": [4, 10], "color": "utility", "icon": "res://Magopoly Assets/Electric.png"},
	13: {"name": "States Avenue", "type": "property", "price": 140, "rents": [10, 50, 150, 450, 625, 750], "color": "pink"},
	14: {"name": "Virginia Avenue", "type": "property", "price": 160, "rents": [12, 60, 180, 500, 700, 900], "color": "pink"},
	15: {"name": "Pennsylvania Railroad", "type": "property", "price": 200, "rents": [25, 50, 100, 200], "color": "railroad", "icon": "res://Magopoly Assets/Railroad.png"},
	16: {"name": "St. James Place", "type": "property", "price": 180, "rents": [14, 70, 200, 550, 750, 950], "color": "orange"},
	17: {"name": "Spell Shop", "type": "spell_shop"},
	18: {"name": "Tennessee Avenue", "type": "property", "price": 180, "rents": [14, 70, 200, 550, 750, 950], "color": "orange"},
	19: {"name": "New York Avenue", "type": "property", "price": 200, "rents": [16, 80, 220, 600, 800, 1000], "color": "orange"},
	20: {"name": "Free Parking", "type": "free_parking"},
	21: {"name": "Kentucky Avenue", "type": "property", "price": 220, "rents": [18, 90, 250, 700, 875, 1050], "color": "red"},
	22: {"name": "Magic Forest", "type": "magic_forest"},
	23: {"name": "Indiana Avenue", "type": "property", "price": 220, "rents": [18, 90, 250, 700, 875, 1050], "color": "red"},
	24: {"name": "Illinois Avenue", "type": "property", "price": 240, "rents": [20, 100, 300, 750, 925, 1100], "color": "red"},
	25: {"name": "B&O Railroad", "type": "property", "price": 200, "rents": [25, 50, 100, 200], "color": "railroad", "icon": "res://Magopoly Assets/Railroad.png"},
	26: {"name": "Atlantic Avenue", "type": "property", "price": 260, "rents": [22, 110, 330, 800, 975, 1150], "color": "yellow"},
	27: {"name": "Ventnor Avenue", "type": "property", "price": 260, "rents": [22, 110, 330, 800, 975, 1150], "color": "yellow"},
	28: {"name": "Water Works", "type": "property", "price": 150, "rent_multipliers": [4, 10], "color": "utility", "icon": "res://Magopoly Assets/Waterworks.png"},
	29: {"name": "Marvin Gardens", "type": "property", "price": 280, "rents": [24, 120, 360, 850, 1025, 1200], "color": "yellow"},
	30: {"name": "Go To Jail", "type": "go_to_jail"},
	31: {"name": "Pacific Avenue", "type": "property", "price": 300, "rents": [26, 130, 390, 900, 1100, 1275], "color": "green"},
	32: {"name": "North Carolina Avenue", "type": "property", "price": 300, "rents": [26, 130, 390, 900, 1100, 1275], "color": "green"},
	33: {"name": "Spell Shop", "type": "spell_shop"},
	34: {"name": "Pennsylvania Avenue", "type": "property", "price": 320, "rents": [28, 150, 450, 1000, 1200, 1400], "color": "green"},
	35: {"name": "Short Line", "type": "property", "price": 200, "rents": [25, 50, 100, 200], "color": "railroad", "icon": "res://Magopoly Assets/Railroad.png"},
	36: {"name": "Magic Forest", "type": "magic_forest"},
	37: {"name": "Park Place", "type": "property", "price": 350, "rents": [35, 175, 500, 1100, 1300, 1500], "color": "ocean_blue"},
	(TOTAL_SPACES - 2): {"name": "Luxury Tax", "type": "tax", "value": 100},
	39: {"name": "Boardwalk", "type": "property", "price": 400, "rents": [50, 200, 600, 1400, 1700, 2000], "color": "ocean_blue"},
}

# Maps a property's SPACE_DATA "color" string to the actual banner Color.
const COLOR_GROUP_COLORS: Dictionary = {
	"brown": Color(0.545, 0.271, 0.075),
	"sky_blue": Color(0.667, 0.878, 0.980),
	"pink": Color(0.851, 0.227, 0.588),
	"orange": Color(0.969, 0.580, 0.114),
	"red": Color(0.929, 0.106, 0.141),
	"yellow": Color(0.996, 0.949, 0.0),
	"green": Color(0.122, 0.698, 0.353),
	"ocean_blue": Color(0.0, 0.447, 0.733),
	"railroad": Color.BLACK,
	"utility": Color(0.6, 0.6, 0.6),
	"black": Color.BLACK,
}

# Cost to build one house on a property, by its color group. Railroads and
# utilities don't build houses, so they have no entry here.
const HOUSE_COSTS_BY_COLOR: Dictionary = {
	"brown": 50,
	"sky_blue": 50,
	"pink": 100,
	"orange": 100,
	"red": 150,
	"yellow": 150,
	"green": 200,
	"ocean_blue": 200,
}

# Color group name -> Array[int] of the property indices in that group.
# Built once from SPACE_DATA rather than hand-authored again, so it can't
# drift out of sync with each property's "color" entry.
var color_groups: Dictionary = {}

var spaces: Array[Node2D] = []


func _ready() -> void:
	_build_color_groups()
	_generate_board()


func get_space_center(index: int) -> Vector2:
	var space: Node2D = spaces[index]
	return space.position + space.tile_size * 0.5


func get_space_info(index: int) -> Dictionary:
	return SPACE_DATA.get(index, {})


func get_color_group(color_name: String) -> Array:
	return color_groups.get(color_name, [])


func _build_color_groups() -> void:
	for i in SPACE_DATA.keys():
		var color_name: String = SPACE_DATA[i].get("color", "")
		if color_name == "":
			continue
		if not color_groups.has(color_name):
			color_groups[color_name] = []
		color_groups[color_name].append(i)


func _generate_board() -> void:
	for i in TOTAL_SPACES:
		var space: Node2D = SPACE_SCENE.instantiate()
		# board_side + tile_size drive the tile's own layout, so set them
		# before the content setters (which lay text/banners out within it).
		space.board_side = i / SPACES_PER_SIDE
		var rect: Rect2 = _tile_rect(i)
		space.position = rect.position
		space.tile_size = rect.size
		space.index = i
		var info: Dictionary = get_space_info(i)
		space.label_text = info.get("name", "")
		var color_name: String = info.get("color", "")
		if color_name != "":
			space.banner_color = COLOR_GROUP_COLORS.get(color_name, Color(0, 0, 0, 0))
		var space_type: String = info.get("type", "")
		if space_type == "magic_forest" or space_type == "spell_shop":
			space.special_marker = space_type
		space.clicked.connect(space_clicked.emit)
		add_child(space)
		spaces.append(space)


# The rectangle (board-local top-left position + size) of tile `i`. Corner
# tiles (pos 0 of each side) are square; the nine edge tiles per side are
# EDGE_THIN along the side and EDGE_DEEP into the board. Side numbering and
# walk direction match _index_to_grid's old scheme: 0 bottom (right->left),
# 1 left (bottom->top), 2 top (left->right), 3 right (top->bottom).
func _tile_rect(i: int) -> Rect2:
	var side: int = i / SPACES_PER_SIDE
	var pos: int = i % SPACES_PER_SIDE
	var far: float = BOARD_SIZE - CORNER_SIZE

	if pos == 0:
		match side:
			0: return Rect2(far, far, CORNER_SIZE, CORNER_SIZE)    # GO -- bottom-right
			1: return Rect2(0.0, far, CORNER_SIZE, CORNER_SIZE)    # Jail -- bottom-left
			2: return Rect2(0.0, 0.0, CORNER_SIZE, CORNER_SIZE)    # Free Parking -- top-left
			_: return Rect2(far, 0.0, CORNER_SIZE, CORNER_SIZE)    # Go To Jail -- top-right

	var along: float = CORNER_SIZE + (pos - 1) * EDGE_THIN
	match side:
		0:  # bottom row, walking right -> left
			return Rect2(BOARD_SIZE - CORNER_SIZE - pos * EDGE_THIN, far, EDGE_THIN, EDGE_DEEP)
		1:  # left column, walking bottom -> top
			return Rect2(0.0, BOARD_SIZE - CORNER_SIZE - pos * EDGE_THIN, EDGE_DEEP, EDGE_THIN)
		2:  # top row, walking left -> right
			return Rect2(along, 0.0, EDGE_THIN, EDGE_DEEP)
		_:  # right column, walking top -> bottom
			return Rect2(far, along, EDGE_DEEP, EDGE_THIN)
