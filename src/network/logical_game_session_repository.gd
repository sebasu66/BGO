class_name LogicalGameSessionRepository
extends GameSessionRepository


## Persists an accepted logical state patch at the active game-session root.
func persist_logical_patch(patch: Dictionary) -> void:
	if patch.is_empty():
		return
	_log(
		"FIREBASE_WRITE",
		{
			"operation": "logical_state_patch",
			"path": _game_path(),
			"state_revision": int(patch.get("state_revision", 0)),
		},
	)
	_adapter.patch(_game_path(), patch)
