class_name FirebaseConfig
extends RefCounted

const PROJECT_ID := "board-game-online-68c3f"
const DATABASE_URL := "https://board-game-online-68c3f-default-rtdb.firebaseio.com"


static func database_path(path: String, auth_token: String = "") -> String:
	var normalized := path.strip_edges()
	if normalized.begins_with("/"):
		normalized = normalized.substr(1)
	var url := "%s/%s.json" % [DATABASE_URL.trim_suffix("/"), normalized]
	if not auth_token.is_empty():
		url += "?auth=" + auth_token.uri_encode()
	return url
