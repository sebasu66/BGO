extends RefCounted

const MCP_API = preload("res://src/mcp/mcp_game_api.gd")
const MCP_POLICY = preload("res://src/mcp/mcp_prototype_access_policy.gd")


static func run(check: Callable) -> void:
	var session := SessionState.create_lobby("TEST001", "host")
	session.assign_participant("host", "seat-1", "player")
	session.assign_participant("player_2", "seat-2", "player")
	session.start_session("host")
	var tabletop := TabletopState.new()
	tabletop.configure_grid(8, 6, Vector2(5.0, 5.0))
	var gameplay := GameplayState.create(session, tabletop)
	var definition := {
		"game": {"id": "test001"},
		"sandbox":
		{
			"enabled": true,
			"component_catalog":
			[
				{
					"id": "basic-miniature",
					"component": "bgo.piece.basic_cylinder",
					"default_config": {"radius": 0.38, "height": 0.32},
				}
			],
		},
	}
	var api: Variant = MCP_API.create(gameplay, definition)
	var host := MCP_POLICY.bind_context("TEST001", "host", "host")
	var player := MCP_POLICY.bind_context("TEST001", "player_2", "player")

	var created: Dictionary = api.create_object_at_point(
		host, "basic-miniature", "mcp-mini-1", 5, 2, "player_2"
	)
	check.call(
		bool(created.get("ok", false)), "MCP host creates a catalog object at grid point 5,2"
	)
	var at_point: Dictionary = api.objects_at_point(player, 5, 2)
	check.call(
		(at_point.get("object_ids", []) as Array).has("mcp-mini-1"),
		"MCP point query finds the created miniature"
	)
	var inspected: Dictionary = api.inspect_object(player, "mcp-mini-1")
	var inspected_object: Dictionary = inspected.get("object", {})
	var inspected_grid: Dictionary = inspected_object.get("grid", {})
	var inspected_origin: Dictionary = inspected_grid.get("origin", {})
	check.call(
		int(inspected_origin.get("x", -1)) == 5 and int(inspected_origin.get("y", -1)) == 2,
		"MCP inverse object query exposes grid origin"
	)
	var moved: Dictionary = api.move_object_to_point(host, "mcp-mini-1", 3, 4)
	check.call(bool(moved.get("ok", false)), "MCP host moves an object by logical grid point")
	var moved_point: Dictionary = api.objects_at_point(host, 3, 4)
	check.call(
		(moved_point.get("object_ids", []) as Array).has("mcp-mini-1"),
		"MCP grid query reflects the validated move"
	)
	var denied: Dictionary = api.create_object_at_point(
		player, "basic-miniature", "forbidden-mini", 1, 1, "player_2"
	)
	check.call(not bool(denied.get("ok", false)), "MCP non-host cannot create sandbox objects")
	var grid_state: Dictionary = api.get_grid_state(host)
	check.call(
		bool(grid_state.get("ok", false)) and (grid_state.get("objects", []) as Array).size() == 1,
		"MCP exposes complete logical grid state"
	)

	var entities: Dictionary = api.get_entities(player)
	var entity_list: Array = entities.get("entities", [])
	var found_entity := false
	for entity_variant in entity_list:
		var entity: Dictionary = entity_variant
		if str(entity.get("entity", "")) == "Match.objects.mcp-mini-1":
			found_entity = true
			break
	check.call(
		found_entity,
		"MCP discovers visible entities through canonical Match.objects paths"
	)
	var properties: Dictionary = api.get_properties(player, "Match.objects.mcp-mini-1")
	var property_schema: Dictionary = properties.get("schema", {})
	check.call(
		bool((property_schema.get("configuration", {}) as Dictionary).get("writable", false)),
		"MCP property schema declares owner-writable configuration"
	)
	var changed: Dictionary = api.set_properties(
		player, "Match.objects.mcp-mini-1", {"visibility": "owner_only"}
	)
	check.call(bool(changed.get("ok", false)), "MCP owner changes a declared safe property")
	var forbidden: Dictionary = api.set_properties(
		player, "Match.objects.mcp-mini-1", {"ownerId": "host"}
	)
	check.call(
		str(forbidden.get("reason", "")).begins_with("property_not_writable"),
		"MCP owner cannot change a host-only property"
	)
	var executed: Dictionary = api.execute(
		host,
		"Match.objects.mcp-mini-1",
		"moveToPoint",
		{"x": 2, "y": 1}
	)
	check.call(bool(executed.get("ok", false)), "MCP executes a registered entity command")
	var arbitrary: Dictionary = api.execute(
		host, "Match.objects.mcp-mini-1", "callGodotMethod", {"method": "queue_free"}
	)
	check.call(
		str(arbitrary.get("reason", "")) == "command_not_allowed",
		"MCP rejects arbitrary method execution"
	)
