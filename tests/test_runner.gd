extends SceneTree

const COMPONENT_REGISTRY = preload("res://src/core/component_registry.gd")
const CONSOLE_COMMAND_BRIDGE_TEST = preload("res://tests/console_command_bridge_test.gd")
const CONFORMANCE_GAME_TEST = preload("res://tests/conformance_game_test.gd")
const GAME_DEFINITION_LOADER = preload("res://src/core/game_definition_loader.gd")
const GAME_COMPONENT_COMPOSER = preload("res://src/demo/game_component_composer.gd")
const SEQUENTIAL_DROP_ANIMATOR = preload("res://src/demo/sequential_drop_animator.gd")
const GAMEPLAY_STATE_TEST = preload("res://tests/gameplay_state_test.gd")
const HAND_STATE = preload("res://src/core/hand_state.gd")
const LOGICAL_OBJECT_STATE = preload("res://src/core/logical_object_state.gd")
const MCP_PROTOTYPE_ACCESS_POLICY = preload("res://src/mcp/mcp_prototype_access_policy.gd")
const MCP_GAME_API_TEST = preload("res://tests/mcp_game_api_test.gd")
const MCP_COMMAND_PROCESSOR_TEST = preload("res://tests/mcp_command_processor_test.gd")
const SESSION_STATE = preload("res://src/core/session_state.gd")
const TABLE_GRID_STATE = preload("res://src/core/table_grid_state.gd")
const TABLETOP_STATE = preload("res://src/core/tabletop_state.gd")
const SETTINGS_PANEL = preload("res://src/components/ui/settings_panel/settings_panel.tscn")
const ACTION_STRIP = preload("res://src/components/ui/action_strip/action_strip.tscn")
const UI_THEME_PROFILES = preload("res://src/components/ui/theme_profiles/ui_theme_profiles.gd")
const VERTICAL_HAND = preload("res://src/components/hands/vertical_hand/vertical_hand.tscn")
const FLUENT_GAME_BUILDER_TEST = preload("res://tests/fluent_game_builder_test.gd")
const RUNTIME_SESSION_ADAPTER_TEST = preload("res://tests/runtime_session_adapter_test.gd")

var failures := 0
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_component_registry()
	_test_component_validation()
	_test_game_definition()
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
	CONFORMANCE_GAME_TEST.run(_check)
	RUNTIME_SESSION_ADAPTER_TEST.run(_check)

	if failures > 0:
		printerr("BGO TESTS FAILED: %d/%d assertions failed." % [failures, assertions])
		quit(1)
		return

	print("BGO TESTS PASSED: %d assertions." % assertions)
	quit(0)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % message)
		return
	failures += 1
	printerr("FAIL: %s" % message)


func _test_sequential_drop_animator() -> void:
	var animator := SEQUENTIAL_DROP_ANIMATOR.new() as BgoSequentialDropAnimator
	get_root().add_child(animator)
	_check(
		is_equal_approx(animator.duration_seconds, 0.2),
		"load sequence uses a 0.2 second drop per component",
	)
	animator.duration_seconds = 0.01
	var first := Node3D.new()
	first.name = "FirstDrop"
	first.position = Vector3(1.0, 0.5, 0.0)
	var second := Node3D.new()
	second.name = "SecondDrop"
	second.position = Vector3(-1.0, 0.25, 0.0)
	get_root().add_child(first)
	get_root().add_child(second)
	var landed: Array[String] = []
	animator.item_landed.connect(func(target: Node3D): landed.append(target.name))
	var first_final := first.position
	var second_final := second.position
	animator.enqueue(first, first_final)
	animator.enqueue(second, second_final)
	_check(not first.visible and not second.visible, "queued load components start hidden")
	animator.play()
	_check(
		first.visible and first.position.y > first_final.y,
		"the active load component starts falling from above",
	)
	await animator.sequence_finished
	_check(landed == ["FirstDrop", "SecondDrop"], "load components land one at a time")
	_check(
		(
			first.position.is_equal_approx(first_final)
			and second.position.is_equal_approx(second_final)
		),
		"load components preserve their final logical positions",
	)
	first.queue_free()
	second.queue_free()
	animator.queue_free()
	await process_frame


func _test_vertical_hand_selection() -> void:
	var hand := VERTICAL_HAND.instantiate() as BgoVerticalHand
	get_root().add_child(hand)
	hand.size = Vector2(144, 600)
	hand.set_preview_factory(Callable(self, "_make_hand_test_preview"))
	hand.set_items([{"id": "newer"}, {"id": "older"}])
	await process_frame
	_check(hand.get_selected_item_id() == "newer", "hand always selects the FILO item")
	hand.set_selected("missing")
	_check(hand.get_selected_item_id() == "newer", "invalid hand selection keeps a valid item")
	hand.set_items([{"id": "older"}], "missing")
	_check(hand.get_selected_item_id() == "older", "hand promotes the remaining item")
	var preview := hand.find_child("HandTestPreview", true, false) as Node3D
	_check(
		preview != null and is_equal_approx(preview.scale.x, 2.04),
		"hand preview content is fifteen percent smaller inside its slot"
	)
	hand.set_items([])
	_check(hand.get_selected_item_id().is_empty(), "empty hand clears visual selection")
	hand.queue_free()
	await process_frame


func _test_context_menu_component() -> void:
	var packed := BgoComponentRegistry.load_scene("bgo.ui.context_menu")
	var menu := packed.instantiate() as BgoContextMenuComponent
	get_root().add_child(menu)
	menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu.size = Vector2(960, 720)
	(
		menu
		. setup(
			{
				"actions":
				[
					{"id": "details", "label": "DETALLES"},
					{"id": "take", "label": "TOMAR"},
				],
			}
		)
	)
	await process_frame
	_check(menu.action_ids() == ["details", "take"], "context menu renders object-defined actions")
	var piece_scene := BgoComponentRegistry.load_scene("bgo.piece.basic_cylinder")
	var piece := piece_scene.instantiate() as BgoBasicCylinderPiece
	var host_actions: Array[Dictionary] = piece.menu_actions("host", "host")
	var spectator_actions: Array[Dictionary] = piece.menu_actions("spectator", "watcher")
	_check(
		_action_ids(host_actions).has("delete") and _action_ids(host_actions).has("change_owner"),
		"host context menu exposes administrative actions"
	)
	_check(
		_action_ids(spectator_actions) == ["details", "details-2"],
		"spectator context menu remains read-only"
	)
	piece.free()
	menu.queue_free()
	await process_frame


func _action_ids(actions: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for action in actions:
		result.append(str(action.get("id", "")))
	return result


func _make_hand_test_preview(_item: Dictionary) -> Node3D:
	var preview := Node3D.new()
	preview.name = "HandTestPreview"
	return preview


func _test_mcp_prototype_access_policy() -> void:
	var owner: Dictionary = MCP_PROTOTYPE_ACCESS_POLICY.bind_context("", "player_1", "player")
	_check(owner.auth_mode == "dev_direct_no_auth", "MCP prototype declares no-auth DEV mode")
	_check(owner.session_id == "TEST001", "MCP prototype binds the default session")
	_check(
		MCP_PROTOTYPE_ACCESS_POLICY.can_execute(owner, "game.execute_action", "player_1"),
		"MCP owner may control an owned object"
	)
	_check(
		not MCP_PROTOTYPE_ACCESS_POLICY.can_execute(owner, "game.execute_action", "player_2"),
		"MCP player cannot control another owner's object"
	)
	var host: Dictionary = MCP_PROTOTYPE_ACCESS_POLICY.bind_context("TEST001", "host", "host")
	_check(
		MCP_PROTOTYPE_ACCESS_POLICY.can_execute(host, "game.delete_object", "player_2"),
		"MCP host receives administrative object capability"
	)
	var spectator: Dictionary = MCP_PROTOTYPE_ACCESS_POLICY.bind_context(
		"TEST001", "watcher", "spectator"
	)
	_check(
		MCP_PROTOTYPE_ACCESS_POLICY.can_execute(spectator, "game.inspect_object", "player_1"),
		"MCP spectator may inspect authorized state"
	)
	_check(
		not MCP_PROTOTYPE_ACCESS_POLICY.can_execute(spectator, "game.end_turn", ""),
		"MCP spectator cannot issue control commands"
	)


func _test_component_registry() -> void:
	var expected := [
		"bgo.board.checkered",
		"bgo.table.grid",
		"bgo.container.asset_box",
		"bgo.hand.vertical",
		"bgo.ui.context_menu",
		"bgo.ui.toast",
		"bgo.ui.settings_panel",
		"bgo.ui.action_strip",
		"bgo.ui.session_header",
		"bgo.piece.basic_cylinder",
		"bgo.player_area.basic",
		"bgo.slot.basic",
	]
	for component_id in expected:
		_check(
			COMPONENT_REGISTRY.has_component(component_id), "registry resolves %s" % component_id
		)
		_check(
			COMPONENT_REGISTRY.load_scene(component_id) != null,
			"scene exists for %s" % component_id
		)

	_check(
		not COMPONENT_REGISTRY.has_component("bgo.missing.component"),
		"unknown component is rejected"
	)
	_check(
		COMPONENT_REGISTRY.load_scene("bgo.missing.component") == null,
		"unknown component has no scene"
	)


func _test_component_validation() -> void:
	var valid_board := {
		"columns": 8,
		"rows": 6,
		"cell_size": 1.2,
		"grid_points_per_unit": 5,
	}
	_check(
		COMPONENT_REGISTRY.validate_config("bgo.board.checkered", valid_board).is_empty(),
		"valid board config passes"
	)
	_check(
		(
			COMPONENT_REGISTRY
			. validate_config(
				"bgo.table.grid",
				{"point_columns": 16, "point_rows": 10, "world_units_per_cm": 0.01}
			)
			. is_empty()
		),
		"valid table grid config passes"
	)
	_check(
		(
			COMPONENT_REGISTRY
			. validate_config(
				"bgo.container.asset_box",
				{"point_columns": 6, "point_rows": 3, "world_units_per_cm": 0.01}
			)
			. is_empty()
		),
		"valid asset box config passes"
	)

	var invalid_board := {"columns": 1, "rows": 6, "cell_size": 1.2}
	_check(
		not COMPONENT_REGISTRY.validate_config("bgo.board.checkered", invalid_board).is_empty(),
		"invalid board columns are rejected"
	)
	_check(
		not COMPONENT_REGISTRY.validate_config("bgo.missing.component", {}).is_empty(),
		"unknown component config is rejected"
	)


func _test_ui_theme_profiles() -> void:
	var boardroom: Theme = UI_THEME_PROFILES.build("boardroom")
	var contrast: Theme = UI_THEME_PROFILES.build("high_contrast", {"font_scale": 1.2})
	_check(boardroom != null, "boardroom UI theme profile builds")
	_check(contrast != null, "high-contrast UI theme profile builds")
	_check(
		boardroom.get_type_variation_base("BgoShellButton") == "Button",
		"UI theme exposes semantic shell button variation"
	)
	_check(
		contrast.default_font_size > boardroom.default_font_size,
		"font scale affects global UI theme"
	)


func _test_action_strip_exclusive_modes() -> void:
	var strip := ACTION_STRIP.instantiate() as BgoActionStrip
	get_root().add_child(strip)
	(
		strip
		. configure(
			"GAME",
			[
				{"id": "pickup", "label": "PICK UP", "toggle": true, "group": "hand_mode"},
				{"id": "place", "label": "PLACE", "toggle": true, "group": "hand_mode"},
			]
		)
	)
	await process_frame
	strip.set_action_active("pickup", true)
	_check(strip.is_action_active("pickup"), "pickup action exposes persistent active state")
	_check(not strip.is_action_active("place"), "place starts inactive while pickup is active")
	strip.set_action_active("place", true)
	_check(strip.is_action_active("place"), "place action exposes persistent active state")
	_check(not strip.is_action_active("pickup"), "activating place clears pickup in the same group")
	strip.set_action_active("place", false)
	_check(not strip.is_action_active("place"), "active hand mode can be switched off")
	strip.queue_free()


func _test_declarative_component_composition() -> void:
	var loaded: Dictionary = GAME_DEFINITION_LOADER.load_game("res://games/test001/game.jsonh")
	_check(bool(loaded.get("ok", false)), "declarative composition fixture validates")
	if not bool(loaded.get("ok", false)):
		return
	var root := Node3D.new()
	get_root().add_child(root)
	var composer := GAME_COMPONENT_COMPOSER.new() as BgoGameComponentComposer
	var data: Dictionary = loaded.get("data", {})
	var table: Dictionary = data.get("table", {})
	var instances := composer.compose(table.get("instances", []), root)
	_check(instances.size() == 3, "all declared table components instantiate")
	_check(instances.has("main_board"), "declared board instance is addressable by id")
	_check(instances.has("player_1_area"), "declared player area is addressable by id")
	var board := instances.get("main_board") as BgoCheckeredBoard
	_check(board != null and board.columns == 8 and board.rows == 6, "board config is applied")
	_check(board.grid_points_per_unit == 5, "game package defines five grid points per unit")
	var fine_grid := board.get_node_or_null("TableGrid") as BgoTableGrid
	_check(
		fine_grid != null and fine_grid.point_columns == 40 and fine_grid.point_rows == 30,
		"one-centimetre grid points cover the complete board surface"
	)
	_check(fine_grid.virtual_infinite, "game package enables a virtually infinite table grid")
	var slot_destination := board.resolve_magnetic_placement(
		board.global_position + board.cell_world(Vector2i(2, 1))
	)
	_check(
		str(slot_destination.get("slot_id", "")) == "board:2:1",
		"magnetic placement prioritizes a board slot"
	)
	var outside_destination := board.resolve_magnetic_placement(Vector3(24.0, 0.0, -18.0))
	_check(
		str(outside_destination.get("type", "")) == "grid",
		"placement outside the board falls back to the infinite table grid"
	)
	board.slots_enabled = false
	board.rebuild()
	var grid_destination := board.resolve_magnetic_placement(
		board.global_position + board.cell_world(Vector2i(2, 1)) + Vector3(0.21, 0.0, 0.0)
	)
	_check(
		(
			str(grid_destination.get("type", "")) == "grid"
			and grid_destination.get("grid_point", Vector2i(-1, -1)) == Vector2i(13, 7)
		),
		"slotless placement falls back to the nearest fine-grid point"
	)
	var area := instances.get("player_1_area") as BgoPlayerArea
	_check(
		area != null and area.position.is_equal_approx(Vector3(-6.15, 0.02, 0.0)),
		"declared component placement is applied"
	)
	root.queue_free()


func _test_logger_levels() -> void:
	var test_logger := BgoLogger.new()
	test_logger.console_enabled = false
	test_logger.file_enabled = false
	_check(test_logger.set_minimum_level("warning"), "logger accepts a supported minimum level")
	_check(test_logger.minimum_level == "warning", "logger stores its minimum level")
	_check(not test_logger.set_minimum_level("trace"), "logger rejects an unsupported level")


func _test_settings_panel() -> void:
	var panel := SETTINGS_PANEL.instantiate() as BgoSettingsPanel
	get_root().add_child(panel)
	await process_frame
	panel.open(BgoClientSettingsController.DEFAULTS)
	await process_frame
	_check(panel.visible, "settings panel opens as a full client overlay")
	var tabs := _find_descendant_of_type(panel, "TabContainer") as TabContainer
	_check(
		tabs != null and tabs.get_tab_count() == 5,
		"settings panel exposes five extensible sections"
	)
	_check(
		panel.get_viewport_rect().encloses(panel.get_global_rect()),
		"settings overlay stays inside the viewport"
	)
	panel.queue_free()
	await process_frame


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


func _find_descendant_of_type(node: Node, class_name_value: String) -> Node:
	for child in node.get_children():
		if child.get_class() == class_name_value:
			return child
		var nested := _find_descendant_of_type(child, class_name_value)
		if nested != null:
			return nested
	return null


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
		"multi-point object is placed"
	)
	_check(
		table.object_grid_points("large-piece") == [Vector2i(2, 2), Vector2i(3, 2)],
		"object exposes its occupied grid points"
	)
	_check(
		table.objects_at_grid_point(Vector2i(3, 2)) == ["large-piece"],
		"point query returns touching object"
	)
	_check(
		table.objects_in_grid_area(Vector2i(3, 2), Vector2i(4, 3)) == ["large-piece"],
		"range query returns objects touching the area"
	)
	_check(
		not table.place_object_at_grid("blocked", Vector2i(3, 2)),
		"grid rejects an overlapping placement by default"
	)
	_check(table.remove_object("large-piece"), "grid placement can be removed")
	_check(
		table.configure_asset_box("game_box", 4, 3, Vector2(5.0, 5.0), "ASSET BOX"),
		"asset box configures with centimetre spacing"
	)
	_check(
		table.add_asset_to_box("reserve", "bgo.piece.basic_cylinder", {"color_source": "fixed"}, 8),
		"asset can be stored in the asset box"
	)
	_check(table.asset_box.has_asset("reserve"), "asset box exposes stored asset")
	_check(
		table.asset_box.objects_at(Vector2i(0, 0)).is_empty(),
		"conceptual asset box does not expose physical occupancy"
	)
	var removed_asset := table.remove_asset_from_box("reserve")
	_check(
		str(removed_asset.get("component_id", "")) == "bgo.piece.basic_cylinder",
		"asset can leave the box"
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
