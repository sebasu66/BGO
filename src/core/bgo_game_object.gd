class_name BGOGameObject
extends Node2D

signal component_added(component_id: StringName, component: Node)

@export var entity_id: String = ""
var _components: Dictionary = {}


## Attaches a component to the logical game object.
func add_component(component_id: StringName, component: Node) -> void:
	if _components.has(component_id):
		push_warning("Component '%s' already exists on entity '%s'." % [component_id, entity_id])
		return

	_components[component_id] = component
	add_child(component)
	component_added.emit(component_id, component)


## Returns the component registered under the supplied identifier.
func get_component(component_id: StringName) -> Node:
	return _components.get(component_id)


## Returns whether the object owns the supplied component identifier.
func has_component(component_id: StringName) -> bool:
	return _components.has(component_id)
