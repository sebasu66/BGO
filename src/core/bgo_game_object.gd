class_name BGOGameObject
extends Node2D

signal property_changed(property_name: StringName, value: Variant)
signal component_added(component_id: StringName, component: Node)

@export var entity_id: String = ""
@export var owner_id: String = ""
@export_range(1, 9999, 1) var quantity: int = 1

var properties: Dictionary = {}
var _components: Dictionary = {}


## Sets a named logical property on the game object.
func set_property_value(property_name: StringName, value: Variant) -> void:
	properties[property_name] = value
	property_changed.emit(property_name, value)


## Returns a named logical property from the game object.
func get_property_value(property_name: StringName, default_value: Variant = null) -> Variant:
	return properties.get(property_name, default_value)


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


## Serializes the object's logical state for persistence or transport.
func serialize_state() -> Dictionary:
	return {
		"entity_id": entity_id,
		"owner_id": owner_id,
		"quantity": quantity,
		"position": {"x": position.x, "y": position.y},
		"properties": properties.duplicate(true),
	}


## Optional developer-console help. The console bridge treats this as metadata,
## not as a gameplay command, and allows concrete objects to override it.
func console_help() -> Dictionary:
	return {
		"_summary": "Developer commands for BGO object '%s'." % entity_id,
	}


## Describes contextual actions for the current viewer.
## Concrete objects may override this, but authority must be checked again
## by the domain command when the action is executed.
func menu_actions(viewer_role: String, viewer_id: String) -> Array[Dictionary]:
	var is_host := viewer_role == "host"
	var is_owner := not owner_id.is_empty() and owner_id == viewer_id
	var actions: Array[Dictionary] = [
		{"id": "details", "label": "DETALLES", "authority": "read"},
		{"id": "details-2", "label": "DETALLES DEL COMPONENTE", "authority": "read"},
	]
	if is_host or is_owner:
		actions.append({"id": "duplicate", "label": "DUPLICAR", "authority": "control"})
		actions.append({"id": "change_owner", "label": "CAMBIAR PROPIETARIO", "authority": "control"})
	if is_host:
		actions.append({"id": "delete", "label": "BORRAR", "authority": "control"})
	return actions
