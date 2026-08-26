extends RefCounted

const PROCESSOR = preload("res://src/mcp/mcp_command_processor.gd")


static func run(check: Callable) -> void:
	var definition := {
		"table":
		{
			"instances":
			[
				{
					"id": "main_board",
					"component": "bgo.board.checkered",
					"config": {"columns": 8, "rows": 6, "cell_size": 1.2, "grid_cell_size_cm": 5.0, "grid_points_per_unit": 5, "grid_virtual_infinite": true},
				}
			]
		},
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
	var session := {
		"session_id": "TEST001",
		"turn_number": 3,
		"active_participant_id": "host",
		"pieces":
		{
			"existing":
			{
				"component_id": "bgo.piece.basic_cylinder",
				"object_config": {"radius": 0.38, "height": 0.32},
				"owner_id": "player_2",
				"quantity": 1,
				"cell": {"x": 1, "y": 2},
				"location": {"type": "slot", "slot_id": "board:1:2"},
			}
		}
	}
	var processor: Variant = PROCESSOR.new()
	var context := {
		"session_id": "TEST001",
		"participant_id": "host",
		"role": "host",
	}
	var instructions: Dictionary = processor.process(
		{
			"tool": "bgo_query",
			"context": context,
			"arguments": {"operation": "instructions"},
		},
		session,
		definition
	)
	check.call(
		bool(instructions.get("ok", false))
		and str(instructions.get("canonical", "")) == "System.instructions",
		"read-only API query exposes a single LLM bootstrap entry"
	)
	check.call(
		(instructions.get("recommended_flow", []) as Array).has(
			"Call System.api.getEntities to discover stable logical entities."
		),
		"bootstrap instructions explain the discovery sequence"
	)
	var entities: Dictionary = processor.process(
		{
			"tool": "bgo_query",
			"context": context,
			"arguments": {"operation": "getEntities"},
		},
		session,
		definition
	)
	var entity_names: Array[String] = []
	for descriptor_variant in entities.get("entities", []):
		var descriptor: Dictionary = descriptor_variant
		entity_names.append(str(descriptor.get("entity", "")))
	check.call(
		entity_names.has("Game.table.instances.main_board"),
		"API discovery exposes declarative table instances"
	)
	var described: Dictionary = processor.process(
		{
			"tool": "bgo_query",
			"context": context,
			"arguments": {
				"operation": "describe",
				"target": "Game.table.instances.main_board.configuration.rows",
			},
		},
		session,
		definition
	)
	check.call(
		bool(described.get("ok", false))
		and str(described.get("kind", "")) == "property"
		and int(described.get("current_value", 0)) == 6,
		"describe resolves a manifest-backed configuration property"
	)
	var view: Dictionary = processor.process(
		{
			"tool": "bgo_query",
			"context": context,
			"arguments": {"operation": "getView", "detail": "compact"},
		},
		session,
		definition
	)
	check.call(
		bool(view.get("ok", false))
		and int(((view.get("table", {}) as Dictionary).get("board", {}) as Dictionary).get("rows", 0)) == 6
		and (view.get("objects", []) as Array).size() == 1,
		"Match.getView returns a compact semantic board/object projection"
	)
	var player_context := context.duplicate(true)
	player_context["participant_id"] = "player_2"
	player_context["role"] = "player"
	var player_query: Dictionary = processor.process(
		{
			"tool": "bgo_query",
			"context": player_context,
			"arguments": {"operation": "getMethods", "entity": "Match.objects.existing"},
		},
		session,
		definition
	)
	check.call(
		bool(player_query.get("ok", false)),
		"read-only discovery queries do not require host authority"
	)

	var created: Dictionary = (
		processor
		. process(
			{
				"tool": "bgo_create_object_at_point",
				"context": context,
				"arguments":
				{
					"catalog_id": "basic-miniature",
					"object_id": "new-mini",
					"x": 5,
					"y": 2,
				},
			},
			session,
			definition
		)
	)
	var created_state: Dictionary = created.get("piece_state", {})
	check.call(bool(created.get("ok", false)), "MCP command processor creates through domain API")
	check.call(
		created_state.get("cell", {}) == {"x": 5, "y": 2},
		"MCP create result returns a Firebase-compatible logical point"
	)

	var moved: Dictionary = (
		processor
		. process(
			{
				"tool": "bgo_move_object_to_point",
				"context": context,
				"arguments": {"object_id": "existing", "x": 4, "y": 3},
			},
			session,
			definition
		)
	)
	var moved_state: Dictionary = moved.get("piece_state", {})
	check.call(bool(moved.get("ok", false)), "MCP host command moves another owner's object")
	check.call(
		moved_state.get("cell", {}) == {"x": 4, "y": 3},
		"MCP move result preserves inverse grid coordinates"
	)

	var changed: Dictionary = processor.process(
		{
			"tool": "bgo_set_properties",
			"context": context,
			"arguments":
			{
				"entity": "Match.objects.existing",
				"changes": {"visibility": "owner_only"},
			},
		},
		session,
		definition
	)
	check.call(
		bool(changed.get("ok", false))
		and str((changed.get("piece_state", {}) as Dictionary).get("visibility", ""))
		== "owner_only",
		"MCP processor persists generic validated properties"
	)
	var board_changed: Dictionary = processor.process(
		{
			"tool": "bgo_set_properties",
			"context": context,
			"arguments": {
				"entity": "Game.table.instances.main_board",
				"changes": {"configuration": {"rows": 8}},
			},
		},
		session,
		definition
	)
	check.call(
		bool(board_changed.get("ok", false))
		and not board_changed.has("piece_id")
		and int(((board_changed.get("definition_update", {}) as Dictionary).get("table", {}) as Dictionary).get("instances", [])[0].get("config", {}).get("rows", 0)) == 8,
		"MCP processor returns a definition update for Game authoring"
	)

	var executed: Dictionary = processor.process(
		{
			"tool": "bgo_execute",
			"context": context,
			"arguments":
			{
				"entity": "Match.objects.existing",
				"command": "changeOwner",
				"arguments": {"ownerId": "host"},
			},
		},
		session,
		definition
	)
	check.call(
		bool(executed.get("ok", false))
		and str((executed.get("piece_state", {}) as Dictionary).get("owner_id", "")) == "host",
		"MCP processor executes a registered entity command"
	)

	var denied_context := context.duplicate(true)
	denied_context["role"] = "player"
	var denied: Dictionary = (
		processor
		. process(
			{
				"tool": "bgo_move_object_to_point",
				"context": denied_context,
				"arguments": {"object_id": "existing", "x": 2, "y": 2},
			},
			session,
			definition
		)
	)
	check.call(
		str(denied.get("reason", "")) == "host_required",
		"MCP command processor rejects non-host mutation contexts"
	)
