extends Node3D

## The visible side of the table: it shows the lights the table state declares.
## The surface look is announced through a signal so the world that owns the
## floor material can change it. This node never decides anything; it only shows.

signal surface_should_change(surface: Dictionary)

const LIGHT_NODE_PREFIX := "Light_"

var _shown_surface: Dictionary = {}


## Shows the table state: one light node per declared light, and the surface look.
func show_table_state(table_state: Dictionary) -> void:
	show_lights(table_state.get("lights", {}))
	show_surface(table_state.get("surface", {}))


## Makes the light nodes match the declared lights exactly.
func show_lights(declared_lights: Dictionary) -> void:
	_remove_lights_that_are_no_longer_declared(declared_lights)
	for light_id in declared_lights:
		_add_or_update_light(declared_lights[light_id])


## Announces the surface look, but only when it really changed.
func show_surface(surface: Dictionary) -> void:
	if surface == _shown_surface:
		return
	_shown_surface = surface.duplicate(true)
	surface_should_change.emit(_shown_surface.duplicate(true))


## Returns the ids of the lights currently shown, sorted.
func shown_light_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for child in get_children():
		if child.name.begins_with(LIGHT_NODE_PREFIX):
			ids.append(child.name.trim_prefix(LIGHT_NODE_PREFIX))
	ids.sort()
	return ids


## Describes what the console and MCP may ask this component to do.
func console_api() -> Dictionary:
	return (
		BgoComponentApiDescriptor
		. create(
			self,
			"bgo.table.basic",
			"BgoTable",
			"Visible table: shows the lights and surface that the table state declares.",
			{
				"showTableState":
				BgoComponentApiDescriptor.method(
					"show_table_state", [{"name": "table_state", "type": "Dictionary"}]
				),
				"shownLightIds":
				BgoComponentApiDescriptor.method("shown_light_ids", [], "PackedStringArray"),
			}
		)
	)


func _remove_lights_that_are_no_longer_declared(declared_lights: Dictionary) -> void:
	for child in get_children():
		if not child.name.begins_with(LIGHT_NODE_PREFIX):
			continue
		var light_id := child.name.trim_prefix(LIGHT_NODE_PREFIX)
		if not declared_lights.has(light_id):
			child.free()


func _add_or_update_light(declared_light: Dictionary) -> void:
	var node_name := LIGHT_NODE_PREFIX + str(declared_light["id"])
	var light := get_node_or_null(node_name) as Light3D
	if light != null and light.get_class() != _node_class_for(str(declared_light["type"])):
		light.free()
		light = null
	if light == null:
		light = _new_light_for(str(declared_light["type"]))
		light.name = node_name
		add_child(light)
	_copy_look_onto(light, declared_light)


func _new_light_for(light_type: String) -> Light3D:
	match light_type:
		"spot":
			return SpotLight3D.new()
		"directional":
			return DirectionalLight3D.new()
	return OmniLight3D.new()


func _node_class_for(light_type: String) -> String:
	match light_type:
		"spot":
			return "SpotLight3D"
		"directional":
			return "DirectionalLight3D"
	return "OmniLight3D"


func _copy_look_onto(light: Light3D, declared_light: Dictionary) -> void:
	var position: Dictionary = declared_light["position"]
	light.position = Vector3(
		float(position.get("x", 0.0)), float(position.get("y", 0.0)), float(position.get("z", 0.0))
	)
	light.light_energy = float(declared_light["intensity"])
	light.light_color = Color.from_string(str(declared_light["color"]), Color.WHITE)
