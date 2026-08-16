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

var _adapter: FirebaseRestAdapter
var _poll_timer: Timer
var _last_piece_snapshot: Dictionary = {}
var _poll_in_flight := false

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
	var initial := {
		"metadata": {
			"status": "prototype",
			"label": "BGO Proof of Concept 01"
		},
		"pieces": {
			"player_1_piece": _piece_payload("player_1", 1, Vector2i(1, 2), 1),
			"player_2_stack": _piece_payload("player_2", 3, Vector2i(6, 3), 1)
		}
	}
	_log("FIREBASE_WRITE", {"operation": "seed", "path": _game_path()})
	_adapter.write(_game_path(), initial)

func pickup_piece(piece_id: String, actor_id: String) -> void:
	var revision := Time.get_unix_time_from_system()
	var path := "%s/pieces/%s" % [_game_path(), piece_id]
	var patch := {
		"holder_id": actor_id,
		"location": {"type": "hand", "player_id": actor_id},
		"revision": revision
	}
	_log("FIREBASE_WRITE", {"operation": "pickup", "path": path, "piece_id": piece_id, "actor_id": actor_id})
	_adapter.patch(path, patch)
	_adapter.push("%s/events" % _game_path(), {
		"type": "OBJECT_PICKED_UP",
		"actor_id": actor_id,
		"piece_id": piece_id,
		"timestamp": revision
	})

func place_piece(piece_id: String, actor_id: String, cell: Vector2i) -> void:
	var revision := Time.get_unix_time_from_system()
	var path := "%s/pieces/%s" % [_game_path(), piece_id]
	var patch := {
		"cell": {"x": cell.x, "y": cell.y},
		"holder_id": "",
		"location": {"type": "board", "cell": {"x": cell.x, "y": cell.y}},
		"revision": revision
	}
	_log("FIREBASE_WRITE", {"operation": "place", "path": path, "piece_id": piece_id, "actor_id": actor_id, "cell": {"x": cell.x, "y": cell.y}})
	_adapter.patch(path, patch)
	_adapter.push("%s/events" % _game_path(), {
		"type": "OBJECT_PLACED",
		"actor_id": actor_id,
		"piece_id": piece_id,
		"cell": {"x": cell.x, "y": cell.y},
		"timestamp": revision
	})

# Compatibility alias for the first PoC API.
func move_piece(piece_id: String, actor_id: String, cell: Vector2i) -> void:
	place_piece(piece_id, actor_id, cell)

func _piece_payload(owner_id: String, quantity: int, cell: Vector2i, revision: float) -> Dictionary:
	return {
		"owner_id": owner_id,
		"holder_id": "",
		"quantity": quantity,
		"cell": {"x": cell.x, "y": cell.y},
		"location": {"type": "board", "cell": {"x": cell.x, "y": cell.y}},
		"revision": revision
	}

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
	session_loaded.emit(session)
	var current_pieces: Dictionary = session.get("pieces", {})
	for piece_id in current_pieces:
		var current: Dictionary = current_pieces[piece_id]
		if not _last_piece_snapshot.has(piece_id) or _last_piece_snapshot[piece_id] != current:
			_log("PIECE_STATE_RECEIVED", {"piece_id": str(piece_id), "state": current})
			piece_changed.emit(str(piece_id), current)
	_last_piece_snapshot = current_pieces.duplicate(true)

func _on_request_failed(operation: StringName, path: String, http_code: int, message: String) -> void:
	if operation == &"read" and path == _game_path():
		_poll_in_flight = false
	_log("FIREBASE_ERROR", {"operation": str(operation), "path": path, "http_code": http_code, "message": message}, "error")
	session_error.emit("Firebase %s %s failed (%d): %s" % [operation, path, http_code, message])

func _log(event_name: String, payload: Dictionary = {}, level: String = "info") -> void:
	if logger != null:
		logger.log_event(event_name, payload, level)
