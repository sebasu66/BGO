class_name BgoMcpPrototypeAccessPolicy
extends RefCounted

## Temporary policy for the single-session MCP prototype. This is explicitly
## not authentication and must remain DEV-only until pairing/OAuth exist.

const AUTH_MODE := "dev_direct_no_auth"
const DEFAULT_SESSION_ID := "TEST001"

const READ_ACTIONS: Array[String] = [
	"session.get_context",
	"session.get_state",
	"game.list_objects",
	"game.inspect_object",
	"game.get_available_actions",
]
const CONTROL_ACTIONS: Array[String] = ["game.execute_action", "game.end_turn"]
const HOST_ACTIONS: Array[String] = [
	"game.duplicate_object", "game.change_owner", "game.delete_object"
]


static func bind_context(
	session_id: String = DEFAULT_SESSION_ID,
	participant_id: String = "player_1",
	role: String = "player"
) -> Dictionary:
	return {
		"auth_mode": AUTH_MODE,
		"session_id": session_id if not session_id.is_empty() else DEFAULT_SESSION_ID,
		"participant_id": participant_id,
		"role": _normalized_role(role),
		"prototype_only": true,
	}


static func allowed_actions(context: Dictionary, object_owner_id: String = "") -> Array[String]:
	var result: Array[String] = READ_ACTIONS.duplicate()
	var role := str(context.get("role", "spectator"))
	var participant_id := str(context.get("participant_id", ""))
	var is_host := role == "host"
	var is_owner := not object_owner_id.is_empty() and object_owner_id == participant_id
	if is_host or is_owner:
		result.append_array(CONTROL_ACTIONS)
	if is_host:
		result.append_array(HOST_ACTIONS)
	return result


static func can_execute(
	context: Dictionary, action_id: String, object_owner_id: String = ""
) -> bool:
	return allowed_actions(context, object_owner_id).has(action_id)


static func _normalized_role(role: String) -> String:
	var normalized := role.to_lower()
	return normalized if normalized in ["host", "player", "spectator", "display"] else "spectator"
