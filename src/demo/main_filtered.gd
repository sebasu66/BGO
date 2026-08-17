extends "res://src/demo/main_componentized.gd"

func _on_piece_tapped(piece: Node3D) -> void:
	if bool(piece.get_meta("bgo_filtered_out", false)):
		if logger != null:
			logger.info("FILTERED_COMPONENT_IGNORED", {"piece_id": piece.name})
		return
	super._on_piece_tapped(piece)

func _projected_piece_at(screen_position: Vector2) -> Node3D:
	var closest: Node3D = null
	var closest_distance := INF
	var viewport_size := get_viewport().get_visible_rect().size
	var threshold := maxf(54.0, minf(viewport_size.x, viewport_size.y) * 0.055)
	for value in pieces.values():
		var piece := value as Node3D
		if piece == null or bool(piece.get_meta("bgo_filtered_out", false)):
			continue
		if camera.is_position_behind(piece.global_position):
			continue
		var projected := camera.unproject_position(piece.global_position)
		var distance := projected.distance_to(screen_position)
		if distance < threshold and distance < closest_distance:
			closest = piece
			closest_distance = distance
	return closest
