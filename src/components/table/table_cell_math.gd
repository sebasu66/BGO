class_name TableCellMath
extends RefCounted

## Pure arithmetic about table cells. A cell is a square of the table grid.
## Cell coordinates count from the center of the table: (0, 0) is the cell whose
## corner is the table center, x grows to the right and y grows upward.

const DEFAULT_CELL_SIZE_CM := 5.0
const ROUNDING_TOLERANCE := 0.0001


## How many cells an object of this size covers (columns, rows), rounding up.
## A 6.3 x 8.8 cm card covers 2 x 2 cells of 5 cm; a 3 cm token covers 1 x 1.
static func cells_covering(
	size_cm: Vector2, cell_size_cm: float = DEFAULT_CELL_SIZE_CM
) -> Vector2i:
	var columns := ceili(size_cm.x / cell_size_cm - ROUNDING_TOLERANCE)
	var rows := ceili(size_cm.y / cell_size_cm - ROUNDING_TOLERANCE)
	return Vector2i(maxi(columns, 1), maxi(rows, 1))


## The cell that contains a position given in centimetres from the table center.
static func cell_containing(
	position_cm: Vector2, cell_size_cm: float = DEFAULT_CELL_SIZE_CM
) -> Vector2i:
	return Vector2i(floori(position_cm.x / cell_size_cm), floori(position_cm.y / cell_size_cm))


## Where the middle of one cell is, in centimetres from the table center.
static func cell_center_cm(cell: Vector2i, cell_size_cm: float = DEFAULT_CELL_SIZE_CM) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size_cm


## Where the middle of a group of cells is. This is where the pivot of whatever
## covers the group is placed, unless the game says otherwise.
static func group_center_cm(
	origin: Vector2i, footprint: Vector2i, cell_size_cm: float = DEFAULT_CELL_SIZE_CM
) -> Vector2:
	return (Vector2(origin) + Vector2(footprint) * 0.5) * cell_size_cm
