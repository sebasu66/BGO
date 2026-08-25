extends Node

## Console/debug projection rooted at the stable global name G.
## Reads return deep copies. Mutations must use execute() and the normal command path.

signal runtime_changed(state: Dictionary)

var _definition: Dictionary = {}
var _definition_path := ""
var _runtime: Variant

func _record(method_name: String, result: Variant = null) -> void:
	var activity: Node = Engine.get_main_loop().root.get_node_or_null("BgoActivityLog") if Engine.get_main_loop() != null else null
	if activity != null:
		activity.record_invocation(method_name, "internal", {}, result)


## Binds the immutable definition projection for the currently loaded game.
func bind_definition(value: Dictionary, path: String) -> void:
	_record("Game.bindDefinition")
	_definition = value.duplicate(true)
	_definition_path = path


## Binds authoritative runtime state for console queries and commands.
func bind_runtime(value: Variant) -> void:
	_record("Match.bindRuntime")
	_runtime = value


## Creates and binds a local sandbox from the loaded definition.
func start_sandbox() -> Dictionary:
	if str((_definition.get("runtime", {}) as Dictionary).get("mode", "match")) != "sandbox":
		return {"ok": false, "reason": "definition_is_not_sandbox"}
	var sandbox := SandboxState.create(_definition)
	if sandbox == null:
		return {"ok": false, "reason": "sandbox_initialization_failed"}
	bind_runtime(sandbox)
	return {"ok": true, "state": sandbox.to_dictionary()}


## Describes the stable console API rooted at G.
func help() -> Dictionary:
	return {
		"root": "G",
		"methods":
		{
			"G.help()": "Describe the debug API.",
			"G.games()": "List installed game definition IDs.",
			"G.definition(path)": "Read the loaded JSONH definition or a dotted path.",
			"G.state(path)": "Read authoritative runtime state or a dotted path.",
			"G.components(component_id)": "List component contracts or inspect one.",
			"G.execute(command)": "Submit a canonical validated command.",
			"G.export_initial_state()": "Export the current sandbox as a setup fragment."
		},
		"definition_path": _definition_path,
		"mutation_rule":
		"All writes use G.execute(command); properties are never changed directly.",
	}


## Lists game definitions available to the current build.
func games() -> Array[String]:
	var result := BgoGameDefinitionLoader.list_game_ids()
	_record("System.games", result)
	return result


## Reads the loaded game definition or one dotted path from it.
func definition(path: String = "") -> Variant:
	var result: Variant = _read_path(_definition, path)
	_record("Game.definition", result)
	return result


## Reads authoritative runtime state or one dotted path from it.
func state(path: String = "") -> Variant:
	if _runtime == null or not _runtime.has_method("to_dictionary"):
		_record("Match.state", {})
		return {}
	var result: Variant = _read_path(_runtime.to_dictionary(), path)
	_record("Match.state", result)
	return result


## Lists component contracts or returns one contract by stable id.
func components(component_id: String = "") -> Variant:
	if not component_id.is_empty():
		var result := BgoComponentRegistry.get_contract(component_id)
		_record("System.components", result)
		return result
	var result: Dictionary = {}
	for id in BgoComponentRegistry.component_ids():
		result[id] = BgoComponentRegistry.get_contract(id)
	_record("System.components", result)
	return result


## Submits one canonical command through the normal validated mutation path.
func execute(command: Dictionary) -> Dictionary:
	if _runtime == null or not _runtime.has_method("execute"):
		var rejected := {"ok": false, "reason": "runtime_not_bound"}
		_record("Match.execute", rejected)
		return rejected
	var result: Dictionary = _runtime.execute(command.duplicate(true))
	if bool(result.get("ok", false)):
		runtime_changed.emit(_runtime.to_dictionary())
	_record("Match.execute", result)
	return result


## Exports the current sandbox state as a declarative initial-state fragment.
func export_initial_state() -> Dictionary:
	if _runtime == null or not _runtime.has_method("export_initial_state"):
		var rejected := {"ok": false, "reason": "sandbox_not_bound"}
		_record("Game.exportInitialState", rejected)
		return rejected
	var result: Dictionary = _runtime.export_initial_state()
	_record("Game.exportInitialState", result)
	return result


func _read_path(source: Dictionary, path: String) -> Variant:
	if path.is_empty():
		return source.duplicate(true)
	var current: Variant = source
	for segment in path.split(".", false):
		if not current is Dictionary:
			return null
		var current_dictionary: Dictionary = current
		if not current_dictionary.has(segment):
			return null
		current = current_dictionary[segment]
	return current.duplicate(true) if current is Dictionary or current is Array else current
