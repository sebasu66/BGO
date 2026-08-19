extends "res://src/demo/main_componentized_base.gd"


func _ready() -> void:
	_request_landscape_orientation()
	_load_game_definition()
	var preview := get_node_or_null("EditorPreview")
	if preview != null:
		preview.queue_free()
	super._ready()
	if not game_definition.is_empty():
		var game: Dictionary = game_definition.get("game", {})
		title_label.text = (
			"BGO · %s · %s" % [str(game.get("name", game_id)), client_role.to_upper()]
		)
	if not definition_errors.is_empty():
		call_deferred("_show_definition_errors")


func _on_piece_tapped(piece: Node3D) -> void:
	var owner_id := str(piece.get_meta("owner_id", ""))
	var holder_id := str(piece.get_meta("holder_id", ""))
	var location_type := str(piece.get_meta("location_type", "slot"))
	logger.info(
		"PIECE_TAPPED",
		{
			"piece_id": piece.name,
			"owner_id": owner_id,
			"holder_id": holder_id,
			"location_type": location_type,
			"mode": interaction_mode
		}
	)

	if not holder_id.is_empty() and holder_id != player_id:
		_set_status("That object is currently held by %s" % holder_id)
		logger.warning(
			"PIECE_CONTROL_DENIED",
			{"piece_id": piece.name, "holder_id": holder_id, "player_id": player_id}
		)
		return
	if not owner_id.is_empty() and owner_id != player_id and holder_id != player_id:
		_set_status("That object belongs to %s" % owner_id)
		logger.warning(
			"PIECE_CONTROL_DENIED",
			{"piece_id": piece.name, "owner_id": owner_id, "player_id": player_id}
		)
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
	logger.info(
		"PICKUP_REQUESTED",
		{
			"piece_id": piece_id,
			"destination": "player_area",
			"duration": MOVE_DURATION,
			"target": _vec3_payload(target)
		}
	)
	piece.set_meta("holder_id", player_id)
	piece.set_meta("location_type", "player_area")
	_select_piece(piece)
	_animate_piece(piece, target, "pickup")
	_reflow_collection(player_id, "player_area")
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
	logger.info(
		"PLACE_REQUESTED",
		{
			"piece_id": piece_id,
			"slot_id": board.slot_id(destination) if board != null else "",
			"duration": MOVE_DURATION,
			"target": _vec3_payload(target)
		}
	)
	piece.set_meta("holder_id", "")
	piece.set_meta("location_type", "slot")
	piece.set_meta("cell", destination)
	_animate_piece(piece, target, "place")
	selected_piece = null
	_reflow_collection(player_id, "player_area")
	_reflow_collection(player_id, "hand")
	_refresh_hand_strip()
	_set_status("Placed %s" % piece.name)
	_set_debug("place slot: %s" % destination)


func _reflow_collection(holder: String, location_type: String) -> void:
	var ids: Array[String] = []
	for key in pieces.keys():
		var piece := pieces[key] as Node3D
		if (
			piece != null
			and str(piece.get_meta("location_type", "slot")) == location_type
			and str(piece.get_meta("holder_id", "")) == holder
		):
			ids.append(str(key))
	ids.sort()
	for index in ids.size():
		var piece := pieces[ids[index]] as Node3D
		if piece == null:
			continue
		var target := (
			_player_area_world_position(holder, ids[index])
			if location_type == "player_area"
			else _private_hand_proxy_world_position(holder, ids[index])
		)
		if piece.position.distance_to(target) > 0.02:
			_animate_piece(piece, target, "collection_reflow")


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


func _on_piece_changed(piece_id: String, piece_data: Dictionary) -> void:
	super._on_piece_changed(piece_id, piece_data)
	_reflow_collection("player_1", "player_area")
	_reflow_collection("player_2", "player_area")
	_reflow_collection("player_1", "hand")
	_reflow_collection("player_2", "hand")


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
	_update_transfer_buttons()


func _fill_collection_strip(
	strip: HBoxContainer, location_type: String, empty_text: String
) -> void:
	for child in strip.get_children():
		child.queue_free()

	var ids: Array[String] = []
	for key in pieces.keys():
		var piece := pieces[key] as Node3D
		if (
			piece != null
			and str(piece.get_meta("location_type", "slot")) == location_type
			and str(piece.get_meta("holder_id", "")) == player_id
		):
			ids.append(str(key))
	ids.sort()

	if ids.is_empty():
		var empty := Label.new()
		empty.text = empty_text
		empty.custom_minimum_size = Vector2(160, 36)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		strip.add_child(empty)
		return

	for piece_id in ids:
		var piece := pieces[piece_id] as Node3D
		var button := Button.new()
		var quantity := int(piece.get_meta("quantity", 1))
		button.text = "%s%s" % [piece_id, " ×%d" % quantity if quantity > 1 else ""]
		button.custom_minimum_size = Vector2(160, 40)
		button.toggle_mode = true
		button.button_pressed = piece == selected_piece
		button.pressed.connect(_on_collection_item_pressed.bind(piece_id))
		strip.add_child(button)


func _on_collection_item_pressed(piece_id: String) -> void:
	if not pieces.has(piece_id):
		return
	_select_piece(pieces[piece_id])
	_update_transfer_buttons()


func _move_selected_to_hand() -> void:
	if selected_piece == null:
		return
	var holder := str(selected_piece.get_meta("holder_id", ""))
	var location_type := str(selected_piece.get_meta("location_type", "slot"))
	if holder != player_id or location_type != "player_area":
		return
	var piece_id := str(selected_piece.get_meta("entity_id"))
	repository.move_to_hand(piece_id, player_id)
	selected_piece.set_meta("location_type", "hand")
	_animate_piece(
		selected_piece, _private_hand_proxy_world_position(player_id, piece_id), "to_hand"
	)
	_reflow_collection(player_id, "player_area")
	_reflow_collection(player_id, "hand")
	_refresh_hand_strip()
	_set_status("Moved %s to HAND" % piece_id)


func _move_selected_to_area() -> void:
	if selected_piece == null:
		return
	var holder := str(selected_piece.get_meta("holder_id", ""))
	var location_type := str(selected_piece.get_meta("location_type", "slot"))
	if holder != player_id or location_type != "hand":
		return
	var piece_id := str(selected_piece.get_meta("entity_id"))
	repository.move_to_player_area(piece_id, player_id)
	selected_piece.set_meta("location_type", "player_area")
	_animate_piece(
		selected_piece, _player_area_world_position(player_id, piece_id), "to_player_area"
	)
	_reflow_collection(player_id, "player_area")
	_reflow_collection(player_id, "hand")
	_refresh_hand_strip()
	_set_status("Moved %s to PLAYER AREA" % piece_id)


func _update_transfer_buttons() -> void:
	var location_type := ""
	var holder := ""
	if selected_piece != null:
		location_type = str(selected_piece.get_meta("location_type", ""))
		holder = str(selected_piece.get_meta("holder_id", ""))
	if _transfer_to_hand_button != null:
		_transfer_to_hand_button.disabled = holder != player_id or location_type != "player_area"
	if _transfer_to_area_button != null:
		_transfer_to_area_button.disabled = holder != player_id or location_type != "hand"


func _apply_landscape_player_layout() -> void:
	if _player_controls == null:
		return
	_player_controls.visible = false
	var root := _create_landscape_player_root()
	_add_landscape_player_identity(root)
	_add_landscape_collection_controls(root)
	_add_landscape_action_controls(root)
	if _mode_label != null:
		_mode_label.visible = false
	if _debug_label != null:
		_debug_label.visible = false
	_set_mode(MODE_PICK_UP)
	_refresh_hand_strip()


func _create_landscape_player_root() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -410.0
	panel.offset_right = -12.0
	panel.offset_top = 14.0
	panel.offset_bottom = -14.0
	$UI.add_child(panel)
	_player_controls = panel
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	return root


func _add_landscape_player_identity(root: VBoxContainer) -> void:
	var player_title := Label.new()
	var definition := _player_definition(player_id)
	player_title.text = (
		"%s · %s"
		% [
			str(definition.get("name", player_id.replace("_", " ").capitalize())),
			player_id.to_upper().replace("_", " ")
		]
	)
	player_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_title.add_theme_font_size_override("font_size", 18)
	player_title.add_theme_color_override("font_color", _player_color(player_id))
	root.add_child(player_title)


func _add_landscape_collection_controls(root: VBoxContainer) -> void:
	var area_title := Label.new()
	area_title.text = "PLAYER AREA"
	area_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(area_title)
	var area_scroll := ScrollContainer.new()
	area_scroll.custom_minimum_size = Vector2(370, 74)
	area_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	area_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(area_scroll)
	_hand_strip = HBoxContainer.new()
	_hand_strip.add_theme_constant_override("separation", 6)
	area_scroll.add_child(_hand_strip)

	var transfer_row := HBoxContainer.new()
	transfer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	transfer_row.add_theme_constant_override("separation", 8)
	root.add_child(transfer_row)
	_transfer_to_hand_button = Button.new()
	_transfer_to_hand_button.text = "TO HAND ↓"
	_transfer_to_hand_button.custom_minimum_size = Vector2(150, 38)
	_transfer_to_hand_button.pressed.connect(_move_selected_to_hand)
	transfer_row.add_child(_transfer_to_hand_button)
	_transfer_to_area_button = Button.new()
	_transfer_to_area_button.text = "↑ TO AREA"
	_transfer_to_area_button.custom_minimum_size = Vector2(150, 38)
	_transfer_to_area_button.pressed.connect(_move_selected_to_area)
	transfer_row.add_child(_transfer_to_area_button)

	var hand_title := Label.new()
	hand_title.text = "HAND"
	hand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hand_title)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(370, 74)
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(hand_scroll)
	_private_hand_strip = HBoxContainer.new()
	_private_hand_strip.add_theme_constant_override("separation", 6)
	hand_scroll.add_child(_private_hand_strip)


func _add_landscape_action_controls(root: VBoxContainer) -> void:
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	root.add_child(action_row)
	_pickup_button = Button.new()
	_pickup_button.text = "PICK UP"
	_pickup_button.toggle_mode = true
	_pickup_button.custom_minimum_size = Vector2(110, 54)
	_pickup_button.pressed.connect(func(): _set_mode(MODE_PICK_UP))
	action_row.add_child(_pickup_button)
	_place_button = Button.new()
	_place_button.text = "PLACE"
	_place_button.toggle_mode = true
	_place_button.custom_minimum_size = Vector2(110, 54)
	_place_button.pressed.connect(func(): _set_mode(MODE_PLACE))
	action_row.add_child(_place_button)
	var fullscreen_button := Button.new()
	fullscreen_button.text = "FULL SCREEN"
	fullscreen_button.custom_minimum_size = Vector2(120, 54)
	fullscreen_button.pressed.connect(_enter_web_fullscreen)
	action_row.add_child(fullscreen_button)


func _request_landscape_orientation() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if OS.has_feature("web"):
		(
			JavaScriptBridge
			. eval(
				"document.documentElement.style.background='#05070a'; document.body.style.margin='0'; document.body.style.overflow='hidden';",
				true
			)
		)


func _enter_web_fullscreen() -> void:
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	(
		JavaScriptBridge
		. eval(
			"(async()=>{try{const e=document.documentElement;if(e.requestFullscreen)await e.requestFullscreen();if(screen.orientation&&screen.orientation.lock)await screen.orientation.lock('landscape');}catch(e){console.warn('BGO fullscreen/orientation:',e);}})();",
			true
		)
	)
