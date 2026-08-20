class_name ConformanceGameTest
extends RefCounted

const GAME_DEFINITION_LOADER = preload("res://src/core/game_definition_loader.gd")
const GAMEPLAY_STATE = preload("res://src/core/gameplay_state.gd")
const LOGICAL_OBJECT_STATE = preload("res://src/core/logical_object_state.gd")
const SESSION_STATE = preload("res://src/core/session_state.gd")
const TABLETOP_STATE = preload("res://src/core/tabletop_state.gd")

const FIXTURE_PATH := "res://games/conformance_race/game.jsonh"


## Plays the declarative conformance fixture from setup to explicit result.
static func run(check: Callable) -> void:
	var loaded := GAME_DEFINITION_LOADER.load_game(FIXTURE_PATH)
	check.call(bool(loaded.get("ok", false)), "complete conformance game definition loads")
	if not bool(loaded.get("ok", false)):
		return
	var data: Dictionary = loaded.get("data", {})
	var game := _build_game(data)
	check.call(game != null, "complete conformance game builds from declarative setup")
	if game == null:
		return

	var before_invalid := game.to_dictionary()
	var invalid := game.move_and_end_turn("player_2", "player_2_piece", "board:1:1")
	(
		check
		. call(
			not bool(invalid.get("ok", false)),
			"fixture rejects an invalid out-of-turn move",
		)
	)
	(
		check
		. call(
			game.to_dictionary() == before_invalid,
			"invalid fixture move preserves state",
		)
	)

	var conformance: Dictionary = data.get("conformance", {})
	for turn in conformance.get("turns", []):
		var result := (
			game
			. move_and_end_turn(
				str(turn.get("participant_id", "")),
				str(turn.get("object_id", "")),
				str(turn.get("to_slot_id", "")),
			)
		)
		check.call(bool(result.get("ok", false)), "fixture accepts declared legal turn")

	var completion: Dictionary = conformance.get("completion", {})
	var winners: Array = completion.get("winner_participant_ids", [])
	(
		check
		. call(
			game.session.end_session(str(completion.get("outcome", "")), winners),
			"fixture reaches explicit game completion",
		)
	)
	check.call(game.session.is_ended(), "complete fixture session is ended")
	(
		check
		. call(
			game.session.result.get("winner_participant_ids", []) == ["player_1"],
			"fixture winner is explicit",
		)
	)
	(
		check
		. call(
			game.tabletop.object_slot("player_1_piece") == "board:2:0",
			"winning piece reaches declared final slot",
		)
	)


static func _build_game(data: Dictionary) -> GameplayState:
	var players: Array = data.get("players", [])
	if players.is_empty():
		return null
	var first_player_id := str(players[0].get("id", ""))
	var session: SessionState = SESSION_STATE.create_lobby("conformance-race", first_player_id)
	for index in players.size():
		var player: Dictionary = players[index]
		(
			session
			. assign_participant(
				str(player.get("id", "")),
				"seat-%d" % (index + 1),
				"player",
			)
		)
	if not session.start_session():
		return null

	var table: TabletopState = TABLETOP_STATE.new()
	table.add_section("main")
	table.add_zone("board", "main")
	var board: Dictionary = data.get("board", {})
	var config: Dictionary = board.get("config", {})
	for y in int(config.get("rows", 0)):
		for x in int(config.get("columns", 0)):
			table.add_slot("board:%d:%d" % [x, y], "board", 1)

	var game: GameplayState = GAMEPLAY_STATE.create(session, table)
	var setup: Dictionary = data.get("setup", {})
	for object_def in setup.get("objects", []):
		var object := (
			LOGICAL_OBJECT_STATE
			. create(
				str(object_def.get("id", "")),
				str(object_def.get("owner_id", "")),
			)
		)
		var location: Dictionary = object_def.get("initial_location", {})
		if not game.add_object(object, str(location.get("slot_id", ""))):
			return null
	return game
