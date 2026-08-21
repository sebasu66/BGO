extends Node

## Console/debug projection rooted at the stable global name G.
## Reads return deep copies. Mutations must use execute() and the normal command path.

var _definition: Dictionary = {}
var _definition_path := ""
var _gameplay: GameplayState


## Binds the immutable definition projection for the currently loaded game.
func bind_definition(value: Dictionary, path: String) -> void:
	_definition = value.duplicate(true)
	_definition_path = path


## Binds authoritative runtime state for console queries and commands.
func bind_gameplay(value: GameplayState) -> void:
	_gameplay = value


## Describes the stable console API rooted at G.
func help() -> Dictionary:
	return {
		"root": "G",
		"methods": {
			"G.help()": "Describe the debug API.",
			"G.games()": "List installed game definition IDs.",
			"G.definition(path)": "Read the loaded JSONH definition or a dotted path.",
			"G.state(path)": "Read authoritative runtime state or a dotted path.",
			"G.components(component_id)": "List component contracts or inspect one.",
			"G.execute(command)": "Submit a canonical validated command."
		},
		"definition_path": _definition_path,
		"mutation_rule": "All writes use G.execute(command); properties are never changed directly.",
	}


## Lists game definitions available to the current build.
func games() -> Array[String]:
	return BgoGameDefinitionLoader.list_game_ids()


## Reads the loaded game definition or one dotted path from it.
func definition(path: String = "") -> Variant:
	return _read_path(_definition, path)


## Reads authoritative runtime state or one dotted path from it.
func state(path: String = "") -> Variant:
	if _gameplay == null:
		return {}
	return _read_path(_gameplay.to_dictionary(), path)


## Lists component contracts or returns one contract by stable id.
func components(component_id: String = "") -> Variant:
	if not component_id.is_empty():
		return BgoComponentRegistry.get_contract(component_id)
	var result: Dictionary = {}
	for id in BgoComponentRegistry.component_ids():
		result[id] = BgoComponentRegistry.get_contract(id)
	return result


## Submits one canonical command through the normal validated mutation path.
func execute(command: Dictionary) -> Dictionary:
	if _gameplay == null:
		return {"ok": false, "reason": "gameplay_not_bound"}
	return _gameplay.execute(command.duplicate(true))


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
