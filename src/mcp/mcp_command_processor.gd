class_name BgoMcpCommandProcessor
extends RefCounted
# gdlint: disable=max-returns

const MCP_GAME_API = preload("res://src/mcp/mcp_game_api.gd")
const PUBLIC_API_DISCOVERY = preload("res://src/mcp/public_api_discovery.gd")

## Converts Firebase session projections into domain state, executes one
## validated MCP command through BgoMcpGameApi, and returns a persistence patch.
## This adapter contains no rendering logic and never talks to Firebase itself.


func process(
	command: Dictionary, session_snapshot: Dictionary, game_definition: Dictionary
) -> Dictionary:
	var activity_log: Node = Engine.get_main_loop().root.get_node_or_null("BgoActivityLog") if Engine.get_main_loop() != null else null
	if activity_log != null:
		activity_log.record_invocation("System.processCommand", "mcp", command.get("context", {}))
	var context: Dictionary = command.get("context", {})
	var tool_name := str(command.get("tool", ""))
	var arguments: Dictionary = command.get("arguments", {})
	if str(context.get("participant_id", "")).is_empty():
		return _rejected("participant_required")
	if tool_name == "bgo_query":
		var discovery: BgoPublicApiDiscovery = PUBLIC_API_DISCOVERY.create(
			session_snapshot, game_definition, context
		)
		return discovery.query(str(arguments.get("operation", "instructions")), arguments)
	if str(context.get("role", "")) != "host":
		return _rejected("host_required")

	var gameplay := _restore_gameplay(session_snapshot, game_definition, context)
	if gameplay == null:
		return _rejected("invalid_session_projection")
	var api: Variant = MCP_GAME_API.create(gameplay, game_definition)
	var result: Dictionary
	match tool_name:
		"bgo_create_object_at_point":
			result = api.create_object_at_point(
				context,
				str(arguments.get("catalog_id", "")),
				str(arguments.get("object_id", "")),
				int(arguments.get("x", -1)),
				int(arguments.get("y", -1)),
				str(arguments.get("owner_id", "")),
				arguments.get("configuration", {}) as Dictionary,
				int(arguments.get("footprint_x", 1)),
				int(arguments.get("footprint_y", 1)),
				bool(arguments.get("allow_overlap", false))
			)
		"bgo_move_object_to_point":
			result = api.move_object_to_point(
				context,
				str(arguments.get("object_id", "")),
				int(arguments.get("x", -1)),
				int(arguments.get("y", -1)),
				int(arguments.get("footprint_x", 1)),
				int(arguments.get("footprint_y", 1)),
				bool(arguments.get("allow_overlap", false))
			)
		"bgo_set_properties":
			result = api.set_properties(
				context,
				str(arguments.get("entity", "")),
				arguments.get("changes", {}) as Dictionary
			)
		"bgo_execute":
			result = api.execute(
				context,
				str(arguments.get("entity", "")),
				str(arguments.get("command", "")),
				arguments.get("arguments", {}) as Dictionary
			)
		_:
			return _rejected("unsupported_mcp_command")
	if not bool(result.get("ok", false)):
		return result

	var object_id := _result_object_id(tool_name, arguments, result)
	var object: LogicalObjectState = gameplay.objects.get(object_id)
	if object == null:
		if result.has("definition_update"):
			return result
		return _rejected("command_result_missing_object")
	return {
		"ok": true,
		"event": result.get("event", {}),
		"piece_id": object_id,
		"piece_state": _serialize_piece(object),
	}


func _result_object_id(tool_name: String, arguments: Dictionary, result: Dictionary) -> String:
	if tool_name in ["bgo_create_object_at_point", "bgo_move_object_to_point"]:
		return str(arguments.get("object_id", ""))
	var entity := str(arguments.get("entity", result.get("entity", "")))
	if entity.begins_with("Match.objects."):
		return entity.trim_prefix("Match.objects.")
	if tool_name == "bgo_execute" and str(arguments.get("command", "")) == "createObjectAtPoint":
		var command_arguments: Dictionary = arguments.get("arguments", {})
		return str(command_arguments.get("objectId", ""))
	return ""


func _restore_gameplay(
	session_snapshot: Dictionary, game_definition: Dictionary, context: Dictionary
) -> GameplayState:
	var participant_id := str(context.get("participant_id", ""))
	var session := SessionState.create_lobby(
		str(context.get("session_id", "TEST001")), participant_id
	)
	if not session.assign_participant(participant_id, "host", "player"):
		return null
	if not session.start_session(participant_id):
		return null

	var tabletop := TabletopState.new()
	var grid_config := _grid_config(game_definition)
	if not tabletop.configure_grid(
		int(grid_config.get("columns", 0)),
		int(grid_config.get("rows", 0)),
		Vector2(
			float(grid_config.get("spacing_x_cm", 1.0)), float(grid_config.get("spacing_y_cm", 1.0))
		),
		bool(grid_config.get("unbounded", false))
	):
		return null
	var gameplay := GameplayState.create(session, tabletop)
	var pieces: Dictionary = session_snapshot.get("pieces", {})
	for object_id_variant in pieces:
		var object_id := str(object_id_variant)
		var piece: Dictionary = pieces[object_id_variant]
		var object := _restore_object(object_id, piece)
		gameplay.objects[object_id] = object
		var location: Dictionary = piece.get("location", {})
		if str(location.get("type", "slot")) not in ["slot", "grid"]:
			continue
		var cell: Dictionary = piece.get("cell", {})
		var origin_data: Dictionary = location.get("origin", cell)
		var origin := Vector2i(int(origin_data.get("x", -1)), int(origin_data.get("y", -1)))
		var footprint_data: Dictionary = location.get("footprint", piece.get("footprint", {}))
		var footprint := Vector2i(int(footprint_data.get("x", 1)), int(footprint_data.get("y", 1)))
		if not tabletop.place_object_at_grid(object_id, origin, footprint, true):
			return null
		if not object.set_grid_placement(origin, footprint):
			return null
	return gameplay


func _restore_object(object_id: String, piece: Dictionary) -> LogicalObjectState:
	var object := LogicalObjectState.create(object_id, str(piece.get("owner_id", "")))
	object.component_id = str(piece.get("component_id", ""))
	object.configuration = (piece.get("object_config", {}) as Dictionary).duplicate(true)
	object.quantity = int(piece.get("quantity", 1))
	object.availability_mode = str(piece.get("availability", "unique"))
	object.available_quantity = int(piece.get("available_quantity", object.quantity))
	object.holder_id = str(piece.get("holder_id", ""))
	object.visibility = str(piece.get("visibility", "public"))
	var location: Dictionary = piece.get("location", {})
	var location_type := str(location.get("type", "slot"))
	if location_type == "asset_box":
		object.set_asset_box_location(str(location.get("box_id", "box")))
	elif location_type not in ["slot", "grid"]:
		object.set_location(location_type, str(location.get("player_id", "unknown")))
	return object


func _serialize_piece(object: LogicalObjectState) -> Dictionary:
	return {
		"component_id": object.component_id,
		"object_config": object.configuration.duplicate(true),
		"owner_id": object.owner_id,
		"availability": object.availability_mode,
		"available_quantity": object.available_quantity,
		"holder_id": object.holder_id,
		"visibility": object.visibility,
		"quantity": object.quantity,
		"cell": {"x": object.grid_origin.x, "y": object.grid_origin.y},
		"footprint": {"x": object.grid_footprint.x, "y": object.grid_footprint.y},
		"location":
		{
			"type": "slot",
			"slot_id": "board:%d:%d" % [object.grid_origin.x, object.grid_origin.y],
		},
		"revision": Time.get_unix_time_from_system(),
	}


func _grid_config(game_definition: Dictionary) -> Dictionary:
	var table: Dictionary = game_definition.get("table", {})
	var instances: Array = table.get("instances", [])
	for instance_variant in instances:
		if not instance_variant is Dictionary:
			continue
		var instance: Dictionary = instance_variant
		if not str(instance.get("component", "")).begins_with("bgo.board."):
			continue
		var config: Dictionary = instance.get("config", {})
		var unit_size_cm := float(config.get("grid_cell_size_cm", 1.0))
		var points_per_unit := maxi(int(config.get("grid_points_per_unit", 1)), 1)
		var spacing := unit_size_cm / float(points_per_unit)
		return {
			"columns": int(config.get("columns", 0)) * points_per_unit,
			"rows": int(config.get("rows", 0)) * points_per_unit,
			"spacing_x_cm": spacing,
			"spacing_y_cm": spacing,
			"unbounded": bool(config.get("grid_virtual_infinite", true)),
		}
	return {}


func _rejected(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
