class_name GameplayState
extends RefCounted

const EVENT_LIMIT := 256

var session: SessionState
var flow: FlowState
var tabletop: TabletopState
var objects: Dictionary = {}
var event_router := GameEventRouter.new()
var event_history: Array[Dictionary] = []
var revision: int = 0
var _verb_handlers: Dictionary = {}


static func create(
	p_session: SessionState,
	p_flow: FlowState,
	p_tabletop: TabletopState,
	listeners: Array = []
) -> GameplayState:
	var state := GameplayState.new()
	state.session = p_session
	state.flow = p_flow
	state.tabletop = p_tabletop
	state.event_router.configure(listeners)
	state._register_core_verbs()
	return state


## Registers one canonical verb handler without replacing an existing handler.
func register_verb(verb: String, handler: Callable) -> bool:
	if verb.is_empty() or not handler.is_valid() or _verb_handlers.has(verb):
		return false
	_verb_handlers[verb] = handler
	return true


## Adds a valid logical object to the session without assigning a table location.
func register_object(object: LogicalObjectState) -> bool:
	if object == null or object.object_id.is_empty() or object.component_id.is_empty():
		return false
	if object.quantity < 0 or objects.has(object.object_id):
		return false
	objects[object.object_id] = object
	return true


## Registers a logical object and places it in an available authoritative slot.
func add_object(object: LogicalObjectState, slot_id: String) -> bool:
	if not register_object(object):
		return false
	if not tabletop.place_object(object.object_id, slot_id):
		objects.erase(object.object_id)
		return false
	object.set_location("slot", slot_id)
	return true


## The only public mutation entry point for game state.
func execute(command: Dictionary) -> Dictionary:
	var before := to_dictionary()
	var validation := _validate_command_shape(command)
	if not validation.is_empty():
		return _rejected(validation)
	var emitted := _dispatch(command)
	if not bool(emitted.get("ok", false)):
		return emitted
	var pending: Array[Dictionary] = emitted.get("events", [])
	var committed: Array[Dictionary] = []
	while not pending.is_empty():
		if committed.size() >= EVENT_LIMIT:
			_restore_snapshot(before)
			return _rejected("event_limit_exceeded")
		var event: Dictionary = pending.pop_front()
		_normalize_event(event, command, committed.size())
		committed.append(event)
		for generated_command in event_router.commands_for(event):
			var generated: Dictionary = _dispatch(generated_command)
			if not bool(generated.get("ok", false)):
				_restore_snapshot(before)
				return _rejected("listener_command_rejected")
			pending.append_array(generated.get("events", []))
	revision += 1
	event_history.append_array(committed)
	return {"ok": true, "revision": revision, "events": committed}


## Returns the registered verbs currently exposed to an actor and optional target.
func available_verbs(actor_id: String, target_id: String = "") -> Array[String]:
	var result: Array[String] = []
	if session == null or not session.is_active():
		return result
	if session.is_host(actor_id):
		result.append("match.finish")
	if flow.is_active(actor_id):
		result.append("turn.end")
	if not target_id.is_empty() and objects.has(target_id):
		var object: LogicalObjectState = objects[target_id]
		if _can_control(object, actor_id, false):
			for verb in BgoComponentRegistry.verbs(object.component_id):
				if _verb_handlers.has(verb):
					result.append(str(verb))
	return result


## Returns the complete deterministic gameplay snapshot.
func to_dictionary() -> Dictionary:
	var snapshots: Dictionary = {}
	for object_id in objects:
		snapshots[object_id] = (objects[object_id] as LogicalObjectState).to_dictionary()
	return {
		"revision": revision,
		"session": session.to_dictionary(),
		"flow": flow.to_dictionary(),
		"tabletop": tabletop.to_dictionary(),
		"objects": snapshots,
		"events": event_history.duplicate(true),
	}


func _dispatch(command: Dictionary) -> Dictionary:
	var verb := str(command.get("verb", ""))
	if not _verb_handlers.has(verb):
		return _rejected("unknown_verb")
	return (_verb_handlers[verb] as Callable).call(command)


func _register_core_verbs() -> void:
	register_verb("object.move", _move_object)
	register_verb("object.move_to_collection", _move_to_collection)
	register_verb("object.set_quantity", _set_quantity)
	register_verb("object.set_state", _set_state)
	register_verb("turn.end", _end_turn)
	register_verb("match.finish", _finish_match)


func _move_object(command: Dictionary) -> Dictionary:
	var actor_id := str(command["actor_id"])
	var object_id := str(command["target_id"])
	var args: Dictionary = command.get("args", {})
	var target_slot_id := str(args.get("slot_id", ""))
	var object := _authorized_object(actor_id, object_id, bool(args.get("acquire_neutral", false)))
	if object == null:
		return _rejected("not_authorized")
	if object.location_type not in ["slot", "player_area", "hand"]:
		return _rejected("object_location_not_movable")
	if not tabletop.can_accept(target_slot_id):
		return _rejected("destination_unavailable")
	var source_type := object.location_type
	var source_id := object.location_id
	var moved := tabletop.move_object(object_id, target_slot_id) if source_type == "slot" else tabletop.place_object(object_id, target_slot_id)
	if not moved:
		return _rejected("table_move_rejected")
	if object.is_neutral() and object.holder_id.is_empty():
		object.set_holder(actor_id)
	object.set_location("slot", target_slot_id)
	return _events([{
		"type": "object.moved", "source_id": object_id, "actor_id": actor_id,
		"data": {"from_type": source_type, "from_id": source_id, "to_type": "slot", "to_id": target_slot_id}
	}])


func _move_to_collection(command: Dictionary) -> Dictionary:
	var actor_id := str(command["actor_id"])
	var object_id := str(command["target_id"])
	var args: Dictionary = command.get("args", {})
	var collection := str(args.get("collection", ""))
	if collection not in ["player_area", "hand"]:
		return _rejected("invalid_collection")
	var object := _authorized_object(actor_id, object_id, bool(args.get("acquire_neutral", false)))
	if object == null:
		return _rejected("not_authorized")
	var source_type := object.location_type
	var source_id := object.location_id
	if source_type == "slot" and not tabletop.remove_object(object_id):
		return _rejected("table_remove_rejected")
	object.set_holder(actor_id)
	object.set_location(collection, actor_id)
	return _events([{
		"type": "object.moved", "source_id": object_id, "actor_id": actor_id,
		"data": {"from_type": source_type, "from_id": source_id, "to_type": collection, "to_id": actor_id}
	}])


func _set_quantity(command: Dictionary) -> Dictionary:
	var actor_id := str(command["actor_id"])
	var object := _authorized_object(actor_id, str(command["target_id"]), false)
	if object == null:
		return _rejected("not_authorized")
	var previous := object.quantity
	var value := int((command.get("args", {}) as Dictionary).get("value", -1))
	if not object.set_quantity(value):
		return _rejected("invalid_quantity")
	return _events([{"type": "object.quantity_changed", "source_id": object.object_id, "actor_id": actor_id, "data": {"from": previous, "to": value}}])


func _set_state(command: Dictionary) -> Dictionary:
	var actor_id := str(command["actor_id"])
	var object := _authorized_object(actor_id, str(command["target_id"]), false)
	if object == null:
		return _rejected("not_authorized")
	var previous := object.state_id
	var value := str((command.get("args", {}) as Dictionary).get("state", ""))
	if not object.set_state(value):
		return _rejected("invalid_state")
	return _events([{"type": "object.state_changed", "source_id": object.object_id, "actor_id": actor_id, "data": {"from": previous, "to": value}}])


func _end_turn(command: Dictionary) -> Dictionary:
	var actor_id := str(command["actor_id"])
	if not flow.is_active(actor_id):
		return _rejected("not_active_participant")
	var previous_turn := flow.turn_number
	if not flow.end_turn(actor_id):
		return _rejected("turn_end_rejected")
	return _events([
		{"type": "turn.ended", "source_id": "flow", "actor_id": actor_id, "data": {"turn_number": previous_turn}},
		{"type": "turn.started", "source_id": "flow", "actor_id": "system", "data": {"turn_number": flow.turn_number, "active_participant_ids": flow.active_participant_ids.duplicate()}},
	])


func _finish_match(command: Dictionary) -> Dictionary:
	var actor_id := str(command["actor_id"])
	if not session.is_host(actor_id):
		return _rejected("host_required")
	var args: Dictionary = command.get("args", {})
	if not session.end_session(str(args.get("outcome", "")), args.get("winner_participant_ids", [])):
		return _rejected("invalid_match_result")
	return _events([{"type": "match.finished", "source_id": session.session_id, "actor_id": actor_id, "data": session.result.duplicate(true)}])


func _authorized_object(actor_id: String, object_id: String, acquire_neutral: bool) -> LogicalObjectState:
	if session == null or not session.is_active() or not flow.is_active(actor_id):
		return null
	if not objects.has(object_id):
		return null
	var object: LogicalObjectState = objects[object_id]
	return object if _can_control(object, actor_id, acquire_neutral) else null


func _can_control(object: LogicalObjectState, actor_id: String, acquire_neutral: bool) -> bool:
	return object.holder_id == actor_id or (object.holder_id.is_empty() and object.owner_id == actor_id) or (acquire_neutral and object.is_neutral() and object.holder_id.is_empty())


func _validate_command_shape(command: Dictionary) -> String:
	if str(command.get("verb", "")).is_empty():
		return "verb_required"
	if str(command.get("actor_id", "")).is_empty():
		return "actor_required"
	if command.has("expected_revision") and int(command["expected_revision"]) != revision:
		return "stale_revision"
	return ""


func _normalize_event(event: Dictionary, command: Dictionary, index: int) -> void:
	event["id"] = "r%d:e%d" % [revision + 1, event_history.size() + index + 1]
	event["revision"] = revision + 1
	event["caused_by"] = command.get("id", "")


func _events(events: Array[Dictionary]) -> Dictionary:
	return {"ok": true, "events": events}


func _rejected(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


func _restore_snapshot(snapshot: Dictionary) -> void:
	revision = int(snapshot.get("revision", 0))
	event_history = (snapshot.get("events", []) as Array).duplicate(true)
	var session_data: Dictionary = snapshot.get("session", {})
	session.session_id = str(session_data.get("session_id", ""))
	session.host_participant_id = str(session_data.get("host_participant_id", ""))
	session.seat_order.assign(session_data.get("seat_order", []))
	session.participant_seats = (session_data.get("participant_seats", {}) as Dictionary).duplicate(true)
	session.participant_roles = (session_data.get("participant_roles", {}) as Dictionary).duplicate(true)
	session.result = (session_data.get("result", {}) as Dictionary).duplicate(true)
	match str(session_data.get("lifecycle", "lobby")):
		"active": session.lifecycle = SessionState.Lifecycle.ACTIVE
		"ended": session.lifecycle = SessionState.Lifecycle.ENDED
		_: session.lifecycle = SessionState.Lifecycle.LOBBY
	var flow_data: Dictionary = snapshot.get("flow", {})
	flow.phase_id = str(flow_data.get("phase_id", "main"))
	flow.turn_number = int(flow_data.get("turn_number", 0))
	flow.active_participant_ids.assign(flow_data.get("active_participant_ids", []))
	flow.turn_order.assign(flow_data.get("turn_order", []))
	flow.turn_index = int(flow_data.get("turn_index", -1))
	var table_data: Dictionary = snapshot.get("tabletop", {})
	tabletop.sections = (table_data.get("sections", {}) as Dictionary).duplicate(true)
	tabletop.zones = (table_data.get("zones", {}) as Dictionary).duplicate(true)
	tabletop.slots = (table_data.get("slots", {}) as Dictionary).duplicate(true)
	tabletop.object_slots = (table_data.get("object_slots", {}) as Dictionary).duplicate(true)
	objects.clear()
	for object_id_variant in (snapshot.get("objects", {}) as Dictionary):
		var data: Dictionary = snapshot["objects"][object_id_variant]
		var object := LogicalObjectState.create(
			str(data.get("object_id", object_id_variant)),
			str(data.get("component_id", "")),
			str(data.get("owner_id", "")),
			int(data.get("quantity", 1)),
		)
		object.holder_id = str(data.get("holder_id", ""))
		object.location_type = str(data.get("location_type", ""))
		object.location_id = str(data.get("location_id", ""))
		object.visibility = str(data.get("visibility", "public"))
		object.state_id = str(data.get("state_id", "default"))
		object.properties = (data.get("properties", {}) as Dictionary).duplicate(true)
		objects[object.object_id] = object
