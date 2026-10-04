class_name PlayerAreaLayoutTest
extends RefCounted

const PLAYER_AREA = preload("res://src/components/player_area/player_area.gd")


## Checks the grid that objects follow inside a player area.
static func run(check: Callable) -> void:
	var length := 7.2
	check.call(PLAYER_AREA.slot_columns(length) == 8, "a default area fits eight objects per row")
	check.call(PLAYER_AREA.slot_columns(0.1) == 1, "a tiny area still has one column")
	check.call(
		PLAYER_AREA.slot_cell(0, length) == Vector2i(0, 0), "first object takes the first cell"
	)
	check.call(
		PLAYER_AREA.slot_cell(7, length) == Vector2i(7, 0), "row one ends at the last column"
	)
	check.call(
		PLAYER_AREA.slot_cell(8, length) == Vector2i(0, 1), "the next object starts a second row"
	)

	var first: Vector3 = PLAYER_AREA.slot_offset(0, length, 1.0)
	var second: Vector3 = PLAYER_AREA.slot_offset(1, length, 1.0)
	var last: Vector3 = PLAYER_AREA.slot_offset(7, length, 1.0)
	check.call(
		is_equal_approx(second.z - first.z, PLAYER_AREA.SLOT_SPACING),
		"neighbours sit one spacing apart"
	)
	check.call(is_equal_approx(first.z, -last.z), "a row is centered on the area")
	check.call(is_zero_approx(first.x), "the first row sits on the area centerline")

	var toward_positive: Vector3 = PLAYER_AREA.slot_offset(8, length, 1.0)
	var toward_negative: Vector3 = PLAYER_AREA.slot_offset(8, length, -1.0)
	check.call(
		is_equal_approx(toward_positive.x, PLAYER_AREA.SLOT_SPACING),
		"rows grow toward a seat on the positive side"
	)
	check.call(
		is_equal_approx(toward_negative.x, -PLAYER_AREA.SLOT_SPACING),
		"rows grow toward a seat on the negative side"
	)
