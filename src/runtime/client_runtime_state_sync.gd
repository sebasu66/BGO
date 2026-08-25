extends "res://src/runtime/client_runtime_base.gd"


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
