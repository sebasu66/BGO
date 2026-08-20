class_name GameplayState
extends RefCounted

## Active logical session governing permissions and turn state.
var session: SessionState

## Logical tabletop occupancy used by gameplay commands.
var tabletop: TabletopState

## Logical objects keyed by stable object id.
var objects: Dictionary = {}


## Creates gameplay state around an existing logical session and tabletop.
static func create(p_session: SessionState, p_tabletop: TabletopState) -> GameplayState:
	var state := GameplayState.new()
	state.session = p_session
	state.tabletop = p_tabletop
	return state


## Registers a logical object at an existing free slot.
func add_object(object: LogicalObjectState, slot_id: String) -> bool:
	if object == null or object.object_id.is_empty() or objects.has(object.object_id):
		return false
	if not tabletop.place_object(object.object_id, slot_id):
		return false
	objects[object.object_id] = object
	object.set_location("slot", slot_id)
	return true


## Applies a validated logical move and returns a stable command result.
func move_object(
	requesting_participant_id: String,
	object_id: String,
	target_slot_id: String,
	allow_neutral_acquire: bool = false
) -> Dictionary:
	var validation := _validate_move(
		requesting_participant_id, object_id, target_slot_id, allow_neutral_acquire
	)
	if not bool(validation.get("ok", false)):
		return validation
	var object: LogicalObjectState = objects[object_id]
	var source_slot_id := object.location_id
	if not tabletop.move_object(object_id, target_slot_id):
		return _rejected("table_move_rejected")
	if object.is_neutral() and object.holder_id.is_empty() and allow_neutral_acquire:
		object.set_holder(requesting_participant_id)
	object.set_location("slot", target_slot_id)
	return {
		"ok": true,
		"event": _move_event(requesting_participant_id, object_id, source_slot_id, target_slot_id),
	}


## Applies one valid move and advances the turn only when the move succeeds.
func move_and_end_turn(
	requesting_participant_id: String,
	object_id: String,
	target_slot_id: String,
	allow_neutral_acquire: bool = false
) -> Dictionary:
	var move_result := move_object(
		requesting_participant_id, object_id, target_slot_id, allow_neutral_acquire
	)
	if not bool(move_result.get("ok", false)):
		return move_result
	if not session.advance_turn(requesting_participant_id):
		return _rejected("turn_advance_rejected")
	return {
		"ok": true,
		"events":
		[
			move_result.get("event", {}),
			{
				"type": "turn_advanced",
				"turn_number": session.turn_number,
				"active_participant_id": session.active_participant_id,
			},
		],
	}


## Returns a deterministic snapshot of session, tabletop and objects.
func to_dictionary() -> Dictionary:
	var object_snapshots: Dictionary = {}
	for object_id in objects:
		var object: LogicalObjectState = objects[object_id]
		object_snapshots[object_id] = object.to_dictionary()
	return {
		"session": session.to_dictionary(),
		"tabletop": tabletop.to_dictionary(),
		"objects": object_snapshots,
	}


func _validate_move(
	requesting_participant_id: String,
	object_id: String,
	target_slot_id: String,
	allow_neutral_acquire: bool
) -> Dictionary:
	if session == null or tabletop == null or not session.is_active():
		return _rejected("session_not_active")
	if requesting_participant_id != session.active_participant_id:
		return _rejected("not_active_participant")
	if not objects.has(object_id):
		return _rejected("unknown_object")
	var object: LogicalObjectState = objects[object_id]
	if object.location_type != "slot" or object.location_id.is_empty():
		return _rejected("object_not_in_slot")
	if not tabletop.can_accept(target_slot_id):
		return _rejected("destination_unavailable")
	if not _can_control(object, requesting_participant_id, allow_neutral_acquire):
		return _rejected("not_authorized")
	return {"ok": true}


func _can_control(
	object: LogicalObjectState, participant_id: String, allow_neutral_acquire: bool
) -> bool:
	if object.holder_id == participant_id:
		return true
	if object.holder_id.is_empty() and object.owner_id == participant_id:
		return true
	return object.is_neutral() and object.holder_id.is_empty() and allow_neutral_acquire


func _move_event(
	participant_id: String, object_id: String, source_slot_id: String, target_slot_id: String
) -> Dictionary:
	return {
		"type": "object_moved",
		"object_id": object_id,
		"participant_id": participant_id,
		"from_slot_id": source_slot_id,
		"to_slot_id": target_slot_id,
	}


func _rejected(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
