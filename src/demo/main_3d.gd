extends Node3D

const GRID_COLUMNS := 8
const GRID_ROWS := 6
const CELL_SIZE := 1.2
const GAME_ID_DEFAULT := "TEST001"
const ROLE_DISPLAY := "display"
const ROLE_PLAYER := "player"
const MODE_PICK_UP := "pick_up"
const MODE_PLACE := "place"

@onready var camera: Camera3D = $Camera3D
@onready var title_label: Label = $UI/Title
@onready var hint_label: Label = $UI/Hint

var repository: GameSessionRepository
var client_role := ROLE_DISPLAY
var game_id := GAME_ID_DEFAULT
var player_id := "player_1"
var interaction_mode := MODE_PICK_UP

var selected_piece: Node3D
var pieces: Dictionary = {}
var _session_seed_requested := false

var _pointer_down := false
var _pointer_dragged := false
var _pointer_start := Vector2.ZERO
var _last_pointer := Vector2.ZERO

var _camera_yaw := 0.0
var _camera_pitch := deg_to_rad(52.0)
var _camera_distance := 10.8
var _camera_focus := Vector3.ZERO
var _desired_focus := Vector3.ZERO
var _focus_release_at := 0.0

var _mode_label: Label
var _status_label: Label
var _debug_label: Label
var _player_controls: Control

func _ready() -> void:
	_read_launch_options()
	_create_board()
	_create_hud()
	_configure_camera()
	_connect_session()

func _process(delta: float) -> void:
	if client_role == ROLE_DISPLAY:
		if _focus_release_at > 0.0 and Time.get_ticks_msec() / 1000.0 >= _focus_release_at:
			_desired_focus = Vector3.ZERO
			_focus_release_at = 0.0
		_camera_focus = _camera_focus.lerp(_desired_focus, minf(delta * 3.5, 1.0))
		_update_camera_transform()

# Use _input instead of _unhandled_input so touch events still reach the 3D picker
# when CanvasLayer controls are present in the Web export.
func _input(event: InputEvent) -> void:
	if client_role != ROLE_PLAYER:
		return

	if event is InputEventScreenTouch:
		if _pointer_is_over_controls(event.position):
			return
		if event.pressed:
			_begin_pointer(event.position)
		else:
			_end_pointer(event.position)
	elif event is InputEventScreenDrag:
		if _pointer_is_over_controls(event.position):
			return
		_pointer_dragged = true
		_orbit_camera(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _pointer_is_over_controls(event.position):
			return
		if event.pressed:
			_begin_pointer(event.position)
		else:
			_end_pointer(event.position)
	elif event is InputEventMouseMotion and _pointer_down and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if event.position.distance_to(_pointer_start) > 8.0:
			_pointer_dragged = true
			_orbit_camera(event.relative)

func _pointer_is_over_controls(position: Vector2) -> bool:
	return _player_controls != null and _player_controls.get_global_rect().has_point(position)

func _begin_pointer(position: Vector2) -> void:
	_pointer_down = true
	_pointer_dragged = false
	_pointer_start = position
	_last_pointer = position
	_set_debug("pointer down %.0f,%.0f" % [position.x, position.y])

func _end_pointer(position: Vector2) -> void:
	_pointer_down = false
	if not _pointer_dragged and position.distance_to(_pointer_start) <= 12.0:
		_pick_at(position)
	else:
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
		if collider != null and collider.has_meta("bgo_piece"):
			_set_debug("ray hit piece: %s" % collider.name)
			_on_piece_tapped(collider)
			return

	# Mobile/Web fallback: select the closest projected piece on screen. This makes
	# picking tolerant of browser/canvas coordinate and physics timing differences.
	var projected_piece := _projected_piece_at(screen_position)
	if projected_piece != null:
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
			repository.move_piece(str(selected_piece.get_meta("entity_id")), player_id, destination)
			_set_status("Placed %s at %s" % [selected_piece.name, destination])
			_set_debug("place cell: %s" % destination)
			return

	_set_debug("tap: no piece/cell hit")

func _projected_piece_at(screen_position: Vector2) -> Node3D:
	var closest: Node3D = null
	var closest_distance := INF
	var threshold := maxf(54.0, minf(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y) * 0.055)
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
	if owner_id != player_id:
		_set_status("That piece belongs to %s" % owner_id)
		return

	if interaction_mode == MODE_PICK_UP:
		_select_piece(piece)
		_set_status("Picked up %s · switch to PLACE and tap a cell" % piece.name)
	else:
		_select_piece(piece)
		_set_status("Selected %s" % piece.name)

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
			material.albedo_color = Color(0.20, 0.22, 0.25) if (x + y) % 2 == 0 else Color(0.12, 0.14, 0.17)
			material.roughness = 0.78
			mesh_instance.material_override = material
			cell.add_child(mesh_instance)

			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(CELL_SIZE, 0.12, CELL_SIZE)
			shape.shape = box
			cell.add_child(shape)
			$Board.add_child(cell)

func _connect_session() -> void:
	repository = GameSessionRepository.new()
	add_child(repository)
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
	push_warning(message)

func _on_piece_changed(piece_id: String, piece_data: Dictionary) -> void:
	var cell_data: Dictionary = piece_data.get("cell", {})
	var cell := Vector2i(int(cell_data.get("x", 0)), int(cell_data.get("y", 0)))
	if not pieces.has(piece_id):
		_create_piece_from_state(piece_id, piece_data, cell)
	else:
		_update_piece_from_state(pieces[piece_id], piece_data, cell)

	if client_role == ROLE_DISPLAY:
		var piece: Node3D = pieces[piece_id]
		_desired_focus = piece.position
		_focus_release_at = Time.get_ticks_msec() / 1000.0 + 2.2

func _create_piece_from_state(id: String, state: Dictionary, cell: Vector2i) -> void:
	var owner := str(state.get("owner_id", ""))
	var quantity := int(state.get("quantity", 1))
	var color := Color(0.95, 0.72, 0.22) if owner == "player_1" else Color(0.30, 0.72, 0.95)

	var body := StaticBody3D.new()
	body.name = id
	body.set_meta("bgo_piece", true)
	body.set_meta("entity_id", id)
	body.set_meta("owner_id", owner)
	body.set_meta("holder_id", str(state.get("holder_id", owner)))
	body.set_meta("quantity", quantity)
	body.set_meta("cell", cell)
	body.position = _cell_world(cell) + Vector3(0, 0.35, 0)

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

func _update_piece_from_state(piece: Node3D, state: Dictionary, cell: Vector2i) -> void:
	piece.set_meta("owner_id", str(state.get("owner_id", piece.get_meta("owner_id", ""))))
	piece.set_meta("holder_id", str(state.get("holder_id", piece.get_meta("holder_id", ""))))
	if piece.get_meta("cell", Vector2i(-1, -1)) == cell:
		return
	piece.set_meta("cell", cell)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(piece, "position", _cell_world(cell) + Vector3(0, 0.35, 0), 0.24)

func _select_piece(piece: Node3D) -> void:
	selected_piece = piece
	for candidate in pieces.values():
		(candidate as Node3D).scale = Vector3.ONE * (1.16 if candidate == selected_piece else 1.0)

func _create_hud() -> void:
	title_label.text = "BGO · %s · %s" % [game_id, client_role.to_upper()]

	_status_label = Label.new()
	_status_label.position = Vector2(30, 96)
	_status_label.size = Vector2(900, 30)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_font_size_override("font_size", 14)
	$UI.add_child(_status_label)

	if client_role == ROLE_DISPLAY:
		hint_label.text = "Shared display · Firebase TEST001 · camera follows activity automatically."
		return

	hint_label.text = "Drag to orbit camera · tap owned piece to pick up · PLACE then tap destination."
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.position = Vector2(-150, -72)
	bar.size = Vector2(300, 52)
	bar.add_theme_constant_override("separation", 12)
	$UI.add_child(bar)
	_player_controls = bar

	var pickup := Button.new()
	pickup.text = "PICK UP"
	pickup.custom_minimum_size = Vector2(120, 48)
	pickup.pressed.connect(func(): _set_mode(MODE_PICK_UP))
	bar.add_child(pickup)

	var place := Button.new()
	place.text = "PLACE"
	place.custom_minimum_size = Vector2(120, 48)
	place.pressed.connect(func(): _set_mode(MODE_PLACE))
	bar.add_child(place)

	_mode_label = Label.new()
	_mode_label.text = "Mode: PICK UP"
	_mode_label.position = Vector2(30, 126)
	_mode_label.size = Vector2(300, 28)
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_mode_label)

	_debug_label = Label.new()
	_debug_label.text = "Input debug: waiting for tap"
	_debug_label.position = Vector2(30, 154)
	_debug_label.size = Vector2(700, 28)
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.add_theme_font_size_override("font_size", 13)
	$UI.add_child(_debug_label)

func _set_mode(mode: String) -> void:
	interaction_mode = mode
	if _mode_label != null:
		_mode_label.text = "Mode: %s" % mode.replace("_", " ").to_upper()
	_set_debug("mode: %s" % mode)

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

func _set_debug(text: String) -> void:
	if _debug_label != null:
		_debug_label.text = "Input debug: %s" % text

func _configure_camera() -> void:
	_camera_yaw = 0.0
	_camera_pitch = deg_to_rad(52.0 if client_role == ROLE_DISPLAY else 45.0)
	_camera_distance = 10.8 if client_role == ROLE_DISPLAY else 8.6
	_update_camera_transform()

func _update_camera_transform() -> void:
	var horizontal := cos(_camera_pitch) * _camera_distance
	camera.position = _camera_focus + Vector3(
		sin(_camera_yaw) * horizontal,
		sin(_camera_pitch) * _camera_distance,
		cos(_camera_yaw) * horizontal
	)
	camera.look_at(_camera_focus, Vector3.UP)

func _read_launch_options() -> void:
	if OS.has_feature("web"):
		var role_value = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('role') || 'display'", true)
		var game_value = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('game') || 'TEST001'", true)
		var player_value = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('player') || 'player_1'", true)
		client_role = str(role_value).to_lower()
		game_id = str(game_value)
		player_id = str(player_value)
	else:
		# Editor/native default is the shared display. Optional CLI args:
		# --role=player --game=TEST001 --player=player_1
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
	return Vector3(float(cell.x) * CELL_SIZE - width * 0.5, 0.0, float(cell.y) * CELL_SIZE - depth * 0.5)
