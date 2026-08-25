class_name SandboxStateTest
extends RefCounted


static func run(check: Callable) -> void:
	var loaded := BgoGameDefinitionLoader.load_game_id("table_debug")
	check.call(bool(loaded.get("ok", false)), "sandbox definition loads without flow or board")
	if not bool(loaded.get("ok", false)):
		return
	var sandbox := SandboxState.create(loaded.get("data", {}))
	check.call(sandbox != null, "sandbox state initializes locally")
	check.call(sandbox.to_dictionary().get("persistent") == false, "sandbox is non-persistent")
	var spawned := (
		sandbox
		. execute(
			{
				"verb": "sandbox.spawn",
				"args":
				{
					"object_id": "authoring-piece",
					"component_id": "bgo.piece.basic_cylinder",
					"owner_id": "player_1",
				},
			}
		)
	)
	check.call(bool(spawned.get("ok", false)), "sandbox spawns a registered component")
	(
		check
		. call(
			bool(
				(
					sandbox
					. execute(
						{
							"verb": "sandbox.move_free",
							"target_id": "authoring-piece",
							"args":
							{
								"zone_id": "pieces_only",
								"pose":
								{
									"position": {"x": -4, "y": 0, "z": 2.7},
									"rotation": {"x": 0, "y": 0, "z": 0},
								},
							},
						}
					)
					. get("ok", false)
				)
			),
			"sandbox freely places compatible objects",
		)
	)
	check.call(bool(sandbox.save_snapshot("initial").get("ok")), "sandbox saves a named snapshot")
	(
		sandbox
		. execute(
			{
				"verb": "sandbox.set_property",
				"target_id": "authoring-piece",
				"args": {"name": "locked", "value": true},
			}
		)
	)
	(
		sandbox
		. execute(
			{
				"verb": "sandbox.set_score",
				"args": {"player_id": "player_1", "track": "points", "value": 12},
			}
		)
	)
	check.call(bool(sandbox.restore_snapshot("initial").get("ok")), "sandbox restores a snapshot")
	(
		check
		. call(
			not (sandbox.objects["authoring-piece"] as LogicalObjectState).properties.has("locked"),
			"snapshot restore replaces later object changes",
		)
	)
	(
		check
		. call(
			not (sandbox.scores["player_1"] as Dictionary).has("points"),
			"snapshot restore replaces later score changes",
		)
	)
	var exported := sandbox.export_initial_state()
	(
		check
		. call(
			((exported.get("setup", {}) as Dictionary).get("objects", []) as Array).size() == 1,
			"sandbox exports authored objects as initial state",
		)
	)
