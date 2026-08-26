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
