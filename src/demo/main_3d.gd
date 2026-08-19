extends "res://src/demo/main_3d_base.gd"


func _ready() -> void:
	_read_launch_options()
	_setup_logger()
	_create_board()
	_create_player_areas()
	_create_hud()
	_configure_camera()
	_connect_session()
	logger.info("CLIENT_READY", {"role": client_role, "player_id": player_id})


func _process(delta: float) -> void:
	if client_role == ROLE_DISPLAY:
		if _focus_release_at > 0.0 and Time.get_ticks_msec() / 1000.0 >= _focus_release_at:
			_desired_focus = Vector3.ZERO
			_focus_release_at = 0.0
		_camera_focus = _camera_focus.lerp(_desired_focus, minf(delta * 3.5, 1.0))
		_update_camera_transform()


func _input(event: InputEvent) -> void:
	if client_role != ROLE_PLAYER:
		return
	if event is InputEventScreenTouch:
		_handle_pointer_screen_touch(event)
		return
	if event is InputEventScreenDrag:
		_handle_pointer_screen_drag(event)
		return
	if event is InputEventMouseButton:
		_handle_pointer_mouse_button(event)
		return
	if event is InputEventMouseMotion:
		_handle_pointer_mouse_motion(event)


func _handle_pointer_screen_touch(event: InputEventScreenTouch) -> void:
	if _pointer_is_over_controls(event.position):
		return
	if event.pressed:
		_begin_pointer(event.position, "touch")
	else:
		_end_pointer(event.position, "touch")


func _handle_pointer_screen_drag(event: InputEventScreenDrag) -> void:
	if _pointer_is_over_controls(event.position):
		return
	_pointer_dragged = true
	_orbit_camera(event.relative)


func _handle_pointer_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT or _pointer_is_over_controls(event.position):
		return
	if event.pressed:
		_begin_pointer(event.position, "mouse")
	else:
		_end_pointer(event.position, "mouse")


func _handle_pointer_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _pointer_down or (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return
	if event.position.distance_to(_pointer_start) <= 8.0:
		return
	_pointer_dragged = true
	_orbit_camera(event.relative)


func _begin_pointer(position: Vector2, source: String) -> void:
	_pointer_down = true
	_pointer_dragged = false
	_pointer_start = position
	logger.info(
		"POINTER_DOWN",
		{"source": source, "x": position.x, "y": position.y, "mode": interaction_mode}
	)
	_set_debug("pointer down %.0f,%.0f" % [position.x, position.y])


func _end_pointer(position: Vector2, source: String) -> void:
	_pointer_down = false
	var distance := position.distance_to(_pointer_start)
	logger.info(
		"POINTER_UP",
		{
			"source": source,
			"x": position.x,
			"y": position.y,
			"dragged": _pointer_dragged,
			"distance": distance
		}
	)
	if not _pointer_dragged and distance <= 12.0:
		_pick_at(position)
	else:
		logger.info("CAMERA_DRAG_END", {"yaw": _camera_yaw, "pitch": _camera_pitch})
		_set_debug("drag end")


func _pick_at(screen_position: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var collider: Node = null
	if not hit.is_empty():
		collider = hit.get("collider") as Node
		logger.info(
			"RAYCAST_HIT",
			{
				"collider": collider.name if collider != null else "null",
				"position": _vec3_payload(hit.get("position", Vector3.ZERO))
			}
		)
		if collider != null and collider.has_meta("bgo_piece"):
			_set_debug("ray hit piece: %s" % collider.name)
			_on_piece_tapped(collider)
			return
	else:
		logger.info("RAYCAST_MISS", {"x": screen_position.x, "y": screen_position.y})

	var projected_piece := _projected_piece_at(screen_position)
	if projected_piece != null:
		logger.info("PROJECTED_PICK_FALLBACK", {"piece_id": projected_piece.name})
		_set_debug("screen hit piece: %s" % projected_piece.name)
		_on_piece_tapped(projected_piece)
		return

	if interaction_mode == MODE_PLACE and selected_piece != null:
		var destination := Vector2i(-1, -1)
		if collider != null and collider.has_meta("board_cell"):
			destination = collider.get_meta("board_cell")
		else:
			destination = _screen_to_board_cell(origin, direction)
		if destination.x >= 0:
			_place_selected_piece(destination)
			return

	logger.info(
		"TAP_NO_TARGET", {"x": screen_position.x, "y": screen_position.y, "mode": interaction_mode}
	)
	_set_debug("tap: no piece/cell hit")


func _projected_piece_at(screen_position: Vector2) -> Node3D:
	var closest: Node3D = null
	var closest_distance := INF
	var viewport_size := get_viewport().get_visible_rect().size
	var threshold := maxf(54.0, minf(viewport_size.x, viewport_size.y) * 0.055)
	for value in pieces.values():
		var piece := value as Node3D
		if piece == null or camera.is_position_behind(piece.global_position):
			continue
		var projected := camera.unproject_position(piece.global_position)
		var distance := projected.distance_to(screen_position)
		if distance < threshold and distance < closest_distance:
			closest = piece
			closest_distance = distance
	return closest


func _screen_to_board_cell(origin: Vector3, direction: Vector3) -> Vector2i:
	if absf(direction.y) < 0.0001:
		return Vector2i(-1, -1)
	var t := -origin.y / direction.y
	if t <= 0.0:
		return Vector2i(-1, -1)
	var point := origin + direction * t
	var width := float(GRID_COLUMNS - 1) * CELL_SIZE
	var depth := float(GRID_ROWS - 1) * CELL_SIZE
	var x := int(round((point.x + width * 0.5) / CELL_SIZE))
	var y := int(round((point.z + depth * 0.5) / CELL_SIZE))
	if x < 0 or x >= GRID_COLUMNS or y < 0 or y >= GRID_ROWS:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


func _on_piece_tapped(piece: Node3D) -> void:
	var owner_id := str(piece.get_meta("owner_id", ""))
	var holder_id := str(piece.get_meta("holder_id", ""))
	var location_type := str(piece.get_meta("location_type", "board"))
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

	if owner_id != player_id and holder_id != player_id:
		_set_status("That piece belongs to %s" % owner_id)
		logger.warning(
			"PIECE_CONTROL_DENIED",
			{"piece_id": piece.name, "owner_id": owner_id, "player_id": player_id}
		)
		return

	if interaction_mode == MODE_PICK_UP:
		if location_type == "hand" and holder_id == player_id:
			_select_piece(piece)
			_set_status("%s is active in your hand" % piece.name)
			return
		_pick_up_piece(piece)
	else:
		_select_piece(piece)
		_set_status("Selected %s" % piece.name)


func _pick_up_piece(piece: Node3D) -> void:
	var piece_id := str(piece.get_meta("entity_id"))
	var target := _hand_world_position(player_id, piece_id)

	# Publish the destination first; animate locally immediately after.
	repository.pickup_piece(piece_id, player_id)
	logger.info(
		"PICKUP_REQUESTED",
		{"piece_id": piece_id, "duration": MOVE_DURATION, "target": _vec3_payload(target)}
	)

	piece.set_meta("holder_id", player_id)
	piece.set_meta("location_type", "hand")
	_select_piece(piece)
	_animate_piece(piece, target, "pickup")
	_refresh_hand_strip()
	_set_status("Picked up %s · moving to PLAYER 1 area" % piece.name)
	_set_debug("pickup → hand: %s" % piece.name)


func _place_selected_piece(destination: Vector2i) -> void:
	if selected_piece == null:
		return
	var piece := selected_piece
	var piece_id := str(piece.get_meta("entity_id"))
	var target := _cell_world(destination) + Vector3(0, 0.35, 0)

	repository.place_piece(piece_id, player_id, destination)
	logger.info(
		"PLACE_REQUESTED",
		{
			"piece_id": piece_id,
			"cell": _cell_payload(destination),
			"duration": MOVE_DURATION,
			"target": _vec3_payload(target)
		}
	)

	piece.set_meta("holder_id", "")
	piece.set_meta("location_type", "board")
	piece.set_meta("cell", destination)
	_animate_piece(piece, target, "place")
	selected_piece = null
	_refresh_hand_strip()
	_set_status("Placed %s at %s" % [piece.name, destination])
	_set_debug("place cell: %s" % destination)


func _create_board() -> void:
	for y in GRID_ROWS:
		for x in GRID_COLUMNS:
			var cell := StaticBody3D.new()
			cell.set_meta("board_cell", Vector2i(x, y))
			cell.position = _cell_world(Vector2i(x, y))

			var mesh_instance := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(CELL_SIZE - 0.03, 0.08, CELL_SIZE - 0.03)
			mesh_instance.mesh = mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = (
				Color(0.20, 0.22, 0.25) if (x + y) % 2 == 0 else Color(0.12, 0.14, 0.17)
			)
			material.roughness = 0.78
			mesh_instance.material_override = material
			cell.add_child(mesh_instance)

			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(CELL_SIZE, 0.12, CELL_SIZE)
			shape.shape = box
			cell.add_child(shape)
			$Board.add_child(cell)


func _create_player_areas() -> void:
	_create_player_area(
		"player_1",
		Vector3(-PLAYER_AREA_X, 0.02, 0),
		Vector3(1.55, 0.06, PLAYER_AREA_DEPTH),
		Color(0.45, 0.31, 0.06),
		"PLAYER 1"
	)
	_create_player_area(
		"player_2",
		Vector3(PLAYER_AREA_X, 0.02, 0),
		Vector3(1.55, 0.06, PLAYER_AREA_DEPTH),
		Color(0.07, 0.27, 0.43),
		"PLAYER 2"
	)


func _create_player_area(
	id: String, position: Vector3, size: Vector3, color: Color, label_text: String
) -> void:
	var root := Node3D.new()
	root.name = id + "_area"
	root.position = position
	add_child(root)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh_instance.material_override = material
	root.add_child(mesh_instance)

	var label := Label3D.new()
	label.text = label_text
	label.font_size = 42
	label.position = Vector3(0, 0.12, -2.85)
	label.rotation_degrees = Vector3(-90, 0, 0)
	root.add_child(label)


func _connect_session() -> void:
	repository = GameSessionRepository.new()
	add_child(repository)
	repository.set_logger(logger)
	repository.session_missing.connect(_on_session_missing)
	repository.session_loaded.connect(_on_session_loaded)
	repository.session_error.connect(_on_session_error)
	repository.piece_changed.connect(_on_piece_changed)
	repository.start(game_id)
	_set_status("Connecting to Firebase /games/%s …" % game_id)


func _on_session_missing() -> void:
	if _session_seed_requested:
		return
	_session_seed_requested = true
	_set_status("Creating demo session %s …" % game_id)
	repository.ensure_demo_session()


func _on_session_loaded(_data: Dictionary) -> void:
	_set_status("Connected · %s · %s" % [game_id, client_role.to_upper()])


func _on_session_error(message: String) -> void:
	_set_status(message)
	logger.error("SESSION_ERROR", {"message": message})
	push_warning(message)


func _on_piece_changed(piece_id: String, piece_data: Dictionary) -> void:
	var cell_data: Dictionary = piece_data.get("cell", {})
	var cell := Vector2i(int(cell_data.get("x", 0)), int(cell_data.get("y", 0)))
	if not pieces.has(piece_id):
		_create_piece_from_state(piece_id, piece_data, cell)
	else:
		_update_piece_from_state(pieces[piece_id], piece_data, cell)

	if client_role == ROLE_DISPLAY:
		_desired_focus = _target_world_position(piece_id, piece_data, cell)
		_focus_release_at = Time.get_ticks_msec() / 1000.0 + 2.4
	if client_role == ROLE_PLAYER:
		_refresh_hand_strip()


func _create_piece_from_state(id: String, state: Dictionary, cell: Vector2i) -> void:
	var owner := str(state.get("owner_id", ""))
	var quantity := int(state.get("quantity", 1))
	var color := Color(0.95, 0.72, 0.22) if owner == "player_1" else Color(0.30, 0.72, 0.95)
	var location: Dictionary = state.get("location", {})
	var location_type := str(location.get("type", "board"))
	var holder := str(state.get("holder_id", location.get("player_id", "")))

	var body := StaticBody3D.new()
	body.name = id
	body.set_meta("bgo_piece", true)
	body.set_meta("entity_id", id)
	body.set_meta("owner_id", owner)
	body.set_meta("holder_id", holder)
	body.set_meta("quantity", quantity)
	body.set_meta("cell", cell)
	body.set_meta("location_type", location_type)
	body.position = _target_world_position(id, state, cell)

	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.38
	cylinder.bottom_radius = 0.38
	cylinder.height = 0.32
	mesh_instance.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.38
	material.metallic = 0.08
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = 0.42
	cylinder_shape.height = 0.38
	shape.shape = cylinder_shape
	body.add_child(shape)

	if quantity > 1:
		var label := Label3D.new()
		label.text = str(quantity)
		label.font_size = 72
		label.position = Vector3(0, 0.28, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		body.add_child(label)

	$Pieces.add_child(body)
	pieces[id] = body
	logger.info(
		"PIECE_CREATED",
		{"piece_id": id, "location_type": location_type, "position": _vec3_payload(body.position)}
	)


func _update_piece_from_state(piece: Node3D, state: Dictionary, cell: Vector2i) -> void:
	var location: Dictionary = state.get("location", {})
	var location_type := str(location.get("type", "board"))
	var holder := str(state.get("holder_id", location.get("player_id", "")))
	var old_location_type := str(piece.get_meta("location_type", "board"))
	var old_holder := str(piece.get_meta("holder_id", ""))
	var old_cell: Vector2i = piece.get_meta("cell", Vector2i(-1, -1))

	piece.set_meta("owner_id", str(state.get("owner_id", piece.get_meta("owner_id", ""))))
	piece.set_meta("holder_id", holder)
	piece.set_meta("location_type", location_type)
	piece.set_meta("cell", cell)

	var state_changed := (
		old_location_type != location_type or old_holder != holder or old_cell != cell
	)
	if not state_changed:
		return

	var target := _target_world_position(str(piece.get_meta("entity_id")), state, cell)
	logger.info(
		"PIECE_ANIMATION_RECEIVED",
		{
			"piece_id": piece.name,
			"from": _vec3_payload(piece.position),
			"to": _vec3_payload(target),
			"duration": MOVE_DURATION,
			"location_type": location_type
		}
	)
	_animate_piece(piece, target, "sync")


func _target_world_position(piece_id: String, state: Dictionary, cell: Vector2i) -> Vector3:
	var location: Dictionary = state.get("location", {})
	if str(location.get("type", "board")) == "hand":
		var holder := str(location.get("player_id", state.get("holder_id", "player_1")))
		return _hand_world_position(holder, piece_id)
	return _cell_world(cell) + Vector3(0, 0.35, 0)


func _hand_world_position(holder: String, piece_id: String) -> Vector3:
	var slot := _hand_slot_index(holder, piece_id)
	var z := -2.35 + float(slot) * 0.9
	if holder == "player_2":
		return Vector3(PLAYER_AREA_X, 0.40, z)
	return Vector3(-PLAYER_AREA_X, 0.40, z)


func _hand_slot_index(holder: String, piece_id: String) -> int:
	var ids: Array[String] = []
	for key in pieces.keys():
		var piece := pieces[key] as Node3D
		if (
			piece != null
			and str(piece.get_meta("location_type", "board")) == "hand"
			and str(piece.get_meta("holder_id", "")) == holder
		):
			ids.append(str(key))
	if not ids.has(piece_id):
		ids.append(piece_id)
	ids.sort()
	return maxi(ids.find(piece_id), 0)
