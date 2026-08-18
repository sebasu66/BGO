extends Node3D

const GRID_COLUMNS := 8
const GRID_ROWS := 6
const CELL_SIZE := 1.2
const GAME_ID_DEFAULT := "TEST001"
const ROLE_DISPLAY := "display"
const ROLE_PLAYER := "player"
const MODE_PICK_UP := "pick_up"
const MODE_PLACE := "place"
const MOVE_DURATION := 1.25
const PLAYER_AREA_X := 6.15
const PLAYER_AREA_DEPTH := 7.2

@onready var camera: Camera3D = $Camera3D
@onready var title_label: Label = $UI/Title
@onready var hint_label: Label = $UI/Hint

var repository: GameSessionRepository
var logger: BgoLogger
var client_role := ROLE_DISPLAY
var game_id := GAME_ID_DEFAULT
var player_id := "player_1"
var interaction_mode := MODE_PICK_UP
var client_id := ""

var selected_piece: Node3D
var pieces: Dictionary = {}
var _session_seed_requested := false
var _pointer_down := false
var _pointer_dragged := false
var _pointer_start := Vector2.ZERO

var _camera_yaw := 0.0
var _camera_pitch := deg_to_rad(52.0)
var _camera_distance := 12.8
var _camera_focus := Vector3.ZERO
var _desired_focus := Vector3.ZERO
var _focus_release_at := 0.0

var _mode_label: Label
var _status_label: Label
var _debug_label: Label
var _player_controls: Control
var _hand_strip: HBoxContainer
var _pickup_button: Button
var _place_button: Button


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
		if _pointer_is_over_controls(event.position):
			return
		if event.pressed:
			_begin_pointer(event.position, "touch")
		else:
			_end_pointer(event.position, "touch")
	elif event is InputEventScreenDrag:
		if _pointer_is_over_controls(event.position):
			return
		_pointer_dragged = true
		_orbit_camera(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _pointer_is_over_controls(event.position):
			return
		if event.pressed:
			_begin_pointer(event.position, "mouse")
		else:
			_end_pointer(event.position, "mouse")
	elif (
		event is InputEventMouseMotion
		and _pointer_down
		and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	):
		if event.position.distance_to(_pointer_start) > 8.0:
			_pointer_dragged = true
			_orbit_camera(event.relative)


func _pointer_is_over_controls(position: Vector2) -> bool:
	return _player_controls != null and _player_controls.get_global_rect().has_point(position)


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


func _orbit_camera(relative: Vector2) -> void:
	_camera_yaw -= relative.x * 0.008
	_camera_pitch = clampf(_camera_pitch + relative.y * 0.006, deg_to_rad(28.0), deg_to_rad(72.0))
	_update_camera_transform()


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


func _animate_piece(piece: Node3D, target: Vector3, reason: String) -> void:
	# A visible lift/travel/drop arc. Total duration is ~1.25 s.
	var start := piece.position
	var lift_start := start + Vector3(0, 0.75, 0)
	var lift_target := target + Vector3(0, 0.75, 0)
	logger.info(
		"PIECE_ANIMATION_STARTED",
		{
			"piece_id": piece.name,
			"reason": reason,
			"from": _vec3_payload(start),
			"to": _vec3_payload(target)
		}
	)
	var tween := piece.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(piece, "position", lift_start, 0.20)
	tween.tween_property(piece, "position", lift_target, 0.80)
	tween.tween_property(piece, "position", target, 0.25)


func _select_piece(piece: Node3D) -> void:
	selected_piece = piece
	for candidate in pieces.values():
		(candidate as Node3D).scale = Vector3.ONE * (1.12 if candidate == selected_piece else 1.0)
	logger.info("HAND_ACTIVE_CHANGED", {"piece_id": piece.name})
	_refresh_hand_strip()


func _create_hud() -> void:
	title_label.text = "BGO · %s · %s" % [game_id, client_role.to_upper()]

	_status_label = Label.new()
	_status_label.position = Vector2(30, 96)
	_status_label.size = Vector2(900, 30)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_font_size_override("font_size", 14)
	$UI.add_child(_status_label)

	if client_role == ROLE_DISPLAY:
		hint_label.text = "Shared display · Firebase TEST001 · player hand areas live outside the board."
		return

	hint_label.text = "Drag to orbit · PICK UP moves a piece into your hand · PLACE moves the active hand piece to the board."

	# Explicit bottom HUD geometry: no scroll/container compression in mobile Web.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 12
	panel.offset_right = -12
	panel.offset_top = -142
	panel.offset_bottom = -10
	$UI.add_child(panel)
	_player_controls = panel

	var content := Control.new()
	content.custom_minimum_size = Vector2(0, 132)
	panel.add_child(content)

	var hand_title := Label.new()
	hand_title.text = "YOUR HAND"
	hand_title.position = Vector2(14, 8)
	hand_title.size = Vector2(180, 24)
	hand_title.add_theme_font_size_override("font_size", 16)
	content.add_child(hand_title)

	_hand_strip = HBoxContainer.new()
	_hand_strip.position = Vector2(14, 34)
	_hand_strip.size = Vector2(760, 46)
	_hand_strip.add_theme_constant_override("separation", 8)
	content.add_child(_hand_strip)

	_pickup_button = Button.new()
	_pickup_button.text = "PICK UP"
	_pickup_button.toggle_mode = true
	_pickup_button.position = Vector2(14, 86)
	_pickup_button.size = Vector2(150, 40)
	_pickup_button.pressed.connect(func(): _set_mode(MODE_PICK_UP))
	content.add_child(_pickup_button)

	_place_button = Button.new()
	_place_button.text = "PLACE"
	_place_button.toggle_mode = true
	_place_button.position = Vector2(174, 86)
	_place_button.size = Vector2(150, 40)
	_place_button.pressed.connect(func(): _set_mode(MODE_PLACE))
	content.add_child(_place_button)

	_mode_label = Label.new()
	_mode_label.text = "Mode: PICK UP"
	_mode_label.position = Vector2(338, 94)
	_mode_label.size = Vector2(240, 30)
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_mode_label)

	_debug_label = Label.new()
	_debug_label.text = "Input debug: waiting for tap"
	_debug_label.position = Vector2(30, 154)
	_debug_label.size = Vector2(800, 28)
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.add_theme_font_size_override("font_size", 13)
	$UI.add_child(_debug_label)

	_set_mode(MODE_PICK_UP)
	_refresh_hand_strip()


func _refresh_hand_strip() -> void:
	if _hand_strip == null:
		return
	for child in _hand_strip.get_children():
		child.queue_free()

	var hand_ids: Array[String] = []
	for key in pieces.keys():
		var piece := pieces[key] as Node3D
		if (
			piece != null
			and str(piece.get_meta("location_type", "board")) == "hand"
			and str(piece.get_meta("holder_id", "")) == player_id
		):
			hand_ids.append(str(key))
	hand_ids.sort()

	if hand_ids.is_empty():
		var empty := Label.new()
		empty.text = "Hand is empty"
		empty.custom_minimum_size = Vector2(180, 42)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hand_strip.add_child(empty)
		return

	for piece_id in hand_ids:
		var piece := pieces[piece_id] as Node3D
		var button := Button.new()
		var quantity := int(piece.get_meta("quantity", 1))
		button.text = "%s%s" % [piece_id, " ×%d" % quantity if quantity > 1 else ""]
		button.custom_minimum_size = Vector2(150, 42)
		button.toggle_mode = true
		button.button_pressed = piece == selected_piece
		button.pressed.connect(_on_hand_item_pressed.bind(piece_id))
		_apply_hand_button_style(button, piece == selected_piece)
		_hand_strip.add_child(button)


func _on_hand_item_pressed(piece_id: String) -> void:
	if not pieces.has(piece_id):
		return
	_select_piece(pieces[piece_id])
	_set_status("Active hand object: %s" % piece_id)


func _set_mode(mode: String) -> void:
	interaction_mode = mode
	if _mode_label != null:
		_mode_label.text = "Mode: %s" % mode.replace("_", " ").to_upper()
	if _pickup_button != null:
		_pickup_button.button_pressed = mode == MODE_PICK_UP
		_apply_mode_button_style(_pickup_button, mode == MODE_PICK_UP, Color(0.90, 0.58, 0.10))
	if _place_button != null:
		_place_button.button_pressed = mode == MODE_PLACE
		_apply_mode_button_style(_place_button, mode == MODE_PLACE, Color(0.18, 0.68, 0.94))
	if logger != null:
		logger.info("INTERACTION_MODE_CHANGED", {"mode": mode})
	_set_debug("mode: %s" % mode)


func _apply_mode_button_style(button: Button, active: bool, accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = accent if active else Color(0.10, 0.11, 0.14, 0.96)
	style.border_width_left = 3 if active else 1
	style.border_width_top = 3 if active else 1
	style.border_width_right = 3 if active else 1
	style.border_width_bottom = 3 if active else 1
	style.border_color = accent.lightened(0.22) if active else Color(0.28, 0.30, 0.34)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.text = ("● " if active else "") + ("PICK UP" if button == _pickup_button else "PLACE")


func _apply_hand_button_style(button: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.28, 0.42, 0.62, 1.0) if active else Color(0.12, 0.13, 0.16, 0.98)
	style.border_width_left = 3 if active else 1
	style.border_width_top = 3 if active else 1
	style.border_width_right = 3 if active else 1
	style.border_width_bottom = 3 if active else 1
	style.border_color = Color(0.62, 0.82, 1.0) if active else Color(0.30, 0.32, 0.36)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover", style)


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _set_debug(text: String) -> void:
	if _debug_label != null:
		_debug_label.text = "Input debug: %s" % text


func _configure_camera() -> void:
	_camera_yaw = 0.0
	_camera_pitch = deg_to_rad(52.0 if client_role == ROLE_DISPLAY else 45.0)
	_camera_distance = 12.8 if client_role == ROLE_DISPLAY else 10.2
	_update_camera_transform()


func _update_camera_transform() -> void:
	var horizontal := cos(_camera_pitch) * _camera_distance
	camera.position = (
		_camera_focus
		+ Vector3(
			sin(_camera_yaw) * horizontal,
			sin(_camera_pitch) * _camera_distance,
			cos(_camera_yaw) * horizontal
		)
	)
	camera.look_at(_camera_focus, Vector3.UP)


func _setup_logger() -> void:
	client_id = (
		"%s-%s-%d-%d" % [client_role, player_id, Time.get_ticks_msec(), randi_range(1000, 9999)]
	)
	logger = BgoLogger.new()
	add_child(logger)
	logger.configure(game_id, client_id)


func _read_launch_options() -> void:
	if OS.has_feature("web"):
		var role_value = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('role') || 'display'", true
		)
		var game_value = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('game') || 'TEST001'", true
		)
		var player_value = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('player') || 'player_1'", true
		)
		client_role = str(role_value).to_lower()
		game_id = str(game_value)
		player_id = str(player_value)
	else:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--role="):
				client_role = arg.trim_prefix("--role=").to_lower()
			elif arg.begins_with("--game="):
				game_id = arg.trim_prefix("--game=")
			elif arg.begins_with("--player="):
				player_id = arg.trim_prefix("--player=")
	if client_role != ROLE_PLAYER:
		client_role = ROLE_DISPLAY


func _cell_world(cell: Vector2i) -> Vector3:
	var width := float(GRID_COLUMNS - 1) * CELL_SIZE
	var depth := float(GRID_ROWS - 1) * CELL_SIZE
	return Vector3(
		float(cell.x) * CELL_SIZE - width * 0.5, 0.0, float(cell.y) * CELL_SIZE - depth * 0.5
	)


func _vec3_payload(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _cell_payload(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}
