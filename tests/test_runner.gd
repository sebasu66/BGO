extends SceneTree

const COMPONENT_REGISTRY = preload("res://src/core/component_registry.gd")
const GAME_DEFINITION_LOADER = preload("res://src/core/game_definition_loader.gd")
const SESSION_STATE = preload("res://src/core/session_state.gd")

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


func _test_session_state_foundation() -> void:
	var session: SessionState = SESSION_STATE.create_lobby("sess-1", "host-a")
	_check(session.session_id == "sess-1", "lobby session keeps identity")
	_check(session.lifecycle == SESSION_STATE.Lifecycle.LOBBY, "new session starts in lobby")
	_check(session.is_host("host-a"), "host identity is explicit")
	_check(not session.is_host("other"), "non-host is not treated as host")
	_check(not session.is_active(), "lobby session is not active")
	_check(not session.is_ended(), "lobby session is not ended")

	_check(
		not session.end_session("abandoned"),
		"lobby session cannot end without becoming active"
	)
	_check(session.lifecycle == SESSION_STATE.Lifecycle.LOBBY, "rejected end leaves lobby intact")

	_check(
		session.assign_participant("host-a", "seat-1", "player"),
		"host can be assigned a seat"
	)
	_check(
		session.assign_participant("player-b", "seat-2", "player"),
		"second participant can be assigned"
	)
	_check(
		not session.assign_participant("player-c", "seat-1"),
		"duplicate seat occupancy is rejected"
	)
	_check(
		not session.assign_participant("", "seat-3"),
		"empty participant id is rejected"
	)
	_check(session.participant_seats["player-b"] == "seat-2", "seat assignment is stored")
	_check(session.participant_roles["player-b"] == "player", "role assignment is stored")
	_check(session.seat_order.size() == 2, "seat order tracks assigned seats")
	_check(session.seat_order[0] == "seat-1", "first seat in order is seat-1")

	_check(not session.start_session("missing"), "start rejects unknown participant")
	_check(session.start_session(), "default start uses first seat in seat_order")
	_check(session.is_active(), "started session is active")
	_check(session.lifecycle == SESSION_STATE.Lifecycle.ACTIVE, "lifecycle becomes active")
	_check(
		session.active_participant_id == "host-a",
		"default active player is occupant of first seat"
	)
	_check(session.turn_number == 1, "turn number starts at 1")
	_check(not session.start_session(), "already active session cannot start again")

	var snapshot: Dictionary = session.to_dictionary()
	_check(snapshot.get("lifecycle") == "active", "serialized lifecycle uses stable name")
	_check(int(snapshot.get("turn_number", 0)) == 1, "serialized turn number is present")
	_check(
		str(snapshot.get("active_participant_id", "")) == "host-a",
		"serialized active participant is present"
	)

	_check(
		session.end_session("victory", ["player-b"]),
		"active session can end with result"
	)
	_check(session.is_ended(), "ended session reports ended lifecycle")
	_check(session.active_participant_id == "", "active player clears on end")
	_check(str(session.result.get("outcome", "")) == "victory", "result outcome is stored")
	var winners: Array = session.result.get("winner_participant_ids", [])
	_check(winners.size() == 1 and str(winners[0]) == "player-b", "winner list is stored")
	_check(not session.end_session("draw"), "already ended session rejects another end")
	_check(not session.end_session(""), "empty outcome is rejected")

	var empty_lobby: SessionState = SESSION_STATE.create_lobby("sess-empty")
	_check(not empty_lobby.start_session(), "empty lobby cannot start without participants")

	var ordered: SessionState = SESSION_STATE.create_lobby("sess-order")
	_check(ordered.assign_participant("p-late", "seat-b"), "late participant assigned")
	_check(ordered.assign_participant("p-first", "seat-a"), "first seat participant assigned")
	_check(ordered.seat_order[0] == "seat-b", "seat_order preserves assignment order")
	_check(ordered.start_session(), "ordered session starts from seat_order")
	_check(
		ordered.active_participant_id == "p-late",
		"default starter matches first seat_order occupant not dictionary key order"
	)


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

	var spectator_first: SessionState = SESSION_STATE.create_lobby("sess-spectator-first")
	_check(
		spectator_first.assign_participant("watcher", "seat-1", "spectator"),
		"leading spectator assigned"
	)
	_check(spectator_first.assign_participant("p1", "seat-2", "player"), "player after spectator")
	_check(spectator_first.start_session(), "session can start with spectator in first seat")
	_check(
		spectator_first.active_participant_id == "p1",
		"default starter is first valid player"
	)


func _test_session_completion() -> void:
	var session: SessionState = SESSION_STATE.create_lobby("sess-complete", "p1")
	_check(session.assign_participant("p1", "seat-1", "player"), "completion p1 assigned")
	_check(session.assign_participant("p2", "seat-2", "player"), "completion p2 assigned")
	_check(session.assign_participant("watcher", "seat-3", "spectator"), "completion spectator assigned")
	_check(session.start_session(), "completion session starts")

	_check(not session.end_session("victory", ["missing"]), "unknown winner is rejected")
	_check(session.is_active(), "invalid winner does not end session")
	_check(not session.end_session("victory", ["watcher"]), "spectator winner is rejected")
	_check(session.is_active(), "invalid spectator winner preserves active session")
	_check(not session.end_session("victory", ["p1", "p1"]), "duplicate winner is rejected")
	_check(session.is_active(), "duplicate winner rejection preserves active session")

	_check(session.end_session("victory", ["p2"]), "valid player winner ends session")
	_check(session.is_ended(), "completion lifecycle is ended")
	_check(session.active_participant_id.is_empty(), "ended completion clears active participant")
	_check(str(session.result.get("outcome", "")) == "victory", "completion outcome is explicit")
	var winners: Array = session.result.get("winner_participant_ids", [])
	_check(winners == ["p2"], "completion winner list is explicit")

	var ended_snapshot := session.to_dictionary()
	_check(ended_snapshot.get("lifecycle") == "ended", "ended lifecycle serializes explicitly")
	_check(not session.advance_turn("p2"), "ended session rejects gameplay turn transition")
	_check(not session.start_session(), "ended session rejects restart transition")
	_check(not session.end_session("draw"), "ended session rejects second completion")
	_check(session.to_dictionary() == ended_snapshot, "rejected ended transitions preserve state")

	var draw: SessionState = SESSION_STATE.create_lobby("sess-draw")
	_check(draw.assign_participant("p1", "seat-1", "player"), "draw player assigned")
	_check(draw.start_session(), "draw session starts")
	_check(draw.end_session("draw"), "draw may end without winners")
	_check((draw.result.get("winner_participant_ids", []) as Array).is_empty(), "draw winners stay empty")
