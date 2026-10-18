class_name TableTest
extends RefCounted

const GAMEPLAY_STATE = preload("res://src/core/gameplay_state.gd")
const SESSION_STATE = preload("res://src/core/session_state.gd")
const TABLETOP_STATE = preload("res://src/core/tabletop_state.gd")
const TABLE_CONFIG_STATE = preload("res://src/components/table/table_config_state.gd")
const POSE := {"position": {"x": 0.0, "y": 0.0, "z": 0.0}, "rotation": {"x": 0, "y": 0, "z": 0}}
const HOST := "p1"
const PLAYER := "p2"


## Runs every table test using the shared assertion callback.
static func run(check: Callable) -> void:
	_test_mode_and_surface(check)
	_test_lights(check)
	_test_building_from_a_definition(check)
	_test_zone_visibility_and_anchored_slots(check)
	_test_removing_slots(check)
	_test_resizing_zones(check)
	_test_closed_mode(check)
	_test_mode_and_surface_verbs(check)
	_test_light_verbs(check)
	_test_zone_and_slot_verbs(check)
	_test_snapshot(check)
	_test_live_view(check)
	_test_texts(check)
	_test_log_and_version(check)


static func _test_mode_and_surface(check: Callable) -> void:
	var config: TableConfigState = TABLE_CONFIG_STATE.new()
	check.call(config.mode == "free", "a table starts in free mode")
	check.call(not config.set_mode("open"), "an unknown table mode is refused")
	check.call(config.set_mode("closed") and config.is_closed(), "closed mode can be set")
	check.call(not config.set_surface({"tint": "nope"}), "an unreadable tint is refused")
	check.call(not config.set_surface({"uv_scale": 0}), "a zero texture scale is refused")
	var before: Dictionary = config.surface.duplicate(true)
	var mixed_change := {"preset": "marble", "tint": "not a color"}
	check.call(not config.set_surface(mixed_change), "a half-bad surface change is refused")
	check.call(config.surface == before, "a refused surface change changes nothing")
	check.call(
		config.set_surface({"preset": "marble", "uv_scale": 2}), "a valid change is accepted"
	)
	check.call(config.surface["preset"] == "marble", "the surface keeps the new preset")


static func _test_lights(check: Callable) -> void:
	var config: TableConfigState = TABLE_CONFIG_STATE.new()
	check.call(config.add_light({"id": "key", "type": "spot", "intensity": 2}), "a light is added")
	check.call(not config.add_light({"id": "key"}), "a duplicate light id is refused")
	check.call(
		not config.add_light({"id": "x", "type": "laser"}), "an unknown light type is refused"
	)
	check.call(not config.add_light({"id": "y", "intensity": 0}), "a zero intensity is refused")
	check.call(config.remove_light("key") and config.lights.is_empty(), "a light is removed")
	check.call(not config.remove_light("key"), "removing an unknown light is refused")


static func _test_building_from_a_definition(check: Callable) -> void:
	var good_definition := {"mode": "closed", "lights": [{"id": "a"}]}
	check.call(
		TableConfigState.from_definition(good_definition) != null, "a good definition builds"
	)
	check.call(TableConfigState.from_definition({"mode": "wide"}) == null, "a bad mode is refused")


static func _test_zone_visibility_and_anchored_slots(check: Callable) -> void:
	var table := _new_table_with_zone("hand_zone", {"visibility": "private", "owner_id": "p2"})
	check.call(table.zones["hand_zone"]["visibility"] == "private", "a zone keeps its visibility")
	check.call(
		not table.add_zone("bad", "main", {"visibility": "secret"}), "bad visibility refused"
	)
	check.call(table.set_zone_visibility("hand_zone", "public"), "zone visibility can change")
	check.call(
		not table.set_zone_visibility("hand_zone", "x"), "a bad visibility change is refused"
	)
	var anchor := {"kind": "board", "id": "main", "cell": [2, -1]}
	check.call(
		table.add_slot("deck", "hand_zone", 1, {"anchor": anchor}), "an anchored slot is added"
	)
	check.call(table.slots["deck"]["anchor"]["cell"] == [2, -1], "the slot keeps its anchor cell")
	var moon_anchor := {"anchor": {"kind": "moon"}}
	check.call(
		not table.add_slot("bad", "hand_zone", 1, moon_anchor), "an unknown anchor is refused"
	)
	var short_cell := {"anchor": {"kind": "board", "cell": [1]}}
	check.call(not table.add_slot("bad", "hand_zone", 1, short_cell), "a malformed cell is refused")


static func _test_removing_slots(check: Callable) -> void:
	var table := _new_table_with_zone("area", {})
	table.add_slot("deck", "area", 1)
	table.place_object("card-1", "deck")
	check.call(not table.remove_slot("deck"), "an occupied slot cannot be removed")
	table.remove_object("card-1")
	check.call(table.remove_slot("deck"), "an empty slot is removed")


static func _test_resizing_zones(check: Callable) -> void:
	var bounds := {"center": {"x": 0, "z": 0}, "size": {"x": 4, "z": 4}}
	var table := _new_table_with_zone("sized", {"bounds": bounds})
	check.call(table.place_object_free("coin", "sized", POSE), "a free object is placed")
	check.call(table.resize_zone("sized", 6, 6), "a zone can grow")
	check.call(not table.resize_zone("sized", 0, 3), "a zero-width zone is refused")
	var far_pose := {
		"position": {"x": 2.5, "y": 0.0, "z": 0.0}, "rotation": {"x": 0, "y": 0, "z": 0}
	}
	table.place_object_free("far", "sized", far_pose)
	check.call(not table.resize_zone("sized", 2, 2), "shrinking past a placed object is refused")


static func _test_closed_mode(check: Callable) -> void:
	var table := _new_table_with_zone("area", {})
	table.add_slot("s1", "area", 1)
	table.config.set_mode("closed")
	check.call(not table.place_object_free("a", "area", POSE), "closed mode refuses free poses")
	check.call(
		not table.place_object_at_grid("b", Vector2i(0, 0)), "closed mode refuses grid drops"
	)
	check.call(table.place_object("c", "s1"), "closed mode still accepts slots")
	table.config.set_mode("free")
	check.call(table.place_object_free("a", "area", POSE), "free mode accepts free poses again")


static func _test_mode_and_surface_verbs(check: Callable) -> void:
	var game := _create_fixture()
	var accepted := game.execute(_command(HOST, "table.set_mode", {"mode": "closed"}))
	check.call(bool(accepted.get("ok", false)), "the host sets the table mode")
	check.call(game.tabletop.config.mode == "closed", "the verb changes the table mode")
	check.call(
		accepted["events"][0]["type"] == "table.mode_changed", "a mode change emits an event"
	)
	var denied := game.execute(_command(PLAYER, "table.set_mode", {"mode": "free"}))
	check.call(denied.get("reason") == "host_only", "a player cannot change the table")
	check.call(game.tabletop.config.mode == "closed", "a denied verb changes nothing")
	var wrong := game.execute(_command(HOST, "table.set_mode", {"mode": "wide"}))
	check.call(wrong.get("reason") == "invalid_mode", "a bad mode is refused with a reason")
	var surface := game.execute(_command(HOST, "table.set_surface", {"preset": "marble"}))
	check.call(bool(surface.get("ok", false)), "the host changes the surface")
	var empty := game.execute(_command(HOST, "table.set_surface", {}))
	check.call(empty.get("reason") == "nothing_to_change", "an empty surface change is refused")


static func _test_light_verbs(check: Callable) -> void:
	var game := _create_fixture()
	var added := game.execute(_command(HOST, "table.add_light", {"id": "l1", "intensity": 1.5}))
	check.call(bool(added.get("ok", false)), "the host adds a light")
	check.call(game.tabletop.config.lights.has("l1"), "the light exists in the state")
	var removed := game.execute(_command(HOST, "table.remove_light", {"id": "l1"}))
	check.call(bool(removed.get("ok", false)), "the host removes a light")
	var unknown := game.execute(_command(HOST, "table.remove_light", {"id": "l1"}))
	check.call(unknown.get("reason") == "unknown_light", "removing an unknown light says why")


static func _test_zone_and_slot_verbs(check: Callable) -> void:
	var game := _create_fixture()
	game.tabletop.add_zone("extra", "main")
	var visibility_change := {"zone_id": "extra", "visibility": "private"}
	var made_private := game.execute(_command(HOST, "zone.set_visibility", visibility_change))
	check.call(bool(made_private.get("ok", false)), "the host makes a zone private")
	var deck_slot := {"slot_id": "deck", "zone_id": "extra", "accepted_kinds": ["deck"]}
	deck_slot["anchor"] = {"kind": "board", "id": "main", "cell": [2, -1]}
	var added := game.execute(_command(HOST, "slot.add", deck_slot))
	check.call(bool(added.get("ok", false)), "the host adds a deck slot on a board cell")
	var removed := game.execute(_command(HOST, "slot.remove", {"slot_id": "deck"}))
	check.call(bool(removed.get("ok", false)), "the host removes the empty slot")
	var revision_before: int = game.revision
	game.execute(_command(HOST, "slot.remove", {"slot_id": "deck"}))
	check.call(game.revision == revision_before, "a refused verb does not advance the revision")


static func _test_snapshot(check: Callable) -> void:
	var table := _new_table_with_zone("area", {})
	table.config.set_mode("closed")
	table.config.set_surface({"preset": "marble"})
	table.config.add_light({"id": "l1", "intensity": 3})
	var snapshot := table.to_dictionary()
	var restored: TabletopState = TABLETOP_STATE.new()
	check.call(restored.load_dictionary(snapshot), "a snapshot with table settings loads")
	check.call(restored.config.mode == "closed", "the restored table keeps its mode")
	check.call(
		restored.config.surface["preset"] == "marble", "the restored table keeps its surface"
	)
	check.call(restored.config.lights.has("l1"), "the restored table keeps its lights")
	snapshot["config"] = {"mode": "wide"}
	check.call(not restored.load_dictionary(snapshot), "a snapshot with bad settings is refused")
	var older_snapshot := table.to_dictionary()
	older_snapshot.erase("config")
	check.call(restored.load_dictionary(older_snapshot), "an older snapshot still loads")


static func _test_live_view(check: Callable) -> void:
	var world := Node3D.new()
	var floor_mesh := MeshInstance3D.new()
	var view := BgoTableStateController.new(world, floor_mesh)
	var game := _create_fixture()
	game.execute(_command(HOST, "table.add_light", {"id": "lamp", "intensity": 2}))
	game.execute(_command(HOST, "table.add_light", {"id": "sun", "type": "directional"}))
	game.execute(_command(HOST, "table.set_surface", {"tint": "#ff0000"}))
	view.show_snapshot(game.to_dictionary())
	var both_lights := PackedStringArray(["lamp", "sun"])
	check.call(view.table_node().shown_light_ids() == both_lights, "the view shows every light")
	var floor_material := floor_mesh.material_override as StandardMaterial3D
	check.call(floor_material.albedo_color == Color.RED, "the view paints the floor with the tint")
	game.execute(_command(HOST, "table.remove_light", {"id": "lamp"}))
	view.show_snapshot(game.to_dictionary())
	var only_sun := PackedStringArray(["sun"])
	check.call(view.table_node().shown_light_ids() == only_sun, "the view drops a removed light")
	view.show_snapshot({"tabletop": "garbage"})
	check.call(view.table_node().shown_light_ids() == only_sun, "a garbage snapshot is ignored")
	world.free()
	floor_mesh.free()


static func _test_texts(check: Callable) -> void:
	for reason in TableTexts.known_reasons():
		for language in TableTexts.supported_languages():
			var sentence := TableTexts.sentence_for(reason, language)
			check.call(sentence != reason, "'%s' has a %s sentence" % [reason, language])
	var spanish := TableTexts.sentence_for("host_only", "es")
	check.call(spanish.begins_with("Solo"), "the Spanish sentence is the Spanish one")
	var english := TableTexts.sentence_for("host_only", "en")
	check.call(
		TableTexts.sentence_for("host_only", "fr") == english, "an unknown language uses English"
	)
	check.call(
		TableTexts.sentence_for("something_new") == "something_new",
		"an unknown reason shows itself"
	)
	var game := _create_fixture()
	var refusal := game.execute(_command(PLAYER, "table.set_mode", {"mode": "closed"}))
	var has_sentence: bool = TableTexts.known_reasons().has(str(refusal["reason"]))
	check.call(has_sentence, "every refusal the verbs give has a sentence")


static func _test_log_and_version(check: Callable) -> void:
	TableLog.command_accepted("table.set_mode", HOST)
	TableLog.command_refused("table.set_mode", PLAYER, "host_only")
	check.call(true, "the table log works even when no activity log is running")
	var manifest := FileAccess.get_file_as_string("res://src/components/table/component.jsonh")
	var contract: Dictionary = JSON.parse_string(manifest)
	check.call(str(contract.get("version", "")).count(".") == 2, "the contract carries a version")


static func _new_table_with_zone(zone_id: String, zone_definition: Dictionary) -> TabletopState:
	var table: TabletopState = TABLETOP_STATE.new()
	table.add_section("main")
	table.add_zone(zone_id, "main", zone_definition)
	return table


static func _command(actor_id: String, verb: String, args: Dictionary) -> Dictionary:
	return {"verb": verb, "actor_id": actor_id, "args": args}


static func _create_fixture() -> GameplayState:
	var session: SessionState = SESSION_STATE.create_lobby("table", HOST)
	session.assign_participant(HOST, "seat-1", "player")
	session.assign_participant(PLAYER, "seat-2", "player")
	session.start_session()
	var table: TabletopState = TABLETOP_STATE.new()
	table.add_section("main")
	return GAMEPLAY_STATE.create(session, table)
