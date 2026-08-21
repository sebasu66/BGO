class_name ConformanceGameTest
extends RefCounted

const FIXTURE_PATH := "res://games/conformance_race/game.jsonh"


static func run(check: Callable) -> void:
	var loaded := BgoGameDefinitionLoader.load_game(FIXTURE_PATH)
	if not bool(loaded.get("ok", false)):
		printerr("Conformance validation errors: %s" % [loaded.get("errors", [])])
	check.call(bool(loaded.get("ok", false)), "complete conformance game definition loads")
	if not bool(loaded.get("ok", false)):
		return
	var data: Dictionary = loaded.get("data", {})
	var game := _build_game(data)
	check.call(game != null, "complete game builds from declarative setup")
	if game == null:
		return
	var before_invalid := game.to_dictionary()
	var invalid := game.execute({
		"verb": "object.move", "actor_id": "player_2", "target_id": "player_2_piece",
		"args": {"slot_id": "board:1:1"}
	})
	check.call(not bool(invalid.get("ok", false)), "out-of-turn command is rejected")
	check.call(game.to_dictionary() == before_invalid, "rejected command preserves state")
	for command in (data.get("conformance", {}) as Dictionary).get("commands", []):
		var result := game.execute(command)
		check.call(bool(result.get("ok", false)), "declared conformance command succeeds")
	check.call(game.session.is_ended(), "fixture reaches explicit completion")
	check.call(game.session.result.get("winner_participant_ids", []) == ["player_1"], "winner is explicit")
	check.call(game.tabletop.object_slot("player_1_piece") == "board:2:0", "final position is deterministic")


static func _build_game(data: Dictionary) -> GameplayState:
	var players: Array = data.get("players", [])
	var host_id := str(players[0].get("id", ""))
	var session := SessionState.create_lobby("conformance-race", host_id)
	var player_ids: Array[String] = []
	for index in players.size():
		var participant_id := str(players[index].get("id", ""))
		player_ids.append(participant_id)
		if not session.assign_participant(participant_id, "seat-%d" % (index + 1), "player"):
			return null
	if not session.start_session():
		return null
	var flow_definition: Dictionary = data.get("flow", {})
	var flow := FlowState.create(player_ids, str(flow_definition.get("initial_phase", "main")))
	if not flow.start():
		return null
	var table := TabletopState.new()
	table.add_section("main")
	table.add_zone("board", "main")
	var board_config: Dictionary = (data.get("board", {}) as Dictionary).get("config", {})
	for y in int(board_config.get("rows", 0)):
		for x in int(board_config.get("columns", 0)):
			table.add_slot("board:%d:%d" % [x, y], "board", 1)
	var game := GameplayState.create(session, flow, table, data.get("listeners", []))
	for definition in (data.get("setup", {}) as Dictionary).get("objects", []):
		var object := LogicalObjectState.create(
			str(definition.get("id", "")), str(definition.get("component", "")),
			str(definition.get("owner_id", "")), int(definition.get("quantity", 1))
		)
		var location: Dictionary = definition.get("initial_location", {})
		if not game.add_object(object, str(location.get("slot_id", ""))):
			return null
	return game
