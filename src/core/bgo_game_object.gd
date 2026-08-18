class_name BGOGameObject
extends Node2D

signal property_changed(property_name: StringName, value: Variant)
signal component_added(component_id: StringName, component: Node)

@export var entity_id: String = ""
@export var owner_id: String = ""
@export_range(1, 9999, 1) var quantity: int = 1

var properties: Dictionary = {}
var _components: Dictionary = {}


func set_property_value(property_name: StringName, value: Variant) -> void:
	properties[property_name] = value
	property_changed.emit(property_name, value)


func get_property_value(property_name: StringName, default_value: Variant = null) -> Variant:
	return properties.get(property_name, default_value)


func add_component(component_id: StringName, component: Node) -> void:
	if _components.has(component_id):
		push_warning("Component '%s' already exists on entity '%s'." % [component_id, entity_id])
		return

	_components[component_id] = component
	add_child(component)
	component_added.emit(component_id, component)


func get_component(component_id: StringName) -> Node:
	return _components.get(component_id)


func has_component(component_id: StringName) -> bool:
	return _components.has(component_id)


func serialize_state() -> Dictionary:
	return {
		"entity_id": entity_id,
		"owner_id": owner_id,
		"quantity": quantity,
		"position": {"x": position.x, "y": position.y},
		"properties": properties.duplicate(true),
	}
