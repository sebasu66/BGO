class_name BgoGameComponentComposer
extends RefCounted

var logger: BgoLogger
var instances: Dictionary = {}


## Instantiates and configures every declared tabletop component under the supplied root.
func compose(definitions: Array, parent: Node3D) -> Dictionary:
	instances.clear()
	for definition_value in definitions:
		if definition_value is Dictionary:
			_instantiate_component(definition_value, parent)
	return instances.duplicate()


func _instantiate_component(definition: Dictionary, parent: Node3D) -> void:
	var instance_id := str(definition.get("id", ""))
	var component_id := str(definition.get("component", ""))
	_log("COMPONENT_INSTANTIATION_STARTED", {"instance_id": instance_id, "component_id": component_id})
	var packed_scene := BgoComponentRegistry.load_scene(component_id)
	if packed_scene == null:
		_log_error("COMPONENT_INSTANTIATION_FAILED", {"instance_id": instance_id, "component_id": component_id})
		return
	var instance := packed_scene.instantiate() as Node3D
	if instance == null:
		_log_error("COMPONENT_ROOT_INVALID", {"instance_id": instance_id, "component_id": component_id})
		return
	instance.name = instance_id
	instance.set_meta("bgo_component_instance", true)
	instance.set_meta("component_id", component_id)
	_connect_component_events(instance, instance_id, component_id)
	_apply_config(instance, definition.get("config", {}), instance_id)
	_apply_placement(instance, definition.get("placement", {}), instance_id)
	parent.add_child(instance)
	instances[instance_id] = instance
	_log(
		"COMPONENT_INSTANCE_READY",
		{"instance_id": instance_id, "component_id": component_id, "node_path": str(instance.get_path())}
	)


func _apply_config(instance: Node3D, config_value: Variant, instance_id: String) -> void:
	if not config_value is Dictionary:
		return
	var config: Dictionary = config_value
	for property_name in config:
		if not _has_property(instance, str(property_name)):
			_log_error(
				"COMPONENT_PROPERTY_MISSING",
				{"instance_id": instance_id, "property": str(property_name)}
			)
			continue
		var current: Variant = instance.get(property_name)
		instance.set(property_name, _coerce_value(config[property_name], typeof(current)))
		_log(
			"COMPONENT_PROPERTY_APPLIED",
			{"instance_id": instance_id, "property": str(property_name), "value": config[property_name]}
		)


func _apply_placement(instance: Node3D, placement_value: Variant, instance_id: String) -> void:
	if not placement_value is Dictionary:
		return
	var placement: Dictionary = placement_value
	instance.position = _vector3(placement.get("position", {}), Vector3.ZERO)
	instance.rotation_degrees = _vector3(placement.get("rotation_degrees", {}), Vector3.ZERO)
	instance.scale = _vector3(placement.get("scale", {}), Vector3.ONE)
	_log(
		"COMPONENT_PLACED",
		{
			"instance_id": instance_id,
			"position": _vector_payload(instance.position),
			"rotation_degrees": _vector_payload(instance.rotation_degrees),
			"scale": _vector_payload(instance.scale),
		}
	)


func _connect_component_events(instance: Node, instance_id: String, component_id: String) -> void:
	if not instance.has_signal("component_event"):
		return
	instance.connect(
		"component_event", _on_component_event.bind(instance_id, component_id)
	)


func _on_component_event(
	event_name: String, payload: Dictionary, instance_id: String, component_id: String
) -> void:
	var enriched := payload.duplicate(true)
	enriched["instance_id"] = instance_id
	enriched["component_id"] = component_id
	_log("COMPONENT_%s" % event_name.to_upper(), enriched)


func _coerce_value(value: Variant, target_type: int) -> Variant:
	if target_type == TYPE_COLOR and value is String:
		return Color.from_string(value, Color.WHITE)
	if target_type == TYPE_VECTOR3:
		return _vector3(value, Vector3.ZERO)
	if target_type == TYPE_VECTOR2:
		var vector := _vector3(value, Vector3.ZERO)
		return Vector2(vector.x, vector.y)
	return value


func _vector3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Dictionary:
		return Vector3(
			float(value.get("x", fallback.x)),
			float(value.get("y", fallback.y)),
			float(value.get("z", fallback.z))
		)
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback


func _has_property(instance: Object, property_name: String) -> bool:
	for property in instance.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _vector_payload(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _log(event_name: String, payload: Dictionary) -> void:
	if logger != null:
		logger.info(event_name, payload)


func _log_error(event_name: String, payload: Dictionary) -> void:
	if logger != null:
		logger.error(event_name, payload)
