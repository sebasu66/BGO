extends SceneTree

const COMPONENT_REGISTRY = preload("res://src/core/component_registry.gd")
const GAME_DEFINITION_LOADER = preload("res://src/core/game_definition_loader.gd")
const SESSION_STATE = preload("res://src/core/session_state.gd")
const TABLETOP_STATE = preload("res://src/core/tabletop_state.gd")

var failures := 0
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_component_registry()
	_test_component_validation()
	_test_game_definition()
	_test_session_state()
	_test_tabletop_state()

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
	var expected := [
		"bgo.board.checkered",
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
	var valid_board := {"columns": 8, "rows": 6, "cell_size": 1.2}
	_check(
		COMPONENT_REGISTRY.validate_config("bgo.board.checkered", valid_board).is_empty(),
		"valid board config passes"
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


func _test_session_state() -> void:
	var session: SessionState = SESSION_STATE.create_lobby("sess-1", "p1")
	_check(session.is_host("p1"), "host identity is explicit")
	_check(session.assign_participant("p1", "seat-1", "player"), "host seat assignment succeeds")
	_check(
		session.assign_participant("watcher", "seat-2", "spectator"),
		"spectator seat assignment succeeds"
	)
	_check(
		session.assign_participant("p2", "seat-3", "player"),
		"second player assignment succeeds"
	)
	_check(not session.assign_participant("p3", "seat-1", "player"), "duplicate seat is rejected")
	_check(session.start_session(), "session starts with seated players")
	_check(session.active_participant_id == "p1", "first valid player starts")
	_check(session.turn_number == 1, "turn number starts at one")

	var before_turn := session.to_dictionary()
	_check(not session.advance_turn("p2"), "non-active player cannot advance turn")
	_check(session.to_dictionary() == before_turn, "rejected turn advance preserves state")
	_check(session.advance_turn("p1"), "active player advances turn")
	_check(session.active_participant_id == "p2", "spectator is skipped in turn order")
	_check(session.turn_number == 2, "turn number increments deterministically")

	var before_invalid_end := session.to_dictionary()
	_check(not session.end_session("victory", ["watcher"]), "spectator cannot be winner")
	_check(session.to_dictionary() == before_invalid_end, "invalid completion preserves state")
	_check(session.end_session("victory", ["p2"]), "active session ends with valid winner")
	_check(session.is_ended(), "session reports ended lifecycle")
	_check(session.active_participant_id.is_empty(), "ended session clears active player")
	_check(str(session.result.get("outcome", "")) == "victory", "result outcome is explicit")
	_check(
		(session.result.get("winner_participant_ids", []) as Array) == ["p2"],
		"winner is explicit"
	)
	var ended_snapshot := session.to_dictionary()
	_check(not session.advance_turn("p2"), "ended session rejects turn progression")
	_check(session.to_dictionary() == ended_snapshot, "ended rejection preserves state")


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
	_check(table.move_object("piece-1", "pool"), "move succeeds when capacity becomes available")
	_check(table.object_slot("piece-1") == "pool", "logical object location updates")
	_check(table.slot_occupants("a1").is_empty(), "source occupancy clears after move")
