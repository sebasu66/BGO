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

	_check(not session.start_session("missing"), "start rejects unknown participant")
	_check(session.start_session("host-a"), "session can start with seated host")
	_check(session.is_active(), "started session is active")
	_check(session.lifecycle == SESSION_STATE.Lifecycle.ACTIVE, "lifecycle becomes active")
	_check(session.active_participant_id == "host-a", "active player is represented")
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
