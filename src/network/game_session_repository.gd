class_name GameSessionRepository
extends Node

signal session_loaded(data: Dictionary)
signal session_missing
signal session_error(message: String)
signal piece_changed(piece_id: String, piece_data: Dictionary)

const MCP_COMMAND_PROCESSOR = preload("res://src/mcp/mcp_command_processor.gd")
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
var _mcp_command_processor: Variant = MCP_COMMAND_PROCESSOR.new()
var _mcp_commands_in_flight: Dictionary = {}
var _mcp_authority_participant_id := ""
var _is_mcp_authority := false


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


## Sets the logger used by the session repository.
func set_logger(value: BgoLogger) -> void:
	logger = value


## Sets the declarative game definition used by the session repository.
func set_game_definition(value: Dictionary) -> void:
	game_definition = value.duplicate(true)
	_definition_objects_checked = false


func _api_get_name() -> String:
	var game: Dictionary = game_definition.get("game", {})
	return str(game.get("name", game.get("id", game_id)))


func _api_get_desc() -> String:
	var game: Dictionary = game_definition.get("game", {})
	return str(game.get("description", ""))


func _api_get_width() -> float:
	var table: Dictionary = game_definition.get("table", {})
	return float(table.get("width", 0.0))


func _api_get_depth() -> float:
	var table: Dictionary = game_definition.get("table", {})
	return float(table.get("depth", 0.0))


func _api_is_turn_based() -> bool:
	var game: Dictionary = game_definition.get("game", {})
	return bool(game.get("turn_based", false))


func console_api() -> Dictionary:
	return {
		"scope": "Game",
		"entity": "definition",
		"class": "GameDefinition",
		"description": "Read-only declarative definition loaded for the current game.",
		"methods":
		{
			"getName": {"call": "_api_get_name", "returns": "String"},
			"getDesc": {"call": "_api_get_desc", "returns": "String"},
			"getWidth": {"call": "_api_get_width", "returns": "float"},
			"getDepth": {"call": "_api_get_depth", "returns": "float"},
			"isTurnBased": {"call": "_api_is_turn_based", "returns": "bool"},
		},
	}


## Enables the one authoritative DEV host client that consumes queued MCP commands.
## This is execution authority, not user authentication.
func set_mcp_command_authority(participant_id: String, enabled: bool) -> void:
	_mcp_authority_participant_id = participant_id
	_is_mcp_authority = enabled and not participant_id.is_empty()


## Starts repository synchronization for the current session context.
func start(target_game_id: String = DEFAULT_GAME_ID) -> void:
	game_id = target_game_id
	_log("SESSION_START", {"path": _game_path(), "poll_seconds": poll_interval_seconds})
	refresh()
	_poll_timer.start()


## Refreshes repository state from the remote source.
func refresh() -> void:
	if _poll_in_flight:
		return
	_poll_in_flight = true
	_adapter.read(_game_path())


## Ensures the development demo session exists with valid initial state.
func ensure_demo_session() -> void:
	var initial := _initial_session()
	_log("FIREBASE_WRITE", {"operation": "seed", "path": _game_path()})
	_adapter.write(_game_path(), initial)


## Moves a whole stack or atomically separates one unit into the player's hand.
## Returns the stable id of the object moved to the hand.
func pickup_piece(piece_id: String, actor_id: String, whole_stack := false) -> String:
	var state: Dictionary = _last_piece_snapshot.get(piece_id, {})
	var quantity := int(state.get("quantity", 1))
	if whole_stack or quantity <= 1:
		move_to_hand(piece_id, actor_id)
		return piece_id

	var revision := Time.get_unix_time_from_system()
	var unit_id := "%s_unit_%d" % [piece_id, Time.get_ticks_msec()]
	var unit_state := state.duplicate(true)
	unit_state["quantity"] = 1
	unit_state["available_quantity"] = 1
	unit_state["holder_id"] = actor_id
	unit_state["location"] = {"type": "hand", "player_id": actor_id}
	unit_state["hand_order"] = Time.get_ticks_msec()
	unit_state["revision"] = revision
	var patch := {}
	patch["pieces/%s/quantity" % piece_id] = quantity - 1
	patch["pieces/%s/revision" % piece_id] = revision
	patch["pieces/%s" % unit_id] = unit_state
	_log(
		"FIREBASE_WRITE",
		{
			"operation": "split_one_to_hand",
			"piece_id": piece_id,
			"unit_id": unit_id,
			"actor_id": actor_id,
			"remaining_quantity": quantity - 1
		}
	)
	_adapter.patch(_game_path(), patch)
	_adapter.push(
		"%s/events" % _game_path(),
		{
			"type": "OBJECT_UNIT_MOVED_TO_HAND",
			"actor_id": actor_id,
			"piece_id": piece_id,
			"unit_id": unit_id,
			"timestamp": revision
		}
	)
	return unit_id


## Moves a logical piece into a player's public area.
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


## Moves a logical piece into a player's private hand.
func move_to_hand(piece_id: String, actor_id: String) -> void:
	var revision := Time.get_unix_time_from_system()
	var path := "%s/pieces/%s" % [_game_path(), piece_id]
	var patch := {
		"holder_id": actor_id,
		"location": {"type": "hand", "player_id": actor_id},
		"hand_order": Time.get_ticks_msec(),
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


## Places a logical piece into an authorized destination slot.
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


## Places a logical piece on a slotless tabletop point grid.
func place_piece_at_grid(
	piece_id: String, actor_id: String, origin: Vector2i, footprint: Vector2i = Vector2i.ONE
) -> void:
	var revision := Time.get_unix_time_from_system()
	var path := "%s/pieces/%s" % [_game_path(), piece_id]
	var point := {"x": origin.x, "y": origin.y}
	var size := {"x": footprint.x, "y": footprint.y}
	var patch := {
		"holder_id": "",
		"location": {"type": "grid", "origin": point, "footprint": size},
		"revision": revision,
	}
	_log(
		"FIREBASE_WRITE",
		{
			"operation": "place_grid",
			"path": path,
			"piece_id": piece_id,
			"actor_id": actor_id,
			"origin": point,
		}
	)
	_adapter.patch(path, patch)
	(
		_adapter
		. push(
			"%s/events" % _game_path(),
			{
				"type": "OBJECT_PLACED_ON_GRID",
				"actor_id": actor_id,
				"piece_id": piece_id,
				"origin": point,
				"footprint": size,
				"timestamp": revision,
			}
		)
	)


## Moves a logical piece between authorized logical locations.
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
	var setup: Dictionary = game_definition.get("setup", {})
	var initial := {
		"metadata":
		{
			"status": "prototype",
			"definition_id": str(game.get("id", "test001")),
			"schema": str(game_definition.get("schema", "bgo.game"))
		},
		"pieces": {},
		"asset_box": (setup.get("asset_box", {}) as Dictionary).duplicate(true),
		"definition": game_definition.duplicate(true),
	}
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
	var availability := _availability_from_definition(object_def)
	var location: Dictionary = object_def.get("initial_location", {})
	var location_type := str(location.get("type", "slot"))
	var slot_id := str(location.get("slot_id", "board:0:0"))
	var cell := _cell_from_slot_id(slot_id)
	var serialized_location := {"type": location_type}
	if location_type == "asset_box":
		# The box is a logical catalog. Legacy origin/footprint data is ignored;
		# the first physical cell is chosen only when the asset is taken out.
		cell = Vector2i.ZERO
		serialized_location["box_id"] = str(location.get("box_id", "box"))
	else:
		serialized_location["slot_id"] = slot_id
	return {
		"component_id": str(object_def.get("component", "bgo.piece.basic_cylinder")),
		"object_config": (object_def.get("config", {}) as Dictionary).duplicate(true),
		"owner_id": owner_id,
		"availability": availability,
		"available_quantity": quantity,
		"holder_id": "",
		"quantity": quantity,
		"cell": {"x": cell.x, "y": cell.y},
		"location": serialized_location,
		"revision": Time.get_unix_time_from_system()
	}


func _piece_payload(owner_id: String, quantity: int, cell: Vector2i, revision: float) -> Dictionary:
	return {
		"component_id": "bgo.piece.basic_cylinder",
		"object_config": {"color_source": "player"},
		"owner_id": owner_id,
		"availability": "unique" if quantity == 1 else "finite",
		"available_quantity": quantity,
		"holder_id": "",
		"quantity": quantity,
		"cell": {"x": cell.x, "y": cell.y},
		"location": {"type": "slot", "slot_id": "board:%d:%d" % [cell.x, cell.y]},
		"revision": revision
	}


func _availability_from_definition(object_def: Dictionary) -> String:
	var raw_value: Variant = object_def.get(
		"qty_available", object_def.get("QtyAvailable", object_def.get("availability", "unique"))
	)
	var value := str(raw_value).to_lower()
	if value in ["unico", "one", "1"]:
		return "unique"
	if value in ["1-n", "finite", "limited"]:
		return "finite"
	if value in ["infinito", "unlimited"]:
		return "infinite"
	return value if value in ["unique", "finite", "infinite"] else "unique"


func _cell_from_slot_id(slot_id: String) -> Vector2i:
	var parts := slot_id.split(":")
	if parts.size() == 3 and parts[0] == "board":
		return Vector2i(int(parts[1]), int(parts[2]))
	return Vector2i.ZERO


func _ensure_definition_objects(session: Dictionary) -> void:
	if _definition_objects_checked or game_definition.is_empty():
		return
	_definition_objects_checked = true
	if not session.has("definition"):
		var definition_path := "%s/definition" % _game_path()
		_log("FIREBASE_WRITE", {"operation": "add_definition", "path": definition_path})
		_adapter.write(definition_path, game_definition.duplicate(true))
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
	_process_pending_mcp_commands(session)
	session_loaded.emit(session)
	var current_pieces: Dictionary = session.get("pieces", {})
	for piece_id in current_pieces:
		var current: Dictionary = current_pieces[piece_id]
		if not _last_piece_snapshot.has(piece_id) or _last_piece_snapshot[piece_id] != current:
			_log("PIECE_STATE_RECEIVED", {"piece_id": str(piece_id), "state": current})
			piece_changed.emit(str(piece_id), current)
	_last_piece_snapshot = current_pieces.duplicate(true)


func _process_pending_mcp_commands(session: Dictionary) -> void:
	if not _is_mcp_authority or game_definition.is_empty():
		return
	var commands: Dictionary = session.get("mcp_commands", {})
	for command_id_variant in commands:
		var command_id := str(command_id_variant)
		var command: Dictionary = commands[command_id_variant]
		if str(command.get("status", "")) != "pending":
			continue
		if _mcp_commands_in_flight.has(command_id):
			continue
		_mcp_commands_in_flight[command_id] = true
		var command_context: Dictionary = command.get("context", {})
		if (
			str(command_context.get("session_id", game_id)) != game_id
			or str(command_context.get("participant_id", "")) != _mcp_authority_participant_id
			or str(command_context.get("role", "")) != "host"
		):
			_finish_mcp_command(command_id, {"ok": false, "reason": "authority_mismatch"})
			continue
		var result: Dictionary = _mcp_command_processor.process(command, session, game_definition)
		_finish_mcp_command(command_id, result)


func _finish_mcp_command(command_id: String, result: Dictionary) -> void:
	var revision := Time.get_unix_time_from_system()
	var accepted := bool(result.get("ok", false))
	var patch := {
		"mcp_commands/%s/status" % command_id: "completed" if accepted else "rejected",
		"mcp_commands/%s/result" % command_id: result.duplicate(true),
		"mcp_commands/%s/processed_at" % command_id: revision,
	}
	if accepted:
		var piece_id := str(result.get("piece_id", ""))
		var piece_state: Dictionary = result.get("piece_state", {})
		if not piece_id.is_empty() and not piece_state.is_empty():
			patch["pieces/%s" % piece_id] = piece_state
	_log(
		"MCP_COMMAND_PROCESSED",
		{
			"command_id": command_id,
			"accepted": accepted,
			"reason": str(result.get("reason", "")),
		}
	)
	_adapter.patch(_game_path(), patch)
	if accepted:
		var event: Dictionary = result.get("event", {})
		if not event.is_empty():
			event["source"] = "mcp"
			event["timestamp"] = revision
			_adapter.push("%s/events" % _game_path(), event)
	_mcp_commands_in_flight.erase(command_id)


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
