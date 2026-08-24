class_name GameplayState
extends RefCounted

const HAND_STATE = preload("res://src/core/hand_state.gd")
const EVENT_LIMIT := 256

## Active logical session governing permissions and turn state.
var session: SessionState

## Canonical phase/turn state used by the shared command protocol.
var flow: FlowState

## Logical tabletop occupancy used by gameplay commands.
var tabletop: TabletopState

## The reserve container is owned by the tabletop and is not a render-only UI.
var asset_box

## Logical hands keyed by participant id. Rendering is client-local.
var hands: Dictionary = {}

## Logical objects keyed by stable object id.
var objects: Dictionary = {}

## Canonical event protocol shared by the runtime, console and MCP adapters.
var event_router := GameEventRouter.new()
var event_history: Array[Dictionary] = []
var revision: int = 0
var _verb_handlers: Dictionary = {}


## Creates gameplay state around an existing logical session and tabletop.
static func create(
	p_session: SessionState,
	p_flow_or_tabletop: Variant,
	p_tabletop: TabletopState = null,
	listeners: Array = []
) -> GameplayState:
	var state := GameplayState.new()
	state.session = p_session
	if p_tabletop == null:
		state.tabletop = p_flow_or_tabletop as TabletopState
		state.flow = FlowState.create(p_session.ordered_players())
		state.flow.start()
	else:
		state.flow = p_flow_or_tabletop as FlowState
		state.tabletop = p_tabletop
	state.asset_box = state.tabletop.asset_box if state.tabletop != null else null
	state.event_router.configure(listeners)
	state._register_core_verbs()
	return state


## Registers one canonical verb handler without replacing an existing handler.
func register_verb(verb: String, handler: Callable) -> bool:
	if verb.is_empty() or not handler.is_valid() or _verb_handlers.has(verb):
		return false
	_verb_handlers[verb] = handler
	return true


## Adds a valid logical object without assigning a table location.
func register_object(object: LogicalObjectState) -> bool:
	if object == null or object.object_id.is_empty() or object.component_id.is_empty():
		return false
	if object.quantity < 0 or objects.has(object.object_id):
		return false
	objects[object.object_id] = object
	return true


## The canonical mutation entry point shared by console, adapters and MCP.
func execute(command: Dictionary) -> Dictionary:
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
			return _rejected("event_limit_exceeded")
		var event: Dictionary = pending.pop_front()
		_normalize_event(event, command, committed.size())
		committed.append(event)
		for generated_command in event_router.commands_for(event):
			var generated: Dictionary = _dispatch(generated_command)
			if not bool(generated.get("ok", false)):
				return _rejected("listener_command_rejected")
			pending.append_array(generated.get("events", []))
	revision += 1
	event_history.append_array(committed)
	return {"ok": true, "revision": revision, "events": committed}


## Returns canonical verbs exposed to an actor and optional object.
func available_verbs(actor_id: String, target_id: String = "") -> Array[String]:
	var result: Array[String] = []
	if session == null or not session.is_active():
		return result
	if session.is_host(actor_id):
		result.append("match.finish")
	if flow != null and flow.is_active(actor_id):
		result.append("turn.end")
	if not target_id.is_empty() and objects.has(target_id):
		var object: LogicalObjectState = objects[target_id]
		if _can_control(object, actor_id, false):
			for verb in BgoComponentRegistry.verbs(object.component_id):
				if _verb_handlers.has(verb):
					result.append(str(verb))
	return result


## Returns or creates a participant's logical hand.
func hand_for(participant_id: String) -> HandState:
	if participant_id.is_empty():
		return null
	if not hands.has(participant_id):
		hands[participant_id] = HAND_STATE.create(participant_id)
	return hands[participant_id] as HandState


## Moves an object into a participant's FILO hand after permission checks.
func pickup_object_to_hand(
	requesting_participant_id: String, object_id: String, allow_neutral_acquire := true
) -> Dictionary:
	if session == null or not session.is_active():
		return _rejected("session_not_active")
	if not objects.has(object_id):
		return _rejected("unknown_object")
	var object: LogicalObjectState = objects[object_id]
	if not _can_control(object, requesting_participant_id, allow_neutral_acquire):
		return _rejected("not_authorized")
	var hand := hand_for(requesting_participant_id)
	if hand == null:
		return _rejected("hand_unavailable")
	if hand.contains(object_id):
		return _rejected("object_already_in_hand")
	if object.location_type == "slot":
		if not tabletop.remove_object(object_id):
			return _rejected("table_remove_rejected")
	elif object.location_type == "grid":
		if not tabletop.remove_object(object_id):
			return _rejected("table_remove_rejected")
	if object.is_neutral() and object.holder_id.is_empty() and allow_neutral_acquire:
		object.set_holder(requesting_participant_id)
	object.set_location("hand", requesting_participant_id)
	if not hand.add_object(object_id):
		return _rejected("hand_add_rejected")
	return {
		"ok": true,
		"event": {
			"type": "object_picked_up",
			"object_id": object_id,
			"participant_id": requesting_participant_id,
			"location": "hand",
		},
	}


## Places the selected hand object on a validated tabletop slot.
func place_object_from_hand(
	requesting_participant_id: String, object_id: String, target_slot_id: String
) -> Dictionary:
	if session == null or not session.is_active():
		return _rejected("session_not_active")
	if not objects.has(object_id):
		return _rejected("unknown_object")
	var hand := hand_for(requesting_participant_id)
	if hand == null or not hand.contains(object_id):
		return _rejected("object_not_in_hand")
	var object: LogicalObjectState = objects[object_id]
	if not _can_control(object, requesting_participant_id, false):
		return _rejected("not_authorized")
	if not tabletop.place_object(object_id, target_slot_id):
		return _rejected("destination_unavailable")
	hand.remove_object(object_id)
	object.set_holder("")
	object.set_location("slot", target_slot_id)
	return {
		"ok": true,
		"event": {
			"type": "object_placed_from_hand",
			"object_id": object_id,
			"participant_id": requesting_participant_id,
			"target_slot_id": target_slot_id,
		},
	}


## Registers a logical object at an existing free slot.
func add_object(object: LogicalObjectState, slot_id: String) -> bool:
	if object == null or object.object_id.is_empty() or objects.has(object.object_id):
		return false
	if not tabletop.place_object(object.object_id, slot_id):
		return false
	object.clear_grid_placement()
	objects[object.object_id] = object
	object.set_location("slot", slot_id)
	return true


## Registers a logical object at a grid origin with a rectangular footprint.
func add_object_at_grid(
	object: LogicalObjectState,
	origin: Vector2i,
	footprint: Vector2i = Vector2i.ONE,
	allow_overlap: bool = false
) -> bool:
	if object == null or object.object_id.is_empty() or objects.has(object.object_id):
		return false
	if not tabletop.place_object_at_grid(object.object_id, origin, footprint, allow_overlap):
		return false
	if not object.set_grid_placement(origin, footprint):
		tabletop.remove_object(object.object_id)
		return false
	objects[object.object_id] = object
	return true


## Registers a game-defined component instance in the asset box.
func add_object_to_box(
	object: LogicalObjectState,
	component_id: String,
	config: Dictionary = {},
	quantity: int = 1,
	origin: Vector2i = Vector2i(-1, -1),
	footprint: Vector2i = Vector2i.ONE,
	allow_overlap: bool = false
) -> bool:
	if object == null or object.object_id.is_empty() or objects.has(object.object_id):
		return false
	if asset_box == null or not asset_box.add_asset(
		object.object_id,
		component_id,
		config,
		quantity,
		origin,
		footprint,
		allow_overlap,
		object.availability_mode,
		object.owner_id,
		object.available_quantity
	):
		return false
	object.component_id = component_id
	object.configuration = config.duplicate(true)
	object.quantity = quantity
	object.available_quantity = quantity
	if not object.set_asset_box_location(asset_box.box_id):
		asset_box.remove_asset(object.object_id)
		return false
	objects[object.object_id] = object
	return true


## Takes an object from the asset box and places it on the tabletop grid.
func take_object_from_box(
	requesting_participant_id: String,
	object_id: String,
	origin: Vector2i = Vector2i(-1, -1),
	footprint: Vector2i = Vector2i.ZERO,
	allow_overlap: bool = false,
	allow_neutral_acquire: bool = false
) -> Dictionary:
	var validation := _validate_box_take(
		requesting_participant_id,
		object_id,
		origin,
		footprint,
		allow_overlap,
		allow_neutral_acquire
	)
	if not bool(validation.get("ok", false)):
		return validation
	var object: LogicalObjectState = objects[object_id]
	var asset_definition: Dictionary = asset_box.get_asset(object_id)
	var resolved_origin: Vector2i = validation["origin"]
	var resolved_footprint: Vector2i = validation["footprint"]
	if not tabletop.place_object_at_grid(object_id, resolved_origin, resolved_footprint, allow_overlap):
		return _rejected("table_grid_destination_unavailable")
	var removed: Dictionary = asset_box.remove_asset(object_id)
	if removed.is_empty():
		tabletop.remove_object(object_id)
		return _rejected("asset_box_remove_rejected")
	if not object.set_grid_placement(resolved_origin, resolved_footprint):
		tabletop.remove_object(object_id)
		asset_box.add_asset(
			object_id,
			str(asset_definition.get("component_id", object.component_id)),
			asset_definition.get("config", {}),
			int(asset_definition.get("quantity", object.quantity)),
			Vector2i(-1, -1),
			Vector2i.ONE,
			false,
			str(asset_definition.get("availability", object.availability_mode)),
			str(asset_definition.get("owner_id", object.owner_id)),
			int(asset_definition.get("available_quantity", object.available_quantity))
		)
		return _rejected("object_grid_placement_rejected")
	if object.is_neutral() and object.holder_id.is_empty() and allow_neutral_acquire:
		object.set_holder(requesting_participant_id)
	return {
		"ok": true,
		"event": {
			"type": "object_taken_from_asset_box",
			"object_id": object_id,
			"participant_id": requesting_participant_id,
			"box_id": asset_box.box_id,
			"to_origin": _grid_point_event(resolved_origin),
			"to_footprint": _grid_point_event(resolved_footprint),
		},
	}


## Returns a tabletop object to the asset-box catalog.
func store_object_in_box(
	requesting_participant_id: String,
	object_id: String,
	_origin: Vector2i = Vector2i(-1, -1),
	_footprint: Vector2i = Vector2i.ZERO,
	_allow_overlap: bool = false,
	allow_neutral_acquire: bool = false
) -> Dictionary:
	if session == null or tabletop == null or asset_box == null or not session.is_active():
		return _rejected("session_not_active")
	if not _is_active_participant(requesting_participant_id):
		return _rejected("not_active_participant")
	if not objects.has(object_id):
		return _rejected("unknown_object")
	var object: LogicalObjectState = objects[object_id]
	if object.location_type not in ["slot", "grid"]:
		return _rejected("object_not_on_table")
	if not _can_control(object, requesting_participant_id, allow_neutral_acquire):
		return _rejected("not_authorized")
	if not asset_box.add_asset(
		object_id,
		object.component_id,
		object.configuration,
		object.quantity,
		Vector2i(-1, -1),
		Vector2i.ONE,
		false,
		object.availability_mode,
		object.owner_id,
		object.available_quantity
	):
		return _rejected("asset_box_destination_unavailable")
	var source_location := object.location_id
	if not tabletop.remove_object(object_id):
		asset_box.remove_asset(object_id)
		return _rejected("table_remove_rejected")
	if not object.set_asset_box_location(asset_box.box_id):
		return _rejected("object_asset_box_placement_rejected")
	return {
		"ok": true,
		"event": {
			"type": "object_stored_in_asset_box",
			"object_id": object_id,
			"participant_id": requesting_participant_id,
			"from_location": source_location,
			"box_id": asset_box.box_id,
		},
	}


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
	object.clear_grid_placement()
	return {
		"ok": true,
		"event": _move_event(
			requesting_participant_id, object_id, source_slot_id, target_slot_id
		),
	}


## Moves a grid-placed object while preserving command validation and ownership rules.
func move_object_at_grid(
	requesting_participant_id: String,
	object_id: String,
	origin: Vector2i,
	footprint: Vector2i = Vector2i.ONE,
	allow_overlap: bool = false,
	allow_neutral_acquire: bool = false
) -> Dictionary:
	var validation := _validate_grid_move(
		requesting_participant_id,
		object_id,
		origin,
		footprint,
		allow_overlap,
		allow_neutral_acquire
	)
	if not bool(validation.get("ok", false)):
		return validation
	var object: LogicalObjectState = objects[object_id]
	var source_origin := object.grid_origin
	var source_footprint := object.grid_footprint
	if not tabletop.move_object_at_grid(object_id, origin, footprint, allow_overlap):
		return _rejected("table_grid_move_rejected")
	if not object.set_grid_placement(origin, footprint):
		return _rejected("object_grid_placement_rejected")
	if object.is_neutral() and object.holder_id.is_empty() and allow_neutral_acquire:
		object.set_holder(requesting_participant_id)
	return {
		"ok": true,
		"event": {
			"type": "object_grid_moved",
			"object_id": object_id,
			"participant_id": requesting_participant_id,
			"from_origin": _grid_point_event(source_origin),
			"from_footprint": _grid_point_event(source_footprint),
			"to_origin": _grid_point_event(origin),
			"to_footprint": _grid_point_event(footprint),
		},
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
	if flow == null or not flow.end_turn(requesting_participant_id):
		return _rejected("turn_advance_rejected")
	return {
		"ok": true,
		"events": [
			move_result.get("event", {}),
			{
				"type": "turn_advanced",
				"turn_number": flow.turn_number,
				"active_participant_id": (
					flow.active_participant_ids[0]
					if not flow.active_participant_ids.is_empty()
					else ""
				),
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
		"revision": revision,
		"session": session.to_dictionary(),
		"flow": flow.to_dictionary() if flow != null else {},
		"tabletop": tabletop.to_dictionary(),
		"objects": object_snapshots,
		"asset_box": asset_box.to_dictionary() if asset_box != null else {},
		"hands": _hands_dictionary(),
		"events": event_history.duplicate(true),
	}


func _hands_dictionary() -> Dictionary:
	var result: Dictionary = {}
	for participant_id in hands:
		var hand := hands[participant_id] as HandState
		if hand != null:
			result[participant_id] = hand.to_dictionary()
	return result


func _validate_box_take(
	requesting_participant_id: String,
	object_id: String,
	origin: Vector2i,
	footprint: Vector2i,
	allow_overlap: bool,
	allow_neutral_acquire: bool
) -> Dictionary:
	if session == null or tabletop == null or asset_box == null or not session.is_active():
		return _rejected("session_not_active")
	if not _is_active_participant(requesting_participant_id):
		return _rejected("not_active_participant")
	if not objects.has(object_id) or not asset_box.has_asset(object_id):
		return _rejected("object_not_in_asset_box")
	var object: LogicalObjectState = objects[object_id]
	if object.location_type != "asset_box":
		return _rejected("object_location_mismatch")
	if not _can_control(object, requesting_participant_id, allow_neutral_acquire):
		return _rejected("not_authorized")
	var resolved_footprint: Vector2i = footprint
	if resolved_footprint == Vector2i.ZERO:
		# AssetBoxState is a catalog and deliberately has no footprint. A caller
		# may provide a placement footprint when taking an asset onto the table.
		resolved_footprint = Vector2i.ONE
	var resolved_origin := origin
	if resolved_origin.x < 0 or resolved_origin.y < 0:
		resolved_origin = _first_free_table_origin(resolved_footprint)
	if not tabletop.grid.is_valid_footprint(resolved_origin, resolved_footprint):
		return _rejected("invalid_grid_footprint")
	if not allow_overlap:
		var touching := tabletop.objects_in_grid_area(
			resolved_origin, resolved_origin + resolved_footprint - Vector2i.ONE
		)
		if not touching.is_empty():
			return _rejected("table_grid_destination_unavailable")
	return {"ok": true, "origin": resolved_origin, "footprint": resolved_footprint}


func _first_free_table_origin(footprint: Vector2i) -> Vector2i:
	for y in tabletop.grid.point_rows:
		for x in tabletop.grid.point_columns:
			var origin := Vector2i(x, y)
			if tabletop.grid.is_valid_footprint(origin, footprint) and tabletop.objects_in_grid_area(
				origin, origin + footprint - Vector2i.ONE
			).is_empty():
				return origin
	return Vector2i(-1, -1)


func _validate_move(
	requesting_participant_id: String,
	object_id: String,
	target_slot_id: String,
	allow_neutral_acquire: bool
) -> Dictionary:
	if session == null or tabletop == null or not session.is_active():
		return _rejected("session_not_active")
	if not _is_active_participant(requesting_participant_id):
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


func _validate_grid_move(
	requesting_participant_id: String,
	object_id: String,
	origin: Vector2i,
	footprint: Vector2i,
	allow_overlap: bool,
	allow_neutral_acquire: bool
) -> Dictionary:
	if session == null or tabletop == null or not session.is_active():
		return _rejected("session_not_active")
	if not _is_active_participant(requesting_participant_id):
		return _rejected("not_active_participant")
	if not objects.has(object_id):
		return _rejected("unknown_object")
	var object: LogicalObjectState = objects[object_id]
	if object.location_type != "grid" or not tabletop.grid.has_object(object_id):
		return _rejected("object_not_on_grid")
	if not tabletop.grid.is_valid_footprint(origin, footprint):
		return _rejected("invalid_grid_footprint")
	if not allow_overlap:
		var touching := tabletop.objects_in_grid_area(origin, origin + footprint - Vector2i.ONE)
		touching.erase(object_id)
		if not touching.is_empty():
			return _rejected("grid_destination_unavailable")
	if not _can_control(object, requesting_participant_id, allow_neutral_acquire):
		return _rejected("not_authorized")
	return {"ok": true}


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
	var source_type := ""
	var source_id := ""
	if objects.has(object_id):
		var object: LogicalObjectState = objects[object_id]
		source_type = object.location_type
		source_id = object.location_id
	var result := move_object(
		actor_id,
		object_id,
		str(args.get("slot_id", "")),
		bool(args.get("acquire_neutral", false))
	)
	if not bool(result.get("ok", false)):
		return result
	return _events(
		[{
			"type": "object.moved",
			"source_id": object_id,
			"actor_id": actor_id,
			"data": {
				"from_type": source_type,
				"from_id": source_id,
				"to_type": "slot",
				"to_id": str(args.get("slot_id", "")),
			},
		}]
	)


func _move_to_collection(command: Dictionary) -> Dictionary:
	var actor_id := str(command["actor_id"])
	var object_id := str(command["target_id"])
	var args: Dictionary = command.get("args", {})
	var collection := str(args.get("collection", ""))
	if collection not in ["player_area", "hand"]:
		return _rejected("invalid_collection")
	if not _is_active_participant(actor_id) or not objects.has(object_id):
		return _rejected("not_authorized")
	var object: LogicalObjectState = objects[object_id]
	if not _can_control(object, actor_id, bool(args.get("acquire_neutral", false))):
		return _rejected("not_authorized")
	var source_type := object.location_type
	var source_id := object.location_id
	if collection == "hand":
		var picked := pickup_object_to_hand(
			actor_id, object_id, bool(args.get("acquire_neutral", false))
		)
		if not bool(picked.get("ok", false)):
			return picked
	else:
		if source_type in ["slot", "grid"] and not tabletop.remove_object(object_id):
			return _rejected("table_remove_rejected")
		if source_type == "hand":
			var source_hand := hand_for(actor_id)
			if source_hand != null:
				source_hand.remove_object(object_id)
		object.set_holder(actor_id)
		object.set_location(collection, actor_id)
	return _events(
		[{
			"type": "object.moved",
			"source_id": object_id,
			"actor_id": actor_id,
			"data": {
				"from_type": source_type,
				"from_id": source_id,
				"to_type": collection,
				"to_id": actor_id,
			},
		}]
	)


func _set_quantity(command: Dictionary) -> Dictionary:
	var actor_id := str(command["actor_id"])
	var object := _authorized_object(actor_id, str(command["target_id"]), false)
	if object == null:
		return _rejected("not_authorized")
	var previous := object.quantity
	var value := int((command.get("args", {}) as Dictionary).get("value", -1))
	if not object.set_quantity(value):
		return _rejected("invalid_quantity")
	return _events([{
		"type": "object.quantity_changed",
		"source_id": object.object_id,
		"actor_id": actor_id,
		"data": {"from": previous, "to": value},
	}])


func _set_state(command: Dictionary) -> Dictionary:
	var actor_id := str(command["actor_id"])
	var object := _authorized_object(actor_id, str(command["target_id"]), false)
	if object == null:
		return _rejected("not_authorized")
	var previous := object.state_id
	var value := str((command.get("args", {}) as Dictionary).get("state", ""))
	if not object.set_state(value):
		return _rejected("invalid_state")
	return _events([{
		"type": "object.state_changed",
		"source_id": object.object_id,
		"actor_id": actor_id,
		"data": {"from": previous, "to": value},
	}])


func _end_turn(command: Dictionary) -> Dictionary:
	var actor_id := str(command["actor_id"])
	if flow == null or not flow.is_active(actor_id):
		return _rejected("not_active_participant")
	var previous_turn := flow.turn_number
	if not flow.end_turn(actor_id):
		return _rejected("turn_end_rejected")
	return _events([
		{
			"type": "turn.ended",
			"source_id": "flow",
			"actor_id": actor_id,
			"data": {"turn_number": previous_turn},
		},
		{
			"type": "turn.started",
			"source_id": "flow",
			"actor_id": "system",
			"data": {
				"turn_number": flow.turn_number,
				"active_participant_ids": flow.active_participant_ids.duplicate(),
			},
		},
	])


func _finish_match(command: Dictionary) -> Dictionary:
	var actor_id := str(command["actor_id"])
	if not session.is_host(actor_id):
		return _rejected("host_required")
	var args: Dictionary = command.get("args", {})
	if not session.end_session(
		str(args.get("outcome", "")), args.get("winner_participant_ids", [])
	):
		return _rejected("invalid_match_result")
	return _events([{
		"type": "match.finished",
		"source_id": session.session_id,
		"actor_id": actor_id,
		"data": session.result.duplicate(true),
	}])


func _authorized_object(
	actor_id: String, object_id: String, acquire_neutral: bool
) -> LogicalObjectState:
	if session == null or not session.is_active() or not _is_active_participant(actor_id):
		return null
	if not objects.has(object_id):
		return null
	var object: LogicalObjectState = objects[object_id]
	return object if _can_control(object, actor_id, acquire_neutral) else null


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


func _is_active_participant(participant_id: String) -> bool:
	return flow != null and flow.is_active(participant_id)


func _can_control(
	object: LogicalObjectState, participant_id: String, allow_neutral_acquire: bool
) -> bool:
	if session != null and session.is_host(participant_id):
		# The host can administer owned/held objects, while neutral acquisition
		# remains an explicit command so a plain move cannot silently claim it.
		if object.is_neutral() and object.holder_id.is_empty():
			return allow_neutral_acquire
		return true
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


func _grid_point_event(point: Vector2i) -> Dictionary:
	return {"x": point.x, "y": point.y}
