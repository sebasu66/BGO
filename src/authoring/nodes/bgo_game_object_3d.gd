@tool
class_name BgoGameObject3D
extends Node3D

signal definition_changed(definition: Dictionary)

@export var component_id := "bgo.authoring.object"
@export var variant_id := ""
@export var definition_properties: Dictionary = {}:
	set(value):
		definition_properties = value.duplicate(true)
		_queue_refresh()

var _refresh_queued := false


func _ready() -> void:
	set_meta("bgo_composed_game_object", true)
	refresh_composition()


## Returns one authored definition value without exposing mutable internal state.
func get_definition_value(key: StringName, fallback: Variant = null) -> Variant:
	return definition_properties.get(String(key), fallback)


## Updates one authored value and refreshes all definition-consuming children.
func set_definition_value(key: StringName, value: Variant) -> void:
	var next: Dictionary = definition_properties.duplicate(true)
	next[String(key)] = value
	definition_properties = next
	definition_changed.emit(effective_definition())


## Returns a safe copy of the current authored definition values.
func effective_definition() -> Dictionary:
	return definition_properties.duplicate(true)


## Merges the typed property descriptors published by child composition nodes.
func get_definition_schema() -> Dictionary:
	var schema := {}
	for child in find_children("*", "", true, false):
		if not is_instance_valid(child) or not child.has_method("get_definition_schema"):
			continue
		var child_schema: Variant = child.call("get_definition_schema")
		if child_schema is Dictionary:
			schema.merge(child_schema, true)
	return schema


## Returns validation errors that are meaningful before a GamePackage is exported.
func validate_definition() -> PackedStringArray:
	var errors := PackedStringArray()
	var schema: Dictionary = get_definition_schema()
	for key in schema:
		var descriptor: Variant = schema[key]
		if descriptor is Dictionary and bool(descriptor.get("required", false)):
			if not definition_properties.has(key):
				errors.append("Missing required definition property: %s" % key)
	return errors


## Refreshes every child that consumes authored definition values.
func refresh_composition() -> void:
	_refresh_queued = false
	var consumers := find_children("*", "", true, false)
	for child in consumers:
		if not is_instance_valid(child) or not child.has_method("refresh_from_definition"):
			continue
		child.call("refresh_from_definition")


## Compact composition description for future authoring/MCP discovery.
func describe_composition() -> Dictionary:
	var items: Array[Dictionary] = []
	for child in find_children("*", "", true, false):
		if not is_instance_valid(child) or not child.has_method("composition_descriptor"):
			continue
		var descriptor: Variant = child.call("composition_descriptor")
		if descriptor is Dictionary:
			items.append(descriptor)
	return {
		"component_id": component_id,
		"variant_id": variant_id,
		"definition": effective_definition(),
		"nodes": items,
	}


func _queue_refresh() -> void:
	if not is_inside_tree() or _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("refresh_composition")


func _get_configuration_warnings() -> PackedStringArray:
	return validate_definition()
