class_name LogicalObjectState
extends RefCounted

## Stable logical object identity.
var object_id: String = ""

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


## Creates a logical object with stable identity and optional owner.
static func create(p_object_id: String, p_owner_id: String = "") -> LogicalObjectState:
	var state := LogicalObjectState.new()
	state.object_id = p_object_id
	state.owner_id = p_owner_id
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


## Returns a deep-copy snapshot suitable for persistence or deterministic tests.
func to_dictionary() -> Dictionary:
	return {
		"object_id": object_id,
		"owner_id": owner_id,
		"holder_id": holder_id,
		"location_type": location_type,
		"location_id": location_id,
		"visibility": visibility,
	}
