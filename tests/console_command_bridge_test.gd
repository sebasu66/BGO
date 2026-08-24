class_name ConsoleCommandBridgeTest
extends RefCounted

const TEST_OBJECT = preload("res://tests/console_command_test_object.gd")


## Exercises discovery, invocation, type conversion, help, arity errors, and
## unregistering when a game object leaves the scene tree.
static func run(check: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var console := tree.root.get_node_or_null("Console")
	var bridge := tree.root.get_node_or_null("BgoGameCommandConsole")
	check.call(console != null, "developer console autoload is available")
	check.call(bridge != null, "BGO console bridge autoload is available")
	if console == null or bridge == null:
		return

	var definition_host := GameSessionRepository.new()
	definition_host.name = "DefinitionApiFixture"
	(
		definition_host
		. set_game_definition(
			{
				"game": {"id": "fixture", "name": "Fixture Game", "turn_based": true},
				"table": {"width": 12.0, "depth": 8.0},
			}
		)
	)
	tree.root.add_child(definition_host)
	await tree.process_frame
	await tree.process_frame
	(
		check
		. call(
			console.console_commands.has("Game.definition.getName"),
			"Game namespace exposes the curated definition API",
		)
	)
	console.call("_on_text_entered", "Game.definition.getName()")
	var game_name_result: Dictionary = bridge.call(
		"_invoke_python_namespace", "Game.definition.getName", []
	)
	check.call(
		bool(game_name_result.get("ok", false)) and game_name_result.get("value") == "Fixture Game",
		"Game definition methods execute with Python-like parentheses"
	)
	var fixture := TEST_OBJECT.new()
	fixture.entity_id = "console_test_object"
	tree.root.add_child(fixture)
	await tree.process_frame
	await tree.process_frame

	var command_name := "game.console_test_object.set_test_value"
	var help_name := "game.console_test_object.help"
	var curated_get_name := "Match.console_test_object.getName"
	var curated_set_width := "Match.console_test_object.setWidth"
	var curated_is_active := "Match.console_test_object.isActive"
	check.call(
		console.console_commands.has(command_name), "new game object method is auto-registered"
	)
	check.call(
		console.console_commands.has(help_name), "console_help creates an object help command"
	)
	check.call(console.console_commands.has(curated_get_name), "curated API exposes getName")
	check.call(console.console_commands.has(curated_set_width), "curated API exposes setWidth")
	check.call(console.console_commands.has(curated_is_active), "curated API exposes isActive")
	(
		check
		. call(
			not console.console_commands.has("Match.console_test_object.serializeState"),
			"curated API does not leak undeclared public methods",
		)
	)

	console.call("_on_text_entered", "%s 24" % curated_set_width)
	check.call(fixture.test_width == 24, "curated setter converts and applies its typed value")
	console.call("_on_text_entered", "Match.console_test_object.setDesc G.ROLES.HOST")
	check.call(fixture.test_desc == "host", "public constants resolve before typed invocation")
	console.call("_on_text_entered", "Match.console_test_object.setWidth(31)")
	check.call(
		fixture.test_width == 31,
		"Match methods execute with Python-like parentheses and typed arguments"
	)
	console.call(
		"_on_text_entered", "Match.console_test_object.setDesc(System.constants.ROLE_HOST)"
	)
	check.call(
		fixture.test_desc == "host",
		"Match methods consume constants from the canonical System root"
	)
	console.call("_on_text_entered", "Match.console_test_object.getName()")
	console.call("_on_text_entered", "Match.console_test_object.isActive()")
	check.call(BgoApiConstants.has_valid_public_names(), "public constants use UPPER_SNAKE_CASE")
	console.call("_on_text_entered", curated_get_name)
	console.call("_on_text_entered", curated_is_active)
	console.call("_on_text_entered", "System.api.describe Match.console_test_object setWidth")
	console.call("_on_text_entered", 'System.api.describe("Match.console_test_object", "setWidth")')
	var public_entities: Dictionary = bridge.call(
		"_invoke_python_namespace", "System.api.getEntities", []
	)
	check.call(
		(
			bool(public_entities.get("ok", false))
			and "Game.Player" in public_entities.get("value", [])
			and "Match.console_test_object" in public_entities.get("value", [])
			and "System.api" in public_entities.get("value", [])
		),
		"System.api discovery reports Game, Match and System hierarchy together"
	)
	var builder_types: Dictionary = bridge.call(
		"_invoke_python_namespace", "System.builders.getTypes", []
	)
	check.call(
		(
			bool(builder_types.get("ok", false))
			and "Game.Player" in builder_types.get("value", [])
			and "Player" not in builder_types.get("value", [])
		),
		"System builder discovery only exposes canonical Game.* type names"
	)
	var player_methods: Dictionary = bridge.call(
		"_invoke_python_namespace", "System.api.getMethods", ["Game.Player"]
	)
	check.call(
		(
			bool(player_methods.get("ok", false))
			and "create" in player_methods.get("value", [])
			and "setName" in player_methods.get("value", [])
		),
		"System.api discovers both Game.Player factory and instance methods"
	)
	var public_constants: Dictionary = bridge.call(
		"_invoke_python_namespace", "System.constants.getAll", []
	)
	check.call(
		(
			bool(public_constants.get("ok", false))
			and public_constants.get("value", {}).has("System.constants.ROLE_HOST")
			and not public_constants.get("value", {}).has("System.constants.ROLES.HOST")
		),
		"canonical constant discovery exposes flat UPPER_SNAKE_CASE names"
	)
	console.reset_autocomplete()
	console.line_edit.text = "Match.console_test_object.setW"
	console.autocomplete()
	check.call(
		console.line_edit.text == "Match.console_test_object.setWidth(",
		"Match autocomplete produces Python-like method calls"
	)
	console.line_edit.text = ""
	console.reset_autocomplete()
	(
		check
		. call(
			console.console_commands.has("System.api.getEntities"),
			"curated System API discovery is registered",
		)
	)
	var highlighted := BgoConsoleSyntax.highlight(
		'ConsoleCommandTestObject.setWidth 42 true "wide" G.TYPES.NUMBER'
	)
	check.call("#61afef" in highlighted, "syntax colors entity and class names")
	check.call("#e5c07b" in highlighted, "syntax colors method names")
	check.call("#d19a66" in highlighted, "syntax colors numeric literals")
	check.call("#56b6c2" in highlighted, "syntax colors boolean literals")
	check.call("#98c379" in highlighted, "syntax colors string literals")
	check.call("#c678dd" in highlighted, "syntax colors registered constants")

	fixture.test_value = 7
	console.call("_on_text_entered", "%s 42" % command_name)
	check.call(fixture.test_value == 42, "console converts and invokes typed integer arguments")

	console.call("_on_text_entered", "%s not_an_integer" % command_name)
	check.call(fixture.test_value == 42, "invalid typed argument does not mutate the object")

	console.call("_on_text_entered", "%s 100 extra" % command_name)
	check.call(fixture.test_value == 42, "too many arguments are rejected without invocation")

	console.call("_on_text_entered", command_name)
	check.call(fixture.test_value == 42, "too few arguments are rejected without invocation")

	console.call("_on_text_entered", help_name)
	check.call(
		console.console_commands.has("game.commands"), "game command listing remains registered"
	)

	fixture.queue_free()
	definition_host.queue_free()
	await tree.process_frame
	await tree.process_frame
	check.call(
		not console.console_commands.has(command_name),
		"freed game object commands are unregistered"
	)
	check.call(
		not console.console_commands.has(curated_get_name), "freed curated entity is unregistered"
	)
	(
		check
		. call(
			not console.console_commands.has("Game.definition.getName"),
			"freed Game definition entity is unregistered",
		)
	)
