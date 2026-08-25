class_name BgoGithubJobRelay
extends RefCounted

## Godot Web never receives a GitHub PAT. Deployments that need authenticated
## dispatch provide this relay outside the client and persist the resulting job.
var endpoint := ""

func submit(_session_id: String, _job: Dictionary) -> Dictionary:
	if endpoint.is_empty():
		return {"ok": false, "reason": "relay_not_configured"}
	return {"ok": false, "reason": "relay_adapter_required", "endpoint": endpoint}
