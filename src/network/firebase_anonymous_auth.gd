class_name FirebaseAnonymousAuth
extends Node
## Signs the device in anonymously with Firebase Auth (REST) and keeps the token fresh.

signal signed_in(uid: String)
signal sign_in_failed(message: String)

const SIGN_UP_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s"
const REFRESH_URL := "https://securetoken.googleapis.com/v1/token?key=%s"
const CACHE_PATH := "user://firebase_auth.json"
const REFRESH_MARGIN_SECONDS := 300

var _refresh_timer: Timer


func _ready() -> void:
	_refresh_timer = Timer.new()
	_refresh_timer.one_shot = true
	_refresh_timer.timeout.connect(_on_refresh_timer)
	add_child(_refresh_timer)


## Signs in (or restores a cached identity) and emits signed_in or sign_in_failed.
func sign_in() -> void:
	var key := FirebaseConfig.web_api_key()
	if key.is_empty():
		sign_in_failed.emit("firebase_web_api_key_missing")
		return
	if FirebaseSession.is_signed_in() and not FirebaseSession.is_expired():
		signed_in.emit(FirebaseSession.uid)
		return
	var cached := _load_cache()
	if not cached.is_empty():
		FirebaseSession.refresh_token = str(cached.get("refresh_token", ""))
		_refresh(key, true)
		return
	_sign_up(key)


func _sign_up(key: String) -> void:
	_post(
		SIGN_UP_URL % key.uri_encode(),
		"application/json",
		JSON.stringify({"returnSecureToken": true}),
		_on_sign_up_done
	)


func _refresh(key: String, fall_back_to_sign_up: bool) -> void:
	var body := (
		"grant_type=refresh_token&refresh_token=%s" % FirebaseSession.refresh_token.uri_encode()
	)
	_post(
		REFRESH_URL % key.uri_encode(),
		"application/x-www-form-urlencoded",
		body,
		_on_refresh_done.bind(key, fall_back_to_sign_up)
	)


func _post(url: String, content_type: String, body: String, done: Callable) -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_http_completed.bind(request, done))
	var error := request.request(
		url, PackedStringArray(["Content-Type: " + content_type]), HTTPClient.METHOD_POST, body
	)
	if error != OK:
		request.queue_free()
		done.call(0, {})


func _on_http_completed(
	result: int,
	code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	request: HTTPRequest,
	done: Callable
) -> void:
	request.queue_free()
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}
	done.call(code if result == HTTPRequest.RESULT_SUCCESS else 0, data)


func _on_sign_up_done(code: int, data: Dictionary) -> void:
	if code < 200 or code >= 300 or not data.has("idToken"):
		sign_in_failed.emit("sign_up_failed_%d: %s" % [code, _error_message(data)])
		return
	_accept(
		str(data.get("localId", "")),
		str(data.get("idToken", "")),
		str(data.get("refreshToken", "")),
		int(str(data.get("expiresIn", "3600")))
	)


func _on_refresh_done(code: int, data: Dictionary, key: String, fall_back: bool) -> void:
	if code < 200 or code >= 300 or not data.has("id_token"):
		if fall_back:
			_clear_cache()
			FirebaseSession.clear()
			_sign_up(key)
		else:
			sign_in_failed.emit("refresh_failed_%d: %s" % [code, _error_message(data)])
		return
	_accept(
		str(data.get("user_id", "")),
		str(data.get("id_token", "")),
		str(data.get("refresh_token", "")),
		int(str(data.get("expires_in", "3600")))
	)


func _accept(uid: String, id_token: String, refresh_token: String, expires_in: int) -> void:
	FirebaseSession.set_session(uid, id_token, refresh_token, expires_in)
	_save_cache(uid, refresh_token)
	_refresh_timer.start(maxf(60.0, float(expires_in - REFRESH_MARGIN_SECONDS)))
	signed_in.emit(uid)


func _on_refresh_timer() -> void:
	var key := FirebaseConfig.web_api_key()
	if not key.is_empty() and not FirebaseSession.refresh_token.is_empty():
		_refresh(key, false)


func _error_message(data: Dictionary) -> String:
	var error: Variant = data.get("error", {})
	if error is Dictionary:
		return str((error as Dictionary).get("message", "unknown"))
	return str(error) if not str(error).is_empty() else "unknown"


func _load_cache() -> Dictionary:
	if not FileAccess.file_exists(CACHE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_PATH))
	if parsed is Dictionary and not str((parsed as Dictionary).get("refresh_token", "")).is_empty():
		return parsed
	return {}


func _save_cache(uid: String, refresh_token: String) -> void:
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"uid": uid, "refresh_token": refresh_token}))


func _clear_cache() -> void:
	if FileAccess.file_exists(CACHE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CACHE_PATH))
