class_name GameSessionRepository
extends Node

signal session_loaded(data: Dictionary)
signal session_missing
signal session_error(message: String)
signal piece_changed(piece_id: String, piece_data: Dictionary)

const DEFAULT_GAME_ID := "TEST001"

var game_id: String = DEFAULT_GAME_ID
var poll_interval_seconds := 0.75
var logger: BgoLogger
var game_definition: Dictionary = {}

var _adapter: FirebaseRestAdapter
var _poll_timer: Timer
var _last_piece_snapshot: Dictionary = {}
var _poll_in_flight := false
var _definition_objects_checked := false


func _ready() -> void:
	_adapter = FirebaseRestAdapter.new()
	add_child(_adapter)
	_adapter.request_succeeded.connect(_on_request_succeeded)
	_adapter.request_failed.connect(_on_request_failed)

	_poll_timer = Timer.new()
	_poll_timer.wait_time = poll_interval_seconds
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(refresh)
	add_child(_poll_timer)


func set_logger(value: BgoLogger) -> void:
	logger = value


func set_game_definition(value: Dictionary) -> void:
	game_definition = value.duplicate(true)
	_definition_objects_checked = false


func start(target_game_id: String = DEFAULT_GAME_ID) -> void:
	game_id = target_game_id
	_log("SESSION_START", {"path": _game_path(), "poll_seconds": poll_interval_seconds})
	refresh()
	_poll_timer.start()


func refresh() -> void:
	if _poll_in_flight:
		return
	_poll_in_flight = true
	_adapter.read(_game_path())


func ensure_demo_session() -> void:
	var initial := _initial_session()
	_log("FIREBASE_WRITE", {"operation": "seed", "path": _game_path()})
	_adapter.write(_game_path(), initial)


func pickup_piece(piece_id: String, actor_id: String) -> void:
	# Compatibility with the first prototype: generic pickup now means moving a
	# public physical object to the player's public area, not to the card hand.
	move_to_player_area(piece_id, actor_id)


func move_to_player_area(piece_id: String, actor_id: String) -> void:
	var revision := Time.get_unix_time_from_system()
	var path := "%s/pieces/%s" % [_game_path(), piece_id]
	var patch := {
		"holder_id": actor_id,
		"location": {"type": "player_area", "player_id": actor_id},
		"revision": revision
	}
	_log(
		"FIREBASE_WRITE",
		{"operation": "player_area", "path": path, "piece_id": piece_id, "actor_id": actor_id}
	)
	_adapter.patch(path, patch)
	_adapter.push(
		"%s/events" % _game_path(),
		{
			"type": "OBJECT_MOVED_TO_PLAYER_AREA",
			"actor_id": actor_id,
			"piece_id": piece_id,
			"timestamp": revision
		}
	)


func move_to_hand(piece_id: String, actor_id: String) -> void:
	var revision := Time.get_unix_time_from_system()
	var path := "%s/pieces/%s" % [_game_path(), piece_id]
	var patch := {
		"holder_id": actor_id,
		"location": {"type": "hand", "player_id": actor_id},
		"revision": revision
	}
	_log(
		"FIREBASE_WRITE",
		{"operation": "hand", "path": path, "piece_id": piece_id, "actor_id": actor_id}
	)
	_adapter.patch(path, patch)
	_adapter.push(
		"%s/events" % _game_path(),
		{
			"type": "OBJECT_MOVED_TO_HAND",
			"actor_id": actor_id,
			"piece_id": piece_id,
			"timestamp": revision
		}
	)


func place_piece(piece_id: String, actor_id: String, cell: Vector2i) -> void:
	var revision := Time.get_unix_time_from_system()
	var path := "%s/pieces/%s" % [_game_path(), piece_id]
	var slot_id := "board:%d:%d" % [cell.x, cell.y]
	var patch := {
		"cell": {"x": cell.x, "y": cell.y},
		"holder_id": "",
		"location": {"type": "slot", "slot_id": slot_id},
		"revision": revision
	}
	_log(
		"FIREBASE_WRITE",
		{
			"operation": "place",
			"path": path,
			"piece_id": piece_id,
			"actor_id": actor_id,
			"slot_id": slot_id
		}
	)
	_adapter.patch(path, patch)
	_adapter.push(
		"%s/events" % _game_path(),
		{
			"type": "OBJECT_PLACED",
			"actor_id": actor_id,
			"piece_id": piece_id,
			"slot_id": slot_id,
			"cell": {"x": cell.x, "y": cell.y},
			"timestamp": revision
		}
	)


func move_piece(piece_id: String, actor_id: String, cell: Vector2i) -> void:
	place_piece(piece_id, actor_id, cell)


func _initial_session() -> Dictionary:
	if game_definition.is_empty():
		return {
			"metadata": {"status": "prototype", "label": "BGO Proof of Concept 01"},
			"pieces":
			{
				"player_1_piece": _piece_payload("player_1", 1, Vector2i(1, 2), 1),
				"player_2_stack": _piece_payload("player_2", 3, Vector2i(6, 3), 1)
			}
		}

	var game: Dictionary = game_definition.get("game", {})
	var initial := {
		"metadata":
		{
			"status": "prototype",
			"definition_id": str(game.get("id", "test001")),
			"schema_version": int(game_definition.get("schema_version", 1))
		},
		"pieces": {}
	}
	var setup: Dictionary = game_definition.get("setup", {})
	var objects: Array = setup.get("objects", [])
	for object_def_variant in objects:
		if not object_def_variant is Dictionary:
			continue
		var object_def: Dictionary = object_def_variant
		initial.pieces[str(object_def.get("id"))] = _state_from_definition(object_def)
	return initial


func _state_from_definition(object_def: Dictionary) -> Dictionary:
	var owner_id := str(object_def.get("owner_id", ""))
	var quantity := int(object_def.get("quantity", 1))
	var location: Dictionary = object_def.get("initial_location", {})
	var slot_id := str(location.get("slot_id", "board:0:0"))
	var cell := _cell_from_slot_id(slot_id)
	return {
		"component_id": str(object_def.get("component", "bgo.piece.basic_cylinder")),
		"object_config": (object_def.get("config", {}) as Dictionary).duplicate(true),
		"owner_id": owner_id,
		"holder_id": "",
		"quantity": quantity,
		"cell": {"x": cell.x, "y": cell.y},
		"location": {"type": "slot", "slot_id": slot_id},
		"revision": Time.get_unix_time_from_system()
	}


func _piece_payload(owner_id: String, quantity: int, cell: Vector2i, revision: float) -> Dictionary:
	return {
		"component_id": "bgo.piece.basic_cylinder",
		"object_config": {"color_source": "player"},
		"owner_id": owner_id,
		"holder_id": "",
		"quantity": quantity,
		"cell": {"x": cell.x, "y": cell.y},
		"location": {"type": "slot", "slot_id": "board:%d:%d" % [cell.x, cell.y]},
		"revision": revision
	}


func _cell_from_slot_id(slot_id: String) -> Vector2i:
	var parts := slot_id.split(":")
	if parts.size() == 3 and parts[0] == "board":
		return Vector2i(int(parts[1]), int(parts[2]))
	return Vector2i.ZERO


func _ensure_definition_objects(session: Dictionary) -> void:
	if _definition_objects_checked or game_definition.is_empty():
		return
	_definition_objects_checked = true
	var existing: Dictionary = session.get("pieces", {})
	var setup: Dictionary = game_definition.get("setup", {})
	var objects: Array = setup.get("objects", [])
	for object_def_variant in objects:
		if not object_def_variant is Dictionary:
			continue
		var object_def: Dictionary = object_def_variant
		var object_id := str(object_def.get("id", ""))
		if object_id.is_empty() or existing.has(object_id):
			continue
		var path := "%s/pieces/%s" % [_game_path(), object_id]
		_log(
			"FIREBASE_WRITE",
			{"operation": "add_definition_object", "path": path, "piece_id": object_id}
		)
		_adapter.write(path, _state_from_definition(object_def))


func _game_path() -> String:
	return "games/%s" % game_id


func _on_request_succeeded(operation: StringName, path: String, data: Variant) -> void:
	if operation != &"read" or path != _game_path():
		return
	_poll_in_flight = false
	if data == null:
		_log("SESSION_MISSING", {"path": path}, "warning")
		session_missing.emit()
		return
	if not data is Dictionary:
		var message := "Unexpected Firebase session payload."
		_log("SESSION_PAYLOAD_ERROR", {"path": path, "value_type": typeof(data)}, "error")
		session_error.emit(message)
		return

	var session: Dictionary = data
	_ensure_definition_objects(session)
	session_loaded.emit(session)
	var current_pieces: Dictionary = session.get("pieces", {})
	for piece_id in current_pieces:
		var current: Dictionary = current_pieces[piece_id]
		if not _last_piece_snapshot.has(piece_id) or _last_piece_snapshot[piece_id] != current:
			_log("PIECE_STATE_RECEIVED", {"piece_id": str(piece_id), "state": current})
			piece_changed.emit(str(piece_id), current)
	_last_piece_snapshot = current_pieces.duplicate(true)


func _on_request_failed(
	operation: StringName, path: String, http_code: int, message: String
) -> void:
	if operation == &"read" and path == _game_path():
		_poll_in_flight = false
	_log(
		"FIREBASE_ERROR",
		{"operation": str(operation), "path": path, "http_code": http_code, "message": message},
		"error"
	)
	session_error.emit("Firebase %s %s failed (%d): %s" % [operation, path, http_code, message])


func _log(event_name: String, payload: Dictionary = {}, level: String = "info") -> void:
	if logger != null:
		logger.log_event(event_name, payload, level)
