extends RefCounted


## Runs focused profile, billboard-angle, and Dracula representation checks.
static func run(tree: SceneTree, check: Callable) -> void:
	_test_adaptive_billboard_angles(check)
	_test_render_profiles(check)
	await _test_dracula_runtime_representations(tree, check)


static func _test_adaptive_billboard_angles(check: Callable) -> void:
	var directions := [
		[Vector3(0, 0, 1), 0, "front (+Z)"],
		[Vector3(-1, 0, 0), 8, "left quarter turn"],
		[Vector3(0, 0, -1), 16, "rear (-Z)"],
		[Vector3(1, 0, 0), 23, "right quarter turn"],
	]
	for definition in directions:
		var frame := BgoAdaptiveRepresentation.frame_for_local_direction(
			definition[0], 31, "counter_clockwise", "+z"
		)
		check.call(frame == definition[1], "adaptive billboard maps %s" % definition[2])


static func _test_render_profiles(check: Callable) -> void:
	var windows := BgoClientRenderProfile.by_id("windows_native")
	var web := BgoClientRenderProfile.by_id("web")
	var mobile := BgoClientRenderProfile.by_id("mobile")
	check.call(windows["representation"] == "desktop_model_lod", "Windows uses 3D model LODs")
	check.call(windows["camera"] == "free_perspective", "Windows camera is free perspective")
	check.call(web["representation"] == "billboard", "Web uses billboard representations")
	check.call(bool(web["fixed_pitch"]), "Web camera pitch remains fixed")
	check.call(bool(mobile["fixed_height"]), "Mobile camera height remains fixed")


static func _test_dracula_runtime_representations(tree: SceneTree, check: Callable) -> void:
	var packed := load("res://src/components/pieces/miniature/miniature.tscn") as PackedScene
	var miniature: BgoMiniature = packed.instantiate() as BgoMiniature if packed != null else null
	check.call(miniature != null, "Dracula miniature scene instantiates")
	if miniature == null:
		return
	tree.get_root().add_child(miniature)
	var camera := Camera3D.new()
	tree.get_root().add_child(camera)
	camera.position = Vector3(0.0, 3.0, 5.0)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var configured := miniature.set_representation_manifest(
		"res://assets/runtime/miniatures/dracula/representation.json"
	)
	check.call(configured, "Dracula representation manifest configures")
	await tree.process_frame
	await tree.process_frame
	var adaptive := (
		miniature.get_node("ModelPivot/AdaptiveRepresentation") as BgoAdaptiveRepresentation
	)
	check.call(
		adaptive.active_representation_id() == "desktop_model",
		"near Windows view uses normal model"
	)
	camera.position = Vector3(0.0, 3.0, 12.0)
	await tree.process_frame
	check.call(
		adaptive.active_representation_id() == "desktop_lod", "far Windows view uses low-poly LOD"
	)
	adaptive.set_tactical_view(true)
	check.call(
		adaptive.active_representation_id() == "top_down_avatar",
		"tactical view uses portrait avatar"
	)
	miniature.queue_free()
	camera.queue_free()
	await tree.process_frame
