class_name FirebaseSession
extends RefCounted
## Shared anonymous-auth identity used by every Firebase REST adapter.

static var uid := ""
static var id_token := ""
static var refresh_token := ""
static var expires_at_unix := 0


static func is_signed_in() -> bool:
	return not uid.is_empty() and not id_token.is_empty()


static func is_expired(margin_seconds: int = 120) -> bool:
	return int(Time.get_unix_time_from_system()) + margin_seconds >= expires_at_unix


static func set_session(
	new_uid: String, new_id_token: String, new_refresh_token: String, expires_in_seconds: int
) -> void:
	uid = new_uid
	id_token = new_id_token
	refresh_token = new_refresh_token
	expires_at_unix = int(Time.get_unix_time_from_system()) + expires_in_seconds


static func clear() -> void:
	uid = ""
	id_token = ""
	refresh_token = ""
	expires_at_unix = 0
