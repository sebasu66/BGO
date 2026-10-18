class_name TableConfigState
extends RefCounted

## Logical table settings that are not tied to one object: placement mode,
## surface look and lights. Pure data with validation; rendering reads it.

const MODES := ["free", "closed"]
const LIGHT_TYPES := ["point", "spot", "directional"]
const DEFAULT_SURFACE := {"preset": "", "tint": "#ffffff", "uv_scale": 1.0}

## "free" accepts objects anywhere a zone allows it; "closed" accepts them only in slots.
var mode := "free"

## Surface look: PBR preset name, tint color (HTML) and texture scale.
var surface: Dictionary = DEFAULT_SURFACE.duplicate(true)

## Extra lights keyed by stable light id.
var lights: Dictionary = {}

## Side of one grid cell, in centimetres. A cell holds one small object.
var cell_size_cm := TableCellMath.DEFAULT_CELL_SIZE_CM

## How many world units one centimetre of table is. 1.2 world units per 5 cm cell.
var world_units_per_cm := 0.24


## Builds the config from the optional "table" block of a game definition.
## Returns null when any declared value is invalid.
static func from_definition(table: Dictionary) -> TableConfigState:
	var config := TableConfigState.new()
	if table.has("mode") and not config.set_mode(str(table["mode"])):
		return null
	if table.has("cell_size_cm") and not config.set_cell_size(table["cell_size_cm"]):
		return null
	if table.has("world_units_per_cm") and not config.set_world_scale(table["world_units_per_cm"]):
		return null
	var surface_block: Variant = table.get("surface", {})
	if surface_block is Dictionary and not config.set_surface(_surface_changes(surface_block)):
		return null
	var lights_block: Variant = table.get("lights", [])
	if not lights_block is Array:
		return null
	for light in lights_block:
		if not light is Dictionary or not config.add_light(light):
			return null
	return config


## Sets the placement mode. Rejects anything but "free" or "closed".
func set_mode(value: String) -> bool:
	if value not in MODES:
		return false
	mode = value
	return true


## Sets the cell side in centimetres. Must be a number above zero.
func set_cell_size(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or float(value) <= 0.0:
		return false
	cell_size_cm = float(value)
	return true


## Sets how many world units one centimetre is. Must be a number above zero.
func set_world_scale(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or float(value) <= 0.0:
		return false
	world_units_per_cm = float(value)
	return true


## Whether free (slot-less) placement is refused by the table itself.
func is_closed() -> bool:
	return mode == "closed"


## Changes any of preset, tint and uv_scale. All-or-nothing: one bad value changes nothing.
func set_surface(changes: Dictionary) -> bool:
	var next := surface.duplicate(true)
	if changes.has("preset"):
		next["preset"] = str(changes["preset"])
	if changes.has("tint"):
		var tint := str(changes["tint"])
		if not Color.html_is_valid(tint):
			return false
		next["tint"] = tint
	if changes.has("uv_scale"):
		if typeof(changes["uv_scale"]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		var scale := float(changes["uv_scale"])
		if scale <= 0.0:
			return false
		next["uv_scale"] = scale
	surface = next
	return true


## Adds one light. Needs a unique id, a known type, a position and a positive intensity.
func add_light(definition: Dictionary) -> bool:
	var light_id := str(definition.get("id", ""))
	if light_id.is_empty() or lights.has(light_id):
		return false
	var light_type := str(definition.get("type", "point"))
	if light_type not in LIGHT_TYPES:
		return false
	var position: Variant = definition.get("position", {"x": 0.0, "y": 3.0, "z": 0.0})
	if not _valid_vector(position):
		return false
	if typeof(definition.get("intensity", 1.0)) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var intensity := float(definition.get("intensity", 1.0))
	var color := str(definition.get("color", "#ffffff"))
	if intensity <= 0.0 or not Color.html_is_valid(color):
		return false
	lights[light_id] = {
		"id": light_id,
		"type": light_type,
		"position": (position as Dictionary).duplicate(true),
		"intensity": intensity,
		"color": color,
	}
	return true


## Removes one light by id.
func remove_light(light_id: String) -> bool:
	return lights.erase(light_id)


## Returns a deterministic deep copy for snapshots and clients.
func to_dictionary() -> Dictionary:
	return {
		"mode": mode,
		"surface": surface.duplicate(true),
		"lights": lights.duplicate(true),
		"cell_size_cm": cell_size_cm,
		"world_units_per_cm": world_units_per_cm,
	}


## Replaces this config with a snapshot. Returns false and keeps the old values if it is invalid.
func load_dictionary(snapshot: Dictionary) -> bool:
	var loaded := TableConfigState.new()
	if not loaded.set_mode(str(snapshot.get("mode", "free"))):
		return false
	var saved_cell_size: Variant = snapshot.get("cell_size_cm", loaded.cell_size_cm)
	var saved_world_scale: Variant = snapshot.get("world_units_per_cm", loaded.world_units_per_cm)
	if not loaded.set_cell_size(saved_cell_size) or not loaded.set_world_scale(saved_world_scale):
		return false
	var surface_block: Variant = snapshot.get("surface", {})
	if not surface_block is Dictionary or not loaded.set_surface(surface_block):
		return false
	var lights_block: Variant = snapshot.get("lights", {})
	if not lights_block is Dictionary:
		return false
	for light_id in lights_block:
		var light: Variant = lights_block[light_id]
		if not light is Dictionary or not loaded.add_light(light):
			return false
	mode = loaded.mode
	surface = loaded.surface
	lights = loaded.lights
	cell_size_cm = loaded.cell_size_cm
	world_units_per_cm = loaded.world_units_per_cm
	return true


static func _surface_changes(block: Dictionary) -> Dictionary:
	var changes: Dictionary = {}
	for key in ["preset", "tint", "uv_scale"]:
		if block.has(key):
			changes[key] = block[key]
	return changes


static func _valid_vector(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for axis in ["x", "y", "z"]:
		if typeof((value as Dictionary).get(axis, 0.0)) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	return true
