extends SceneTree

const COMPONENT_REGISTRY = preload("res://src/core/component_registry.gd")
const GAME_DEFINITION_LOADER = preload("res://src/core/game_definition_loader.gd")
const GAMEPLAY_STATE_TEST = preload("res://tests/gameplay_state_test.gd")
const LOGICAL_OBJECT_STATE = preload("res://src/core/logical_object_state.gd")
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
	_test_session_state_foundation()
	_test_session_turn_progression()
	_test_session_completion()
	_test_tabletop_state()
	_test_logical_object_state()
	GAMEPLAY_STATE_TEST.run(_check)

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

	_check(not COMPONENT_REGISTRY.has_component("bgo.missing.component"), "unknown component is rejected")
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
	_check(session.assign_participant("player-b", "seat-2", "player"), "second participant assigned")
	_check(not session.assign_participant("player-c", "seat-1"), "duplicate seat occupancy rejected")
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
	_check(session.active_participant_id == before_active, "rejected advance preserves active player")
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
	_check(session.assign_participant("watcher", "seat-3", "spectator"), "completion spectator assigned")
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
	neutral.clear_location()
	_check(neutral.location_id.is_empty(), "logical location can be cleared")
