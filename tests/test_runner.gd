extends SceneTree

const COMPONENT_REGISTRY = preload("res://src/core/component_registry.gd")
const CAPABILITY_REGISTRY = preload("res://src/core/capability_registry.gd")
const CONFORMANCE_GAME_TEST = preload("res://tests/conformance_game_test.gd")
const GAME_DEFINITION_LOADER = preload("res://src/core/game_definition_loader.gd")
const GAMEPLAY_STATE_TEST = preload("res://tests/gameplay_state_test.gd")
const LOGICAL_OBJECT_STATE = preload("res://src/core/logical_object_state.gd")
const RUNTIME_SESSION_ADAPTER_TEST = preload("res://tests/runtime_session_adapter_test.gd")
const SESSION_STATE = preload("res://src/core/session_state.gd")
const TABLETOP_STATE = preload("res://src/core/tabletop_state.gd")

var failures := 0
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_component_registry()
	_test_capability_contracts()
	_test_component_validation()
	_test_game_definition()
	_test_session_state()
	_test_tabletop_state()
	_test_logical_object_state()
	GAMEPLAY_STATE_TEST.run(_check)
	RUNTIME_SESSION_ADAPTER_TEST.run(_check)
	CONFORMANCE_GAME_TEST.run(_check)

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


func _test_component_registry() -> void:
	var registry_errors: Array[String] = COMPONENT_REGISTRY.load_components()
	_check(registry_errors.is_empty(), "all component contracts are compliant")
	var expected := [
		"bgo.board.checkered",
		"bgo.piece.basic_cylinder",
		"bgo.player_area.basic",
		"bgo.slot.basic",
	]
	for component_id in expected:
		_check(
			COMPONENT_REGISTRY.has_component(component_id),
			"registry resolves %s" % component_id,
		)
		_check(
			COMPONENT_REGISTRY.load_scene(component_id) != null,
			"scene exists for %s" % component_id,
		)

	_check(
		not COMPONENT_REGISTRY.has_component("bgo.missing.component"),
		"unknown component is rejected",
	)
	_check(
		COMPONENT_REGISTRY.load_scene("bgo.missing.component") == null,
		"unknown component has no scene",
	)


func _test_capability_contracts() -> void:
	var catalog_errors: Array[String] = CAPABILITY_REGISTRY.load_catalog()
	_check(catalog_errors.is_empty(), "capability catalog loads without errors")
	_check(CAPABILITY_REGISTRY.has("movable"), "movable capability is registered")
	var incomplete := {
		"capabilities": ["quantifiable"],
		"verbs": {},
	}
	_check(
		not CAPABILITY_REGISTRY.validate_component(incomplete).is_empty(),
		"capability rejects a component missing its required verb",
	)
	var compliant := {
		"capabilities": ["quantifiable"],
		"verbs": {"object.set_quantity": {}},
	}
	_check(
		CAPABILITY_REGISTRY.validate_component(compliant).is_empty(),
		"capability accepts a component implementing its contract",
	)


func _test_component_validation() -> void:
	var valid_board := {"columns": 8, "rows": 6, "cell_size": 1.2}
	_check(
		COMPONENT_REGISTRY.validate_config("bgo.board.checkered", valid_board).is_empty(),
		"valid board config passes",
	)

	var invalid_board := {"columns": 1, "rows": 6, "cell_size": 1.2}
	_check(
		not COMPONENT_REGISTRY.validate_config("bgo.board.checkered", invalid_board).is_empty(),
		"invalid board columns are rejected",
	)

	_check(
		not COMPONENT_REGISTRY.validate_config("bgo.missing.component", {}).is_empty(),
		"unknown component config is rejected",
	)


func _test_game_definition() -> void:
	var result: Dictionary = GAME_DEFINITION_LOADER.load_game("res://games/test001/game.jsonh")
	if not bool(result.get("ok", false)):
		printerr("TEST001 validation errors: %s" % [result.get("errors", [])])
	_check(bool(result.get("ok", false)), "TEST001 definition loads and validates")
	if bool(result.get("ok", false)):
		var data: Dictionary = result.get("data", {})
		_check(
			str(data.get("schema", "")) == "bgo.game",
			"TEST001 declares the canonical game schema",
		)

	var missing: Dictionary = GAME_DEFINITION_LOADER.load_game(
		"res://games/does-not-exist/game.jsonh"
	)
	_check(not bool(missing.get("ok", false)), "missing game definition fails safely")
	_check(
		not (missing.get("errors", []) as Array).is_empty(),
		"missing game definition returns a useful error",
	)


func _test_session_state() -> void:
	var session: SessionState = SESSION_STATE.create_lobby("sess-1", "p1")
	_check(session.is_host("p1"), "host identity is explicit")
	_check(
		session.assign_participant("p1", "seat-1", "player"),
		"host seat assignment succeeds",
	)
	_check(
		session.assign_participant("watcher", "seat-2", "spectator"),
		"spectator seat assignment succeeds",
	)
	_check(
		session.assign_participant("p2", "seat-3", "player"),
		"second player assignment succeeds",
	)
	_check(
		not session.assign_participant("p3", "seat-1", "player"),
		"duplicate seat is rejected",
	)
	_check(session.start_session(), "session starts with seated players")
	_check(
		session.ordered_players() == ["p1", "p2"],
		"session exposes seated players without owning turn flow"
	)

	var before_invalid_end := session.to_dictionary()
	_check(not session.end_session("victory", ["watcher"]), "spectator cannot be winner")
	_check(session.to_dictionary() == before_invalid_end, "invalid completion preserves state")
	_check(session.end_session("victory", ["p2"]), "active session ends with valid winner")
	_check(session.is_ended(), "session reports ended lifecycle")
	_check(str(session.result.get("outcome", "")) == "victory", "result outcome is explicit")
	_check(
		(session.result.get("winner_participant_ids", []) as Array) == ["p2"],
		"winner is explicit",
	)
	var ended_snapshot := session.to_dictionary()
	_check(session.to_dictionary() == ended_snapshot, "ended session snapshot is stable")


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
	_check(table.place_object("piece-2", "pool"), "first pool object is placed")
	_check(table.place_object("piece-3", "pool"), "second pool object is placed")
	var before_move := table.to_dictionary()
	_check(not table.move_object("piece-1", "pool"), "move rejects full destination")
	_check(table.to_dictionary() == before_move, "rejected move preserves table state")
	_check(table.remove_object("piece-3"), "object can leave a slot")
	_check(
		table.move_object("piece-1", "pool"),
		"move succeeds when capacity becomes available",
	)
	_check(table.object_slot("piece-1") == "pool", "logical object location updates")
	_check(table.slot_occupants("a1").is_empty(), "source occupancy clears after move")


func _test_logical_object_state() -> void:
	var neutral: LogicalObjectState = LOGICAL_OBJECT_STATE.create(
		"neutral-token", "bgo.piece.basic_cylinder"
	)
	_check(neutral.object_id == "neutral-token", "logical object keeps stable identity")
	_check(neutral.is_neutral(), "empty owner represents neutral ownership")
	_check(neutral.holder_id.is_empty(), "neutral object starts unheld")
	neutral.set_holder("p1")
	_check(neutral.holder_id == "p1", "holder is independent from owner")
	_check(neutral.owner_id.is_empty(), "holding does not change neutral ownership")
	_check(
		neutral.set_location("slot", "board:a1"),
		"logical location can be assigned",
	)
	_check(neutral.location_type == "slot", "location type is explicit")
	_check(neutral.location_id == "board:a1", "location id is explicit")
	var before_invalid := neutral.to_dictionary()
	_check(not neutral.set_location("", "missing"), "invalid location is rejected")
	_check(
		neutral.to_dictionary() == before_invalid,
		"invalid location preserves object state",
	)
	neutral.visibility = "owner_only"
	var snapshot := neutral.to_dictionary()
	_check(snapshot.get("visibility") == "owner_only", "visibility metadata is represented")
	_check(neutral.set_quantity(100), "logical quantity can represent an aggregate")
	_check(neutral.set_state("exhausted"), "logical object supports named state")
	_check(neutral.to_dictionary().get("quantity") == 100, "quantity is serialized")
	neutral.clear_location()
	_check(neutral.location_id.is_empty(), "logical location can be cleared")
