class_name BgoGithubJobLease
extends RefCounted

const DEFAULT_TTL_SECONDS := 15

static func candidate(current: Dictionary, client_id: String, now: int, ttl: int = DEFAULT_TTL_SECONDS) -> Dictionary:
	var holder := str(current.get("holder_id", ""))
	var expires_at := int(current.get("expires_at", 0))
	if client_id.is_empty():
		return {"acquired": false, "reason": "client_required", "lease": current.duplicate(true)}
	if holder != "" and holder != client_id and expires_at > now:
		return {"acquired": false, "reason": "held_by_other", "lease": current.duplicate(true)}
	var token := str(current.get("token", ""))
	if holder != client_id or token.is_empty():
		token = "%s:%s" % [client_id, now]
	return {
		"acquired": true,
		"reason": "renewed" if holder == client_id else "acquired",
		"lease": {"holder_id": client_id, "token": token, "expires_at": now + maxi(ttl, 1)},
	}

static func owns(current: Dictionary, client_id: String, now: int) -> bool:
	return str(current.get("holder_id", "")) == client_id and int(current.get("expires_at", 0)) > now
