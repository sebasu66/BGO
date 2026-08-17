extends "res://src/demo/main_3d.gd"

const GAME_DEFINITION_PATH := "res://games/test001/game.jsonh"

var game_definition: Dictionary = {}
var definition_errors: Array[String] = []
var _private_hand_strip: HBoxContainer

func _ready() -> void:
	_request_landscape_orientation()
	_load_game_definition()
	var preview := get_node_or_null("EditorPreview")
	if preview != null:
		preview.queue_free()
	super._ready()
	if not game_definition.is_empty():
		var game: Dictionary = game_definition.get("game", {})
		title_label.text = "BGO · %s · %s" % [str(game.get("name", game_id)), client_role.to_upper()]
	if not definition_errors.is_empty():
		call_deferred("_show_definition_errors")

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
		logger.error("GAME_DEFINITION_REJECTED", {"path": GAME_DEFINITION_PATH, "errors": definition_errors})

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
	_configure_player_area(p1, _player_definition("player_1"), "player_1", "PLAYER 1", Color(0.45, 0.31, 0.06))
	_configure_player_area(p2, _player_definition("player_2"), "player_2", "PLAYER 2", Color(0.07, 0.27, 0.43))

func _configure_player_area(area: BgoPlayerArea, definition: Dictionary, fallback_id: String, fallback_label: String, fallback_color: Color) -> void:
	if area == null:
		return
	var id := str(definition.get("id", fallback_id))
	area.player_id = id
	area.label_text = str(definition.get("label", id.to_upper().replace("_", " "))) if not definition.is_empty() else fallback_label
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
	var fallback := Color(0.95, 0.72, 0.22) if target_player_id == "player_1" else Color(0.30, 0.72, 0.95)
	return _color_from_definition(_player_definition(target_player_id), fallback)

func _color_from_definition(definition: Dictionary, fallback: Color) -> Color:
	var value := str(definition.get("color", ""))
	if value.is_empty():
		return fallback
	return Color.from_string(value, fallback)

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
		color = Color.from_string(str(object_config.get("color", "#E7E0CF")), Color(0.91, 0.88, 0.81))

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
	logger.info("PIECE_CREATED", {"piece_id": id, "component": component_id, "owner_id": owner, "location_type": location_type, "position": _vec3_payload(body.position)})

func _normalize_location_type(value: String) -> String:
	return "slot" if value == "board" else value

func _on_piece_tapped(piece: Node3D) -> void:
	var owner_id := str(piece.get_meta("owner_id", ""))
	var holder_id := str(piece.get_meta("holder_id", ""))
	var location_type := str(piece.get_meta("location_type", "slot"))
	logger.info("PIECE_TAPPED", {"piece_id": piece.name, "owner_id": owner_id, "holder_id": holder_id, "location_type": location_type, "mode": interaction_mode})

	# Neutral pieces (owner_id == "") may be claimed while public. A piece currently
	# held by another player cannot be manipulated by this client.
	if not holder_id.is_empty() and holder_id != player_id:
		_set_status("That object is currently held by %s" % holder_id)
		logger.warning("PIECE_CONTROL_DENIED", {"piece_id": piece.name, "holder_id": holder_id, "player_id": player_id})
		return
	if not owner_id.is_empty() and owner_id != player_id and holder_id != player_id:
		_set_status("That object belongs to %s" % owner_id)
		logger.warning("PIECE_CONTROL_DENIED", {"piece_id": piece.name, "owner_id": owner_id, "player_id": player_id})
		return

	if interaction_mode == MODE_PICK_UP:
		if location_type in ["player_area", "hand"] and holder_id == player_id:
			_select_piece(piece)
			_set_status("%s is active" % piece.name)
			return
		_pick_up_piece(piece)
	else:
		_select_piece(piece)
		_set_status("Selected %s" % piece.name)

func _pick_up_piece(piece: Node3D) -> void:
	var piece_id := str(piece.get_meta("entity_id"))
	var target := _player_area_world_position(player_id, piece_id)
	repository.move_to_player_area(piece_id, player_id)
	logger.info("PICKUP_REQUESTED", {"piece_id": piece_id, "destination": "player_area", "duration": MOVE_DURATION, "target": _vec3_payload(target)})
	piece.set_meta("holder_id", player_id)
	piece.set_meta("location_type", "player_area")
	_select_piece(piece)
	_animate_piece(piece, target, "pickup")
	_refresh_hand_strip()
	_set_status("Picked up %s · moving to your PLAYER AREA" % piece.name)
	_set_debug("pickup → player area: %s" % piece.name)

func _place_selected_piece(destination: Vector2i) -> void:
	if selected_piece == null:
		return
	var board := $Board as BgoCheckeredBoard
	if board != null and not board.is_valid_cell(destination):
		_set_status("That destination is not a valid board slot")
		return

	var piece := selected_piece
	var piece_id := str(piece.get_meta("entity_id"))
	var target := _cell_world(destination) + Vector3(0, 0.35, 0)
	repository.place_piece(piece_id, player_id, destination)
	logger.info("PLACE_REQUESTED", {"piece_id": piece_id, "slot_id": board.slot_id(destination) if board != null else "", "duration": MOVE_DURATION, "target": _vec3_payload(target)})
	piece.set_meta("holder_id", "")
	piece.set_meta("location_type", "slot")
	piece.set_meta("cell", destination)
	_animate_piece(piece, target, "place")
	selected_piece = null
	_refresh_hand_strip()
	_set_status("Placed %s" % piece.name)
	_set_debug("place slot: %s" % destination)

func _target_world_position(piece_id: String, state: Dictionary, cell: Vector2i) -> Vector3:
	var location: Dictionary = state.get("location", {})
	var location_type := _normalize_location_type(str(location.get("type", "slot")))
	match location_type:
		"player_area":
			var area_player := str(location.get("player_id", state.get("holder_id", "player_1")))
			return _player_area_world_position(area_player, piece_id)
		"hand":
			# A true Hand is private state. Until cards have a dedicated renderer, put
			# its public proxy near the owner area rather than conflating it with Area.
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
		return area.global_position + Vector3(0.0, 0.55, 1.4 + float(slot) * 0.45)
	return super._hand_world_position(holder, piece_id)

func _collection_slot_index(holder: String, piece_id: String, location_type: String) -> int:
	var ids: Array[String] = []
	for key in pieces.keys():
		var piece := pieces[key] as Node3D
		if piece != null and str(piece.get_meta("location_type", "slot")) == location_type and str(piece.get_meta("holder_id", "")) == holder:
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

func _connect_session() -> void:
	repository = GameSessionRepository.new()
	add_child(repository)
	repository.set_logger(logger)
	if not game_definition.is_empty():
		repository.set_game_definition(game_definition)
	repository.session_missing.connect(_on_session_missing)
	repository.session_loaded.connect(_on_session_loaded)
	repository.session_error.connect(_on_session_error)
	repository.piece_changed.connect(_on_piece_changed)
	repository.start(game_id)
	_set_status("Connecting to Firebase /games/%s …" % game_id)

func _create_hud() -> void:
	super._create_hud()
	if client_role != ROLE_PLAYER or _player_controls == null:
		return
	call_deferred("_apply_landscape_player_layout")

func _refresh_hand_strip() -> void:
	if _hand_strip != null:
		_fill_collection_strip(_hand_strip, "player_area", "Area empty")
	if _private_hand_strip != null:
		_fill_collection_strip(_private_hand_strip, "hand", "Hand empty")

func _fill_collection_strip(strip: HBoxContainer, location_type: String, empty_text: String) -> void:
	for child in strip.get_children():
		child.free()

	var ids: Array[String] = []
	for key in pieces.keys():
		var piece := pieces[key] as Node3D
		if piece != null and str(piece.get_meta("location_type", "slot")) == location_type and str(piece.get_meta("holder_id", "")) == player_id:
			ids.append(str(key))
	ids.sort()

	if ids.is_empty():
		var empty := Label.new()
		empty.text = empty_text
		empty.custom_minimum_size = Vector2(150, 36)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		strip.add_child(empty)
		return

	for piece_id in ids:
		var piece := pieces[piece_id] as Node3D
		var button := Button.new()
		var quantity := int(piece.get_meta("quantity", 1))
		button.text = "%s%s" % [piece_id, " ×%d" % quantity if quantity > 1 else ""]
		button.custom_minimum_size = Vector2(150, 40)
		button.toggle_mode = true
		button.button_pressed = piece == selected_piece
		button.pressed.connect(_on_hand_item_pressed.bind(piece_id))
		strip.add_child(button)

func _apply_landscape_player_layout() -> void:
	if _player_controls == null:
		return
	_player_controls.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_player_controls.offset_left = -340.0
	_player_controls.offset_right = -12.0
	_player_controls.offset_top = 14.0
	_player_controls.offset_bottom = -14.0

	var old_column := _player_controls.get_child(0) as VBoxContainer
	if old_column == null:
		return
	var area_title = old_column.get_child(0) if old_column.get_child_count() > 0 else null
	var area_scroll = old_column.get_child(1) if old_column.get_child_count() > 1 else null
	var old_bar = _pickup_button.get_parent() if _pickup_button != null else null

	if area_title != null:
		old_column.remove_child(area_title)
		area_title.text = "PLAYER AREA"
	if area_scroll != null:
		old_column.remove_child(area_scroll)
	if _pickup_button != null and old_bar != null:
		old_bar.remove_child(_pickup_button)
	if _place_button != null and old_bar != null:
		old_bar.remove_child(_place_button)
	old_column.queue_free()

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	_player_controls.add_child(columns)

	var collections := VBoxContainer.new()
	collections.custom_minimum_size = Vector2(205, 0)
	collections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collections.add_theme_constant_override("separation", 6)
	columns.add_child(collections)

	if area_title != null:
		area_title.custom_minimum_size = Vector2(190, 28)
		collections.add_child(area_title)
	if area_scroll != null:
		area_scroll.custom_minimum_size = Vector2(190, 105)
		collections.add_child(area_scroll)

	var hand_title := Label.new()
	hand_title.text = "HAND"
	hand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collections.add_child(hand_title)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(190, 105)
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	collections.add_child(hand_scroll)
	_private_hand_strip = HBoxContainer.new()
	_private_hand_strip.add_theme_constant_override("separation", 6)
	hand_scroll.add_child(_private_hand_strip)

	var action_column := VBoxContainer.new()
	action_column.custom_minimum_size = Vector2(108, 0)
	action_column.alignment = BoxContainer.ALIGNMENT_CENTER
	action_column.add_theme_constant_override("separation", 10)
	columns.add_child(action_column)
	if _pickup_button != null:
		_pickup_button.custom_minimum_size = Vector2(106, 64)
		action_column.add_child(_pickup_button)
	if _place_button != null:
		_place_button.custom_minimum_size = Vector2(106, 64)
		action_column.add_child(_place_button)

	var fullscreen_button := Button.new()
	fullscreen_button.text = "FULL\nSCREEN"
	fullscreen_button.custom_minimum_size = Vector2(106, 58)
	fullscreen_button.pressed.connect(_enter_web_fullscreen)
	action_column.add_child(fullscreen_button)

	if _mode_label != null:
		_mode_label.visible = false
	if _debug_label != null:
		_debug_label.visible = false
	_refresh_hand_strip()

func _request_landscape_orientation() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.documentElement.style.background='#05070a'; document.body.style.margin='0'; document.body.style.overflow='hidden';", true)

func _enter_web_fullscreen() -> void:
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	JavaScriptBridge.eval("(async()=>{try{const e=document.documentElement;if(e.requestFullscreen)await e.requestFullscreen();if(screen.orientation&&screen.orientation.lock)await screen.orientation.lock('landscape');}catch(e){console.warn('BGO fullscreen/orientation:',e);}})();", true)
