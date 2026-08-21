class_name RuntimeSessionAdapterTest
extends RefCounted

const RUNTIME_SESSION_ADAPTER = preload("res://src/demo/runtime_session_adapter.gd")


## Runs focused tests for the runtime-to-domain adapter boundary.
static func run(check: Callable) -> void:
	_test_load_and_command_boundary(check)
	_test_explicit_turn_control(check)
	_test_ended_session_controls(check)
	_test_reconnect_and_stale_remote_state(check)


static func _test_load_and_command_boundary(check: Callable) -> void:
	var adapter := RUNTIME_SESSION_ADAPTER.new()
	var loaded := adapter.load_session("runtime-test", _game_definition(), _repository_state())
	check.call(bool(loaded.get("ok", false)), "runtime adapter loads logical gameplay state")
	check.call(adapter.active_participant_id() == "p1", "runtime adapter exposes active player")
	check.call(adapter.turn_number() == 1, "runtime adapter exposes turn number")

	var before_rejected := adapter.snapshot()
	var wrong_turn := adapter.move_object_to_collection("p2", "p2-piece", "player_area")
	check.call(not bool(wrong_turn.get("ok", false)), "runtime adapter rejects non-active player")
	check.call(adapter.snapshot() == before_rejected, "rejected runtime command preserves state")
	check.call(adapter.state_revision == 0, "rejected runtime command preserves revision")

	var pickup := adapter.move_object_to_collection("p1", "p1-piece", "player_area")
	check.call(bool(pickup.get("ok", false)), "accepted runtime pickup updates logical state")
	check.call(adapter.state_revision == 1, "accepted runtime command increments revision")
	var pickup_patch: Dictionary = pickup.get("persistence_patch", {})
	check.call(
		int(pickup_patch.get("state_revision", 0)) == 1,
		"accepted command exposes persistence revision"
	)
	(
		check
		. call(
			(
				pickup_patch.get("pieces/p1-piece/location")
				== {
					"type": "player_area",
					"player_id": "p1",
				}
			),
			"pickup persistence is derived from logical location",
		)
	)

	var to_hand := adapter.move_object_to_collection("p1", "p1-piece", "hand")
	check.call(
		bool(to_hand.get("ok", false)), "runtime adapter keeps hand distinct from player area"
	)
	check.call(adapter.state_revision == 2, "second accepted command increments revision")

	var placed := adapter.move_object_and_end_turn("p1", "p1-piece", "board:2:0")
	check.call(bool(placed.get("ok", false)), "accepted placement completes active turn")
	check.call(adapter.active_participant_id() == "p2", "accepted turn exposes next active player")
	check.call(adapter.turn_number() == 2, "accepted turn exposes advanced turn number")
	var place_patch: Dictionary = placed.get("persistence_patch", {})
	var session_patch: Dictionary = place_patch.get("session", {})
	(
		check
		. call(
			str(session_patch.get("active_participant_id", "")) == "p2",
			"turn persistence carries next active player",
		)
	)
	check.call(
		int(session_patch.get("turn_number", 0)) == 2, "turn persistence carries turn number"
	)
	(
		check
		. call(
			(
				place_patch.get("pieces/p1-piece/location")
				== {
					"type": "slot",
					"slot_id": "board:2:0",
				}
			),
			"placement persistence carries logical slot",
		)
	)


static func _test_explicit_turn_control(check: Callable) -> void:
	var adapter := RUNTIME_SESSION_ADAPTER.new()
	adapter.load_session("runtime-test", _game_definition(), _repository_state())
	var before := adapter.snapshot()
	var rejected := adapter.end_turn("p2", "not allowed")
	check.call(not bool(rejected.get("ok", false)), "non-active player cannot complete turn")
	check.call(adapter.snapshot() == before, "rejected turn control preserves runtime state")
	check.call(adapter.state_revision == 0, "rejected turn control preserves revision")

	var accepted := adapter.end_turn("p1", " ready ")
	check.call(bool(accepted.get("ok", false)), "active player can complete turn explicitly")
	check.call(adapter.active_participant_id() == "p2", "explicit turn control advances player")
	check.call(adapter.turn_number() == 2, "explicit turn control advances turn number")
	check.call(adapter.state_revision == 1, "explicit turn control increments revision")
	var event: Dictionary = accepted.get("event", {})
	check.call(event.get("comment", "") == "ready", "explicit turn comment is normalized")
	var patch: Dictionary = accepted.get("persistence_patch", {})
	var session_patch: Dictionary = patch.get("session", {})
	check.call(
		str(session_patch.get("active_participant_id", "")) == "p2",
		"explicit turn persistence carries active player"
	)
	check.call(
		int(session_patch.get("turn_number", 0)) == 2,
		"explicit turn persistence carries turn number"
	)


static func _test_ended_session_controls(check: Callable) -> void:
	var repository_state := _repository_state()
	repository_state["state_revision"] = 7
	repository_state["session"] = {
		"session_id": "runtime-test",
		"lifecycle": "ended",
		"host_participant_id": "p1",
		"seat_order": ["seat-1", "seat-2"],
		"participant_seats": {"p1": "seat-1", "p2": "seat-2"},
		"participant_roles": {"p1": "player", "p2": "player"},
		"active_participant_id": "",
		"turn_number": 4,
		"result":
		{
			"outcome": "victory",
			"winner_participant_ids": ["p2"],
		},
	}
	var adapter := RUNTIME_SESSION_ADAPTER.new()
	var loaded := adapter.load_session("runtime-test", _game_definition(), repository_state)
	check.call(bool(loaded.get("ok", false)), "ended session loads through runtime adapter")
	check.call(adapter.is_session_ended(), "runtime adapter exposes ended lifecycle")
	check.call(
		adapter.session_result().get("winner_participant_ids", []) == ["p2"],
		"runtime adapter exposes ended-session winner"
	)
	var before := adapter.snapshot()
	var rejected := adapter.end_turn("p2")
	check.call(not bool(rejected.get("ok", false)), "ended session rejects turn control")
	check.call(adapter.snapshot() == before, "ended turn rejection preserves runtime state")
	check.call(adapter.state_revision == 7, "ended turn rejection preserves revision")


static func _test_reconnect_and_stale_remote_state(check: Callable) -> void:
	var adapter := RUNTIME_SESSION_ADAPTER.new()
	adapter.load_session("runtime-test", _game_definition(), _repository_state())
	adapter.move_object_to_collection("p1", "p1-piece", "player_area")
	adapter.move_object_to_collection("p1", "p1-piece", "hand")
	var accepted := adapter.move_object_and_end_turn("p1", "p1-piece", "board:2:0")
	var accepted_snapshot := adapter.snapshot()

	var stale := _repository_state()
	stale["state_revision"] = 2
	var stale_result := adapter.load_session("runtime-test", _game_definition(), stale)
	check.call(not bool(stale_result.get("ok", false)), "older remote revision is rejected")
	check.call(
		adapter.snapshot() == accepted_snapshot,
		"stale remote state cannot overwrite accepted state"
	)

	var persisted := _repository_state()
	persisted["state_revision"] = int(accepted.get("revision", 0))
	persisted["session"] = accepted_snapshot.get("session", {})
	var pieces: Dictionary = persisted.get("pieces", {})
	var p1_piece: Dictionary = pieces.get("p1-piece", {})
	p1_piece["holder_id"] = "p1"
	p1_piece["location"] = {"type": "slot", "slot_id": "board:2:0"}
	p1_piece["cell"] = {"x": 2, "y": 0}

	var reconnected := RUNTIME_SESSION_ADAPTER.new()
	var reconnect_result := (
		reconnected
		. load_session(
			"runtime-test",
			_game_definition(),
			persisted,
		)
	)
	check.call(
		bool(reconnect_result.get("ok", false)), "persisted logical session reloads after reconnect"
	)
	check.call(reconnected.active_participant_id() == "p2", "reconnect restores active player")
	check.call(reconnected.turn_number() == 2, "reconnect restores turn number")
	check.call(reconnected.state_revision == 3, "reconnect restores logical revision")


static func _game_definition() -> Dictionary:
	return {
		"board": {"config": {"columns": 3, "rows": 2}},
		"players":
		[
			{"id": "p1", "name": "Player 1"},
			{"id": "p2", "name": "Player 2"},
		],
	}


static func _repository_state() -> Dictionary:
	return {
		"state_revision": 0,
		"pieces":
		{
			"p1-piece":
			{
				"owner_id": "p1",
				"holder_id": "",
				"location": {"type": "slot", "slot_id": "board:0:0"},
				"cell": {"x": 0, "y": 0},
			},
			"p2-piece":
			{
				"owner_id": "p2",
				"holder_id": "",
				"location": {"type": "slot", "slot_id": "board:1:1"},
				"cell": {"x": 1, "y": 1},
			},
		},
	}
