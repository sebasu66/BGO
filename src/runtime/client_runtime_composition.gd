extends "res://src/runtime/client_runtime_interaction.gd"

const GAME_COMPONENT_COMPOSER = preload("res://src/runtime/game_component_composer.gd")
const ASSET_BOX_SCENE = preload("res://src/components/containers/asset_box/asset_box.tscn")
const VERTICAL_HAND_SCENE = preload("res://src/components/hands/vertical_hand/vertical_hand.tscn")
const SEQUENTIAL_DROP_ANIMATOR = preload("res://src/runtime/sequential_drop_animator.gd")
const SANDBOX_RUNTIME_CONTROLLER = preload("res://src/runtime/sandbox_runtime_controller.gd")

var game_definition: Dictionary = {}
var game_definition_path := ""
var definition_errors: Array[String] = []
var _private_hand_strip: HBoxContainer
var _transfer_to_hand_button: Button
var _transfer_to_area_button: Button
var _asset_box_button: Button
var _asset_box: BgoAssetBox
var _asset_box_open := false
var _vertical_hand: BgoVerticalHand
var _table_components: Dictionary = {}
var _player_areas: Dictionary = {}
var _primary_board: BgoCheckeredBoard
var _load_drop_animator: BgoSequentialDropAnimator
var _sandbox_runtime_controller


func _load_game_definition() -> void:
	game_definition_path = "res://games/%s/game.jsonh" % game_id.to_lower()
	var result := BgoGameDefinitionLoader.load_game_id(game_id)
	if bool(result.get("ok", false)):
		game_definition = (result.get("data", {}) as Dictionary).duplicate(true)
		definition_errors.clear()
		get_node("/root/G").bind_definition(game_definition, game_definition_path)
		return
	game_definition.clear()
	definition_errors = result.get("errors", [])
	for message in definition_errors:
		push_warning("Game definition ignored: %s" % message)


func _show_definition_errors() -> void:
	if _status_label == null or definition_errors.is_empty():
		return
	_set_status("Definition ignored Â· %s" % definition_errors[0])
	if logger != null:
		logger.error(
			"GAME_DEFINITION_REJECTED", {"path": game_definition_path, "errors": definition_errors}
		)


func _create_board() -> void:
	var components_root := get_node_or_null("Components") as Node3D
	if components_root == null:
		push_error("Main/Components is required for declarative composition.")
		return
	var table_definition: Dictionary = game_definition.get("table", {})
	var definitions: Array = table_definition.get("instances", [])
	var composer := GAME_COMPONENT_COMPOSER.new() as BgoGameComponentComposer
	composer.logger = logger
	_table_components = composer.compose(definitions, components_root)
	_index_table_components()
	_prepare_table_component_intro(definitions)
	_create_asset_box()


func _begin_initial_load_presentation(on_finished: Callable) -> bool:
	if _load_drop_animator == null or not _load_drop_animator.has_pending():
		return false
	_load_drop_animator.sequence_finished.connect(on_finished, CONNECT_ONE_SHOT)
	_load_drop_animator.play(true)
	return true


func _prepare_table_component_intro(definitions: Array) -> void:
	var animator := _ensure_load_drop_animator()
	for definition_variant in definitions:
		if not definition_variant is Dictionary:
			continue
		var instance_id := str((definition_variant as Dictionary).get("id", ""))
		var instance := _table_components.get(instance_id) as Node3D
		if instance != null:
			animator.enqueue(instance, instance.position)


func _ensure_load_drop_animator() -> BgoSequentialDropAnimator:
	if _load_drop_animator != null:
		return _load_drop_animator
	_load_drop_animator = SEQUENTIAL_DROP_ANIMATOR.new() as BgoSequentialDropAnimator
	_load_drop_animator.name = "SequentialDropAnimator"
	add_child(_load_drop_animator)
	return _load_drop_animator


func _create_asset_box() -> void:
	if _asset_box != null:
		_asset_box.queue_free()
	# The box is conceptual. Asset Placer represents it as an editor/catalog
	# surface; runtime never spawns a physical box or places its contents in 3D.
	_asset_box = null


func _configure_table_surface() -> void:
	var table_mesh := get_node_or_null("Table") as MeshInstance3D
	if table_mesh == null:
		return
	var table: Dictionary = game_definition.get("table", {})
	var mesh := table_mesh.mesh.duplicate() as BoxMesh
	if mesh == null:
		return
	mesh.size = Vector3(
		float(table.get("width", 15.5)), mesh.size.y, float(table.get("depth", 9.8))
	)
	table_mesh.mesh = mesh


func _create_player_areas() -> void:
	# Player areas are regular table.instances and were composed with the board.
	pass


func _create_debug_table_areas(table: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "DebugTableAreas"
	add_child(root)
	var areas: Array = table.get("areas", [])
	for index in areas.size():
		var area: Dictionary = areas[index]
		var bounds: Dictionary = area.get("bounds", {})
		var center: Dictionary = bounds.get("center", {})
		var size: Dictionary = bounds.get("size", {})
		var marker := MeshInstance3D.new()
		marker.name = str(area.get("id", "area_%d" % index))
		var mesh := BoxMesh.new()
		mesh.size = Vector3(float(size.get("x", 1.0)), 0.035, float(size.get("z", 1.0)))
		marker.mesh = mesh
		marker.position = Vector3(float(center.get("x", 0.0)), 0.055, float(center.get("z", 0.0)))
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = _debug_area_color(index)
		material.roughness = 0.9
		marker.material_override = material
		root.add_child(marker)
		var label := Label3D.new()
		label.text = "%s\n%s" % [marker.name, str(area.get("placement_mode", "free_or_slot"))]
		label.font_size = 34
		label.outline_size = 8
		label.position = marker.position + Vector3(0, 0.08, 0)
		label.rotation_degrees = Vector3(-90, 0, 0)
		root.add_child(label)


func _debug_area_color(index: int) -> Color:
	var colors := [
		Color(0.20, 0.65, 0.95, 0.28),
		Color(0.95, 0.55, 0.18, 0.28),
		Color(0.34, 0.82, 0.48, 0.28),
		Color(0.78, 0.38, 0.88, 0.28),
	]
	return colors[index % colors.size()]


func _sync_sandbox_state(state: Dictionary) -> void:
	_sandbox_controller().sync_state(state)


func _sandbox_controller():
	if _sandbox_runtime_controller == null:
		var pieces_root := get_node_or_null("Pieces") as Node3D
		if pieces_root == null:
			push_error("Main/Pieces is required for sandbox rendering.")
			return null
		_sandbox_runtime_controller = SANDBOX_RUNTIME_CONTROLLER.new(pieces, pieces_root)
	return _sandbox_runtime_controller


func _index_table_components() -> void:
	_primary_board = null
	_player_areas.clear()
	for instance_value in _table_components.values():
		var instance := instance_value as Node3D
		if instance is BgoCheckeredBoard and _primary_board == null:
			_primary_board = instance as BgoCheckeredBoard
		elif instance is BgoPlayerArea:
			var area := instance as BgoPlayerArea
			_player_areas[area.player_id] = area
	if _primary_board == null:
		logger.error("PRIMARY_BOARD_MISSING", {})
	(
		logger
		. info(
			"TABLE_COMPOSITION_READY",
			{
				"instance_count": _table_components.size(),
				"player_area_count": _player_areas.size(),
				"board_instance_id": _primary_board.name if _primary_board != null else "",
			}
		)
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
	_connect_runtime_component_events(body, id, component_id)
	if body is BgoBasicCylinderPiece:
		(body as BgoBasicCylinderPiece).configure(id, owner, holder, quantity, color)
	else:
		body.name = id
		body.set_meta("bgo_piece", true)
		body.set_meta("entity_id", id)
	body.set_meta("owner_id", owner)
	body.set_meta("holder_id", holder)
	body.set_meta("quantity", quantity)
	body.set_meta("availability", str(state.get("availability", "unique")))
	body.set_meta("available_quantity", int(state.get("available_quantity", quantity)))
	body.set_meta(
		"hand_stack_key", "%s|%s|%s" % [component_id, owner, JSON.stringify(object_config)]
	)

	var location: Dictionary = state.get("location", {})
	var location_type := _normalize_location_type(str(location.get("type", "slot")))
	body.set_meta("component_id", component_id)
	body.set_meta("cell", cell)
	body.set_meta("location_type", location_type)
	body.set_meta("hand_order", float(state.get("hand_order", 0.0)))
	body.position = _target_world_position(id, state, cell)
	_set_piece_render_state(body, location_type != "asset_box" and location_type != "hand")
	var pieces_root := get_node_or_null("Pieces") as Node3D
	if pieces_root == null:
		logger.error("PIECES_ROOT_MISSING", {"piece_id": id})
		body.queue_free()
		return
	pieces_root.add_child(body)
	pieces[id] = body
	if body.visible:
		var animator := _ensure_load_drop_animator()
		animator.enqueue(body, body.position)
		animator.play()
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
		"asset_box":
			return _board_support_position(cell)
		"grid":
			var origin := _point_from_payload(location.get("origin", {}), cell)
			if _primary_board != null:
				return _grid_support_position(origin)
		"slot":
			var board := _primary_board
			var slot_id := str(location.get("slot_id", ""))
			if board != null and not slot_id.is_empty() and board.is_valid_slot(slot_id):
				return board.slot_world(slot_id)
	return _board_support_position(cell)


func _point_from_payload(value: Variant, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("x", fallback.x)), int(value.get("y", fallback.y)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback


func _grid_support_position(point: Vector2i) -> Vector3:
	if _primary_board == null:
		return Vector3.ZERO
	var result := _primary_board.grid_point_world(point)
	var board_cell := _primary_board.grid_point_to_cell(point)
	if not _primary_board.is_valid_cell(board_cell):
		var table_surface := get_node_or_null("InfiniteLightSurface") as Node3D
		if table_surface != null:
			result.y = table_surface.global_position.y
	return result


func _board_support_position(cell: Vector2i) -> Vector3:
	var board := _primary_board
	if board != null:
		return (
			board.global_position
			+ board.cell_world(cell)
			+ Vector3(0.0, board.surface_height(), 0.0)
		)
	return _cell_world(cell)


func _set_asset_box_piece_visibility(piece: Node3D, enabled: bool) -> void:
	_set_piece_render_state(piece, enabled)


## Hand and asset-box objects are logical/UI content, not physical tabletop
## bodies. This prevents invisible hand objects from intercepting placement taps.
func _set_piece_render_state(piece: Node3D, enabled: bool) -> void:
	if piece == null:
		return
	piece.visible = enabled
	_set_collision_state_recursive(piece, enabled)


func _set_collision_state_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 1 if enabled else 0
		(node as CollisionObject3D).collision_mask = 1 if enabled else 0
	for child in node.get_children():
		_set_collision_state_recursive(child, enabled)


func _player_area_world_position(holder: String, piece_id: String) -> Vector3:
	var slot := _collection_slot_index(holder, piece_id, "player_area")
	var area := _player_areas.get(holder) as BgoPlayerArea
	if area != null:
		return area.area_slot_world(slot)
	return super._hand_world_position(holder, piece_id)


func _private_hand_proxy_world_position(holder: String, piece_id: String) -> Vector3:
	var slot := _collection_slot_index(holder, piece_id, "hand")
	var area := _player_areas.get(holder) as BgoPlayerArea
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
	var board := _primary_board
	if board != null:
		return board.cell_world(cell)
	return super._cell_world(cell)


func _screen_to_board_cell(origin: Vector3, direction: Vector3) -> Vector2i:
	if _primary_board == null or absf(direction.y) < 0.0001:
		return Vector2i(-1, -1)
	var board_y := _primary_board.global_position.y
	var distance := (board_y - origin.y) / direction.y
	if distance <= 0.0:
		return Vector2i(-1, -1)
	var local_point := _primary_board.to_local(origin + direction * distance)
	var width := float(_primary_board.columns - 1) * _primary_board.cell_size
	var depth := float(_primary_board.rows - 1) * _primary_board.cell_size
	var cell := Vector2i(
		int(round((local_point.x + width * 0.5) / _primary_board.cell_size)),
		int(round((local_point.z + depth * 0.5) / _primary_board.cell_size))
	)
	return cell if _primary_board.is_valid_cell(cell) else Vector2i(-1, -1)


func _connect_runtime_component_events(
	component: Node, instance_id: String, component_id: String
) -> void:
	if component.has_signal("component_event"):
		component.connect(
			"component_event", _on_runtime_component_event.bind(instance_id, component_id)
		)


func _on_runtime_component_event(
	event_name: String, payload: Dictionary, instance_id: String, component_id: String
) -> void:
	var enriched := payload.duplicate(true)
	enriched["instance_id"] = instance_id
	enriched["component_id"] = component_id
	logger.info("COMPONENT_%s" % event_name.to_upper(), enriched)
