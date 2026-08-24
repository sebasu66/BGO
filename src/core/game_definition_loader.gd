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
	# Migrate the early named-schema package form without mutating source files.
	# Loaded snapshots always expose the canonical numeric version to consumers.
	if not data.has("schema_version") and str(data.get("schema", "")) == "bgo.game":
		data["schema_version"] = 1
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
	if int(data.get("schema_version", 0)) != 1:
		errors.append("schema_version must be 1.")

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

	var board_columns := 0
	var board_rows := 0
	var board: Variant = _validate_table_instances(data.get("table", {}), errors)
	if not board is Dictionary or board.is_empty():
		board = data.get("board")
	if not board is Dictionary:
		errors.append("A board component is required in table.instances.")
	else:
		if data.has("board"):
			_validate_component_reference(board, "board", errors)
		var board_config: Variant = board.get("config", {})
		if board_config is Dictionary:
			board_columns = int(board_config.get("columns", 0))
			board_rows = int(board_config.get("rows", 0))

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

	var occupied_initial_slots: Dictionary = {}
	var occupied_asset_box_points: Dictionary = {}
	var asset_box_id := ""
	var asset_box_columns := 0
	var asset_box_rows := 0
	var setup: Variant = data.get("setup", {})
	if setup is Dictionary:
		var asset_box: Variant = setup.get("asset_box", {})
		if asset_box is Dictionary and not asset_box.is_empty():
			asset_box_id = str(asset_box.get("id", "box"))
			asset_box_columns = int(asset_box.get("point_columns", 0))
			asset_box_rows = int(asset_box.get("point_rows", 0))
			_validate_asset_box(asset_box, "setup.asset_box", errors)
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
				_validate_quantity_policy(object_def, index, errors)
				_validate_initial_location(
					object_def,
					index,
					board_columns,
					board_rows,
					occupied_initial_slots,
					asset_box_id,
					asset_box_columns,
					asset_box_rows,
					occupied_asset_box_points,
					errors
				)

	return errors


static func _validate_table_instances(table_value: Variant, errors: Array[String]) -> Dictionary:
	if not table_value is Dictionary:
		errors.append("table must be an object.")
		return {}
	var instances_value: Variant = table_value.get("instances", [])
	if not instances_value is Array or instances_value.is_empty():
		return {}
	var instance_ids: Dictionary = {}
	var board: Dictionary = {}
	for index in instances_value.size():
		var instance_value: Variant = instances_value[index]
		if not instance_value is Dictionary:
			errors.append("table.instances[%d] must be an object." % index)
			continue
		var instance: Dictionary = instance_value
		var instance_id := str(instance.get("id", ""))
		if instance_id.is_empty():
			errors.append("table.instances[%d].id is required." % index)
		elif instance_ids.has(instance_id):
			errors.append("Duplicate table instance id '%s'." % instance_id)
		else:
			instance_ids[instance_id] = true
		_validate_component_reference(instance, "table.instances[%d]" % index, errors)
		_validate_placement(instance.get("placement", {}), index, errors)
		var component_id := str(instance.get("component", ""))
		if BgoComponentRegistry.get_kind(component_id) == "board":
			if not board.is_empty():
				errors.append("table.instances currently supports one primary board.")
			else:
				board = instance
	return board


static func _validate_placement(value: Variant, index: int, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("table.instances[%d].placement must be an object." % index)
		return
	for key in ["position", "rotation_degrees", "scale"]:
		if value.has(key) and not _is_vector3(value[key]):
			errors.append("table.instances[%d].placement.%s must be a 3D vector." % [index, key])


static func _is_vector3(value: Variant) -> bool:
	if value is Array:
		return value.size() == 3
	if value is Dictionary:
		return value.has("x") and value.has("y") and value.has("z")
	return false


static func _validate_initial_location(
	object_def: Dictionary,
	index: int,
	columns: int,
	rows: int,
	occupied: Dictionary,
	asset_box_id: String,
	asset_box_columns: int,
	asset_box_rows: int,
	occupied_asset_box_points: Dictionary,
	errors: Array[String]
) -> void:
	var location: Variant = object_def.get("initial_location", {})
	if not location is Dictionary:
		errors.append("setup.objects[%d].initial_location must be an object." % index)
		return
	var location_type := str(location.get("type", ""))
	if location_type == "asset_box":
		_validate_asset_box_location(
			location,
			index,
			asset_box_id,
			asset_box_columns,
			asset_box_rows,
			occupied_asset_box_points,
			errors
		)
		return
	if location_type != "slot":
		errors.append("setup.objects[%d].initial_location.type must currently be 'slot'." % index)
		return
	var slot_id := str(location.get("slot_id", ""))
	var parts := slot_id.split(":")
	if parts.size() != 3 or parts[0] != "board":
		errors.append(
			"setup.objects[%d] has invalid board slot '%s'. Expected board:x:y." % [index, slot_id]
		)
		return
	var x := int(parts[1])
	var y := int(parts[2])
	if x < 0 or y < 0 or x >= columns or y >= rows:
		errors.append(
			"setup.objects[%d] slot '%s' is outside the configured board." % [index, slot_id]
		)
		return
	if occupied.has(slot_id):
		errors.append(
			"Initial slot '%s' is already occupied by '%s'." % [slot_id, str(occupied[slot_id])]
		)
	else:
		occupied[slot_id] = str(object_def.get("id", "unnamed"))


static func _validate_asset_box(
	asset_box: Dictionary, label: String, errors: Array[String]
) -> void:
	var box_id := str(asset_box.get("id", ""))
	if box_id.is_empty():
		errors.append("%s.id is required." % label)


static func _validate_asset_box_location(
	location: Dictionary,
	index: int,
	asset_box_id: String,
	columns: int,
	rows: int,
	occupied: Dictionary,
	errors: Array[String]
) -> void:
	if asset_box_id.is_empty():
		errors.append(
			"setup.objects[%d] uses asset_box but setup.asset_box is missing or invalid." % index
		)
		return
	var location_box_id := str(location.get("box_id", asset_box_id))
	if location_box_id != asset_box_id:
		errors.append(
			"setup.objects[%d] references unknown asset box '%s'." % [index, location_box_id]
		)
		return
	# Legacy origin/footprint values are accepted for schema compatibility but
	# do not define runtime box state. Asset Placer owns catalog layout.


static func _validate_quantity_policy(
	object_def: Dictionary, index: int, errors: Array[String]
) -> void:
	var raw_value: Variant = object_def.get(
		"qty_available", object_def.get("QtyAvailable", object_def.get("availability", "unique"))
	)
	var policy := str(raw_value).to_lower()
	if policy in ["unico", "one", "1"]:
		policy = "unique"
	elif policy in ["1-n", "finite", "limited"]:
		policy = "finite"
	elif policy in ["infinito", "unlimited"]:
		policy = "infinite"
	if policy not in ["unique", "finite", "infinite"]:
		errors.append(
			"setup.objects[%d].qty_available must be unique, finite or infinite." % index
		)
		return
	var quantity := int(object_def.get("quantity", 1))
	if quantity < 1:
		errors.append("setup.objects[%d].quantity must be at least 1." % index)
	if policy == "unique" and quantity != 1:
		errors.append("setup.objects[%d] with qty_available=unique must have quantity 1." % index)


static func _read_point(value: Variant) -> Vector2i:
	if value is Dictionary:
		return Vector2i(int(value.get("x", -1)), int(value.get("y", -1)))
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


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
