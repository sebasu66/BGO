class_name GameplayStateTest
extends RefCounted

const GAMEPLAY_STATE = preload("res://src/core/gameplay_state.gd")
const LOGICAL_OBJECT_STATE = preload("res://src/core/logical_object_state.gd")
const SESSION_STATE = preload("res://src/core/session_state.gd")
const TABLETOP_STATE = preload("res://src/core/tabletop_state.gd")


## Runs focused gameplay command tests using the shared assertion callback.
static func run(check: Callable) -> void:
	_test_validated_moves(check)
	_test_grid_placements(check)
	_test_hand_transitions(check)
	_test_asset_box_transfers(check)
	_test_hand_and_area_commands(check)
	_test_box_commands(check)
	_test_turn_flow_and_convergence(check)


static func _test_validated_moves(check: Callable) -> void:
	var game := _create_fixture()
	var before := game.to_dictionary()
	var wrong_turn := game.move_object("p2", "p2-piece", "board:c")
	check.call(not bool(wrong_turn.get("ok", false)), "wrong-turn move is rejected")
	check.call(game.to_dictionary() == before, "wrong-turn rejection preserves gameplay state")

	var host_override := game.move_object("p1", "p2-piece", "board:c")
	check.call(bool(host_override.get("ok", false)), "host can control another player's object")
	check.call(
		game.objects["p2-piece"].location_id == "board:c", "host override updates object location"
	)

	var neutral_game := _create_fixture()
	var neutral_before := neutral_game.to_dictionary()
	var neutral_denied := neutral_game.move_object("p1", "neutral", "board:c")
	check.call(not bool(neutral_denied.get("ok", false)), "neutral move requires explicit acquire")
	check.call(
		neutral_game.to_dictionary() == neutral_before, "neutral denial preserves gameplay state"
	)

	var neutral_move := neutral_game.move_object("p1", "neutral", "board:c", true)
	check.call(
		bool(neutral_move.get("ok", false)), "active player can explicitly acquire neutral object"
	)
	var neutral: LogicalObjectState = neutral_game.objects["neutral"]
	check.call(neutral.owner_id.is_empty(), "neutral acquisition does not change ownership")
	check.call(neutral.holder_id == "p1", "neutral acquisition assigns holder")
	check.call(neutral.location_id == "board:c", "successful move updates logical object location")
	check.call(
		neutral_game.tabletop.object_slot("neutral") == "board:c",
		"successful move updates occupancy"
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
		check.call(
			bool(first_result.get("ok", false)), "first client accepts deterministic turn command"
		)
		check.call(
			bool(second_result.get("ok", false)), "second client accepts deterministic turn command"
		)
		check.call(first_result == second_result, "accepted command results are deterministic")
		check.call(
			first.to_dictionary() == second.to_dictionary(),
			"logical clients converge after command"
		)

	var before_rejected := first.to_dictionary()
	var rejected := first.move_and_end_turn("p2", "p2-piece", "board:b")
	check.call(not bool(rejected.get("ok", false)), "rejected move does not complete a turn")
	check.call(first.to_dictionary() == before_rejected, "rejected turn command preserves state")


static func _test_grid_placements(check: Callable) -> void:
	var session: SessionState = SESSION_STATE.create_lobby("grid-game", "p1")
	session.assign_participant("p1", "seat-1", "player")
	session.assign_participant("p2", "seat-2", "player")
	session.start_session()

	var table: TabletopState = TABLETOP_STATE.new()
	table.configure_grid(6, 6, Vector2(5.0, 5.0))
	var game: GameplayState = GAMEPLAY_STATE.create(session, table)
	check.call(
		game.add_object_at_grid(
			LOGICAL_OBJECT_STATE.create("grid-piece", "p1"), Vector2i(1, 1), Vector2i(2, 1)
		),
		"game object can be added with a grid footprint"
	)
	check.call(
		game.add_object_at_grid(LOGICAL_OBJECT_STATE.create("other-piece", "p2"), Vector2i(4, 4)),
		"second game object can use another grid origin"
	)
	var blocked := game.move_object_at_grid("p1", "grid-piece", Vector2i(4, 4))
	check.call(not bool(blocked.get("ok", false)), "grid move rejects an occupied destination")
	var moved := game.move_object_at_grid("p1", "grid-piece", Vector2i(2, 2), Vector2i(2, 2))
	check.call(bool(moved.get("ok", false)), "grid move accepts a free destination")
	check.call(
		(
			game.objects["grid-piece"].grid_points()
			== [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]
		),
		"grid move updates the object's footprint"
	)


static func _test_asset_box_transfers(check: Callable) -> void:
	var session: SessionState = SESSION_STATE.create_lobby("box-game", "p1")
	session.assign_participant("p1", "seat-1", "player")
	session.assign_participant("p2", "seat-2", "player")
	session.start_session()
	var table: TabletopState = TABLETOP_STATE.new()
	table.configure_grid(6, 6, Vector2(5.0, 5.0))
	table.configure_asset_box("game_box", 4, 3, Vector2(5.0, 5.0))
	var game: GameplayState = GAMEPLAY_STATE.create(session, table)
	var reserve := LOGICAL_OBJECT_STATE.create("reserve-token")
	reserve.availability_mode = "finite"
	reserve.available_quantity = 8
	check.call(
		game.add_object_to_box(
			reserve, "bgo.piece.basic_cylinder", {"color_source": "fixed"}, 8, Vector2i(1, 1)
		),
		"game object can be added to the asset box"
	)
	check.call(reserve.location_type == "asset_box", "asset-box location is explicit")
	check.call(game.asset_box.has_asset("reserve-token"), "game state tracks box contents")
	check.call(
		game.asset_box.get_asset("reserve-token").get("availability") == "finite",
		"asset box preserves quantity availability policy"
	)
	check.call(
		int(game.asset_box.get_asset("reserve-token").get("available_quantity", 0)) == 8,
		"asset box preserves available quantity"
	)
	var taken := game.take_object_from_box(
		"p1", "reserve-token", Vector2i(2, 2), Vector2i.ONE, false, true
	)
	check.call(bool(taken.get("ok", false)), "asset can be taken from the box to the table")
	check.call(reserve.location_type == "grid", "taken asset is now on the table grid")
	check.call(not game.asset_box.has_asset("reserve-token"), "taken asset leaves the box")
	var stored := game.store_object_in_box(
		"p1", "reserve-token", Vector2i(0, 0), Vector2i.ONE, false, true
	)
	check.call(bool(stored.get("ok", false)), "table asset can return to the box")
	check.call(reserve.location_type == "asset_box", "returned asset is in the box")
	check.call(game.asset_box.has_asset("reserve-token"), "returned asset is available in the box")


static func _test_hand_transitions(check: Callable) -> void:
	var game := _create_fixture()
	var picked := game.pickup_object_to_hand("p1", "p1-piece")
	check.call(bool(picked.get("ok", false)), "owned object can enter the logical hand")
	check.call(game.objects["p1-piece"].location_type == "hand", "pickup updates hand location")
	check.call(game.hand_for("p1").top_object_id() == "p1-piece", "hand exposes FILO selection")
	var placed := game.place_object_from_hand("p1", "p1-piece", "board:b")
	check.call(bool(placed.get("ok", false)), "selected hand object can be placed")
	check.call(not game.hand_for("p1").contains("p1-piece"), "placed object leaves the hand")
	check.call(game.objects["p1-piece"].location_id == "board:b", "placing updates object location")


static func _command(
	verb: String, actor: String, target: String, args: Dictionary = {}
) -> Dictionary:
	return {"verb": verb, "actor_id": actor, "target_id": target, "args": args}


static func _test_hand_and_area_commands(check: Callable) -> void:
	var game := _create_fixture()
	var picked := game.execute(
		_command("object.move_to_collection", "p1", "p1-piece", {"collection": "hand"})
	)
	check.call(bool(picked.get("ok", false)), "command picks an object up into the hand")
	var placed := game.execute(_command("object.move", "p1", "p1-piece", {"slot_id": "board:b"}))
	check.call(bool(placed.get("ok", false)), "object.move places a hand object on the table")
	var piece: LogicalObjectState = game.objects["p1-piece"]
	check.call(
		piece.location_type == "slot" and piece.location_id == "board:b",
		"placed hand object sits in the slot"
	)
	check.call(not game.hand_for("p1").contains("p1-piece"), "command placement empties the hand")
	check.call(piece.holder_id.is_empty(), "placing from the hand releases the holder")
	check.call(
		game.tabletop.object_slot("p1-piece") == "board:b",
		"placing from the hand updates occupancy"
	)
	var event: Dictionary = (placed["events"] as Array)[0]
	check.call(
		str(event["data"]["from_type"]) == "hand", "placement event reports the hand as its source"
	)

	game.execute(_command("object.move_to_collection", "p1", "p1-piece", {"collection": "hand"}))
	var before := game.to_dictionary()
	var blocked := game.execute(_command("object.move", "p1", "p1-piece", {"slot_id": "board:d"}))
	check.call(
		not bool(blocked.get("ok", false)), "placing from the hand on an occupied slot is rejected"
	)
	check.call(game.to_dictionary() == before, "rejected placement leaves the hand untouched")

	var area_game := _create_fixture()
	var into_area := area_game.execute(
		_command("object.move_to_collection", "p1", "p1-piece", {"collection": "player_area"})
	)
	check.call(bool(into_area.get("ok", false)), "command moves an object into a player area")
	check.call(
		area_game.objects["p1-piece"].location_type == "player_area", "object is in the player area"
	)
	var out_of_area := area_game.execute(
		_command("object.move", "p1", "p1-piece", {"slot_id": "board:c"})
	)
	check.call(
		bool(out_of_area.get("ok", false)), "object.move takes an object out of a player area"
	)
	check.call(
		area_game.objects["p1-piece"].location_id == "board:c", "object left the area for the slot"
	)
	check.call(
		area_game.objects["p1-piece"].holder_id.is_empty(), "leaving an area releases the holder"
	)

	var hand_game := _create_fixture()
	hand_game.pickup_object_to_hand("p1", "p1-piece")
	hand_game.pickup_object_to_hand("p1", "neutral", true)
	check.call(
		hand_game.hand_for("p1").to_array() == ["neutral", "p1-piece"],
		"newest object is on top of the hand"
	)
	var reordered := hand_game.execute(
		_command("object.reorder_in_hand", "p1", "p1-piece", {"index": 0})
	)
	check.call(bool(reordered.get("ok", false)), "owner can reorder their own hand")
	check.call(
		hand_game.hand_for("p1").to_array() == ["p1-piece", "neutral"],
		"reorder changes the hand order"
	)
	var reorder_event: Dictionary = (reordered["events"] as Array)[0]
	check.call(str(reorder_event["type"]) == "hand.reordered", "reorder emits hand.reordered")
	var hand_before := hand_game.to_dictionary()
	var bad_index := hand_game.execute(
		_command("object.reorder_in_hand", "p1", "p1-piece", {"index": 5})
	)
	check.call(not bool(bad_index.get("ok", false)), "reorder rejects an index outside the hand")
	check.call(
		hand_game.to_dictionary() == hand_before, "rejected reorder leaves the hand untouched"
	)
	var not_mine := hand_game.execute(
		_command("object.reorder_in_hand", "p2", "p1-piece", {"index": 1})
	)
	check.call(not bool(not_mine.get("ok", false)), "nobody can reorder another player's hand")

	hand_game.add_object(LOGICAL_OBJECT_STATE.create("p2-extra", "p2"), "board:c")
	hand_game.pickup_object_to_hand("p2", "p2-piece")
	hand_game.pickup_object_to_hand("p2", "p2-extra")
	var out_of_turn := hand_game.execute(
		_command("object.reorder_in_hand", "p2", "p2-piece", {"index": 0})
	)
	check.call(bool(out_of_turn.get("ok", false)), "hand can be reordered out of turn")
	check.call(
		hand_game.hand_for("p2").to_array() == ["p2-piece", "p2-extra"],
		"out-of-turn reorder applies"
	)


static func _test_box_commands(check: Callable) -> void:
	var session: SessionState = SESSION_STATE.create_lobby("box-commands", "p1")
	session.assign_participant("p1", "seat-1", "player")
	session.assign_participant("p2", "seat-2", "player")
	session.start_session()
	var table: TabletopState = TABLETOP_STATE.new()
	table.configure_grid(6, 6, Vector2(5.0, 5.0))
	table.configure_asset_box("game_box", 4, 3, Vector2(5.0, 5.0))
	var game: GameplayState = GAMEPLAY_STATE.create(session, table)
	var token := LOGICAL_OBJECT_STATE.create("box-token")
	game.add_object_to_box(token, "bgo.piece.basic_cylinder", {}, 1)

	var no_claim := game.execute(
		_command("object.take_from_box", "p1", "box-token", {"origin_x": 2, "origin_y": 2})
	)
	check.call(
		not bool(no_claim.get("ok", false)), "taking a neutral object needs an explicit claim"
	)
	var half_origin := game.execute(
		_command(
			"object.take_from_box", "p1", "box-token", {"origin_x": 2, "acquire_neutral": true}
		)
	)
	check.call(not bool(half_origin.get("ok", false)), "an origin needs both x and y")
	var missing := game.execute(
		_command("object.take_from_box", "p1", "nothing", {"acquire_neutral": true})
	)
	check.call(not bool(missing.get("ok", false)), "taking an unknown object is rejected")
	check.call(game.asset_box.has_asset("box-token"), "rejected takes leave the box untouched")

	var taken := game.execute(
		_command(
			"object.take_from_box",
			"p1",
			"box-token",
			{"origin_x": 2, "origin_y": 2, "acquire_neutral": true}
		)
	)
	check.call(bool(taken.get("ok", false)), "object.take_from_box moves an object to the table")
	check.call(
		token.location_type == "grid" and token.location_id == "grid:2:2",
		"taken object sits on the requested cell"
	)
	check.call(not game.asset_box.has_asset("box-token"), "taken object leaves the box")
	var take_event: Dictionary = (taken["events"] as Array)[0]
	check.call(str(take_event["type"]) == "object.moved", "taking emits object.moved")
	check.call(
		str(take_event["data"]["from_type"]) == "asset_box",
		"take event reports the box as its source"
	)

	var returned := game.execute(_command("object.return_to_box", "p1", "box-token"))
	check.call(bool(returned.get("ok", false)), "object.return_to_box stores an object back")
	check.call(token.location_type == "asset_box", "returned object is in the box")
	check.call(game.asset_box.has_asset("box-token"), "box lists the returned object")
	var return_event: Dictionary = (returned["events"] as Array)[0]
	check.call(
		str(return_event["data"]["to_type"]) == "asset_box",
		"return event reports the box as its target"
	)


static func _create_fixture() -> GameplayState:
	var session: SessionState = SESSION_STATE.create_lobby("gameplay", "p1")
	session.assign_participant("p1", "seat-1", "player")
	session.assign_participant("p2", "seat-2", "player")
	session.start_session()

	var table: TabletopState = TABLETOP_STATE.new()
	table.add_section("main")
	table.add_zone("board", "main")
	for slot_id in ["board:a", "board:b", "board:c", "board:d", "board:e"]:
		table.add_slot(slot_id, "board", 1)

	var game: GameplayState = GAMEPLAY_STATE.create(session, table)
	game.add_object(LOGICAL_OBJECT_STATE.create("p1-piece", "p1"), "board:a")
	game.add_object(LOGICAL_OBJECT_STATE.create("p2-piece", "p2"), "board:d")
	game.add_object(LOGICAL_OBJECT_STATE.create("neutral"), "board:e")
	return game
