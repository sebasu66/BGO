extends SceneTree

const PORTRAIT_SIZE := Vector2i(512, 512)
const PORTRAIT_TARGET_HEIGHT_RATIO := 0.77
const PORTRAIT_DISTANCE_HEIGHT_RATIO := 1.05


func _initialize() -> void:
	call_deferred("_render_portrait")


func _render_portrait() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	var model_path := str(options.get("model", ""))
	var output_path := str(options.get("output", ""))
	var packed := load(model_path) as PackedScene
	if packed == null or output_path.is_empty():
		push_error("usage: -- --model res://model.glb --output res://portrait.png")
		quit(1)
		return
	var viewport := _create_viewport()
	var stage := Node3D.new()
	viewport.add_child(stage)
	var model := packed.instantiate() as Node3D
	stage.add_child(model)
	var bounds := _visual_bounds(model)
	_add_camera(stage, bounds)
	_add_lighting(stage)
	for _frame in 12:
		await process_frame
	var error := viewport.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("PORTRAIT_SAVE_FAILED error=%s" % error_string(error))
		quit(2)
		return
	print("PORTRAIT_RENDERED model=", model_path, " output=", output_path)
	quit()


func _create_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = PORTRAIT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _add_camera(stage: Node3D, bounds: AABB) -> void:
	var center := bounds.get_center()
	var target := Vector3(
		center.x, bounds.position.y + bounds.size.y * PORTRAIT_TARGET_HEIGHT_RATIO, center.z
	)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = target + Vector3(
		0.0, bounds.size.y * 0.03, bounds.size.y * PORTRAIT_DISTANCE_HEIGHT_RATIO
	)
	stage.add_child(camera)
	camera.look_at(target, Vector3.UP)
	camera.current = true


func _add_lighting(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32.0, -25.0, 0.0)
	key.light_energy = 2.2
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 145.0, 0.0)
	fill.light_energy = 1.1
	stage.add_child(fill)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.06, 0.075, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.68)
	environment.ambient_light_energy = 1.1
	world_environment.environment = environment
	stage.add_child(world_environment)


func _visual_bounds(model: Node3D) -> AABB:
	var combined := AABB()
	var has_bounds := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative: Transform3D = (
			model.global_transform.affine_inverse() * mesh_instance.global_transform
		)
		var transformed: AABB = relative * mesh_instance.get_aabb()
		combined = transformed if not has_bounds else combined.merge(transformed)
		has_bounds = true
	return combined


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var options := {}
	var index := 0
	while index + 1 < arguments.size():
		var key := arguments[index].trim_prefix("--")
		options[key] = arguments[index + 1]
		index += 2
	return options
