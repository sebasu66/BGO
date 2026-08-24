class_name TabletopState
extends RefCounted

const TABLE_GRID_STATE = preload("res://src/core/table_grid_state.gd")
const ASSET_BOX_STATE = preload("res://src/core/asset_box_state.gd")

## Named logical tabletop sections keyed by stable section id.
var sections: Dictionary = {}

## Logical zones keyed by stable zone id.
var zones: Dictionary = {}

## Logical slots keyed by stable slot id.
var slots: Dictionary = {}

## Current logical slot for each placed object id.
var object_slots: Dictionary = {}

## Point grid used by placeable objects that are not represented by a named slot.
var grid = TABLE_GRID_STATE.new()

## Runtime reserve/catalog container. It has no physical tabletop position.
var asset_box = ASSET_BOX_STATE.new()


## Configures the tabletop point grid in centimetres.
func configure_grid(
	point_columns: int,
	point_rows: int,
	point_spacing_cm: Vector2 = Vector2.ONE,
	unbounded: bool = false
) -> bool:
	return grid.configure(point_columns, point_rows, point_spacing_cm, unbounded)


## Configures the game's conceptual asset catalog. Legacy geometry arguments are
## accepted so old callers can migrate without resetting session state.
func configure_asset_box(
	box_id: String,
	point_columns: int,
	point_rows: int,
	point_spacing_cm: Vector2 = Vector2(5.0, 5.0),
	label: String = "ASSET BOX"
) -> bool:
	return asset_box.configure(box_id, point_columns, point_rows, point_spacing_cm, label)


## Adds a declared asset instance to the reserve container.
func add_asset_to_box(
	object_id: String,
	component_id: String,
	config: Dictionary = {},
	quantity: int = 1,
	origin: Vector2i = Vector2i(-1, -1),
	footprint: Vector2i = Vector2i.ONE,
	allow_overlap: bool = false,
	availability_mode: String = "unique",
	owner_id: String = "",
	available_quantity: int = -1
) -> bool:
	return asset_box.add_asset(
		object_id,
		component_id,
		config,
		quantity,
		origin,
		footprint,
		allow_overlap,
		availability_mode,
		owner_id,
		available_quantity
	)


## Removes an asset instance from the reserve container.
func remove_asset_from_box(object_id: String) -> Dictionary:
	return asset_box.remove_asset(object_id)


## Adds a named tabletop section.
func add_section(section_id: String) -> bool:
	if section_id.is_empty() or sections.has(section_id):
		return false
	sections[section_id] = {"zone_ids": []}
	return true


## Adds a zone owned by an existing section.
func add_zone(zone_id: String, section_id: String) -> bool:
	if zone_id.is_empty() or zones.has(zone_id) or not sections.has(section_id):
		return false
	zones[zone_id] = {"section_id": section_id, "slot_ids": []}
	var zone_ids: Array = sections[section_id]["zone_ids"]
	zone_ids.append(zone_id)
	return true


## Adds a slot owned by an existing zone with a positive capacity.
func add_slot(slot_id: String, zone_id: String, capacity: int = 1) -> bool:
	if slot_id.is_empty() or slots.has(slot_id) or not zones.has(zone_id) or capacity < 1:
		return false
	slots[slot_id] = {"zone_id": zone_id, "capacity": capacity, "occupants": []}
	var slot_ids: Array = zones[zone_id]["slot_ids"]
	slot_ids.append(slot_id)
	return true


## Places an unplaced object into a slot when capacity allows.
func place_object(object_id: String, slot_id: String) -> bool:
	if (
		object_id.is_empty()
		or object_slots.has(object_id)
		or grid.has_object(object_id)
		or not can_accept(slot_id)
	):
		return false
	var occupants: Array = slots[slot_id]["occupants"]
	occupants.append(object_id)
	object_slots[object_id] = slot_id
	return true


## Moves a placed object atomically to another slot when the destination is valid.
func move_object(object_id: String, target_slot_id: String) -> bool:
	if not object_slots.has(object_id) or grid.has_object(object_id):
		return false
	var source_slot_id := str(object_slots[object_id])
	if source_slot_id == target_slot_id or not can_accept(target_slot_id):
		return false
	var source_occupants: Array = slots[source_slot_id]["occupants"]
	var target_occupants: Array = slots[target_slot_id]["occupants"]
	source_occupants.erase(object_id)
	target_occupants.append(object_id)
	object_slots[object_id] = target_slot_id
	return true


## Removes an object from its current logical slot.
func remove_object(object_id: String) -> bool:
	if grid.has_object(object_id):
		return grid.remove_object(object_id)
	if not object_slots.has(object_id):
		return false
	var slot_id := str(object_slots[object_id])
	var occupants: Array = slots[slot_id]["occupants"]
	occupants.erase(object_id)
	object_slots.erase(object_id)
	return true


## Returns whether a slot exists and currently has free capacity.
func can_accept(slot_id: String) -> bool:
	if not slots.has(slot_id):
		return false
	var slot: Dictionary = slots[slot_id]
	var occupants: Array = slot["occupants"]
	return occupants.size() < int(slot["capacity"])


## Returns a copy of the current occupants for a slot.
func slot_occupants(slot_id: String) -> Array[String]:
	var result: Array[String] = []
	if not slots.has(slot_id):
		return result
	for object_id in slots[slot_id]["occupants"]:
		result.append(str(object_id))
	return result


## Returns the logical slot containing an object, or an empty string when unplaced.
func object_slot(object_id: String) -> String:
	return str(object_slots.get(object_id, ""))


## Places an object at a grid origin with an optional multi-point footprint.
func place_object_at_grid(
	object_id: String,
	origin: Vector2i,
	footprint: Vector2i = Vector2i.ONE,
	allow_overlap: bool = false
) -> bool:
	if object_id.is_empty() or object_slots.has(object_id):
		return false
	return grid.place_object(object_id, origin, footprint, allow_overlap)


## Moves a grid-placed object atomically to another origin and footprint.
func move_object_at_grid(
	object_id: String,
	origin: Vector2i,
	footprint: Vector2i = Vector2i.ONE,
	allow_overlap: bool = false
) -> bool:
	return grid.move_object(object_id, origin, footprint, allow_overlap)


## Returns the grid origin for an object, or (-1, -1) when unplaced.
func object_grid_origin(object_id: String) -> Vector2i:
	return grid.object_origin(object_id)


## Returns all grid points occupied by an object.
func object_grid_points(object_id: String) -> Array[Vector2i]:
	return grid.object_points(object_id)


## Returns objects touching one grid point.
func objects_at_grid_point(point: Vector2i) -> Array[String]:
	return grid.objects_at(point)


## Alias for querying the table grid using get_* naming.
func get_objects_at(point: Vector2i) -> Array[String]:
	return grid.get_objects_at(point)


## Returns objects touching an inclusive rectangular grid range.
func objects_in_grid_area(from_point: Vector2i, to_point: Vector2i) -> Array[String]:
	return grid.objects_in_area(from_point, to_point)


## Alias for querying the table grid by an inclusive point range.
func get_objects_in_area(from_point: Vector2i, to_point: Vector2i) -> Array[String]:
	return grid.get_objects_in_area(from_point, to_point)


## Returns a deep-copy snapshot suitable for tests and persistence adapters.
func to_dictionary() -> Dictionary:
	return {
		"sections": sections.duplicate(true),
		"zones": zones.duplicate(true),
		"slots": slots.duplicate(true),
		"object_slots": object_slots.duplicate(true),
		"grid": grid.to_dictionary(),
		"asset_box": asset_box.to_dictionary(),
	}
