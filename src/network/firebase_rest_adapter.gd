class_name FirebaseRestAdapter
extends Node

signal request_succeeded(operation: StringName, path: String, data: Variant)
signal request_failed(operation: StringName, path: String, http_code: int, message: String)

var auth_token: String = ""
var _requests: Dictionary = {}

func read(path: String) -> void:
	_send(&"read", path, HTTPClient.METHOD_GET)

func write(path: String, value: Variant) -> void:
	_send(&"write", path, HTTPClient.METHOD_PUT, JSON.stringify(value))

func patch(path: String, value: Dictionary) -> void:
	_send(&"patch", path, HTTPClient.METHOD_PATCH, JSON.stringify(value))

func remove(path: String) -> void:
	_send(&"remove", path, HTTPClient.METHOD_DELETE)

func _send(operation: StringName, path: String, method: HTTPClient.Method, body: String = "") -> void:
	var request := HTTPRequest.new()
	add_child(request)
	_requests[request] = {"operation": operation, "path": path}
	request.request_completed.connect(_on_request_completed.bind(request))

	var headers := PackedStringArray(["Content-Type: application/json"])
	var error := request.request(FirebaseConfig.database_path(path, auth_token), headers, method, body)
	if error != OK:
		_requests.erase(request)
		request.queue_free()
		request_failed.emit(operation, path, 0, error_string(error))

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	var meta: Dictionary = _requests.get(request, {})
	_requests.erase(request)
	request.queue_free()

	var operation: StringName = meta.get("operation", &"")
	var path: String = meta.get("path", "")
	var text := body.get_string_from_utf8()

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		request_failed.emit(operation, path, response_code, text)
		return

	var data: Variant = null
	if not text.is_empty():
		data = JSON.parse_string(text)
	request_succeeded.emit(operation, path, data)
