extends RefCounted
# gdlint: disable=max-line-length

const TEST_GAME_PATH := "res://games/test001/game.jsonh"
const ROUND_TRIP_PATH := "user://tests/fluent_test001.json"
const PROJECT_ROUND_TRIP_PATH := "res://games/__fluent_builder_test/game.jsonh"


static func run(check: Callable) -> void:
	var registry := BgoBuilderRegistry.new()
	var parser := BgoFluentExpressionParser.new(registry)
	var identity_builder := registry.create("Player")
	check.call(
		identity_builder.invoke("setName", ["Same instance"]).get("value") == identity_builder,
		"every fluent setter returns the same builder instance"
	)
	var tree := Engine.get_main_loop() as SceneTree
	var console := tree.root.get_node_or_null("Console")
	check.call(
		console != null and console.expression_handler.is_valid(),
		"the live developer console has the fluent-expression handler installed"
	)
	check.call(
		console != null and console.autocomplete_provider.is_valid(),
		"the live developer console has the fluent autocomplete provider installed"
	)
	check.call(
		"Game.Player." in parser.complete("Game.") and "Game.Table." in parser.complete("Game."),
		"Game dot completion exposes hierarchical authoring types"
	)
	check.call(
		(
			"System.api." in parser.complete("System.")
			and "System.builders." in parser.complete("System.")
			and "System.constants." in parser.complete("System.")
		),
		"System dot completion exposes its three curated service namespaces"
	)
	check.call(
		"System.constants.ROLE_HOST" in parser.complete("System.constants.ROLE_H"),
		"System constants complete flat UPPER_SNAKE_CASE names"
	)
	check.call(
		"Game.Player.create().setName(" in parser.complete("Game.Player.create().setN"),
		"builder completion filters Player methods from a partial name"
	)
	check.call(
		(
			"Game.current().setTable(Game.Table.create().setWidth("
			in parser.complete("Game.current().setTable(Game.Table.create().setW")
		),
		"nested builder completion follows the innermost builder type"
	)
	if console != null:
		console.reset_autocomplete()
		console.line_edit.text = "Game."
		console.autocomplete()
		check.call(
			console.line_edit.text.begins_with("Game."),
			"pressing Tab after Game dot uses the fluent suggestions in the real console"
		)
		console.line_edit.text = ""
		console.reset_autocomplete()
	var created := (
		parser
		. execute(
			'Game.Player.create().setName("Ada").setColor(System.constants.PLAYER_COLOR_RED).setPosition(1.6, -2.4).setRotation(451.2)'
		)
	)
	check.call(bool(created.get("ok", false)), "fluent parser executes a typed Player chain")
	var player: BgoDefinitionBuilder = created.get("value")
	check.call(
		player != null and player.values.position == {"x": 2, "y": 0, "z": -2},
		"logical positions round to integer grid points"
	)
	check.call(
		player != null and player.values.rotation.y == 91,
		"rotations round and normalize to integer degrees"
	)
	check.call(
		player != null and not player.getWarnings().is_empty(),
		"automatic coordinate rounding is reported"
	)

	var lines := [
		'Game.create().setId("test001_console").setName("BGO Component Test").setPlayerCount(2).setTurnBased(true).setSandboxEnabled(true)',
		'Game.current().setTable(Game.Table.create().setWidth(15.5004).setDepth(9.8).addComponent(Game.CheckeredBoard.create().setId("main_board").setColumns(8).setRows(6).setCellSize(1.2).setGridCellSizeCm(5).setGridPointsPerUnit(5).setGridVirtualInfinite(true).setPosition(0, 0)))',
		'Game.current().addPlayer(Game.Player.create().setName("Player 1"))',
		'Game.current().addPlayer(Game.Player.create().setName("Player 2"))',
		'Game.current().addCatalogEntry(Game.CatalogEntry.create().setId("basic-miniature").setComponent(System.constants.COMPONENT_BASIC_CYLINDER).setRadius(0.38).setHeight(0.32))',
		'Game.current().setAssetBox(Game.AssetBox.create().setId("game_box").setLabel("ASSET BOX"))',
		'Game.current().addObject(Game.BasicCylinder.create().setOwner(1).setInitialSlot("1,2"))',
		'Game.current().addObject(Game.BasicCylinder.create().setOwner(2).setAvailability(System.constants.AVAILABILITY_FINITE).setQuantity(3).setInitialSlot("6,3"))',
		'Game.current().addObject(Game.BasicCylinder.create().setOwner("").setAvailability(System.constants.AVAILABILITY_FINITE).setQuantity(5).setColorSource(System.constants.COLOR_SOURCE_FIXED).setColor("#E7E0CF").setInitialSlot("3,2"))',
	]
	for line in lines:
		var result := parser.execute(line)
		check.call(bool(result.get("ok", false)), "console accepts: %s" % line)
	var built_result := parser.execute("Game.current().build()")
	check.call(bool(built_result.get("ok", false)), "console executes the terminal build method")
	var terminal: Dictionary = built_result.get("value", {})
	check.call(
		bool(terminal.get("ok", false)), "complete console-built definition passes BGO validation"
	)
	var definition: Dictionary = terminal.get("data", {})
	check.call(
		BgoGameDefinitionLoader.validate_game(definition).is_empty(),
		"loader independently validates console-built definition"
	)
	check.call(
		definition.players[0].id == "player_1" and definition.players[1].id == "player_2",
		"player ids are generated deterministically"
	)
	check.call(
		definition.players[0].color == "#E34850" and definition.players[1].color == "#4DB7F2",
		"two-player preset assigns red and blue"
	)
	check.call(
		(
			definition.table.instances[-2].placement.position.x == -6
			and definition.table.instances[-1].placement.position.x == 6
		),
		"two-player seats are opposite and integer-positioned"
	)
	check.call(
		definition.table.instances[0].config.grid_points_per_unit == 5,
		"game definition stores five 1cm points per main-grid unit"
	)

	var saved_result := registry.current_game.saveAs(ROUND_TRIP_PATH)
	check.call(
		bool(saved_result.get("ok", false)) and FileAccess.file_exists(ROUND_TRIP_PATH),
		"builder serializes a validated definition to user storage"
	)
	var file := FileAccess.open(ROUND_TRIP_PATH, FileAccess.READ)
	var parsed_json: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	check.call(parsed_json is Dictionary, "serialized builder output reloads as JSON")
	var serialization_normalized: Variant = JSON.parse_string(JSON.stringify(definition))
	check.call(
		parsed_json == serialization_normalized,
		"serialized and reloaded definition preserves the complete state"
	)
	check.call(
		BgoGameDefinitionLoader.validate_game(parsed_json).is_empty(),
		"reloaded JSON passes the production definition validator"
	)
	var project_saved := registry.current_game.saveAs(PROJECT_ROUND_TRIP_PATH)
	var project_loaded := parser.execute(
		'Game.load("res://games/__fluent_builder_test/game.jsonh").build()'
	)
	check.call(
		(
			bool(project_saved.get("ok", false))
			and bool(project_loaded.get("ok", false))
			and bool((project_loaded.get("value", {}) as Dictionary).get("ok", false))
		),
		"DEV builder saves into the games catalog and Game.load opens it again"
	)

	var fixture := BgoGameDefinitionLoader.load_game(TEST_GAME_PATH)
	var loaded_expression := parser.execute(
		'Game.load("res://games/test001/game.jsonh").migrateToCurrent().build()'
	)
	var loaded_terminal: Dictionary = loaded_expression.get("value", {})
	var migrated: Dictionary = loaded_terminal.get("data", {})
	check.call(
		(
			bool(fixture.get("ok", false))
			and bool(loaded_expression.get("ok", false))
			and bool(loaded_terminal.get("ok", false))
			and BgoGameDefinitionLoader.validate_game(migrated).is_empty()
		),
		"Game.load migrates TEST001 through the console and keeps it loadable"
	)
	check.call(
		not bool(registry.current_game.saveAs("res://src/forbidden.json").get("ok", false)),
		"builder refuses writes outside user storage and the DEV games catalog"
	)
	check.call(
		migrated.table.instances[1].placement.position.x == -6,
		"migration canonicalizes legacy decimal placement to integer grid coordinates"
	)

	var forbidden := parser.execute('OS.execute("cmd")')
	check.call(not bool(forbidden.get("ok", false)), "fluent parser rejects arbitrary engine APIs")
	var legacy_root := parser.execute('Player.create().setName("legacy")')
	check.call(
		not bool(legacy_root.get("ok", false)),
		"public builders reject roots outside Game, Match and System"
	)
	var legacy_constant_root := parser.execute("G.ROLE_HOST")
	check.call(
		not bool(legacy_constant_root.get("ok", false)),
		"public expressions reject the legacy G root"
	)
	var misspelled := parser.execute('Game.Player.create().setNaem("bad")')
	check.call(
		not bool(misspelled.get("ok", false)) and "Available:" in str(misspelled.get("error", "")),
		"invalid methods return discoverable curated alternatives"
	)
	check.call(
		(
			registry.describe("Player").type == "Game.Player"
			and "setName" in registry.describe("Player").methods
		),
		"builder discovery exposes the curated Game.Player API"
	)

	if FileAccess.file_exists(ROUND_TRIP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ROUND_TRIP_PATH))
	if FileAccess.file_exists(PROJECT_ROUND_TRIP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROJECT_ROUND_TRIP_PATH))
	var generated_directory := (
		ProjectSettings.globalize_path(PROJECT_ROUND_TRIP_PATH).get_base_dir()
	)
	if DirAccess.dir_exists_absolute(generated_directory):
		DirAccess.remove_absolute(generated_directory)
