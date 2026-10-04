class_name BgoAssetResolver
extends Node

signal model_loaded(url: String, model: Node3D)
signal model_failed(url: String, reason: String)

const MAX_MODEL_BYTES := 50 * 1024 * 1024
const CACHE_ROOT := "user://bgo_asset_cache"
var _request: HTTPRequest
var _url := ""
var _expected_sha256 := ""


func _ready() -> void:
	_request = HTTPRequest.new()
	_request.download_chunk_size = 65536
	_request.request_completed.connect(_on_request_completed)
	add_child(_request)


## Resolves one remote GLB through the validated URL, integrity, and cache contract.
func load_model(url: String, expected_sha256: String = "") -> bool:
	if not (url.begins_with("https://") or url.begins_with("http://")):
		model_failed.emit(url, "url_must_use_http_or_https")
		return false
	_url = url
	_expected_sha256 = expected_sha256.to_lower()
	DirAccess.make_dir_recursive_absolute(CACHE_ROOT)
	var cache_path := CACHE_ROOT.path_join(url.sha256_text() + ".glb")
	if FileAccess.file_exists(cache_path):
		var cached := FileAccess.get_file_as_bytes(cache_path)
		if _accept_integrity(cached):
			_parse_model(cached)
			return true
	return _request.request(url) == OK


func _on_request_completed(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		model_failed.emit(_url, "http_%d" % response_code)
		return
	if (
		body.size() > MAX_MODEL_BYTES
		or not _url.to_lower().ends_with(".glb")
		or not _accept_integrity(body)
	):
		model_failed.emit(_url, "invalid_glb_asset")
		return
	DirAccess.make_dir_recursive_absolute(CACHE_ROOT)
	var file := FileAccess.open(CACHE_ROOT.path_join(_url.sha256_text() + ".glb"), FileAccess.WRITE)
	if file != null:
		file.store_buffer(body)
	_parse_model(body)


func _accept_integrity(body: PackedByteArray) -> bool:
	if _expected_sha256.is_empty():
		return true
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return false
	hashing.update(body)
	return hashing.finish().hex_encode().to_lower() == _expected_sha256


func _parse_model(body: PackedByteArray) -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_buffer(body, "", state) != OK:
		model_failed.emit(_url, "gltf_parse_failed")
		return
	var model := document.generate_scene(state)
	if model == null:
		model_failed.emit(_url, "gltf_scene_generation_failed")
		return
	model_loaded.emit(_url, model)
