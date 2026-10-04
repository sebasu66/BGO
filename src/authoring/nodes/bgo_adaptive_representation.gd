class_name BgoAdaptiveRepresentation
extends Node3D

signal representation_sized(metrics: Dictionary)

@export_range(0.0001, 0.1, 0.0001) var billboard_pixel_size := 0.006

var _manifest: Dictionary = {}
var _billboard_definition: Dictionary = {}
var _tactical_definition: Dictionary = {}
var _selection: Dictionary = {}
var _sprite: Sprite3D
var _tactical_sprite: Sprite3D
var _model: Node3D
var _lod_model: Node3D
var _frame_textures: Array[Texture2D] = []
var _frame_bounds: Array[Rect2i] = []
var _physical_size_applied := false
var _current_frame := 0
var _resolved_world_units_per_cm := 0.24
var _tactical_view := false


## Loads all representations from one validated authoring manifest.
func configure(manifest_path: String, model: Node3D) -> bool:
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	_manifest = parsed as Dictionary
	_selection = _manifest.get("selection", {}) as Dictionary
	var representations := _manifest.get("representations", {}) as Dictionary
	_billboard_definition = representations.get("billboard", {}) as Dictionary
	_tactical_definition = representations.get("top_down_avatar", {}) as Dictionary
	_model = model
	_lod_model = _load_model(representations.get("desktop_lod", {}) as Dictionary)
	_physical_size_applied = false
	return _build_billboard() and _build_tactical_avatar()


## Enables the client-local orthographic tactical representation.
func set_tactical_view(enabled: bool) -> void:
	_tactical_view = enabled
	_apply_visibility(false, false, false, enabled)


## Returns the currently visible representation for diagnostics and tests.
func active_representation_id() -> String:
	if _tactical_sprite != null and _tactical_sprite.visible:
		return "top_down_avatar"
	if _sprite != null and _sprite.visible:
		return "billboard"
	if _lod_model != null and _lod_model.visible:
		return "desktop_lod"
	return "desktop_model" if _model != null and _model.visible else "none"


func _process(_delta: float) -> void:
	if _sprite == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	if not _physical_size_applied:
		_apply_physical_size()
	if _tactical_view or camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_apply_visibility(false, false, false, true)
		return
	var distance := global_position.distance_to(camera.global_position)
	var near_distance := float(_selection.get("desktop_near_distance", 9.0))
	var billboard_only := OS.has_feature("web") or OS.has_feature("mobile")
	var use_lod := not billboard_only and distance > near_distance and _lod_model != null
	var use_billboard := (
		billboard_only or (distance > near_distance and not use_lod) or _model == null
	)
	_apply_visibility(not use_billboard and not use_lod, use_lod, use_billboard, false)
	if use_billboard:
		_update_billboard_frame(camera)


func _apply_visibility(
	model_visible: bool, lod_visible: bool, billboard_visible: bool, tactical_visible: bool
) -> void:
	if _model != null:
		_model.visible = model_visible
	if _lod_model != null:
		_lod_model.visible = lod_visible
	if _sprite != null:
		_sprite.visible = billboard_visible
	if _tactical_sprite != null:
		_tactical_sprite.visible = tactical_visible


func _load_model(definition: Dictionary) -> Node3D:
	var path := str(definition.get("path", ""))
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate() as Node3D
	instance.name = "AdaptiveLodModel"
	instance.visible = false
	add_child(instance)
	return instance


func _build_billboard() -> bool:
	_frame_textures.clear()
	for frame_value in _billboard_definition.get("frames", []) as Array:
		if not frame_value is Dictionary:
			return false
		var texture := (
			ResourceLoader.load(str((frame_value as Dictionary).get("path", ""))) as Texture2D
		)
		if texture == null:
			return false
		_frame_textures.append(texture)
	if _frame_textures.is_empty():
		return false
	if _sprite == null:
		_sprite = _create_billboard_sprite("AdaptiveBillboard")
	_sprite.texture = _frame_textures[0]
	_sprite.pixel_size = billboard_pixel_size
	_frame_bounds = _measure_frame_bounds()
	_apply_sprite_frame(_sprite, 0, 1.0)
	return true


func _create_billboard_sprite(sprite_name: String) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = sprite_name
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# Turntable frames already contain their final lighting.
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.region_enabled = false
	add_child(sprite)
	return sprite


func _build_tactical_avatar() -> bool:
	var texture := ResourceLoader.load(str(_tactical_definition.get("path", ""))) as Texture2D
	if texture == null:
		return false
	_tactical_sprite = _create_billboard_sprite("TacticalAvatar")
	_tactical_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Tactical tokens are presentation overlays. Keep them readable above the
	# piece base, board, and selection geometry without changing game physics.
	_tactical_sprite.no_depth_test = true
	_tactical_sprite.render_priority = 1
	_tactical_sprite.texture = texture
	_tactical_sprite.visible = false
	return true


func _update_billboard_frame(camera: Camera3D) -> void:
	var frame_count := int(_billboard_definition.get("frame_count", 0))
	if frame_count <= 0 or _frame_textures.size() != frame_count:
		return
	var direction := camera.global_position - global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	var local_direction := global_transform.basis.inverse() * direction.normalized()
	# Godot's conventional model-forward direction is -Z. Frame zero is the
	# front view, so a camera on -Z must select frame zero.
	var frame := frame_for_local_direction(
		local_direction,
		frame_count,
		str(_billboard_definition.get("direction", "clockwise")),
		str(_billboard_definition.get("front_axis", "-z")),
	)
	_current_frame = frame
	_apply_sprite_frame(_sprite, frame, 1.0)


static func frame_for_local_direction(
	local_direction: Vector3,
	frame_count: int,
	sequence_direction: String = "clockwise",
	front_axis: String = "-z",
) -> int:
	return posmod(
		int(
			round(
				frame_position_for_local_direction(
					local_direction, frame_count, sequence_direction, front_axis
				)
			)
		),
		frame_count,
	)


static func frame_position_for_local_direction(
	local_direction: Vector3,
	frame_count: int,
	sequence_direction: String = "clockwise",
	front_axis: String = "-z",
) -> float:
	if frame_count <= 0:
		return 0.0
	var angle := (
		fposmod(rad_to_deg(atan2(local_direction.x, local_direction.z)), 360.0)
		if front_axis == "+z"
		else fposmod(rad_to_deg(atan2(-local_direction.x, -local_direction.z)), 360.0)
	)
	if sequence_direction == "counter_clockwise":
		angle = fposmod(-angle, 360.0)
	return angle / (360.0 / frame_count)


func _apply_physical_size() -> void:
	var physical := _manifest.get("physical_size_cm", {}) as Dictionary
	var height_cm := float(physical.get("height", 0.0))
	var diameter_cm := float(physical.get("base_diameter", 0.0))
	if height_cm <= 0.0 or diameter_cm <= 0.0:
		_physical_size_applied = true
		return
	var world_units_per_cm := _world_units_per_cm()
	_resolved_world_units_per_cm = world_units_per_cm
	var target_height := height_cm * world_units_per_cm
	var target_width := diameter_cm * world_units_per_cm
	_fit_model_to_bounds(target_width, target_height)
	_fit_lod_to_bounds(target_width, target_height)
	_fit_billboard_to_bounds(target_width, target_height)
	_fit_tactical_avatar(target_width)
	_physical_size_applied = true
	(
		representation_sized
		. emit(
			{
				"height_cm": height_cm,
				"base_diameter_cm": diameter_cm,
				"world_units_per_cm": world_units_per_cm,
				"target_height_world": target_height,
				"target_width_world": target_width,
				"billboard_pixel_size": billboard_pixel_size,
				"billboard_vertical_offset_cm":
				float(_billboard_definition.get("vertical_offset_cm", 0.0)),
				"billboard_opacity": 1.0,
			}
		)
	)


func _world_units_per_cm() -> float:
	var scene := get_tree().current_scene
	if scene != null:
		for candidate in scene.find_children("*", "BgoCheckeredBoard", true, false):
			var board := candidate as BgoCheckeredBoard
			if board != null and board.grid_cell_size_cm > 0.0:
				return board.cell_size / board.grid_cell_size_cm
	return float(_manifest.get("world_units_per_cm_fallback", 0.24))


func _fit_model_to_bounds(target_width: float, target_height: float) -> void:
	if _model == null:
		return
	var bounds := _visual_bounds(_model)
	if bounds.size.y <= 0.0:
		return
	var width := maxf(bounds.size.x, bounds.size.z)
	var factor := target_height / bounds.size.y
	if width > 0.0:
		factor = minf(factor, target_width / width)
	_model.scale *= factor


func _fit_lod_to_bounds(target_width: float, target_height: float) -> void:
	if _lod_model == null:
		return
	var original_model := _model
	_model = _lod_model
	_fit_model_to_bounds(target_width, target_height)
	_model = original_model


func _fit_tactical_avatar(target_width: float) -> void:
	if _tactical_sprite == null or _tactical_sprite.texture == null:
		return
	var texture_width := float(_tactical_sprite.texture.get_width())
	if texture_width <= 0.0:
		return
	_tactical_sprite.pixel_size = target_width / texture_width
	_tactical_sprite.position.y = 0.45


func _fit_billboard_to_bounds(target_width: float, target_height: float) -> void:
	if _sprite == null or _frame_bounds.is_empty():
		return
	var content_width := 0
	var content_height := 0
	for bounds in _frame_bounds:
		content_width = maxi(content_width, bounds.size.x)
		content_height = maxi(content_height, bounds.size.y)
	if content_width <= 0 or content_height <= 0:
		return
	billboard_pixel_size = minf(
		target_width / float(content_width), target_height / float(content_height)
	)
	_sprite.pixel_size = billboard_pixel_size
	_apply_sprite_frame(_sprite, _current_frame, _sprite.modulate.a)


func _measure_frame_bounds() -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	var frame_size := Vector2i(_frame_size())
	for texture in _frame_textures:
		var image := texture.get_image()
		var min_point := frame_size
		var max_point := Vector2i(-1, -1)
		for y in frame_size.y:
			for x in frame_size.x:
				if image.get_pixel(x, y).a > 0.05:
					min_point.x = mini(min_point.x, x)
					min_point.y = mini(min_point.y, y)
					max_point.x = maxi(max_point.x, x)
					max_point.y = maxi(max_point.y, y)
		result.append(
			(
				Rect2i(min_point, max_point - min_point + Vector2i.ONE)
				if max_point.x >= 0
				else Rect2i(Vector2i.ZERO, frame_size)
			)
		)
	return result


func _apply_sprite_frame(sprite: Sprite3D, frame: int, alpha: float) -> void:
	if sprite == null or frame < 0 or frame >= _frame_textures.size():
		return
	sprite.texture = _frame_textures[frame]
	sprite.modulate.a = clampf(alpha, 0.0, 1.0)
	var frame_size := _frame_size()
	var visible_bottom := frame_size.y
	if frame >= 0 and frame < _frame_bounds.size():
		visible_bottom = float(_frame_bounds[frame].end.y)
	var calibration := _frame_calibration(frame)
	var offset := calibration.get("offset_pixels", [0.0, 0.0]) as Array
	var offset_x := float(offset[0]) if offset.size() > 0 else 0.0
	var offset_y := float(offset[1]) if offset.size() > 1 else 0.0
	var scale_multiplier := float(calibration.get("scale", 1.0))
	sprite.scale = Vector3.ONE * scale_multiplier
	sprite.position.x = offset_x * billboard_pixel_size
	sprite.position.y = (
		(visible_bottom - frame_size.y * 0.5 - offset_y) * billboard_pixel_size
		+ float(_billboard_definition.get("vertical_offset_cm", 0.0)) * _resolved_world_units_per_cm
	)


func _frame_calibration(frame: int) -> Dictionary:
	var definitions := _billboard_definition.get("frames", []) as Array
	if frame < 0 or frame >= definitions.size() or not definitions[frame] is Dictionary:
		return {}
	return (definitions[frame] as Dictionary).get("calibration", {}) as Dictionary


func _visual_bounds(root: Node3D) -> AABB:
	var combined := AABB()
	var has_bounds := false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local_transform := _transform_relative_to(mesh_instance, root)
		var transformed := local_transform * mesh_instance.get_aabb()
		combined = transformed if not has_bounds else combined.merge(transformed)
		has_bounds = true
	return combined


func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node3D = node
	while current != null and current != ancestor:
		result = current.transform * result
		current = current.get_parent() as Node3D
	return result


func _frame_size() -> Vector2:
	var value: Array = _billboard_definition.get("frame_size", [256, 256]) as Array
	if value.size() < 2:
		return Vector2(256, 256)
	return Vector2(float(value[0]), float(value[1]))
