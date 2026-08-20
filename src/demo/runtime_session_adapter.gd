class_name RuntimeSessionAdapter
extends RefCounted

const GAMEPLAY_STATE = preload("res://src/core/gameplay_state.gd")
const LOGICAL_OBJECT_STATE = preload("res://src/core/logical_object_state.gd")
const SESSION_STATE = preload("res://src/core/session_state.gd")
const TABLETOP_STATE = preload("res://src/core/tabletop_state.gd")

var gameplay_state: GameplayState
var state_revision: int = 0
var session_id: String = ""
var game_definition: Dictionary = {}


## Loads one logical gameplay state from declarative game data and repository state.
func load_session(
	p_session_id: String, p_game_definition: Dictionary, repository_state: Dictionary
) -> Dictionary:
	var incoming_revision := int(repository_state.get("state_revision", 0))
	if gameplay_state != null and incoming_revision < state_revision:
		return _rejected("stale_remote_state")

	var session := _build_session(p_session_id, p_game_definition, repository_state)
	if session == null:
		return _rejected("invalid_session_state")
	var tabletop := _build_tabletop(p_game_definition)
	if tabletop == null:
		return _rejected("invalid_tabletop_definition")
	var next_gameplay := GAMEPLAY_STATE.create(session, tabletop)
	var objects_result := _load_objects(next_gameplay, repository_state)
	if not bool(objects_result.get("ok", false)):
		return objects_result

	session_id = p_session_id
	game_definition = p_game_definition.duplicate(true)
	gameplay_state = next_gameplay
	state_revision = incoming_revision
	return {
		"ok": true,
		"revision": state_revision,
		"snapshot": gameplay_state.to_dictionary(),
	}


## Returns the active participant for the current logical session.
func active_participant_id() -> String:
	if gameplay_state == null or gameplay_state.session == null:
		return ""
	return gameplay_state.session.active_participant_id


## Returns the current 1-based turn number, or zero before a session is loaded.
func turn_number() -> int:
	if gameplay_state == null or gameplay_state.session == null:
		return 0
	return gameplay_state.session.turn_number


## Returns whether the supplied participant may currently perform gameplay commands.
func is_active_participant(participant_id: String) -> bool:
	return not participant_id.is_empty() and participant_id == active_participant_id()


## Moves a controlled object into the active participant's player area or hand.
func move_object_to_collection(
	participant_id: String, object_id: String, collection_type: String
) -> Dictionary:
	if gameplay_state == null:
		return _rejected("session_not_loaded")
	var allow_neutral_acquire := _object_is_available_neutral(object_id)
	var result := (
		gameplay_state
		. move_object_to_collection(
			participant_id,
			object_id,
			collection_type,
			allow_neutral_acquire,
		)
	)
	return _finalize_command(result, object_id)


## Moves an object to a slot and completes the active participant's turn.
func move_object_and_end_turn(
	participant_id: String, object_id: String, target_slot_id: String
) -> Dictionary:
	if gameplay_state == null:
		return _rejected("session_not_loaded")
	var allow_neutral_acquire := _object_is_available_neutral(object_id)
	var result := (
		gameplay_state
		. move_and_end_turn(
			participant_id,
			object_id,
			target_slot_id,
			allow_neutral_acquire,
		)
	)
	return _finalize_command(result, object_id)


## Returns a deterministic snapshot of the loaded logical gameplay state.
func snapshot() -> Dictionary:
	if gameplay_state == null:
		return {}
	return gameplay_state.to_dictionary()


func _build_session(
	p_session_id: String, p_game_definition: Dictionary, repository_state: Dictionary
) -> SessionState:
	var persisted: Dictionary = repository_state.get("session", {})
	if not persisted.is_empty():
		return _session_from_snapshot(p_session_id, persisted)
	return _new_session_from_definition(p_session_id, p_game_definition)


func _new_session_from_definition(
	p_session_id: String, p_game_definition: Dictionary
) -> SessionState:
	var players: Array = p_game_definition.get("players", [])
	if players.is_empty():
		return null
	var first_player_id := str(players[0].get("id", ""))
	if first_player_id.is_empty():
		return null
	var session: SessionState = SESSION_STATE.create_lobby(p_session_id, first_player_id)
	for index in players.size():
		var player: Dictionary = players[index]
		var participant_id := str(player.get("id", ""))
		if participant_id.is_empty():
			return null
		if not (
			session
			. assign_participant(
				participant_id,
				"seat-%d" % (index + 1),
				"player",
			)
		):
			return null
	if not session.start_session():
		return null
	return session


func _session_from_snapshot(p_session_id: String, persisted: Dictionary) -> SessionState:
	var session := SESSION_STATE.new()
	session.session_id = str(persisted.get("session_id", p_session_id))
	if session.session_id.is_empty():
		session.session_id = p_session_id
	session.host_participant_id = str(persisted.get("host_participant_id", ""))
	for seat_id in persisted.get("seat_order", []):
		session.seat_order.append(str(seat_id))
	session.participant_seats = ((persisted.get("participant_seats", {}) as Dictionary).duplicate(
		true
	))
	session.participant_roles = ((persisted.get("participant_roles", {}) as Dictionary).duplicate(
		true
	))
	session.active_participant_id = str(persisted.get("active_participant_id", ""))
	session.turn_number = int(persisted.get("turn_number", 0))
	session.result = (persisted.get("result", {}) as Dictionary).duplicate(true)
	session.lifecycle = _lifecycle_value(str(persisted.get("lifecycle", "lobby")))
	if session.lifecycle < 0:
		return null
	return session


func _build_tabletop(p_game_definition: Dictionary) -> TabletopState:
	var board: Dictionary = p_game_definition.get("board", {})
	var config: Dictionary = board.get("config", {})
	var columns := int(config.get("columns", 0))
	var rows := int(config.get("rows", 0))
	if columns < 1 or rows < 1:
		return null
	var tabletop: TabletopState = TABLETOP_STATE.new()
	if not tabletop.add_section("main") or not tabletop.add_zone("board", "main"):
		return null
	for y in rows:
		for x in columns:
			if not tabletop.add_slot("board:%d:%d" % [x, y], "board", 1):
				return null
	return tabletop


func _load_objects(gameplay: GameplayState, repository_state: Dictionary) -> Dictionary:
	var pieces: Dictionary = repository_state.get("pieces", {})
	for object_id_variant in pieces:
		var object_id := str(object_id_variant)
		var piece_state: Dictionary = pieces[object_id_variant]
		var object := (
			LOGICAL_OBJECT_STATE
			. create(
				object_id,
				str(piece_state.get("owner_id", "")),
			)
		)
		object.set_holder(str(piece_state.get("holder_id", "")))
		object.visibility = str(piece_state.get("visibility", "public"))
		var location: Dictionary = piece_state.get("location", {})
		var location_type := _normalize_location_type(str(location.get("type", "slot")))
		var location_id := _location_id(location_type, location, object.holder_id)
		if location_type == "slot":
			if not gameplay.add_object(object, location_id):
				return _rejected("invalid_object_slot")
		else:
			if not object.set_location(location_type, location_id):
				return _rejected("invalid_object_location")
			if not gameplay.register_object(object):
				return _rejected("duplicate_object")
	return {"ok": true}


func _location_id(location_type: String, location: Dictionary, holder_id: String) -> String:
	if location_type == "slot":
		return str(location.get("slot_id", ""))
	if location_type in ["player_area", "hand"]:
		return str(location.get("player_id", holder_id))
	return ""


func _normalize_location_type(value: String) -> String:
	return "slot" if value == "board" else value


func _lifecycle_value(value: String) -> int:
	match value:
		"lobby":
			return SESSION_STATE.Lifecycle.LOBBY
		"active":
			return SESSION_STATE.Lifecycle.ACTIVE
		"ended":
			return SESSION_STATE.Lifecycle.ENDED
		_:
			return -1


func _object_is_available_neutral(object_id: String) -> bool:
	if gameplay_state == null or not gameplay_state.objects.has(object_id):
		return false
	var object: LogicalObjectState = gameplay_state.objects[object_id]
	return object.is_neutral() and object.holder_id.is_empty()


func _finalize_command(result: Dictionary, object_id: String) -> Dictionary:
	if not bool(result.get("ok", false)):
		return result
	state_revision += 1
	var finalized := result.duplicate(true)
	finalized["revision"] = state_revision
	finalized["persistence_patch"] = _persistence_patch(object_id)
	return finalized


func _persistence_patch(object_id: String) -> Dictionary:
	var object: LogicalObjectState = gameplay_state.objects[object_id]
	var patch := {
		"state_revision": state_revision,
		"session": gameplay_state.session.to_dictionary(),
		"pieces/%s/owner_id" % object_id: object.owner_id,
		"pieces/%s/holder_id" % object_id: object.holder_id,
		"pieces/%s/location" % object_id: _repository_location(object),
		"pieces/%s/revision" % object_id: state_revision,
	}
	if object.location_type == "slot":
		patch["pieces/%s/cell" % object_id] = _cell_payload(object.location_id)
	return patch


func _repository_location(object: LogicalObjectState) -> Dictionary:
	if object.location_type == "slot":
		return {"type": "slot", "slot_id": object.location_id}
	return {"type": object.location_type, "player_id": object.location_id}


func _cell_payload(slot_id: String) -> Dictionary:
	var parts := slot_id.split(":")
	if parts.size() == 3 and parts[0] == "board":
		return {"x": int(parts[1]), "y": int(parts[2])}
	return {"x": 0, "y": 0}


func _rejected(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
