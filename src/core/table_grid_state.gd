class_name TableGridState
extends RefCounted

## Logical point grid owned by a tabletop.
##
## Coordinates identify points, not cells. An object has one origin point and a
## rectangular footprint extending from that origin toward positive x/y.
## Centimetres are domain units; renderers choose their own world-unit scale.

var point_columns: int = 0
var point_rows: int = 0
var point_spacing_cm: Vector2 = Vector2.ONE
var unbounded := false

## Object placements keyed by stable object id.
var placements: Dictionary = {}


## Configures an empty grid. Existing placements are never discarded implicitly.
func configure(
	p_point_columns: int,
	p_point_rows: int,
	p_point_spacing_cm: Vector2 = Vector2.ONE,
	p_unbounded: bool = false
) -> bool:
	if p_point_columns < 1 or p_point_rows < 1:
		return false
	if p_point_spacing_cm.x <= 0.0 or p_point_spacing_cm.y <= 0.0:
		return false
	if not placements.is_empty():
		return false

	point_columns = p_point_columns
	point_rows = p_point_rows
	point_spacing_cm = p_point_spacing_cm
	unbounded = p_unbounded
	return true


## Returns whether the grid has usable dimensions.
func is_configured() -> bool:
	return point_columns > 0 and point_rows > 0


## Returns whether a point lies inside the configured grid.
func is_valid_point(point: Vector2i) -> bool:
	return (
		is_configured()
		and (
			unbounded
			or (point.x >= 0 and point.x < point_columns and point.y >= 0 and point.y < point_rows)
		)
	)


## Returns whether a rectangular footprint fits from the supplied origin.
func is_valid_footprint(origin: Vector2i, footprint: Vector2i) -> bool:
	return (
		footprint.x > 0
		and footprint.y > 0
		and is_valid_point(origin)
		and is_valid_point(origin + footprint - Vector2i.ONE)
	)


## Places an object at an origin point when every footprint point is free.
func place_object(
	object_id: String,
	origin: Vector2i,
	footprint: Vector2i = Vector2i.ONE,
	allow_overlap: bool = false
) -> bool:
	if object_id.is_empty() or placements.has(object_id):
		return false
	if not is_valid_footprint(origin, footprint):
		return false
	if (
		not allow_overlap
		and not objects_in_area(origin, origin + footprint - Vector2i.ONE).is_empty()
	):
		return false

	placements[object_id] = {
		"origin": origin,
		"footprint": footprint,
	}
	return true


## Moves an existing object atomically to another grid footprint.
func move_object(
	object_id: String,
	origin: Vector2i,
	footprint: Vector2i = Vector2i.ONE,
	allow_overlap: bool = false
) -> bool:
	if not placements.has(object_id) or not is_valid_footprint(origin, footprint):
		return false
	var previous: Dictionary = placements[object_id]
	placements.erase(object_id)
	if (
		not allow_overlap
		and not objects_in_area(origin, origin + footprint - Vector2i.ONE).is_empty()
	):
		placements[object_id] = previous
		return false
	placements[object_id] = {"origin": origin, "footprint": footprint}
	return true


## Removes a grid placement without affecting the logical object itself.
func remove_object(object_id: String) -> bool:
	return placements.erase(object_id)


## Returns whether an object currently has a grid placement.
func has_object(object_id: String) -> bool:
	return placements.has(object_id)


## Returns the origin point for an object, or (-1, -1) when unplaced.
func object_origin(object_id: String) -> Vector2i:
	if not placements.has(object_id):
		return Vector2i(-1, -1)
	return placements[object_id].get("origin", Vector2i(-1, -1))


## Returns the occupied footprint dimensions for an object.
func object_footprint(object_id: String) -> Vector2i:
	if not placements.has(object_id):
		return Vector2i.ZERO
	return placements[object_id].get("footprint", Vector2i.ZERO)


## Returns every point occupied by an object, in deterministic row-major order.
func object_points(object_id: String) -> Array[Vector2i]:
	if not placements.has(object_id):
		return []
	var points: Array[Vector2i] = []
	var origin := object_origin(object_id)
	var footprint := object_footprint(object_id)
	for y in footprint.y:
		for x in footprint.x:
			points.append(origin + Vector2i(x, y))
	return points


## Returns object ids touching one exact grid point.
func objects_at(point: Vector2i) -> Array[String]:
	if not is_valid_point(point):
		return []
	return objects_in_area(point, point)


## Explicit query alias for callers that prefer get_* naming.
func get_objects_at(point: Vector2i) -> Array[String]:
	return objects_at(point)


## Returns object ids touching the inclusive rectangular point range.
func objects_in_area(from_point: Vector2i, to_point: Vector2i) -> Array[String]:
	var minimum := Vector2i(mini(from_point.x, to_point.x), mini(from_point.y, to_point.y))
	var maximum := Vector2i(maxi(from_point.x, to_point.x), maxi(from_point.y, to_point.y))
	var result: Array[String] = []
	for object_id in placements:
		var origin := object_origin(str(object_id))
		var footprint := object_footprint(str(object_id))
		var object_maximum := origin + footprint - Vector2i.ONE
		if _rectangles_touch(minimum, maximum, origin, object_maximum):
			result.append(str(object_id))
	result.sort()
	return result


## Explicit range-query alias for callers that prefer get_* naming.
func get_objects_in_area(from_point: Vector2i, to_point: Vector2i) -> Array[String]:
	return objects_in_area(from_point, to_point)


## Converts a logical point to centimetres relative to the grid origin.
func point_to_cm(point: Vector2i) -> Vector2:
	return Vector2(point) * point_spacing_cm


## Converts centimetres relative to the grid origin to the nearest point.
func cm_to_point(position_cm: Vector2) -> Vector2i:
	return Vector2i(
		roundi(position_cm.x / point_spacing_cm.x), roundi(position_cm.y / point_spacing_cm.y)
	)


## Returns a deep-copy snapshot suitable for persistence and network adapters.
func to_dictionary() -> Dictionary:
	var serialized_placements: Dictionary = {}
	for object_id in placements:
		var placement: Dictionary = placements[object_id]
		var origin: Vector2i = placement.get("origin", Vector2i(-1, -1))
		var footprint: Vector2i = placement.get("footprint", Vector2i.ZERO)
		serialized_placements[str(object_id)] = {
			"origin": {"x": origin.x, "y": origin.y},
			"footprint": {"x": footprint.x, "y": footprint.y},
		}
	return {
		"point_columns": point_columns,
		"point_rows": point_rows,
		"point_spacing_cm": {"x": point_spacing_cm.x, "y": point_spacing_cm.y},
		"unbounded": unbounded,
		"placements": serialized_placements,
	}


func _rectangles_touch(
	first_minimum: Vector2i,
	first_maximum: Vector2i,
	second_minimum: Vector2i,
	second_maximum: Vector2i
) -> bool:
	return not (
		first_maximum.x < second_minimum.x
		or second_maximum.x < first_minimum.x
		or first_maximum.y < second_minimum.y
		or second_maximum.y < first_minimum.y
	)
