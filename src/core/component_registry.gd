class_name BgoComponentRegistry
extends RefCounted

const COMPONENTS := {
	"bgo.board.checkered":
	{
		"kind": "board",
		"scene": "res://src/components/boards/checkered_board/checkered_board.tscn",
	},
	"bgo.piece.basic_cylinder":
	{
		"kind": "piece",
		"scene": "res://src/components/pieces/basic_cylinder/basic_cylinder_piece.tscn",
	},
	"bgo.player_area.basic":
	{
		"kind": "player_area",
		"scene": "res://src/components/player_area/player_area.tscn",
	},
	"bgo.player_presence.basic_mask":
	{
		"kind": "player_presence",
		"scene": "res://src/components/player_presence/basic_mask/player_presence_mask.tscn",
	},
	"bgo.slot.basic":
	{
		"kind": "slot",
		"scene": "res://src/components/slots/basic_slot/basic_slot.tscn",
	},
}


static func has_component(component_id: String) -> bool:
	return COMPONENTS.has(component_id)


static func get_kind(component_id: String) -> String:
	if not COMPONENTS.has(component_id):
		return ""
	return str(COMPONENTS[component_id].get("kind", ""))


static func load_scene(component_id: String) -> PackedScene:
	if not COMPONENTS.has(component_id):
		return null
	var scene_path := str(COMPONENTS[component_id].get("scene", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return null
	return load(scene_path) as PackedScene


static func validate_config(component_id: String, config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not COMPONENTS.has(component_id):
		errors.append("Unknown component id '%s'." % component_id)
		return errors

	match component_id:
		"bgo.board.checkered":
			_validate_int_range(config, "columns", 2, 30, errors)
			_validate_int_range(config, "rows", 2, 30, errors)
			_validate_float_range(config, "cell_size", 0.5, 3.0, errors)
		"bgo.piece.basic_cylinder":
			_validate_float_range(config, "radius", 0.1, 2.0, errors, true)
			_validate_float_range(config, "height", 0.05, 2.0, errors, true)
		"bgo.player_area.basic", "bgo.player_presence.basic_mask":
			pass
		"bgo.slot.basic":
			if config.has("capacity"):
				_validate_int_range(config, "capacity", 1, 1000, errors)
	return errors


static func _validate_int_range(
	config: Dictionary,
	key: String,
	minimum: int,
	maximum: int,
	errors: Array[String],
	optional := false
) -> void:
	if not config.has(key):
		if not optional:
			errors.append("Missing required property '%s'." % key)
		return
	var value: Variant = config[key]
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		errors.append("'%s' must be an integer." % key)
		return
	var int_value := int(value)
	if float(int_value) != float(value) or int_value < minimum or int_value > maximum:
		errors.append("'%s' must be an integer between %d and %d." % [key, minimum, maximum])


static func _validate_float_range(
	config: Dictionary,
	key: String,
	minimum: float,
	maximum: float,
	errors: Array[String],
	optional := false
) -> void:
	if not config.has(key):
		if not optional:
			errors.append("Missing required property '%s'." % key)
		return
	var value: Variant = config[key]
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		errors.append("'%s' must be numeric." % key)
		return
	var number := float(value)
	if number < minimum or number > maximum:
		errors.append("'%s' must be between %.2f and %.2f." % [key, minimum, maximum])
