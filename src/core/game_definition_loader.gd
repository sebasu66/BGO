class_name BgoGameDefinitionLoader
extends RefCounted

const JSONH_GD_PATH := "res://addons/JsonhGd/JsonhGd.gd"


static func load_game(path: String) -> Dictionary:
	var errors: Array[String] = []
	var result := {
		"ok": false,
		"data": {},
		"errors": errors,
		"path": path,
	}

	if not FileAccess.file_exists(path):
		errors.append("Game definition not found: %s" % path)
		return result

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Could not open game definition: %s" % path)
		return result
	var source := file.get_as_text()

	var parsed := _parse_jsonh(source)
	if not bool(parsed.get("ok", false)):
		errors.append("JSONH parse error: %s" % str(parsed.get("error", "Unknown parse error")))
		return result
	var parsed_value: Variant = parsed.get("value")
	if not parsed_value is Dictionary:
		errors.append("The root of the game definition must be an object.")
		return result

	var data: Dictionary = parsed_value
	var validation_errors := validate_game(data)
	if not validation_errors.is_empty():
		result["errors"] = validation_errors
		return result

	result["ok"] = true
	result["data"] = data
	return result


static func _parse_jsonh(source: String) -> Dictionary:
	if FileAccess.file_exists(JSONH_GD_PATH):
		var jsonh_script: Script = load(JSONH_GD_PATH)
		if jsonh_script != null:
			var reader_class: Variant = jsonh_script.get("JsonhReader")
			if reader_class != null:
				var parse_result: Variant = reader_class.call("parse_element_from_string", source)
				if parse_result != null:
					if bool(parse_result.get("is_error")):
						return {
							"ok": false, "value": null, "error": str(parse_result.call("error"))
						}
					return {"ok": true, "value": parse_result.call("value"), "error": ""}

	# JSON is a strict subset of JSONH. This fallback means a game still loads
	# safely if the optional JsonhGd addon is absent, as long as the file uses
	# strict JSON syntax.
	var json := JSON.new()
	var error := json.parse(source)
	if error == OK:
		return {"ok": true, "value": json.data, "error": ""}
	return {
		"ok": false,
		"value": null,
		"error":
		(
			"JsonhGd is not installed at %s, and strict JSON parsing also failed at line %d: %s"
			% [JSONH_GD_PATH, json.get_error_line(), json.get_error_message()]
		)
	}


static func validate_game(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(data.get("schema", "")) != "bgo.game":
		errors.append("schema must be 'bgo.game'.")

	var game: Variant = data.get("game")
	if not game is Dictionary:
		errors.append("Missing object 'game'.")
	else:
		if str(game.get("id", "")).is_empty():
			errors.append("game.id is required.")
		var min_players := int(game.get("min_players", 0))
		var max_players := int(game.get("max_players", 0))
		if min_players < 1:
			errors.append("game.min_players must be at least 1.")
		if max_players < min_players:
			errors.append("game.max_players must be >= game.min_players.")

	var board: Variant = data.get("board")
	if not board is Dictionary:
		errors.append("Missing object 'board'.")
	else:
		_validate_component_reference(board, "board", errors)

	var table: Variant = data.get("table")
	if not table is Dictionary:
		errors.append("Missing object 'table'.")
	else:
		_validate_table(table, errors)

	var flow: Variant = data.get("flow")
	if not flow is Dictionary:
		errors.append("Missing object 'flow'.")
	else:
		if str(flow.get("initial_phase", "")).is_empty():
			errors.append("flow.initial_phase is required.")
		if str(flow.get("turn_order", "")) != "round_robin":
			errors.append("flow.turn_order must currently be 'round_robin'.")
		if str(flow.get("turn_end", "")) != "manual":
			errors.append("flow.turn_end must be 'manual'.")

	var player_ids: Dictionary = {}
	var players: Variant = data.get("players")
	if not players is Array or players.is_empty():
		errors.append("players must be a non-empty array.")
	else:
		for index in players.size():
			var player: Variant = players[index]
			if not player is Dictionary:
				errors.append("players[%d] must be an object." % index)
				continue
			var player_id := str(player.get("id", ""))
			if player_id.is_empty():
				errors.append("players[%d].id is required." % index)
			elif player_ids.has(player_id):
				errors.append("Duplicate player id '%s'." % player_id)
			else:
				player_ids[player_id] = true
			var area: Variant = player.get("area", {})
			if area is Dictionary and not area.is_empty():
				_validate_component_reference(area, "players[%d].area" % index, errors)

	var setup: Variant = data.get("setup", {})
	if setup is Dictionary:
		var objects: Variant = setup.get("objects", [])
		if objects is Array:
			var object_ids: Dictionary = {}
			for index in objects.size():
				var object_def: Variant = objects[index]
				if not object_def is Dictionary:
					errors.append("setup.objects[%d] must be an object." % index)
					continue
				var object_id := str(object_def.get("id", ""))
				if object_id.is_empty():
					errors.append("setup.objects[%d].id is required." % index)
				elif object_ids.has(object_id):
					errors.append("Duplicate object id '%s'." % object_id)
				else:
					object_ids[object_id] = true
				_validate_component_reference(object_def, "setup.objects[%d]" % index, errors)
				var owner_id := str(object_def.get("owner_id", ""))
				if not owner_id.is_empty() and not player_ids.has(owner_id):
					errors.append(
						(
							"setup.objects[%d].owner_id references unknown player '%s'."
							% [index, owner_id]
						)
					)
				var quantity := int(object_def.get("quantity", 1))
				if quantity < 0:
					errors.append("setup.objects[%d].quantity must be >= 0." % index)
				var location: Variant = object_def.get("initial_location")
				if not location is Dictionary or str(location.get("type", "")).is_empty():
					errors.append("setup.objects[%d].initial_location is required." % index)

	var listeners: Variant = data.get("listeners", [])
	if not listeners is Array:
		errors.append("listeners must be an array.")
	else:
		var router := GameEventRouter.new()
		errors.append_array(router.configure(listeners))

	return errors


static func _validate_component_reference(
	definition: Dictionary, label: String, errors: Array[String]
) -> void:
	var component_id := str(definition.get("component", ""))
	if component_id.is_empty():
		errors.append("%s.component is required." % label)
		return
	if not BgoComponentRegistry.has_component(component_id):
		errors.append("%s.component references unknown component '%s'." % [label, component_id])
		return
	var config: Variant = definition.get("config", {})
	if not config is Dictionary:
		errors.append("%s.config must be an object." % label)
		return
	for component_error in BgoComponentRegistry.validate_config(component_id, config):
		errors.append("%s: %s" % [label, component_error])


static func _validate_table(table: Dictionary, errors: Array[String]) -> void:
	if float(table.get("width", 0.0)) <= 0.0 or float(table.get("depth", 0.0)) <= 0.0:
		errors.append("table.width and table.depth must be positive.")
	var areas: Variant = table.get("areas", [])
	if not areas is Array:
		errors.append("table.areas must be an array.")
		return
	var ids: Dictionary = {}
	for index in areas.size():
		var area: Variant = areas[index]
		if not area is Dictionary:
			errors.append("table.areas[%d] must be an object." % index)
			continue
		var area_id := str(area.get("id", ""))
		if area_id.is_empty() or ids.has(area_id):
			errors.append("table.areas[%d].id must be unique and non-empty." % index)
		else:
			ids[area_id] = true
		var mode := str(area.get("placement_mode", "free_or_slot"))
		if mode not in ["free", "slots_only", "free_or_slot"]:
			errors.append("table.areas[%d].placement_mode is invalid." % index)
		var bounds: Variant = area.get("bounds")
		if not bounds is Dictionary:
			errors.append("table.areas[%d].bounds is required." % index)
			continue
		var size: Variant = bounds.get("size")
		if (
			not size is Dictionary
			or float(size.get("x", 0.0)) <= 0.0
			or float(size.get("z", 0.0)) <= 0.0
		):
			errors.append("table.areas[%d].bounds.size must be positive." % index)
