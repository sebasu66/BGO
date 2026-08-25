extends "res://tests/test_runner_base.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_component_registry()
	_test_capability_contracts()
	_test_component_validation()
	_test_game_definition()
	_test_debug_game_api()
	_test_declarative_component_composition()
	await _test_sequential_drop_animator()
	_test_logger_levels()
	_test_client_settings_controller()
	_test_ui_theme_profiles()
	await _test_action_strip_exclusive_modes()
	await _test_settings_panel()
	await _test_context_menu_component()
	await _test_vertical_hand_selection()
	_test_session_state_foundation()
	_test_session_turn_progression()
	_test_session_completion()
	_test_table_grid_state()
	_test_hand_state()
	_test_tabletop_state()
	_test_logical_object_state()
	_test_mcp_prototype_access_policy()
	MCP_GAME_API_TEST.run(_check)
	MCP_COMMAND_PROCESSOR_TEST.run(_check)
	GAMEPLAY_STATE_TEST.run(_check)
	await CONSOLE_COMMAND_BRIDGE_TEST.run(_check)
	FLUENT_GAME_BUILDER_TEST.run(_check)
	SANDBOX_STATE_TEST.run(_check)
	CONFORMANCE_GAME_TEST.run(_check)
	RUNTIME_SESSION_ADAPTER_TEST.run(_check)

	if failures > 0:
		printerr("BGO TESTS FAILED: %d/%d assertions failed." % [failures, assertions])
		quit(1)
		return

	print("BGO TESTS PASSED: %d assertions." % assertions)
	quit(0)


func _test_client_settings_controller() -> void:
	var scene_root := Node3D.new()
	get_root().add_child(scene_root)
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_energy = 0.8
	scene_root.add_child(key)
	var fill := OmniLight3D.new()
	fill.name = "FillLight"
	fill.light_energy = 0.4
	scene_root.add_child(fill)
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = Environment.new()
	world.environment.ambient_light_energy = 0.2
	scene_root.add_child(world)
	var debug_grid := BgoTableGrid.new()
	debug_grid.name = "DebugGrid"
	debug_grid.point_columns = 2
	debug_grid.point_rows = 2
	scene_root.add_child(debug_grid)
	var debug_model := Node3D.new()
	debug_model.name = "DebugModel"
	debug_model.set_meta("bgo_placeable", true)
	debug_model.set_meta("bgo_piece", true)
	scene_root.add_child(debug_model)
	debug_grid.virtual_infinite = true
	var controller := BgoClientSettingsController.new()
	controller.persistence_enabled = false
	scene_root.add_child(controller)
	controller.initialize(scene_root)
	_check(not bool(controller.values["visual_debug"]), "visual debug defaults to disabled")
	_check(not debug_grid.show_points, "disabled visual debug hides grid points")
	_check(controller.set_value("visual_debug", true), "visual debug setting is accepted")
	_check(debug_grid.show_points, "visual debug reveals grid points")
	var sparse_points := debug_grid.get_node_or_null("GridPoints") as MultiMeshInstance3D
	_check(
		sparse_points != null and sparse_points.multimesh.instance_count == 121,
		"infinite debug grid renders only a minimal patch around objects"
	)
	_check(
		debug_model.get_node_or_null("BgoDebugPivot") != null,
		"visual debug adds a runtime model pivot gizmo"
	)
	_check(controller.set_value("lighting_intensity", 0.5), "lighting setting is accepted")
	_check(
		int(controller.values.get("hand_pickup_mode", -1)) == 0,
		"stackable pickup defaults to one unit at a time"
	)
	_check(controller.set_value("hand_pickup_mode", 1), "whole-stack pickup setting is accepted")
	_check(
		int(controller.values["hand_pickup_mode"]) == 1,
		"whole-stack pickup setting persists in state"
	)
	_check(is_equal_approx(key.light_energy, 0.4), "lighting setting updates key light immediately")
	_check(
		is_equal_approx(fill.light_energy, 0.2), "lighting setting updates fill light immediately"
	)
	_check(
		is_equal_approx(world.environment.ambient_light_energy, 0.1),
		"lighting setting updates ambient light immediately"
	)
	_check(not controller.set_value("unknown_setting", true), "unknown client setting is rejected")
	scene_root.queue_free()


func _test_game_definition() -> void:
	var result: Dictionary = GAME_DEFINITION_LOADER.load_game("res://games/test001/game.jsonh")
	_check(bool(result.get("ok", false)), "TEST001 definition loads and validates")
	if bool(result.get("ok", false)):
		var data: Dictionary = result.get("data", {})
		_check(int(data.get("schema_version", 0)) == 1, "TEST001 schema version is supported")

	var missing: Dictionary = GAME_DEFINITION_LOADER.load_game(
		"res://games/does-not-exist/game.jsonh"
	)
	_check(not bool(missing.get("ok", false)), "missing game definition fails safely")
	_check(
		not (missing.get("errors", []) as Array).is_empty(),
		"missing game definition returns a useful error"
	)


func _test_debug_game_api() -> void:
	var loaded: Dictionary = GAME_DEFINITION_LOADER.load_game_id("table_debug")
	if not bool(loaded.get("ok", false)):
		printerr("TABLE_DEBUG validation errors: %s" % [loaded.get("errors", [])])
	_check(bool(loaded.get("ok", false)), "table-only debug scenario loads by game id")
	if not bool(loaded.get("ok", false)):
		return
	var definition: Dictionary = loaded.get("data", {})
	_check(not definition.has("board"), "table debug scenario does not require a board")
	_check(
		((definition.get("table", {}) as Dictionary).get("areas", []) as Array).size() == 4,
		"table debug scenario exposes four declarative areas",
	)
	var game_api := GAME_API.new()
	game_api.bind_definition(definition, "res://games/table_debug/game.jsonh")
	_check(bool(game_api.definition("table.debug")), "G reads loaded definition properties")
	_check((game_api.games() as Array).has("table_debug"), "G lists available game definitions")
	_check(
		(game_api.components() as Dictionary).has("bgo.slot.basic"),
		"G exposes component contracts",
	)
	_check((game_api.help() as Dictionary).has("methods"), "G describes its console API")
	game_api.free()


func _test_session_state_foundation() -> void:
	var session: SessionState = SESSION_STATE.create_lobby("sess-1", "host-a")
	_check(session.session_id == "sess-1", "lobby session keeps identity")
	_check(session.lifecycle == SESSION_STATE.Lifecycle.LOBBY, "new session starts in lobby")
	_check(session.is_host("host-a"), "host identity is explicit")
	_check(not session.is_host("other"), "non-host is not treated as host")
	_check(not session.is_active(), "lobby session is not active")
	_check(not session.is_ended(), "lobby session is not ended")
	_check(not session.end_session("abandoned"), "lobby session cannot end without becoming active")
	_check(session.lifecycle == SESSION_STATE.Lifecycle.LOBBY, "rejected end leaves lobby intact")
	_check(session.assign_participant("host-a", "seat-1", "player"), "host can be assigned a seat")
	_check(
		session.assign_participant("player-b", "seat-2", "player"), "second participant assigned"
	)
	_check(
		not session.assign_participant("player-c", "seat-1"), "duplicate seat occupancy rejected"
	)
	_check(not session.assign_participant("", "seat-3"), "empty participant id rejected")
	_check(session.participant_seats["player-b"] == "seat-2", "seat assignment is stored")
	_check(session.participant_roles["player-b"] == "player", "role assignment is stored")
	_check(session.seat_order.size() == 2, "seat order tracks assigned seats")
	_check(session.seat_order[0] == "seat-1", "first seat in order is seat-1")
	_check(not session.start_session("missing"), "start rejects unknown participant")
	_check(session.start_session(), "default start uses first seat in seat_order")
	_check(session.is_active(), "started session is active")
	_check(session.active_participant_id == "host-a", "active player is represented")
	_check(session.turn_number == 1, "turn number starts at 1")
	_check(not session.start_session(), "already active session cannot start again")
	var snapshot: Dictionary = session.to_dictionary()
	_check(snapshot.get("lifecycle") == "active", "serialized lifecycle uses stable name")
	_check(int(snapshot.get("turn_number", 0)) == 1, "serialized turn number is present")
	_check(session.end_session("victory", ["player-b"]), "active session can end with result")
	_check(session.is_ended(), "ended session reports ended lifecycle")
	_check(session.active_participant_id == "", "active player clears on end")
	_check(str(session.result.get("outcome", "")) == "victory", "result outcome is stored")
	var winners: Array = session.result.get("winner_participant_ids", [])
	_check(winners.size() == 1 and str(winners[0]) == "player-b", "winner list is stored")
	_check(not session.end_session("draw"), "already ended session rejects another end")
	var empty_lobby: SessionState = SESSION_STATE.create_lobby("sess-empty")
	_check(not empty_lobby.start_session(), "empty lobby cannot start without participants")


func _test_session_turn_progression() -> void:
	var session: SessionState = SESSION_STATE.create_lobby("sess-turns", "p1")
	_check(session.assign_participant("p1", "seat-1", "player"), "turn p1 assigned")
	_check(session.assign_participant("watcher", "seat-2", "spectator"), "spectator assigned")
	_check(session.assign_participant("p2", "seat-3", "player"), "turn p2 assigned")
	_check(session.start_session(), "turn session starts")
	_check(session.active_participant_id == "p1", "first player starts")
	var before_turn := session.turn_number
	var before_active := session.active_participant_id
	_check(not session.advance_turn("p2"), "non-active participant cannot advance turn")
	_check(session.turn_number == before_turn, "rejected advance preserves turn number")
	_check(
		session.active_participant_id == before_active, "rejected advance preserves active player"
	)
	_check(session.advance_turn("p1"), "active participant advances turn")
	_check(session.active_participant_id == "p2", "spectator seat is skipped")
	_check(session.turn_number == 2, "turn number increments once")
	_check(session.advance_turn("p2"), "second player advances turn")
	_check(session.active_participant_id == "p1", "turn order wraps deterministically")
	_check(session.turn_number == 3, "wrapped turn increments deterministically")
	_check(session.end_session("complete", ["p1"]), "turn session can end")
	var ended_turn := session.turn_number
	_check(not session.advance_turn("p1"), "ended session rejects turn advance")
	_check(session.turn_number == ended_turn, "ended rejection preserves turn number")


func _test_session_completion() -> void:
	var session: SessionState = SESSION_STATE.create_lobby("sess-complete", "p1")
	_check(session.assign_participant("p1", "seat-1", "player"), "completion p1 assigned")
	_check(session.assign_participant("p2", "seat-2", "player"), "completion p2 assigned")
	_check(
		session.assign_participant("watcher", "seat-3", "spectator"),
		"completion spectator assigned"
	)
	_check(session.start_session(), "completion session starts")
	_check(not session.end_session("victory", ["missing"]), "unknown winner is rejected")
	_check(session.is_active(), "invalid winner does not end session")
	_check(not session.end_session("victory", ["watcher"]), "spectator winner is rejected")
	_check(session.is_active(), "spectator winner rejection preserves session")
	_check(not session.end_session("victory", ["p1", "p1"]), "duplicate winner is rejected")
	_check(session.end_session("victory", ["p2"]), "valid player winner ends session")
	_check(session.is_ended(), "completion lifecycle is ended")
	var ended_snapshot := session.to_dictionary()
	_check(not session.advance_turn("p2"), "ended session rejects gameplay transition")
	_check(not session.start_session(), "ended session rejects restart")
	_check(not session.end_session("draw"), "ended session rejects second completion")
	_check(session.to_dictionary() == ended_snapshot, "ended rejections preserve state")
	var draw: SessionState = SESSION_STATE.create_lobby("sess-draw")
	_check(draw.assign_participant("p1", "seat-1", "player"), "draw player assigned")
	_check(draw.start_session(), "draw session starts")
	_check(draw.end_session("draw"), "draw may end without winners")


func _test_tabletop_state() -> void:
	var table: TabletopState = TABLETOP_STATE.new()
	_check(table.add_section("main"), "table section is added")
	_check(not table.add_section("main"), "duplicate section is rejected")
	_check(table.add_zone("board", "main"), "zone belongs to section")
	_check(not table.add_zone("lost", "missing"), "zone rejects unknown section")
	_check(table.add_slot("a1", "board", 1), "single-capacity slot is added")
	_check(table.add_slot("pool", "board", 2), "multi-capacity slot is added")
	_check(not table.add_slot("bad", "board", 0), "non-positive capacity is rejected")
	_check(table.place_object("piece-1", "a1"), "object occupies free slot")
	_check(not table.place_object("piece-2", "a1"), "full slot rejects another object")
	_check(table.slot_occupants("a1") == ["piece-1"], "capacity rejection preserves occupants")
	_check(table.object_slot("piece-1") == "a1", "object location is explicit")
	_check(table.place_object("piece-2", "pool"), "object occupies multi-capacity slot")
	_check(table.place_object("piece-3", "pool"), "second object fits multi-capacity slot")
	var before_move := table.to_dictionary()
	_check(not table.move_object("piece-1", "pool"), "move rejects full destination")
	_check(table.to_dictionary() == before_move, "rejected move preserves complete table state")
	_check(table.remove_object("piece-3"), "object can leave a slot")
	_check(table.move_object("piece-1", "pool"), "object moves when destination gains capacity")
	_check(table.object_slot("piece-1") == "pool", "move updates object location")
	_check(table.slot_occupants("a1").is_empty(), "move clears source occupancy")
	_check(not table.place_object("piece-1", "a1"), "already placed object cannot duplicate")
	_check(table.configure_grid(8, 8, Vector2(5.0, 5.0)), "table grid is configured in centimetres")
	_check(
		table.place_object_at_grid("large-piece", Vector2i(2, 2), Vector2i(2, 1)),
		"multi-point object is placed",
	)
	_test_tabletop_free_placement(table)
	_test_tabletop_grid_and_asset_box(table)


func _test_tabletop_free_placement(table: TabletopState) -> void:
	_check(table.object_slot("piece-1") == "pool", "logical object location updates")
	_check(table.slot_occupants("a1").is_empty(), "source occupancy clears after move")
	_check(
		(
			table
			. add_zone(
				"studio",
				"main",
				{
					"placement_mode": "free_or_slot",
					"bounds": {"center": {"x": 0, "z": 0}, "size": {"x": 20, "z": 12}},
				},
			)
		),
		"table zone supports bounded free placement",
	)
	var pose := {
		"position": {"x": 2.5, "y": 0.0, "z": -1.0},
		"rotation": {"x": 0.0, "y": 0.4, "z": 0.0},
	}
	_check(table.place_object_free("loose-die", "studio", pose, "die"), "free pose is placed")
	_check(table.object_poses["loose-die"]["pose"] == pose, "free pose is authoritative")
	var before_invalid_pose := table.to_dictionary()
	var outside_pose := pose.duplicate(true)
	outside_pose["position"] = {"x": 50.0, "y": 0.0, "z": 0.0}
	_check(
		not table.move_object_free("loose-die", "studio", outside_pose, "die"),
		"free placement rejects poses outside zone bounds",
	)
	_check(table.to_dictionary() == before_invalid_pose, "rejected free move restores placement")
	_check(
		(
			table
			. add_slot(
				"board-home",
				"board",
				1,
				{
					"accepted_kinds": ["board"],
					"pose":
					{
						"position": {"x": 0.0, "y": 0.0, "z": 0.0},
						"rotation": {"x": 0.0, "y": 0.0, "z": 0.0},
					},
				},
			)
		),
		"slot declares accepted kinds and snap pose",
	)
	_check(not table.can_accept("board-home", "piece"), "slot rejects a non-whitelisted kind")
	_check(table.can_accept("board-home", "board"), "slot accepts a whitelisted kind")


func _test_tabletop_grid_and_asset_box(table: TabletopState) -> void:
	_check(
		table.object_grid_points("large-piece") == [Vector2i(2, 2), Vector2i(3, 2)],
		"object exposes its occupied grid points",
	)
	_check(
		table.objects_at_grid_point(Vector2i(3, 2)) == ["large-piece"],
		"point query returns touching object",
	)
	_check(
		table.objects_in_grid_area(Vector2i(3, 2), Vector2i(4, 3)) == ["large-piece"],
		"range query returns objects touching the area",
	)
	_check(
		not table.place_object_at_grid("blocked", Vector2i(3, 2)),
		"grid rejects an overlapping placement by default",
	)
	_check(table.remove_object("large-piece"), "grid placement can be removed")
	_check(
		table.configure_asset_box("game_box", 4, 3, Vector2(5.0, 5.0), "ASSET BOX"),
		"asset box configures with centimetre spacing",
	)
	_check(
		table.add_asset_to_box("reserve", "bgo.piece.basic_cylinder", {"color_source": "fixed"}, 8),
		"asset can be stored in the asset box",
	)
	_check(table.asset_box.has_asset("reserve"), "asset box exposes stored asset")
	_check(
		table.asset_box.objects_at(Vector2i(0, 0)).is_empty(),
		"conceptual asset box does not expose physical occupancy",
	)
	var removed_asset := table.remove_asset_from_box("reserve")
	_check(
		str(removed_asset.get("component_id", "")) == "bgo.piece.basic_cylinder",
		"asset can leave the box",
	)


func _test_table_grid_state() -> void:
	var grid = TABLE_GRID_STATE.new()
	_check(grid.configure(4, 3, Vector2(2.5, 5.0)), "standalone grid stores centimetre spacing")
	_check(grid.point_to_cm(Vector2i(2, 1)) == Vector2(5.0, 5.0), "point converts to centimetres")
	_check(
		grid.cm_to_point(Vector2(4.0, 7.0)) == Vector2i(2, 1), "centimetres snap to nearest point"
	)
	_check(
		not grid.is_valid_footprint(Vector2i(3, 2), Vector2i(2, 1)), "footprint cannot leave grid"
	)
	_check(grid.place_object("a", Vector2i(0, 0), Vector2i(2, 2)), "grid accepts valid footprint")
	_check(not grid.place_object("b", Vector2i(1, 1)), "grid detects footprint collision")
	_check(
		grid.place_object("b", Vector2i(1, 1), Vector2i.ONE, true), "explicit overlap is allowed"
	)
	var infinite_grid = TABLE_GRID_STATE.new()
	_check(
		infinite_grid.configure(1, 1, Vector2.ONE, true),
		"table grid can be configured as virtually infinite"
	)
	_check(infinite_grid.is_valid_point(Vector2i(-40, 75)), "infinite grid accepts signed points")


func _test_hand_state() -> void:
	var hand: HandState = HAND_STATE.create("p1")
	_check(hand.add_object("older"), "hand accepts first object")
	_check(hand.add_object("newer"), "hand accepts second object")
	_check(hand.top_object_id() == "newer", "hand uses FILO order")
	_check(hand.contains("older"), "hand tracks object membership")
	_check(hand.remove_object("newer"), "hand removes selected object")
	_check(hand.top_object_id() == "older", "hand promotes next FILO object")


func _test_logical_object_state() -> void:
	var neutral: LogicalObjectState = LOGICAL_OBJECT_STATE.create("neutral-token")
	_check(neutral.object_id == "neutral-token", "logical object keeps stable identity")
	_check(neutral.is_neutral(), "empty owner represents neutral ownership")
	_check(neutral.holder_id.is_empty(), "neutral object starts unheld")
	neutral.set_holder("p1")
	_check(neutral.holder_id == "p1", "holder is independent from owner")
	_check(neutral.owner_id.is_empty(), "holding does not change neutral ownership")
	_check(neutral.set_location("slot", "board:a1"), "logical location can be assigned")
	_check(neutral.location_type == "slot", "location type is explicit")
	_check(neutral.location_id == "board:a1", "location id is explicit")
	var before_invalid := neutral.to_dictionary()
	_check(not neutral.set_location("", "missing"), "invalid location is rejected")
	_check(neutral.to_dictionary() == before_invalid, "invalid location preserves object state")
	neutral.visibility = "owner_only"
	var snapshot := neutral.to_dictionary()
	_check(snapshot.get("visibility") == "owner_only", "visibility metadata is represented")
	_check(
		neutral.set_grid_placement(Vector2i(2, 3), Vector2i(2, 1)),
		"logical object accepts grid origin and footprint"
	)
	_check(neutral.location_type == "grid", "grid placement updates logical location type")
	_check(
		neutral.grid_points() == [Vector2i(2, 3), Vector2i(3, 3)],
		"logical object enumerates its footprint"
	)
	neutral.clear_location()
	_check(neutral.location_id.is_empty(), "logical location can be cleared")
