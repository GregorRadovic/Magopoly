extends Node2D

const SPACE_SCENE: PackedScene = preload("res://scenes/board_space.tscn")

const SPACES_PER_SIDE: int = 10
const TOTAL_SPACES: int = SPACES_PER_SIDE * 4
const CELL_SIZE: float = 60.0
const SPACE_VISUAL_SIZE: float = 54.0

# Keys are resolved board indices (0..39). "-2" in the design spec counts
# backward from Go, i.e. TOTAL_SPACES - 2 == 38.
const SPACE_DATA: Dictionary = {
	0: {"name": "GO"},
	4: {"name": "Income Tax", "type": "tax", "value": 200},
	10: {"name": "Jail"},
	20: {"name": "Free Parking", "type": "free_parking"},
	30: {"name": "Go To Jail", "type": "go_to_jail"},
	(TOTAL_SPACES - 2): {"name": "Luxury Tax", "type": "tax", "value": 100},
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
