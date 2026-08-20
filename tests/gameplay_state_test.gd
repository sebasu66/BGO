class_name GameplayStateTest
extends RefCounted

const GAMEPLAY_STATE = preload("res://src/core/gameplay_state.gd")
const LOGICAL_OBJECT_STATE = preload("res://src/core/logical_object_state.gd")
const SESSION_STATE = preload("res://src/core/session_state.gd")
const TABLETOP_STATE = preload("res://src/core/tabletop_state.gd")


## Runs focused gameplay command tests using the shared assertion callback.
static func run(check: Callable) -> void:
	_test_validated_moves(check)
	_test_turn_flow_and_convergence(check)


static func _test_validated_moves(check: Callable) -> void:
	var game := _create_fixture()
	var before := game.to_dictionary()
	var wrong_turn := game.move_object("p2", "p2-piece", "board:c")
	check.call(not bool(wrong_turn.get("ok", false)), "wrong-turn move is rejected")
	(
		check
		. call(
			game.to_dictionary() == before,
			"wrong-turn rejection preserves gameplay state",
		)
	)

	var unauthorized := game.move_object("p1", "p2-piece", "board:c")
	(
		check
		. call(
			not bool(unauthorized.get("ok", false)),
			"other player's object is rejected",
		)
	)
	(
		check
		. call(
			game.to_dictionary() == before,
			"ownership rejection preserves gameplay state",
		)
	)

	var neutral_denied := game.move_object("p1", "neutral", "board:c")
	(
		check
		. call(
			not bool(neutral_denied.get("ok", false)),
			"neutral move requires explicit acquire",
		)
	)
	(
		check
		. call(
			game.to_dictionary() == before,
			"neutral denial preserves gameplay state",
		)
	)

	var neutral_move := game.move_object("p1", "neutral", "board:c", true)
	(
		check
		. call(
			bool(neutral_move.get("ok", false)),
			"active player can explicitly acquire neutral object",
		)
	)
	var neutral: LogicalObjectState = game.objects["neutral"]
	check.call(neutral.owner_id.is_empty(), "neutral acquisition does not change ownership")
	check.call(neutral.holder_id == "p1", "neutral acquisition assigns holder")
	(
		check
		. call(
			neutral.location_id == "board:c",
			"successful move updates logical object location",
		)
	)
	(
		check
		. call(
			game.tabletop.object_slot("neutral") == "board:c",
			"successful move updates occupancy",
		)
	)


static func _test_turn_flow_and_convergence(check: Callable) -> void:
	var first := _create_fixture()
	var second := _create_fixture()
	var commands := [
		["p1", "p1-piece", "board:c"],
		["p2", "p2-piece", "board:a"],
		["p1", "p1-piece", "board:b"],
	]
	for command in commands:
		var first_result := first.move_and_end_turn(command[0], command[1], command[2])
		var second_result := second.move_and_end_turn(command[0], command[1], command[2])
		(
			check
			. call(
				bool(first_result.get("ok", false)),
				"first client accepts deterministic turn command",
			)
		)
		(
			check
			. call(
				bool(second_result.get("ok", false)),
				"second client accepts deterministic turn command",
			)
		)
		(
			check
			. call(
				first_result == second_result,
				"accepted command results are deterministic",
			)
		)
		(
			check
			. call(
				first.to_dictionary() == second.to_dictionary(),
				"logical clients converge after command",
			)
		)

	var before_rejected := first.to_dictionary()
	var rejected := first.move_and_end_turn("p2", "p2-piece", "board:c")
	(
		check
		. call(
			not bool(rejected.get("ok", false)),
			"rejected move does not complete a turn",
		)
	)
	(
		check
		. call(
			first.to_dictionary() == before_rejected,
			"rejected turn command preserves state",
		)
	)


static func _create_fixture() -> GameplayState:
	var session: SessionState = SESSION_STATE.create_lobby("gameplay", "p1")
	session.assign_participant("p1", "seat-1", "player")
	session.assign_participant("p2", "seat-2", "player")
	session.start_session()

	var table: TabletopState = TABLETOP_STATE.new()
	table.add_section("main")
	table.add_zone("board", "main")
	for slot_id in ["board:a", "board:b", "board:c", "board:d"]:
		table.add_slot(slot_id, "board", 1)

	var game: GameplayState = GAMEPLAY_STATE.create(session, table)
	game.add_object(LOGICAL_OBJECT_STATE.create("p1-piece", "p1"), "board:a")
	game.add_object(LOGICAL_OBJECT_STATE.create("p2-piece", "p2"), "board:d")
	game.add_object(LOGICAL_OBJECT_STATE.create("neutral"), "board:b")
	return game
