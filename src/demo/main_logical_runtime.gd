extends "res://src/demo/main_filtered.gd"

const LOGICAL_SESSION_REPOSITORY = preload(
	"res://src/network/logical_game_session_repository.gd"
)
const RUNTIME_SESSION_ADAPTER = preload("res://src/demo/runtime_session_adapter.gd")

var _runtime_session: RuntimeSessionAdapter
var _turn_status_label: Label


func _create_hud() -> void:
	super._create_hud()
	if client_role != ROLE_PLAYER:
		return
	_turn_status_label = Label.new()
	_turn_status_label.position = Vector2(30, 126)
	_turn_status_label.size = Vector2(900, 30)
	_turn_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_status_label.add_theme_font_size_override("font_size", 15)
	_turn_status_label.text = "TURN · loading logical session…"
	$UI.add_child(_turn_status_label)


func _connect_session() -> void:
	_runtime_session = RUNTIME_SESSION_ADAPTER.new()
	repository = LOGICAL_SESSION_REPOSITORY.new()
	add_child(repository)
	repository.set_logger(logger)
	if not game_definition.is_empty():
		repository.set_game_definition(game_definition)
	repository.session_missing.connect(_on_session_missing)
	repository.session_loaded.connect(_on_session_loaded)
	repository.session_error.connect(_on_session_error)
	repository.piece_changed.connect(_on_piece_changed)
	repository.start(game_id)
	_set_status("Connecting logical runtime to Firebase /games/%s …" % game_id)


func _on_session_loaded(data: Dictionary) -> void:
	super._on_session_loaded(data)
	if _runtime_session == null:
		return
	var loaded := _runtime_session.load_session(game_id, game_definition, data)
	if bool(loaded.get("ok", false)):
		_refresh_logical_turn_ui()
		return
	var reason := str(loaded.get("reason", "logical_session_load_failed"))
	if reason == "stale_remote_state":
		return
	logger.error("LOGICAL_SESSION_LOAD_REJECTED", {"reason": reason})
	_set_status("Logical session rejected · %s" % reason)


func _pick_up_piece(piece: Node3D) -> void:
	if _runtime_session == null:
		_set_status("Logical session is still loading")
		return
	var piece_id := str(piece.get_meta("entity_id"))
	var result := _runtime_session.move_object_to_collection(
		player_id,
		piece_id,
		"player_area",
	)
	if not _persist_accepted_command(result, "pickup"):
		return

	var logical_object: LogicalObjectState = _runtime_session.gameplay_state.objects[piece_id]
	var target := _player_area_world_position(player_id, piece_id)
	piece.set_meta("holder_id", logical_object.holder_id)
	piece.set_meta("location_type", logical_object.location_type)
	_select_piece(piece)
	_animate_piece(piece, target, "logical_pickup")
	_reflow_collection(player_id, "player_area")
	_refresh_hand_strip()
	_set_status("Accepted · %s → PLAYER AREA" % piece.name)
	_refresh_logical_turn_ui()


func _move_selected_to_hand() -> void:
	if selected_piece == null or _runtime_session == null:
		return
	var piece_id := str(selected_piece.get_meta("entity_id"))
	var result := _runtime_session.move_object_to_collection(player_id, piece_id, "hand")
	if not _persist_accepted_command(result, "to_hand"):
		return

	var logical_object: LogicalObjectState = _runtime_session.gameplay_state.objects[piece_id]
	selected_piece.set_meta("holder_id", logical_object.holder_id)
	selected_piece.set_meta("location_type", logical_object.location_type)
	_animate_piece(
		selected_piece,
		_private_hand_proxy_world_position(player_id, piece_id),
		"logical_to_hand",
	)
	_reflow_collection(player_id, "player_area")
	_reflow_collection(player_id, "hand")
	_refresh_hand_strip()
	_set_status("Accepted · %s → HAND" % piece_id)
	_refresh_logical_turn_ui()


func _move_selected_to_area() -> void:
	if selected_piece == null or _runtime_session == null:
		return
	var piece_id := str(selected_piece.get_meta("entity_id"))
	var result := _runtime_session.move_object_to_collection(
		player_id,
		piece_id,
		"player_area",
	)
	if not _persist_accepted_command(result, "to_player_area"):
		return

	var logical_object: LogicalObjectState = _runtime_session.gameplay_state.objects[piece_id]
	selected_piece.set_meta("holder_id", logical_object.holder_id)
	selected_piece.set_meta("location_type", logical_object.location_type)
	_animate_piece(
		selected_piece,
		_player_area_world_position(player_id, piece_id),
		"logical_to_player_area",
	)
	_reflow_collection(player_id, "player_area")
	_reflow_collection(player_id, "hand")
	_refresh_hand_strip()
	_set_status("Accepted · %s → PLAYER AREA" % piece_id)
	_refresh_logical_turn_ui()


func _place_selected_piece(destination: Vector2i) -> void:
	if selected_piece == null or _runtime_session == null:
		return
	var board := $Board as BgoCheckeredBoard
	if board == null or not board.is_valid_cell(destination):
		_set_status("That destination is not a valid board slot")
		return

	var piece := selected_piece
	var piece_id := str(piece.get_meta("entity_id"))
	var target_slot_id := board.slot_id(destination)
	var result := _runtime_session.move_object_and_end_turn(
		player_id,
		piece_id,
		target_slot_id,
	)
	if not _persist_accepted_command(result, "place_and_end_turn"):
		return

	var logical_object: LogicalObjectState = _runtime_session.gameplay_state.objects[piece_id]
	var target := _cell_world(destination) + Vector3(0, 0.35, 0)
	piece.set_meta("holder_id", logical_object.holder_id)
	piece.set_meta("location_type", logical_object.location_type)
	piece.set_meta("cell", destination)
	_animate_piece(piece, target, "logical_place")
	selected_piece = null
	_reflow_collection(player_id, "player_area")
	_reflow_collection(player_id, "hand")
	_refresh_hand_strip()
	_set_status("Accepted · placed %s and completed turn" % piece.name)
	_refresh_logical_turn_ui()


func _update_transfer_buttons() -> void:
	super._update_transfer_buttons()
	if _runtime_session == null or not _runtime_session.is_active_participant(player_id):
		if _transfer_to_hand_button != null:
			_transfer_to_hand_button.disabled = true
		if _transfer_to_area_button != null:
			_transfer_to_area_button.disabled = true


func _persist_accepted_command(result: Dictionary, operation: String) -> bool:
	if not bool(result.get("ok", false)):
		var reason := str(result.get("reason", "rejected"))
		logger.warning(
			"LOGICAL_COMMAND_REJECTED",
			{"operation": operation, "player_id": player_id, "reason": reason},
		)
		_set_status("Action rejected · %s" % reason)
		_refresh_logical_turn_ui()
		return false
	var patch: Dictionary = result.get("persistence_patch", {})
	var logical_repository := repository as LogicalGameSessionRepository
	if logical_repository == null:
		_set_status("Logical persistence adapter is unavailable")
		return false
	logical_repository.persist_logical_patch(patch)
	logger.info(
		"LOGICAL_COMMAND_ACCEPTED",
		{
			"operation": operation,
			"player_id": player_id,
			"revision": int(result.get("revision", 0)),
		},
	)
	return true


func _refresh_logical_turn_ui() -> void:
	if client_role != ROLE_PLAYER or _turn_status_label == null:
		return
	if _runtime_session == null or _runtime_session.gameplay_state == null:
		_turn_status_label.text = "TURN · loading logical session…"
		return
	var session := _runtime_session.gameplay_state.session
	if session.is_ended():
		_turn_status_label.text = "GAME ENDED · %s" % str(session.result.get("outcome", "complete"))
		_set_gameplay_buttons_enabled(false)
		return
	var active_id := _runtime_session.active_participant_id()
	var is_my_turn := _runtime_session.is_active_participant(player_id)
	_turn_status_label.text = "TURN %d · %s%s" % [
		_runtime_session.turn_number(),
		active_id.replace("_", " ").to_upper(),
		" · YOUR TURN" if is_my_turn else "",
	]
	_set_gameplay_buttons_enabled(is_my_turn)


func _set_gameplay_buttons_enabled(enabled: bool) -> void:
	if _pickup_button != null:
		_pickup_button.disabled = not enabled
	if _place_button != null:
		_place_button.disabled = not enabled
	if not enabled:
		if _transfer_to_hand_button != null:
			_transfer_to_hand_button.disabled = true
		if _transfer_to_area_button != null:
			_transfer_to_area_button.disabled = true
	else:
		super._update_transfer_buttons()
