class_name LogicalObjectState
extends RefCounted

## Stable logical object identity.
var object_id: String = ""

## Stable component contract used to interpret capabilities and presentation.
var component_id: String = ""

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

## Logical amount represented by this object. It is independent from rendering.
var quantity: int = 1

## Named semantic state declared by the game/component contract.
var state_id: String = "default"

## Extensible serializable state owned by the logical object.
var properties: Dictionary = {}


## Creates a logical object with stable identity and optional owner.
static func create(
	p_object_id: String, p_component_id: String, p_owner_id: String = "", p_quantity: int = 1
) -> LogicalObjectState:
	var state := LogicalObjectState.new()
	state.object_id = p_object_id
	state.component_id = p_component_id
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
	location_type = p_location_type
	location_id = p_location_id
	return true


## Clears the object's logical location.
func clear_location() -> void:
	location_type = ""
	location_id = ""


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


## Returns a deep-copy snapshot suitable for persistence or deterministic tests.
func to_dictionary() -> Dictionary:
	return {
		"object_id": object_id,
		"component_id": component_id,
		"owner_id": owner_id,
		"holder_id": holder_id,
		"location_type": location_type,
		"location_id": location_id,
		"visibility": visibility,
		"quantity": quantity,
		"state_id": state_id,
		"properties": properties.duplicate(true),
	}
