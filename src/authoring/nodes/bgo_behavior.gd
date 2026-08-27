@tool
class_name BgoBehavior
extends BgoFeature

## Authoring-only rule descriptors for now. Execution/interpreter is intentionally deferred.
@export var rules: Array = []


func _init() -> void:
	feature_id = &"behavior"


## Returns authored rules matching a friendly or canonical event name.
func matching_rules(event_name: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_rule in rules:
		if raw_rule is not Dictionary:
			continue
		var rule := raw_rule as Dictionary
		if StringName(rule.get("event", "")) == event_name:
			result.append(rule.duplicate(true))
	return result


func composition_descriptor() -> Dictionary:
	return {
		"type": "behavior",
		"id": String(feature_id),
		"enabled": enabled,
		"rule_count": rules.size(),
	}
