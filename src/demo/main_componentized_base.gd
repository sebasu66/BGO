extends "res://src/demo/main_3d.gd"

const GAME_DEFINITION_PATH := "res://games/test001/game.jsonh"

var game_definition: Dictionary = {}
var definition_errors: Array[String] = []
var _private_hand_strip: HBoxContainer
var _transfer_to_hand_button: Button
var _transfer_to_area_button: Button


func _load_game_definition() -> void:
	var result := BgoGameDefinitionLoader.load_game(GAME_DEFINITION_PATH)
	if bool(result.get("ok", false)):
		game_definition = (result.get("data", {}) as Dictionary).duplicate(true)
		definition_errors.clear()
		return
	game_definition.clear()
	definition_errors = result.get("errors", [])
	for message in definition_errors:
		push_warning("Game definition ignored: %s" % message)


func _show_definition_errors() -> void:
	if _status_label == null or definition_errors.is_empty():
		return
	_set_status("Definition ignored · %s" % definition_errors[0])
	if logger != null:
		logger.error(
			"GAME_DEFINITION_REJECTED", {"path": GAME_DEFINITION_PATH, "errors": definition_errors}
		)


func _create_board() -> void:
	var board := $Board as BgoCheckeredBoard
	if board == null:
		push_error("Main/Board must be a BgoCheckeredBoard component instance.")
		return

	var columns := GRID_COLUMNS
	var rows := GRID_ROWS
	var cell_size := CELL_SIZE
	if not game_definition.is_empty():
		var board_definition: Dictionary = game_definition.get("board", {})
		var component_id := str(board_definition.get("component", ""))
		if BgoComponentRegistry.get_kind(component_id) == "board":
			var config: Dictionary = board_definition.get("config", {})
			columns = int(config.get("columns", columns))
			rows = int(config.get("rows", rows))
			cell_size = float(config.get("cell_size", cell_size))
	board.configure(columns, rows, cell_size)


func _create_player_areas() -> void:
	var p1 := $Player1Area as BgoPlayerArea
	var p2 := $Player2Area as BgoPlayerArea
	_configure_player_area(
		p1, _player_definition("player_1"), "player_1", "PLAYER 1", Color(0.45, 0.31, 0.06)
	)
	_configure_player_area(
		p2, _player_definition("player_2"), "player_2", "PLAYER 2", Color(0.07, 0.27, 0.43)
	)


func _configure_player_area(
	area: BgoPlayerArea,
	definition: Dictionary,
	fallback_id: String,
	fallback_label: String,
	fallback_color: Color
) -> void:
	if area == null:
		return
	var id := str(definition.get("id", fallback_id))
	area.player_id = id
	area.label_text = (
		str(definition.get("label", id.to_upper().replace("_", " ")))
		if not definition.is_empty()
		else fallback_label
	)
	area.area_color = _color_from_definition(definition, fallback_color)


func _player_definition(target_player_id: String) -> Dictionary:
	if game_definition.is_empty():
		return {}
	var players: Array = game_definition.get("players", [])
	for value in players:
		if value is Dictionary and str(value.get("id", "")) == target_player_id:
			return value
	return {}


func _player_color(target_player_id: String) -> Color:
	if target_player_id.is_empty():
		return Color(0.91, 0.88, 0.81)
	var fallback := (
		Color(0.95, 0.72, 0.22) if target_player_id == "player_1" else Color(0.30, 0.72, 0.95)
	)
	return _color_from_definition(_player_definition(target_player_id), fallback)


func _color_from_definition(definition: Dictionary, fallback: Color) -> Color:
	var value := str(definition.get("color", ""))
	if value.is_empty():
		return fallback
	return Color.from_string(value, fallback)


func _configure_camera() -> void:
	if client_role == ROLE_DISPLAY:
		super._configure_camera()
		return
	_camera_focus = Vector3.ZERO
	_desired_focus = Vector3.ZERO
	_camera_pitch = deg_to_rad(42.0)
	_camera_distance = 10.6
	_camera_yaw = deg_to_rad(-90.0 if player_id == "player_1" else 90.0)
	_update_camera_transform()


func _create_piece_from_state(id: String, state: Dictionary, cell: Vector2i) -> void:
	var component_id := str(state.get("component_id", "bgo.piece.basic_cylinder"))
	var packed_scene := BgoComponentRegistry.load_scene(component_id)
	if packed_scene == null:
		logger.error("PIECE_COMPONENT_MISSING", {"piece_id": id, "component_id": component_id})
		return

	var owner := str(state.get("owner_id", ""))
	var holder := str(state.get("holder_id", ""))
	var quantity := int(state.get("quantity", 1))
	var object_config: Dictionary = state.get("object_config", {})
	var color := _player_color(owner)
	if str(object_config.get("color_source", "player")) == "fixed":
		color = Color.from_string(
			str(object_config.get("color", "#E7E0CF")), Color(0.91, 0.88, 0.81)
		)

	var body := packed_scene.instantiate() as Node3D
	if body == null:
		logger.error("PIECE_COMPONENT_INVALID", {"piece_id": id, "component_id": component_id})
		return
	if body is BgoBasicCylinderPiece:
		(body as BgoBasicCylinderPiece).configure(id, owner, holder, quantity, color)
	else:
		body.name = id
		body.set_meta("bgo_piece", true)
		body.set_meta("entity_id", id)
		body.set_meta("owner_id", owner)
		body.set_meta("holder_id", holder)
		body.set_meta("quantity", quantity)

	var location: Dictionary = state.get("location", {})
	var location_type := _normalize_location_type(str(location.get("type", "slot")))
	body.set_meta("component_id", component_id)
	body.set_meta("cell", cell)
	body.set_meta("location_type", location_type)
	body.position = _target_world_position(id, state, cell)
	$Pieces.add_child(body)
	pieces[id] = body
	logger.info(
		"PIECE_CREATED",
		{
			"piece_id": id,
			"component": component_id,
			"owner_id": owner,
			"location_type": location_type,
			"position": _vec3_payload(body.position)
		}
	)


func _normalize_location_type(value: String) -> String:
	return "slot" if value == "board" else value


func _target_world_position(piece_id: String, state: Dictionary, cell: Vector2i) -> Vector3:
	var location: Dictionary = state.get("location", {})
	var location_type := _normalize_location_type(str(location.get("type", "slot")))
	match location_type:
		"player_area":
			var area_player := str(location.get("player_id", state.get("holder_id", "player_1")))
			return _player_area_world_position(area_player, piece_id)
		"hand":
			var hand_player := str(location.get("player_id", state.get("holder_id", "player_1")))
			return _private_hand_proxy_world_position(hand_player, piece_id)
		"slot":
			var board := $Board as BgoCheckeredBoard
			var slot_id := str(location.get("slot_id", ""))
			if board != null and not slot_id.is_empty() and board.is_valid_slot(slot_id):
				return board.slot_world(slot_id) + Vector3(0, 0.35, 0)
	return _cell_world(cell) + Vector3(0, 0.35, 0)


func _player_area_world_position(holder: String, piece_id: String) -> Vector3:
	var slot := _collection_slot_index(holder, piece_id, "player_area")
	var area := ($Player2Area if holder == "player_2" else $Player1Area) as BgoPlayerArea
	if area != null:
		return area.area_slot_world(slot)
	return super._hand_world_position(holder, piece_id)


func _private_hand_proxy_world_position(holder: String, piece_id: String) -> Vector3:
	var slot := _collection_slot_index(holder, piece_id, "hand")
	var area := ($Player2Area if holder == "player_2" else $Player1Area) as BgoPlayerArea
	if area != null:
		var side := -1.0 if holder == "player_1" else 1.0
		return area.global_position + Vector3(side * 0.95, 0.55, -2.3 + float(slot) * 0.85)
	return super._hand_world_position(holder, piece_id)


func _collection_slot_index(holder: String, piece_id: String, location_type: String) -> int:
	var ids: Array[String] = []
	for key in pieces.keys():
		var piece := pieces[key] as Node3D
		if (
			piece != null
			and str(piece.get_meta("location_type", "slot")) == location_type
			and str(piece.get_meta("holder_id", "")) == holder
		):
			ids.append(str(key))
	if not ids.has(piece_id):
		ids.append(piece_id)
	ids.sort()
	return maxi(ids.find(piece_id), 0)


func _cell_world(cell: Vector2i) -> Vector3:
	var board := $Board as BgoCheckeredBoard
	if board != null:
		return board.cell_world(cell)
	return super._cell_world(cell)
