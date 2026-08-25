class_name BgoSandboxRuntimeController
extends RefCounted

var _pieces: Dictionary
var _pieces_root: Node3D


func _init(pieces: Dictionary, pieces_root: Node3D) -> void:
	_pieces = pieces
	_pieces_root = pieces_root


## Synchronizes rendered sandbox objects from authoritative sandbox state.
func sync_state(state: Dictionary) -> void:
	var sandbox_objects: Dictionary = state.get("objects", {})
	for object_id in _pieces.keys().duplicate():
		if not sandbox_objects.has(object_id):
			(_pieces[object_id] as Node).queue_free()
			_pieces.erase(object_id)
	for object_id in sandbox_objects:
		var object_state: Dictionary = sandbox_objects[object_id]
		if not _pieces.has(object_id):
			_create_object(str(object_id), object_state, state.get("tabletop", {}))
		else:
			_place_object(_pieces[object_id], object_state, state.get("tabletop", {}))


func _create_object(
	object_id: String, object_state: Dictionary, tabletop_state: Dictionary
) -> void:
	var component_id := str(object_state.get("component_id", ""))
	var packed_scene := BgoComponentRegistry.load_scene(component_id)
	if packed_scene == null:
		push_warning("Sandbox cannot render component '%s'." % component_id)
		return
	var instance := packed_scene.instantiate() as Node3D
	if instance == null:
		return
	instance.name = object_id
	instance.set_meta("entity_id", object_id)
	instance.set_meta("component_id", component_id)
	instance.set_meta("owner_id", str(object_state.get("owner_id", "")))
	instance.set_meta("quantity", int(object_state.get("quantity", 1)))
	_pieces_root.add_child(instance)
	_pieces[object_id] = instance
	_place_object(instance, object_state, tabletop_state)


func _place_object(instance: Node3D, object_state: Dictionary, tabletop_state: Dictionary) -> void:
	var object_id := str(object_state.get("object_id", instance.name))
	var location_type := str(object_state.get("location_type", ""))
	var location_id := str(object_state.get("location_id", ""))
	instance.set_meta("location_type", location_type)
	if location_type == "zone":
		var placements: Dictionary = tabletop_state.get("object_poses", {})
		var placement: Dictionary = placements.get(object_id, {})
		_apply_pose(instance, placement.get("pose", {}))
	elif location_type == "slot":
		var slots: Dictionary = tabletop_state.get("slots", {})
		var slot: Dictionary = slots.get(location_id, {})
		_apply_pose(instance, slot.get("pose", {}))


func _apply_pose(instance: Node3D, pose: Variant) -> void:
	if not pose is Dictionary or pose.is_empty():
		return
	var position: Dictionary = pose.get("position", {})
	var rotation: Dictionary = pose.get("rotation", {})
	instance.position = Vector3(
		float(position.get("x", 0.0)),
		float(position.get("y", 0.35)),
		float(position.get("z", 0.0)),
	)
	instance.rotation = Vector3(
		float(rotation.get("x", 0.0)),
		float(rotation.get("y", 0.0)),
		float(rotation.get("z", 0.0)),
	)
