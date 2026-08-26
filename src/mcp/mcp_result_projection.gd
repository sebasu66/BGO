class_name BgoMcpResultProjection
extends RefCounted

## Returns the public/persistable form of a canonical API result.
## Large internal snapshots are omitted and slash-delimited definition patch
## paths are converted to an array because Firebase RTDB forbids '/' in data keys.
static func for_persistence(result: Dictionary) -> Dictionary:
	var projected := result.duplicate(true)
	projected.erase("definition_update")
	if projected.has("definition_patch"):
		var patch: Dictionary = projected.get("definition_patch", {})
		var paths: Array[String] = []
		for path_variant in patch:
			paths.append(str(path_variant))
		paths.sort()
		var changes: Array[Dictionary] = []
		for path in paths:
			changes.append({"path": path, "value": patch[path]})
		projected.erase("definition_patch")
		projected["definition_changes"] = changes
	return projected
