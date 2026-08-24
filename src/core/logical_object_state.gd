class_name LogicalObjectState
extends RefCounted

## Stable logical object identity.
var object_id: String = ""

## Stable public component used to render this logical object.
var component_id: String = ""

## Declarative component configuration supplied by the game package.
var configuration: Dictionary = {}

## Number of physical instances represented by this logical object.
var quantity: int = 1

## Named semantic state declared by the game/component contract.
var state_id: String = "default"

## Extensible serializable state owned by the logical object.
var properties: Dictionary = {}

## Availability policy declared by the game package: unique, finite or infinite.
var availability_mode: String = "unique"

## Available quantity for finite/infinite sources. Quantity remains the current
## represented amount for an individual object or stack.
var available_quantity: int = 1

## Participant that owns the object. Empty means neutral ownership.
var owner_id: String = ""

## Participant currently holding or controlling the object. Empty means unheld.
var holder_id: String = ""

## Logical location category, for example "slot", "hand", or "zone".
var location_type: String = ""

## Stable logical location identifier within the current location category.
var location_id: String = ""

## Visibility policy identifier consumed by authorized view filtering.
var visibility: String = "public"

## Origin point when this object is placed on a tabletop grid.
var grid_origin: Vector2i = Vector2i(-1, -1)

## Number of grid points occupied from grid_origin, in x/y dimensions.
var grid_footprint: Vector2i = Vector2i.ZERO

## Container id when the object is stored in an asset box.
var container_id: String = ""


## Creates a logical object with stable identity and optional owner.
static func create(
	p_object_id: String,
	p_component_or_owner: String = "",
	p_owner_id: String = "",
	p_quantity: int = 1
) -> LogicalObjectState:
	var state := LogicalObjectState.new()
	state.object_id = p_object_id
	# Preserve the early prototype's create(id, owner) shorthand while accepting
	# the canonical create(id, component, owner, quantity) contract.
	if p_owner_id.is_empty() and not p_component_or_owner.begins_with("bgo."):
		state.owner_id = p_component_or_owner
	else:
		state.component_id = p_component_or_owner
		state.owner_id = p_owner_id
	state.quantity = p_quantity
	return state


## Returns whether the object currently has neutral ownership.
func is_neutral() -> bool:
	return owner_id.is_empty()


## Assigns or clears the current holder/controller identity.
func set_holder(participant_id: String) -> void:
	holder_id = participant_id


## Updates the object's logical location without any rendering coordinates.
func set_location(p_location_type: String, p_location_id: String) -> bool:
	if p_location_type.is_empty() or p_location_id.is_empty():
		return false
	if p_location_type != "grid" and p_location_type != "asset_box":
		grid_origin = Vector2i(-1, -1)
		grid_footprint = Vector2i.ZERO
	if p_location_type != "asset_box":
		container_id = ""
	location_type = p_location_type
	location_id = p_location_id
	return true


## Clears the object's logical location.
func clear_location() -> void:
	var was_grid := location_type == "grid"
	location_type = ""
	location_id = ""
	if was_grid:
		grid_origin = Vector2i(-1, -1)
		grid_footprint = Vector2i.ZERO


## Assigns a grid origin and rectangular footprint to this placeable object.
func set_grid_placement(origin: Vector2i, footprint: Vector2i = Vector2i.ONE) -> bool:
	if footprint.x < 1 or footprint.y < 1:
		return false
	grid_origin = origin
	grid_footprint = footprint
	container_id = ""
	location_type = "grid"
	location_id = "grid:%d:%d" % [origin.x, origin.y]
	return true


## Clears the object's grid placement metadata.
func clear_grid_placement() -> void:
	grid_origin = Vector2i(-1, -1)
	grid_footprint = Vector2i.ZERO
	if location_type == "grid":
		clear_location()


## Assigns this object to the conceptual asset-box catalog.
func set_asset_box_location(box_id: String) -> bool:
	if box_id.is_empty():
		return false
	grid_origin = Vector2i(-1, -1)
	grid_footprint = Vector2i.ZERO
	container_id = box_id
	location_type = "asset_box"
	location_id = box_id
	return true


## Backward-compatible alias for the former physical-box API. Origin and
## footprint are intentionally ignored because the runtime box is a catalog.
func set_asset_box_placement(box_id: String, _origin: Vector2i, _footprint: Vector2i = Vector2i.ONE) -> bool:
	return set_asset_box_location(box_id)


## Clears asset-box placement metadata.
func clear_asset_box_placement() -> void:
	if location_type == "asset_box":
		clear_location()


## Assigns a non-negative authoritative quantity.
func set_quantity(value: int) -> bool:
	if value < 0:
		return false
	quantity = value
	return true


## Assigns a non-empty semantic state identifier.
func set_state(value: String) -> bool:
	if value.is_empty():
		return false
	state_id = value
	return true


## Assigns one named extensible property.
func set_property_value(property_name: String, value: Variant) -> bool:
	if property_name.is_empty():
		return false
	properties[property_name] = value
	return true


## Returns all points occupied by this object in deterministic row-major order.
func grid_points() -> Array[Vector2i]:
	if grid_origin.x < 0 or grid_origin.y < 0 or grid_footprint.x < 1 or grid_footprint.y < 1:
		return []
	var points: Array[Vector2i] = []
	for y in grid_footprint.y:
		for x in grid_footprint.x:
			points.append(grid_origin + Vector2i(x, y))
	return points


## Returns a deep-copy snapshot suitable for persistence or deterministic tests.
func to_dictionary() -> Dictionary:
	return {
		"object_id": object_id,
		"component_id": component_id,
		"configuration": configuration.duplicate(true),
		"quantity": quantity,
		"state_id": state_id,
		"properties": properties.duplicate(true),
		"availability": availability_mode,
		"available_quantity": available_quantity,
		"owner_id": owner_id,
		"holder_id": holder_id,
		"location_type": location_type,
		"location_id": location_id,
		"visibility": visibility,
		"container_id": container_id,
		"grid": {
			"origin": {"x": grid_origin.x, "y": grid_origin.y},
			"footprint": {"x": grid_footprint.x, "y": grid_footprint.y},
		},
	}
