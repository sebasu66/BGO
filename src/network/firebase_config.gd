class_name FirebaseConfig
extends RefCounted

const PROJECT_ID := "board-game-online-68c3f"
const DATABASE_URL := "https://board-game-online-68c3f-default-rtdb.firebaseio.com"
const WEB_KEY_FILES := ["user://firebase_web.json", "res://.local/firebase_web.json"]
const WEB_KEY_ENV := "BGO_FIREBASE_API_KEY"


## Returns the Firebase web API key, or an empty string when none is configured.
## Order: environment variable, then local files that are never committed.
static func web_api_key() -> String:
	var from_env := OS.get_environment(WEB_KEY_ENV)
	if not from_env.is_empty():
		return from_env
	for path in WEB_KEY_FILES:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and not str((parsed as Dictionary).get("apiKey", "")).is_empty():
			return str((parsed as Dictionary)["apiKey"])
	return ""


static func database_path(path: String, auth_token: String = "") -> String:
	var normalized := path.strip_edges()
	if normalized.begins_with("/"):
		normalized = normalized.substr(1)
	var url := "%s/%s.json" % [DATABASE_URL.trim_suffix("/"), normalized]
	if not auth_token.is_empty():
		url += "?auth=" + auth_token.uri_encode()
	return url
