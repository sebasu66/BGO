extends SceneTree

const COMPONENT_REGISTRY = preload("res://src/core/component_registry.gd")
const CONSOLE_COMMAND_BRIDGE_TEST = preload("res://tests/console_command_bridge_test.gd")
const CONFORMANCE_GAME_TEST = preload("res://tests/conformance_game_test.gd")
const GAME_DEFINITION_LOADER = preload("res://src/core/game_definition_loader.gd")
const GAME_COMPONENT_COMPOSER = preload("res://src/demo/game_component_composer.gd")
const SEQUENTIAL_DROP_ANIMATOR = preload("res://src/demo/sequential_drop_animator.gd")
const GAMEPLAY_STATE_TEST = preload("res://tests/gameplay_state_test.gd")
const GAME_API = preload("res://src/core/game_api.gd")
const RUNTIME_SESSION_ADAPTER_TEST = preload("res://tests/runtime_session_adapter_test.gd")
const SANDBOX_STATE_TEST = preload("res://tests/sandbox_state_test.gd")
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

var failures := 0
var assertions := 0



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


func _test_capability_contracts() -> void:
	var component_ids := COMPONENT_REGISTRY.component_ids()
	var sorted_ids := component_ids.duplicate()
	sorted_ids.sort()
	_check(component_ids == sorted_ids, "component registry ids are deterministic")
	for component_id in component_ids:
		var contract := COMPONENT_REGISTRY.get_contract(component_id)
		_check(contract.get("capabilities", []) is Array, "%s capabilities are an array" % component_id)
		_check(contract.get("verbs", {}) is Dictionary, "%s verbs are an object" % component_id)
		_check(contract.get("state", {}) is Dictionary, "%s state is an object" % component_id)


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
func _find_descendant_of_type(node: Node, class_name_value: String) -> Node:
	for child in node.get_children():
		if child.get_class() == class_name_value:
			return child
		var nested := _find_descendant_of_type(child, class_name_value)
		if nested != null:
			return nested
	return null
