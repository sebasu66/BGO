class_name BgoBuilderRegistry
extends RefCounted
# gdlint: disable=max-returns

const TYPES := [
	"Game",
	"Table",
	"Player",
	"CheckeredBoard",
	"PlayerArea",
	"CatalogEntry",
	"AssetBox",
	"BasicCylinder"
]
const METHODS := {
	"Game":
	[
		"setId",
		"setName",
		"setSchemaVersion",
		"setMinPlayers",
		"setMaxPlayers",
		"setPlayerCount",
		"setPlayerRange",
		"setTurnBased",
		"setTable",
		"addPlayer",
		"setSandboxEnabled",
		"addCatalogEntry",
		"setAssetBox",
		"addObject",
		"getDefinition",
		"getJson",
		"getWarnings",
		"validate",
		"isValid",
		"build",
		"saveAs",
		"migrateToCurrent"
	],
	"Table": ["setWidth", "setDepth", "addComponent", "getWarnings"],
	"Player":
	[
		"setId",
		"setName",
		"setColor",
		"setSeat",
		"setPosition",
		"setRotation",
		"setPresenceComponent",
		"setHandVisibility",
		"getWarnings"
	],
	"CheckeredBoard":
	[
		"setId",
		"setColumns",
		"setRows",
		"setCellSize",
		"setGridCellSizeCm",
		"setGridPointsPerUnit",
		"setGridVirtualInfinite",
		"setPosition",
		"setRotation",
		"getWarnings"
	],
	"PlayerArea":
	[
		"setId",
		"setPlayer",
		"setLabel",
		"setColor",
		"setSize",
		"setPosition",
		"setRotation",
		"setPublicObjects",
		"getWarnings"
	],
	"CatalogEntry": ["setId", "setComponent", "setRadius", "setHeight", "getWarnings"],
	"AssetBox": ["setId", "setLabel", "getWarnings"],
	"BasicCylinder":
	[
		"setId",
		"setOwner",
		"setQuantity",
		"setAvailability",
		"setColorSource",
		"setColor",
		"setInitialSlot",
		"setAssetBox",
		"getWarnings"
	],
}

var current_game: BgoDefinitionBuilder


func create(type_name: String) -> BgoDefinitionBuilder:
	if type_name not in TYPES:
		return null
	var builder := BgoDefinitionBuilder.new(type_name, self)
	if type_name == "Game":
		builder.values = {
			"schema_version": 1,
			"min_players": 2,
			"max_players": 2,
			"turn_based": true,
			"sandbox_enabled": false
		}
		current_game = builder
	return builder


func from_definition(definition: Dictionary) -> BgoDefinitionBuilder:
	var builder := create("Game")
	builder.values["source_definition"] = definition.duplicate(true)
	return builder


func get_types() -> PackedStringArray:
	return PackedStringArray(TYPES)


func get_public_types() -> PackedStringArray:
	var result := PackedStringArray(["Game"])
	for type_name in TYPES:
		if type_name != "Game":
			result.append("Game.%s" % type_name)
	return result


func describe(type_name: String) -> Dictionary:
	return {
		"type": "Game" if type_name == "Game" else "Game.%s" % type_name,
		"factories":
		(
			["Game.create()", "Game.current()", "Game.load(path)"]
			if type_name == "Game"
			else ["Game.%s.create()" % type_name]
		),
		"methods": METHODS.get(type_name, [])
	}


func has_method_for(type_name: String, method_name: String) -> bool:
	return method_name in METHODS.get(type_name, [])


func invoke(builder: BgoDefinitionBuilder, method_name: String, args: Array) -> Dictionary:
	if not has_method_for(builder.type_name, method_name):
		return {
			"ok": false,
			"error":
			(
				"%s has no public method %s. Available: %s"
				% [builder.type_name, method_name, ", ".join(METHODS.get(builder.type_name, []))]
			)
		}
	if (
		method_name
		in [
			"getDefinition",
			"getJson",
			"getWarnings",
			"validate",
			"isValid",
			"build",
			"saveAs",
			"migrateToCurrent"
		]
	):
		return _invoke_terminal(builder, method_name, args)
	var error := _apply_setter(builder, method_name, args)
	return {"ok": error.is_empty(), "value": builder, "error": error}


func _invoke_terminal(
	builder: BgoDefinitionBuilder, method_name: String, args: Array
) -> Dictionary:
	match method_name:
		"getDefinition":
			return {"ok": true, "value": builder.getDefinition()}
		"getJson":
			return {"ok": true, "value": builder.getJson()}
		"getWarnings":
			return {"ok": true, "value": builder.getWarnings()}
		"validate":
			return {"ok": true, "value": builder.validate()}
		"isValid":
			return {"ok": true, "value": builder.isValid()}
		"build":
			return {"ok": true, "value": builder.build()}
		"saveAs":
			if args.size() != 1:
				return {"ok": false, "error": "saveAs(path) expects one argument."}
			return {"ok": true, "value": builder.saveAs(str(args[0]))}
		"migrateToCurrent":
			return {"ok": true, "value": builder.migrateToCurrent()}
	return {"ok": false, "error": "Unsupported terminal."}


func _apply_setter(builder: BgoDefinitionBuilder, method_name: String, args: Array) -> String:
	if method_name in ["setPosition", "setRotation", "setSize", "setPlayerRange"]:
		return _apply_multi(builder, method_name, args)
	if (
		method_name
		in [
			"setTable",
			"addPlayer",
			"addCatalogEntry",
			"setAssetBox",
			"addObject",
			"addComponent",
			"setPlayer",
			"setOwner"
		]
	):
		if args.size() != 1:
			return "%s expects one builder or id." % method_name
		if method_name.begins_with("add"):
			var collection: Array = builder.children.get(method_name, [])
			collection.append(args[0])
			builder.children[method_name] = collection
		else:
			builder.children[method_name] = args[0]
		return ""
	if args.size() != 1:
		return "%s expects one argument." % method_name
	var keys := {
		"setId": "id",
		"setName": "name",
		"setSchemaVersion": "schema_version",
		"setMinPlayers": "min_players",
		"setMaxPlayers": "max_players",
		"setPlayerCount": "player_count",
		"setTurnBased": "turn_based",
		"setSandboxEnabled": "sandbox_enabled",
		"setWidth": "width",
		"setDepth": "depth",
		"setColor": "color",
		"setSeat": "seat",
		"setPresenceComponent": "presence_component",
		"setHandVisibility": "hand_visibility",
		"setColumns": "columns",
		"setRows": "rows",
		"setCellSize": "cell_size",
		"setGridCellSizeCm": "grid_cell_size_cm",
		"setGridPointsPerUnit": "grid_points_per_unit",
		"setGridVirtualInfinite": "grid_virtual_infinite",
		"setLabel": "label",
		"setPublicObjects": "public_objects",
		"setComponent": "component",
		"setRadius": "radius",
		"setHeight": "height",
		"setQuantity": "quantity",
		"setAvailability": "availability",
		"setColorSource": "color_source",
		"setInitialSlot": "initial_slot"
	}
	var key := str(keys.get(method_name, ""))
	if key.is_empty():
		return "Unsupported setter %s." % method_name
	var value: Variant = args[0]
	if key in ["width", "depth", "cell_size", "grid_cell_size_cm", "radius", "height"]:
		value = _decimal(builder, key, float(value))
	if (
		key
		in [
			"schema_version",
			"min_players",
			"max_players",
			"player_count",
			"seat",
			"columns",
			"rows",
			"grid_points_per_unit",
			"quantity"
		]
	):
		value = roundi(float(value))
	builder.values[key] = value
	if key == "player_count":
		builder.values["min_players"] = value
		builder.values["max_players"] = value
	return ""


func _apply_multi(builder: BgoDefinitionBuilder, method_name: String, args: Array) -> String:
	if method_name == "setPlayerRange" and args.size() == 2:
		builder.values["min_players"] = roundi(float(args[0]))
		builder.values["max_players"] = roundi(float(args[1]))
		return ""
	if method_name == "setPosition" and args.size() in [2, 3]:
		var y: Variant = args[1] if args.size() == 3 else 0
		var z: Variant = args[2] if args.size() == 3 else args[1]
		var original := Vector3(float(args[0]), float(y), float(z))
		var rounded := {"x": roundi(original.x), "y": roundi(original.y), "z": roundi(original.z)}
		if original != Vector3(rounded.x, rounded.y, rounded.z):
			builder.warnings.append("position rounded from %s to %s" % [original, rounded])
		builder.values["position"] = rounded
		return ""
	if method_name == "setRotation" and args.size() in [1, 3]:
		var vector := (
			Vector3(0, float(args[0]), 0)
			if args.size() == 1
			else Vector3(float(args[0]), float(args[1]), float(args[2]))
		)
		builder.values["rotation"] = {
			"x": posmod(roundi(vector.x), 360),
			"y": posmod(roundi(vector.y), 360),
			"z": posmod(roundi(vector.z), 360)
		}
		return ""
	if method_name == "setSize" and args.size() == 3:
		builder.values["size"] = {
			"x": _decimal(builder, "size.x", float(args[0])),
			"y": _decimal(builder, "size.y", float(args[1])),
			"z": _decimal(builder, "size.z", float(args[2]))
		}
		return ""
	return "%s received invalid arguments." % method_name


func _decimal(builder: BgoDefinitionBuilder, label: String, value: float) -> float:
	var rounded := snappedf(value, 0.001)
	if not is_equal_approx(value, rounded):
		builder.warnings.append("%s rounded from %s to %s" % [label, value, rounded])
	return rounded


func build(game: BgoDefinitionBuilder) -> Dictionary:
	if game.type_name != "Game":
		return {}
	if game.values.has("source_definition"):
		return _canonicalize(game.values["source_definition"])
	var player_builders: Array = game.children.get("addPlayer", [])
	var players: Array = []
	for index in player_builders.size():
		players.append(_build_player(player_builders[index], index, player_builders.size()))
	var table_builder: BgoDefinitionBuilder = game.children.get("setTable")
	var table := _build_table(table_builder, player_builders, players)
	var result := {
		"schema_version": int(game.values.get("schema_version", 1)),
		"game":
		{
			"id": str(game.values.get("id", "game_1")),
			"name": str(game.values.get("name", "Untitled Game")),
			"min_players":
			int(
				game.values.get(
					"min_players", game.values.get("player_count", maxi(players.size(), 1))
				)
			),
			"max_players":
			int(
				game.values.get(
					"max_players", game.values.get("player_count", maxi(players.size(), 1))
				)
			),
			"turn_based": bool(game.values.get("turn_based", true))
		},
		"table": table,
		"players": players,
		"sandbox":
		{"enabled": bool(game.values.get("sandbox_enabled", false)), "component_catalog": []},
		"setup": {"objects": []}
	}
	for index in (game.children.get("addCatalogEntry", []) as Array).size():
		result.sandbox.component_catalog.append(
			_build_catalog(game.children["addCatalogEntry"][index], index)
		)
	var box: Variant = game.children.get("setAssetBox")
	if box is BgoDefinitionBuilder:
		result.setup["asset_box"] = {
			"id": str(box.values.get("id", "game_box")),
			"label": str(box.values.get("label", "ASSET BOX"))
		}
	for index in (game.children.get("addObject", []) as Array).size():
		result.setup.objects.append(
			_build_object(
				game.children["addObject"][index], index, result.setup.get("asset_box", {})
			)
		)
	return result


func _build_player(builder: BgoDefinitionBuilder, index: int, count: int) -> Dictionary:
	var player_id := str(builder.values.get("id", "player_%d" % (index + 1)))
	builder.values["resolved_id"] = player_id
	var colors := ["#E34850", "#4DB7F2", "#54B66A", "#F2B837"]
	return {
		"id": player_id,
		"name": str(builder.values.get("name", "Player %d" % (index + 1))),
		"color": str(builder.values.get("color", colors[index % colors.size()])),
		"presence":
		{
			"component":
			str(builder.values.get("presence_component", "bgo.player_presence.basic_mask")),
			"config": {}
		},
		"hand":
		{"visibility": str(builder.values.get("hand_visibility", "owner_face_others_hidden"))},
		"seat": int(builder.values.get("seat", index + 1)) if count > 0 else 1
	}


func _build_table(
	builder: BgoDefinitionBuilder, player_builders: Array, players: Array
) -> Dictionary:
	if builder == null:
		builder = create("Table")
	var instances: Array = []
	for index in (builder.children.get("addComponent", []) as Array).size():
		instances.append(_build_component(builder.children["addComponent"][index], index))
	var explicit_player_areas: Dictionary = {}
	for instance in instances:
		if instance is Dictionary and str(instance.get("component", "")) == "bgo.player_area.basic":
			explicit_player_areas[str(instance.get("config", {}).get("player_id", ""))] = true
	for index in players.size():
		var player: Dictionary = players[index]
		if explicit_player_areas.has(str(player.id)):
			continue
		var player_builder: BgoDefinitionBuilder = player_builders[index]
		var x := -6 if index == 0 else 6 if index == 1 else (index - 1) * 4
		var rotation := 90 if index == 0 else 270 if index == 1 else 0
		instances.append(
			{
				"id": "%s_area" % player.id,
				"component": "bgo.player_area.basic",
				"config":
				{
					"player_id": player.id,
					"label_text": str(player.name).to_upper(),
					"area_color": player.color,
					"area_size": {"x": 2.0, "y": 0.1, "z": 7.0},
					"public_objects": true
				},
				"placement":
				{
					"position": player_builder.values.get("position", {"x": x, "y": 0, "z": 0}),
					"rotation_degrees":
					player_builder.values.get("rotation", {"x": 0, "y": rotation, "z": 0})
				}
			}
		)
	return {
		"width": float(builder.values.get("width", 15.5)),
		"depth": float(builder.values.get("depth", 9.8)),
		"instances": instances
	}


func _build_component(builder: BgoDefinitionBuilder, index: int) -> Dictionary:
	if builder.type_name == "CheckeredBoard":
		return {
			"id":
			str(builder.values.get("id", "main_board" if index == 0 else "board_%d" % (index + 1))),
			"component": "bgo.board.checkered",
			"config":
			{
				"columns": int(builder.values.get("columns", 8)),
				"rows": int(builder.values.get("rows", 6)),
				"cell_size": float(builder.values.get("cell_size", 1.0)),
				"grid_cell_size_cm": float(builder.values.get("grid_cell_size_cm", 1.0)),
				"grid_points_per_unit": int(builder.values.get("grid_points_per_unit", 1)),
				"grid_virtual_infinite": bool(builder.values.get("grid_virtual_infinite", false))
			},
			"placement":
			{
				"position": builder.values.get("position", {"x": 0, "y": 0, "z": 0}),
				"rotation_degrees": builder.values.get("rotation", {"x": 0, "y": 0, "z": 0})
			}
		}
	var player_ref: Variant = builder.children.get("setPlayer", "")
	var player_id := _reference_id(player_ref)
	return {
		"id": str(builder.values.get("id", "%s_area" % player_id)),
		"component": "bgo.player_area.basic",
		"config":
		{
			"player_id": player_id,
			"label_text": str(builder.values.get("label", player_id)).to_upper(),
			"area_color": str(builder.values.get("color", "#666666")),
			"area_size": builder.values.get("size", {"x": 2.0, "y": 0.1, "z": 7.0}),
			"public_objects": bool(builder.values.get("public_objects", true))
		},
		"placement":
		{
			"position": builder.values.get("position", {"x": 0, "y": 0, "z": 0}),
			"rotation_degrees": builder.values.get("rotation", {"x": 0, "y": 0, "z": 0})
		}
	}


func _build_catalog(builder: BgoDefinitionBuilder, index: int) -> Dictionary:
	return {
		"id": str(builder.values.get("id", "catalog_%d" % (index + 1))),
		"component": str(builder.values.get("component", "bgo.piece.basic_cylinder")),
		"default_config":
		{
			"radius": float(builder.values.get("radius", 0.38)),
			"height": float(builder.values.get("height", 0.32))
		}
	}


func _build_object(builder: BgoDefinitionBuilder, index: int, box: Dictionary) -> Dictionary:
	var object := {
		"id": str(builder.values.get("id", "basic_cylinder_%d" % (index + 1))),
		"component": "bgo.piece.basic_cylinder",
		"owner_id": _reference_id(builder.children.get("setOwner", "")),
		"qty_available": str(builder.values.get("availability", "unique")),
		"quantity": int(builder.values.get("quantity", 1)),
		"config": {"color_source": str(builder.values.get("color_source", "player"))}
	}
	if builder.values.has("color"):
		object.config["color"] = builder.values.color
	if builder.values.has("initial_slot"):
		object["initial_location"] = {
			"type": "slot", "slot_id": _slot_id(builder.values.initial_slot)
		}
	else:
		object["initial_location"] = {"type": "asset_box", "box_id": str(box.get("id", "game_box"))}
	return object


func _reference_id(value: Variant) -> String:
	if value is BgoDefinitionBuilder:
		return str(value.values.get("resolved_id", value.values.get("id", "")))
	if value is int or value is float:
		return "player_%d" % roundi(float(value))
	return str(value)


func _slot_id(value: Variant) -> String:
	if value is String and str(value).begins_with("board:"):
		return value
	return "board:%s" % str(value).replace(",", ":")


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _canonicalize(value[key])
		if result.has("position") and result.position is Dictionary:
			for axis in ["x", "y", "z"]:
				result.position[axis] = roundi(float(result.position.get(axis, 0)))
		if result.has("rotation_degrees") and result.rotation_degrees is Dictionary:
			for axis in ["x", "y", "z"]:
				result.rotation_degrees[axis] = posmod(
					roundi(float(result.rotation_degrees.get(axis, 0))), 360
				)
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonicalize(item))
		return result
	if value is float:
		return snappedf(value, 0.001)
	return value
