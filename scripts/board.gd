extends Node2D

signal space_clicked(index: int)

const SPACE_SCENE: PackedScene = preload("res://scenes/board_space.tscn")

const SPACES_PER_SIDE: int = 10
const TOTAL_SPACES: int = SPACES_PER_SIDE * 4
const CELL_SIZE: float = 60.0
const SPACE_VISUAL_SIZE: float = 54.0

# Keys are resolved board indices (0..39). "-2" in the design spec counts
# backward from Go, i.e. TOTAL_SPACES - 2 == 38.
const SPACE_DATA: Dictionary = {
	0: {"name": "GO"},
	1: {"name": "Mediterranean Avenue", "type": "property", "price": 60, "rents": [2, 10, 30, 90, 160, 250]},
	3: {"name": "Baltic Avenue", "type": "property", "price": 60, "rents": [4, 20, 60, 180, 320, 450]},
	4: {"name": "Income Tax", "type": "tax", "value": 200},
	5: {"name": "Reading Railroad", "type": "property", "price": 200},
	6: {"name": "Oriental Avenue", "type": "property", "price": 100, "rents": [6, 30, 90, 270, 400, 550]},
	8: {"name": "Vermont Avenue", "type": "property", "price": 100, "rents": [6, 30, 90, 270, 400, 550]},
	9: {"name": "Connecticut Avenue", "type": "property", "price": 120, "rents": [8, 40, 100, 300, 450, 600]},
	10: {"name": "Jail"},
	11: {"name": "St. Charles Place", "type": "property", "price": 140, "rents": [10, 50, 150, 450, 625, 750]},
	12: {"name": "Electric Company", "type": "property", "price": 150},
	13: {"name": "States Avenue", "type": "property", "price": 140, "rents": [10, 50, 150, 450, 625, 750]},
	14: {"name": "Virginia Avenue", "type": "property", "price": 160, "rents": [12, 60, 180, 500, 700, 900]},
	15: {"name": "Pennsylvania Railroad", "type": "property", "price": 200},
	16: {"name": "St. James Place", "type": "property", "price": 180, "rents": [14, 70, 200, 550, 750, 950]},
	18: {"name": "Tennessee Avenue", "type": "property", "price": 180, "rents": [14, 70, 200, 550, 750, 950]},
	19: {"name": "New York Avenue", "type": "property", "price": 200, "rents": [16, 80, 220, 600, 800, 1000]},
	20: {"name": "Free Parking", "type": "free_parking"},
	21: {"name": "Kentucky Avenue", "type": "property", "price": 220, "rents": [18, 90, 250, 700, 875, 1050]},
	23: {"name": "Indiana Avenue", "type": "property", "price": 220, "rents": [18, 90, 250, 700, 875, 1050]},
	24: {"name": "Illinois Avenue", "type": "property", "price": 240, "rents": [20, 100, 300, 750, 925, 1100]},
	25: {"name": "B&O Railroad", "type": "property", "price": 200},
	26: {"name": "Atlantic Avenue", "type": "property", "price": 260, "rents": [22, 110, 330, 800, 975, 1150]},
	27: {"name": "Ventnor Avenue", "type": "property", "price": 260, "rents": [22, 110, 330, 800, 975, 1150]},
	28: {"name": "Water Works", "type": "property", "price": 150},
	29: {"name": "Marvin Gardens", "type": "property", "price": 280, "rents": [24, 120, 360, 850, 1025, 1200]},
	30: {"name": "Go To Jail", "type": "go_to_jail"},
	31: {"name": "Pacific Avenue", "type": "property", "price": 300, "rents": [26, 130, 390, 900, 1100, 1275]},
	32: {"name": "North Carolina Avenue", "type": "property", "price": 300, "rents": [26, 130, 390, 900, 1100, 1275]},
	34: {"name": "Pennsylvania Avenue", "type": "property", "price": 320, "rents": [28, 150, 450, 1000, 1200, 1400]},
	35: {"name": "Short Line", "type": "property", "price": 200},
	37: {"name": "Park Place", "type": "property", "price": 350, "rents": [35, 175, 500, 1100, 1300, 1500]},
	(TOTAL_SPACES - 2): {"name": "Luxury Tax", "type": "tax", "value": 100},
	39: {"name": "Boardwalk", "type": "property", "price": 400, "rents": [50, 200, 600, 1400, 1700, 2000]},
}

var spaces: Array[Node2D] = []


func _ready() -> void:
	_generate_board()


func get_space_center(index: int) -> Vector2:
	var space: Node2D = spaces[index]
	return space.position + Vector2(SPACE_VISUAL_SIZE, SPACE_VISUAL_SIZE) / 2.0


func get_space_info(index: int) -> Dictionary:
	return SPACE_DATA.get(index, {})


func _generate_board() -> void:
	for i in TOTAL_SPACES:
		var space: Node2D = SPACE_SCENE.instantiate()
		space.index = i
		space.label_text = get_space_info(i).get("name", "")
		space.position = _grid_to_position(_index_to_grid(i))
		space.clicked.connect(space_clicked.emit)
		add_child(space)
		spaces.append(space)


# Walks the perimeter of an 11x11 grid (indices 0..10), split into four
# 10-space sides. Each side's first space is a shared corner; the corner
# belongs to the side that starts there, so 4 sides * 10 spaces = 40 total
# with no duplicated positions.
func _index_to_grid(i: int) -> Vector2i:
	var side: int = i / SPACES_PER_SIDE
	var pos: int = i % SPACES_PER_SIDE
	match side:
		0: return Vector2i(SPACES_PER_SIDE - pos, SPACES_PER_SIDE) # bottom row, right -> left
		1: return Vector2i(0, SPACES_PER_SIDE - pos)               # left column, bottom -> top
		2: return Vector2i(pos, 0)                                 # top row, left -> right
		_: return Vector2i(SPACES_PER_SIDE, pos)                   # right column, top -> bottom


func _grid_to_position(grid: Vector2i) -> Vector2:
	return Vector2(grid.x, grid.y) * CELL_SIZE
