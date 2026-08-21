class_name GameplayStateTest
extends RefCounted


static func run(check: Callable) -> void:
	_test_command_protocol(check)
	_test_manual_turn_flow(check)
	_test_quantity_and_state(check)
	_test_revision_guard(check)
	_test_declarative_listener(check)


static func _test_command_protocol(check: Callable) -> void:
	var game := _fixture()
	var before := game.to_dictionary()
	var rejected := game.execute(_move("p2", "p2-piece", "board:c"))
	check.call(not bool(rejected.get("ok", false)), "inactive actor is rejected")
	check.call(game.to_dictionary() == before, "rejected command preserves state")
	var moved := game.execute(_move("p1", "p1-piece", "board:c"))
	check.call(bool(moved.get("ok", false)), "object.move succeeds through command protocol")
	check.call(game.flow.turn_number == 1, "moving never ends the turn implicitly")
	check.call(
		(moved.get("events", []) as Array)[0].get("type") == "object.moved",
		"command emits canonical past-tense event"
	)


static func _test_manual_turn_flow(check: Callable) -> void:
	var game := _fixture()
	check.call(
		bool(game.execute(_move("p1", "p1-piece", "board:c")).get("ok")), "first action succeeds"
	)
	check.call(
		bool(game.execute(_move("p1", "p1-piece", "board:a")).get("ok")),
		"same player may act repeatedly"
	)
	var ended := game.execute({"verb": "turn.end", "actor_id": "p1"})
	check.call(bool(ended.get("ok", false)), "turn ends only through turn.end")
	check.call(game.flow.active_participant_ids == ["p2"], "next participant becomes active")
	var events: Array = ended.get("events", [])
	check.call(events[0].get("type") == "turn.ended", "turn.ended is recorded")
	check.call(events[1].get("type") == "turn.started", "turn.started is recorded")


static func _test_quantity_and_state(check: Callable) -> void:
	var game := _fixture()
	var quantity := game.execute(
		{
			"verb": "object.set_quantity",
			"actor_id": "p1",
			"target_id": "p1-piece",
			"args": {"value": 100}
		}
	)
	check.call(bool(quantity.get("ok", false)), "quantity changes through a canonical verb")
	var state := game.execute(
		{
			"verb": "object.set_state",
			"actor_id": "p1",
			"target_id": "p1-piece",
			"args": {"state": "wounded"}
		}
	)
	check.call(bool(state.get("ok", false)), "semantic state changes through a canonical verb")
	var snapshot: Dictionary = game.to_dictionary()["objects"]["p1-piece"]
	check.call(snapshot.get("quantity") == 100, "quantity belongs to authoritative logical state")
	check.call(snapshot.get("state_id") == "wounded", "semantic state is serialized")


static func _test_revision_guard(check: Callable) -> void:
	var game := _fixture()
	var command := _move("p1", "p1-piece", "board:c")
	command["expected_revision"] = 0
	check.call(bool(game.execute(command).get("ok", false)), "matching revision succeeds")
	var before := game.to_dictionary()
	check.call(not bool(game.execute(command).get("ok", false)), "stale revision is rejected")
	check.call(game.to_dictionary() == before, "stale command cannot mutate state")


static func _test_declarative_listener(check: Callable) -> void:
	var game := _fixture(
		[
			{
				"id": "exhaust_after_move",
				"event": "object.moved",
				"commands":
				[
					{
						"verb": "object.set_state",
						"actor_id": "p1",
						"target_id": "p1-piece",
						"args": {"state": "exhausted"},
					}
				],
			}
		]
	)
	var result := game.execute(_move("p1", "p1-piece", "board:c"))
	check.call(bool(result.get("ok", false)), "declarative listener chain succeeds")
	check.call(
		game.objects["p1-piece"].state_id == "exhausted", "listener issues a normal state command"
	)
	check.call(
		(result.get("events", []) as Array).size() == 2,
		"listener event is recorded in the same result"
	)


static func _fixture(listeners: Array = []) -> GameplayState:
	var session := SessionState.create_lobby("gameplay", "p1")
	session.assign_participant("p1", "seat-1", "player")
	session.assign_participant("p2", "seat-2", "player")
	session.start_session()
	var flow := FlowState.create(["p1", "p2"])
	flow.start()
	var table := TabletopState.new()
	table.add_section("main")
	table.add_zone("board", "main")
	for slot_id in ["board:a", "board:b", "board:c", "board:d"]:
		table.add_slot(slot_id, "board", 1)
	var game := GameplayState.create(session, flow, table, listeners)
	game.add_object(
		LogicalObjectState.create("p1-piece", "bgo.piece.basic_cylinder", "p1"), "board:a"
	)
	game.add_object(
		LogicalObjectState.create("p2-piece", "bgo.piece.basic_cylinder", "p2"), "board:d"
	)
	game.add_object(LogicalObjectState.create("neutral", "bgo.piece.basic_cylinder"), "board:b")
	return game


static func _move(actor_id: String, object_id: String, slot_id: String) -> Dictionary:
	return {
		"verb": "object.move",
		"actor_id": actor_id,
		"target_id": object_id,
		"args": {"slot_id": slot_id}
	}
