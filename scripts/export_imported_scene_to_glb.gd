extends SceneTree


func _initialize() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	var source_path := str(options.get("source", ""))
	var output_path := str(options.get("output", ""))
	if source_path.is_empty() or output_path.is_empty():
		push_error("usage: -- --source res://model.fbx --output res://model.glb")
		quit(1)
		return
	var packed := load(source_path) as PackedScene
	if packed == null:
		push_error("SOURCE_SCENE_LOAD_FAILED path=%s" % source_path)
		quit(2)
		return
	var root := packed.instantiate()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var append_error := document.append_from_scene(root, state)
	if append_error != OK:
		push_error("GLTF_APPEND_FAILED error=%s" % error_string(append_error))
		root.free()
		quit(3)
		return
	var write_error := document.write_to_filesystem(state, output_path)
	root.free()
	if write_error != OK:
		push_error("GLTF_WRITE_FAILED error=%s" % error_string(write_error))
		quit(4)
		return
	print("GLB_EXPORTED source=", source_path, " output=", output_path)
	quit()


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var options := {}
	var index := 0
	while index + 1 < arguments.size():
		var key := arguments[index].trim_prefix("--")
		options[key] = arguments[index + 1]
		index += 2
	return options
