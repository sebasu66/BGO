extends "res://src/demo/main_componentized_base.gd"


func _set_mode(mode: String) -> void:
	super._set_mode(mode)
	if _vertical_hand != null:
		_vertical_hand.set_mode(_hand_mode_name(mode))


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
	if location_type == "asset_box":
		_set_status("Asset Box entries are catalog data, not physical table objects")
		_set_debug("asset box object ignored in 3D")
		return

	if not _is_host_viewer() and not holder_id.is_empty() and holder_id != player_id:
		_set_status("That object is currently held by %s" % holder_id)
		logger.warning(
			"PIECE_CONTROL_DENIED",
			{"piece_id": piece.name, "holder_id": holder_id, "player_id": player_id}
		)
		return
	if (
		not _is_host_viewer()
		and not owner_id.is_empty()
		and owner_id != player_id
		and holder_id != player_id
	):
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


## Extension point for trusted local host tooling. Normal clients never bypass ownership.
func _is_host_viewer() -> bool:
	return false


func _pick_up_piece(piece: Node3D) -> void:
	var piece_id := str(piece.get_meta("entity_id"))
	var target := piece.position
	var hand_order := float(Time.get_ticks_msec())
	var quantity := int(piece.get_meta("quantity", 1))
	var stackable := piece.has_method("is_stackable") and bool(piece.call("is_stackable"))
	var whole_stack := _hand_pickup_whole_stack() or not stackable or quantity <= 1
	var picked_id := repository.pickup_piece(piece_id, player_id, whole_stack)
	logger.info(
		"PICKUP_REQUESTED",
		{
			"piece_id": piece_id,
			"picked_id": picked_id,
			"pickup_mode": "whole_stack" if whole_stack else "one_at_a_time",
			"destination": "hand",
			"duration": MOVE_DURATION,
			"target": _vec3_payload(target)
		}
	)
	if not whole_stack:
		piece.set_meta("quantity", quantity - 1)
		if piece is BgoBasicCylinderPiece:
			(piece as BgoBasicCylinderPiece).quantity = quantity - 1
		selected_piece = null
		_refresh_hand_strip()
		_set_status("Picked up 1 from %s · added to HAND" % piece.name)
		_set_debug("pickup one → hand: %s" % picked_id)
		return
	piece.set_meta("holder_id", player_id)
	piece.set_meta("location_type", "hand")
	piece.set_meta("hand_order", hand_order)
	_select_piece(piece)
	_set_piece_render_state(piece, false)
	_refresh_hand_strip()
	_set_status("Picked up %s · added to HAND" % piece.name)
	_set_debug("pickup → hand: %s" % piece.name)


func _hand_pickup_whole_stack() -> bool:
	var controller: Node = get("_settings_controller")
	if controller == null:
		return false
	var settings: Dictionary = controller.get("values")
	return int(settings.get("hand_pickup_mode", 0)) == 1


func _place_selected_at_pointer(
	_collider: Node, hit_position: Vector3, origin: Vector3, direction: Vector3
) -> bool:
	var board := _primary_board
	if board == null or absf(direction.y) < 0.0001:
		return false
	var world_position := hit_position
	if world_position == Vector3.ZERO:
		var distance := (board.global_position.y - origin.y) / direction.y
		if distance <= 0.0:
			return false
		world_position = origin + direction * distance
	var destination := board.resolve_magnetic_placement(world_position)
	match str(destination.get("type", "")):
		"slot":
			_place_selected_piece(destination.get("cell", Vector2i(-1, -1)))
			return true
		"grid":
			_place_selected_piece_on_grid(destination.get("grid_point", Vector2i(-1, -1)))
			return true
	return false


func _place_selected_piece(destination: Vector2i) -> void:
	if selected_piece == null:
		return
	if str(selected_piece.get_meta("location_type", "")) != "hand":
		_set_status("Select an object from HAND before placing")
		return
	var board := _primary_board
	if board != null and not board.is_valid_cell(destination):
		_set_status("That destination is not a valid board slot")
		return

	var piece := selected_piece
	var piece_id := str(piece.get_meta("entity_id"))
	var target := _board_support_position(destination)
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
	_set_piece_render_state(piece, true)
	_animate_piece(piece, target, "place")
	selected_piece = null
	_select_top_hand_piece()
	_reflow_collection(player_id, "player_area")
	_reflow_collection(player_id, "hand")
	_refresh_hand_strip()
	_set_status("Placed %s" % piece.name)
	_set_debug("place slot: %s" % destination)


func _place_selected_piece_on_grid(destination: Vector2i) -> void:
	if selected_piece == null or _primary_board == null:
		return
	if str(selected_piece.get_meta("location_type", "")) != "hand":
		_set_status("Select an object from HAND before placing")
		return
	var grid := _primary_board.get_node_or_null("TableGrid") as BgoTableGrid
	if grid == null or not grid.is_valid_point(destination):
		_set_status("That destination is outside the table grid")
		return
	var piece := selected_piece
	var piece_id := str(piece.get_meta("entity_id"))
	var target := _grid_support_position(destination)
	repository.place_piece_at_grid(piece_id, player_id, destination)
	(
		logger
		. info(
			"PLACE_REQUESTED",
			{
				"piece_id": piece_id,
				"grid_point": {"x": destination.x, "y": destination.y},
				"duration": MOVE_DURATION,
				"target": _vec3_payload(target),
			}
		)
	)
	piece.set_meta("holder_id", "")
	piece.set_meta("location_type", "grid")
	piece.set_meta("grid_origin", destination)
	_set_piece_render_state(piece, true)
	_animate_piece(piece, target, "place_grid")
	selected_piece = null
	_select_top_hand_piece()
	_refresh_hand_strip()
	_set_status("Placed %s on grid %s" % [piece.name, destination])
	_set_debug("place grid: %s" % destination)


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
	repository.set_mcp_command_authority(player_id, _is_host_viewer())
	repository.session_missing.connect(_on_session_missing)
	repository.session_loaded.connect(_on_session_loaded)
	repository.session_error.connect(_on_session_error)
	repository.piece_changed.connect(_on_piece_changed)
	repository.start(game_id)
	_set_status("Connecting to Firebase /games/%s …" % game_id)


func _on_piece_changed(piece_id: String, piece_data: Dictionary) -> void:
	super._on_piece_changed(piece_id, piece_data)
	if pieces.has(piece_id):
		var piece := pieces[piece_id] as Node3D
		var location: Dictionary = piece_data.get("location", {})
		if piece != null:
			_set_asset_box_piece_visibility(
				piece, str(location.get("type", "slot")) not in ["asset_box", "hand"]
			)
			if str(location.get("type", "")) == "hand":
				piece.set_meta(
					"hand_order", float(piece_data.get("hand_order", Time.get_ticks_msec()))
				)
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
	if _vertical_hand != null:
		var raw_items: Array = []
		for key in pieces.keys():
			var piece := pieces[key] as Node3D
			if (
				piece != null
				and str(piece.get_meta("location_type", "slot")) == "hand"
				and str(piece.get_meta("holder_id", "")) == player_id
			):
				(
					raw_items
					. append(
						{
							"id": str(key),
							"label": str(key).to_upper().replace("_", " "),
							"quantity": int(piece.get_meta("quantity", 1)),
							"component_id": str(piece.get_meta("component_id", "")),
							"owner_id": str(piece.get_meta("owner_id", "")),
							"color": _player_color(str(piece.get_meta("owner_id", player_id))),
							"hand_order": float(piece.get_meta("hand_order", 0.0)),
							"stack_key": str(piece.get_meta("hand_stack_key", str(key))),
						}
					)
				)
		raw_items.sort_custom(_sort_hand_items)
		_ensure_selected_hand_item(raw_items)
		var items := _stack_hand_items(raw_items)
		_vertical_hand.set_items(
			items, str(selected_piece.get_meta("entity_id", "")) if selected_piece != null else ""
		)
	_update_transfer_buttons()


func _ensure_selected_hand_item(raw_items: Array) -> void:
	if raw_items.is_empty():
		if selected_piece != null and str(selected_piece.get_meta("location_type", "")) == "hand":
			selected_piece = null
		return
	var selection_is_in_hand := (
		selected_piece != null
		and str(selected_piece.get_meta("location_type", "")) == "hand"
		and str(selected_piece.get_meta("holder_id", "")) == player_id
	)
	if selection_is_in_hand:
		return
	var top_item: Dictionary = raw_items[0]
	var top_id := str(top_item.get("id", ""))
	if pieces.has(top_id):
		selected_piece = pieces[top_id] as Node3D


func _stack_hand_items(raw_items: Array) -> Array:
	var grouped: Dictionary = {}
	var order: Array[String] = []
	for value in raw_items:
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		var stack_key := str(item.get("stack_key", item.get("id", "")))
		if not grouped.has(stack_key):
			var group := item.duplicate(true)
			group["member_ids"] = [str(item.get("id", ""))]
			grouped[stack_key] = group
			order.append(stack_key)
			continue
		var group: Dictionary = grouped[stack_key]
		group["quantity"] = int(group.get("quantity", 1)) + int(item.get("quantity", 1))
		var member_ids: Array = group.get("member_ids", [])
		member_ids.append(str(item.get("id", "")))
		group["member_ids"] = member_ids
		if selected_piece != null and member_ids.has(str(selected_piece.get_meta("entity_id", ""))):
			group["id"] = str(selected_piece.get_meta("entity_id", ""))
		grouped[stack_key] = group
	var result: Array = []
	for stack_key in order:
		result.append(grouped[stack_key])
	return result


func _select_top_hand_piece() -> void:
	var candidates: Array[Dictionary] = []
	for key in pieces.keys():
		var piece := pieces[key] as Node3D
		if (
			piece != null
			and str(piece.get_meta("location_type", "")) == "hand"
			and str(piece.get_meta("holder_id", "")) == player_id
		):
			(
				candidates
				. append(
					{
						"id": str(key),
						"hand_order": float(piece.get_meta("hand_order", 0.0)),
					}
				)
			)
	if candidates.is_empty():
		selected_piece = null
		return
	candidates.sort_custom(_sort_hand_items)
	var next_id := str(candidates[0].get("id", ""))
	if pieces.has(next_id):
		_select_piece(pieces[next_id])


func _sort_hand_items(left: Dictionary, right: Dictionary) -> bool:
	var left_order := float(left.get("hand_order", 0.0))
	var right_order := float(right.get("hand_order", 0.0))
	if is_equal_approx(left_order, right_order):
		return str(left.get("id", "")) < str(right.get("id", ""))
	return left_order > right_order


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


func _toggle_asset_box() -> void:
	_asset_box_open = not _asset_box_open
	for piece in pieces.values():
		var object := piece as Node3D
		if object != null and str(object.get_meta("location_type", "")) == "asset_box":
			_set_asset_box_piece_visibility(object, false)
	if _asset_box_button != null:
		_asset_box_button.text = "CLOSE BOX" if _asset_box_open else "ASSET BOX"
	_set_status("Asset catalog opened" if _asset_box_open else "Asset catalog closed")
	_set_debug("asset catalog: %s" % ("open" if _asset_box_open else "closed"))


func _apply_landscape_player_layout() -> void:
	if _player_controls == null:
		return
	_player_controls.visible = false
	var root := _create_landscape_player_root()
	_add_landscape_collection_controls(root)
	if _mode_label != null:
		_mode_label.visible = false
	if _debug_label != null:
		_debug_label.visible = false
	_set_mode(MODE_NONE)
	_refresh_hand_strip()


func _create_landscape_player_root() -> VBoxContainer:
	var root := VBoxContainer.new()
	root.name = "FloatingHandLayer"
	root.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	root.offset_left = -154.0
	root.offset_right = -10.0
	root.offset_top = 92.0
	root.offset_bottom = -22.0
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	$UI.add_child(root)
	_player_controls = root
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
	_vertical_hand = VERTICAL_HAND_SCENE.instantiate() as BgoVerticalHand
	_vertical_hand.name = "PlayerHand"
	_vertical_hand.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vertical_hand.custom_minimum_size = Vector2(136, 0)
	_vertical_hand.set_preview_factory(Callable(self, "_build_hand_preview"))
	_vertical_hand.item_selected.connect(_on_hand_item_pressed)
	_vertical_hand.mode_selected.connect(_on_hand_mode_selected)
	root.add_child(_vertical_hand)


func _add_landscape_action_controls(root: VBoxContainer) -> void:
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	root.add_child(action_row)
	var fullscreen_button := Button.new()
	fullscreen_button.text = "FULL SCREEN"
	fullscreen_button.custom_minimum_size = Vector2(120, 54)
	fullscreen_button.pressed.connect(_enter_web_fullscreen)
	action_row.add_child(fullscreen_button)
	_asset_box_button = Button.new()
	_asset_box_button.text = "ASSET BOX"
	_asset_box_button.custom_minimum_size = Vector2(120, 54)
	_asset_box_button.pressed.connect(_toggle_asset_box)
	action_row.add_child(_asset_box_button)


func _on_hand_mode_selected(mode: String) -> void:
	match mode:
		"pickup":
			_set_mode(MODE_PICK_UP)
		"place":
			_set_mode(MODE_PLACE)
		_:
			_set_mode(MODE_NONE)


func _build_hand_preview(item: Dictionary) -> Node3D:
	var packed_scene := BgoComponentRegistry.load_scene(str(item.get("component_id", "")))
	if packed_scene == null:
		return null
	var preview := packed_scene.instantiate() as Node3D
	if preview == null:
		return null
	var owner_id := str(item.get("owner_id", ""))
	var color: Color = item.get("color", _player_color(owner_id))
	if preview is BgoBasicCylinderPiece:
		(preview as BgoBasicCylinderPiece).configure(
			str(item.get("id", "preview")), owner_id, player_id, int(item.get("quantity", 1)), color
		)
	return preview


func _request_landscape_orientation() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if OS.has_feature("web"):
		var page_style := (
			"document.documentElement.style.background='#05070a';"
			+ "document.body.style.margin='0';"
			+ "document.body.style.overflow='hidden';"
		)
		JavaScriptBridge.eval(page_style, true)


func _enter_web_fullscreen() -> void:
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	var fullscreen_script := (
		"(async()=>{try{const e=document.documentElement;"
		+ "if(e.requestFullscreen)await e.requestFullscreen();"
		+ "if(screen.orientation&&screen.orientation.lock)"
		+ "await screen.orientation.lock('landscape');"
		+ "}catch(e){console.warn('BGO fullscreen/orientation:',e);}})();"
	)
	JavaScriptBridge.eval(fullscreen_script, true)
