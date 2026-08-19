class_name BgoPlayerPresenceLayer
extends Node3D

const DEFAULT_PRESENCE_COMPONENT := "bgo.player_presence.basic_mask"
const POSE_PUBLISH_SECONDS := 0.5

var game_id := "TEST001"
var client_role := "display"
var local_player_id := "player_1"
var definitions: Dictionary = {}
var masks: Dictionary = {}

var _repository: PlayerPresenceRepository
var _camera: Camera3D
var _publish_elapsed := 0.0


func _ready() -> void:
	_read_launch_options()
	_load_player_definitions()
	_camera = get_parent().get_node_or_null("Camera3D") as Camera3D
	_repository = PlayerPresenceRepository.new()
	add_child(_repository)
	_repository.players_received.connect(_on_players_received)
	_repository.presence_error.connect(_on_presence_error)
	_repository.start(game_id)
	if client_role == "player":
		var definition := _player_definition(local_player_id)
		_repository.publish_player(
			local_player_id,
			str(definition.get("name", _fallback_name(local_player_id))),
			str(definition.get("color", "#D9D9D9")),
			"player",
			false
		)
	call_deferred("_update_client_identity_hud")


func _process(delta: float) -> void:
	if client_role != "player" or _camera == null or _repository == null:
		return
	_publish_elapsed += delta
	if _publish_elapsed < POSE_PUBLISH_SECONDS:
		return
	_publish_elapsed = 0.0
	_repository.publish_pose(
		local_player_id, _camera.global_position, -_camera.global_transform.basis.z.normalized()
	)


func _load_player_definitions() -> void:
	var result := BgoGameDefinitionLoader.load_game(
		"res://games/%s/game.jsonh" % game_id.to_lower()
	)
	if not bool(result.get("ok", false)):
		return
	var definition: Dictionary = result.get("data", {})
	var players: Array = definition.get("players", [])
	for value in players:
		if value is Dictionary:
			var id := str(value.get("id", ""))
			if not id.is_empty():
				definitions[id] = value.duplicate(true)


func _on_players_received(players: Dictionary) -> void:
	for player_id_variant in players:
		var player_id := str(player_id_variant)
		var state_variant: Variant = players[player_id_variant]
		if not state_variant is Dictionary:
			continue
		var state: Dictionary = state_variant
		if bool(state.get("spectator", false)):
			continue
		var mask := _ensure_mask(player_id, state)
		if mask == null:
			continue
		mask.visible = (
			bool(state.get("connected", true))
			and not (client_role == "player" and player_id == local_player_id)
		)
		_apply_pose(mask, player_id, state)


func _ensure_mask(player_id: String, state: Dictionary) -> BgoPlayerPresenceMask:
	if masks.has(player_id):
		var existing := masks[player_id] as BgoPlayerPresenceMask
		_configure_mask(existing, player_id, state)
		return existing
	var definition := _player_definition(player_id)
	var presence: Dictionary = definition.get("presence", {})
	var component_id := str(presence.get("component", DEFAULT_PRESENCE_COMPONENT))
	var scene := BgoComponentRegistry.load_scene(component_id)
	if scene == null:
		scene = BgoComponentRegistry.load_scene(DEFAULT_PRESENCE_COMPONENT)
	if scene == null:
		return null
	var mask := scene.instantiate() as BgoPlayerPresenceMask
	if mask == null:
		return null
	add_child(mask)
	masks[player_id] = mask
	_configure_mask(mask, player_id, state)
	_apply_fallback_pose(mask, player_id)
	return mask


func _configure_mask(mask: BgoPlayerPresenceMask, player_id: String, state: Dictionary) -> void:
	var definition := _player_definition(player_id)
	var player_name := str(state.get("name", definition.get("name", _fallback_name(player_id))))
	var color_text := str(state.get("color", definition.get("color", "#D9D9D9")))
	mask.configure(player_name, Color.from_string(color_text, Color(0.85, 0.85, 0.85)))


func _apply_pose(mask: BgoPlayerPresenceMask, player_id: String, state: Dictionary) -> void:
	var pose_variant: Variant = state.get("camera_pose", {})
	if not pose_variant is Dictionary or pose_variant.is_empty():
		_apply_fallback_pose(mask, player_id)
		return
	var pose: Dictionary = pose_variant
	var position := _dictionary_to_vec3(pose.get("position", {}))
	var forward := _dictionary_to_vec3(pose.get("forward", {}))
	if forward.length_squared() < 0.0001:
		_apply_fallback_pose(mask, player_id)
		return
	mask.set_pose(position, forward)


func _apply_fallback_pose(mask: BgoPlayerPresenceMask, player_id: String) -> void:
	var area_name := "Player2Area" if player_id == "player_2" else "Player1Area"
	var area := get_parent().get_node_or_null(area_name) as Node3D
	var area_position := area.global_position if area != null else Vector3.ZERO
	var outward := Vector3(area_position.x, 0.0, area_position.z).normalized()
	if outward.length_squared() < 0.0001:
		outward = Vector3.LEFT if player_id == "player_1" else Vector3.RIGHT
	var position := area_position + outward * 1.0 + Vector3.UP * 1.25
	mask.set_pose(position, (Vector3(0.0, position.y, 0.0) - position).normalized())


func _update_client_identity_hud() -> void:
	if client_role != "player":
		return
	var title := get_parent().get_node_or_null("UI/Title") as Label
	if title == null:
		return
	var definition := _player_definition(local_player_id)
	var player_name := str(definition.get("name", _fallback_name(local_player_id)))
	title.text = (
		"%s · %s · %s" % [title.text, local_player_id.to_upper().replace("_", " "), player_name]
	)
	title.add_theme_color_override(
		"font_color", Color.from_string(str(definition.get("color", "#D9D9D9")), Color.WHITE)
	)


func _player_definition(player_id: String) -> Dictionary:
	return definitions.get(player_id, {}) as Dictionary


func _fallback_name(player_id: String) -> String:
	return player_id.replace("_", " ").capitalize()


func _dictionary_to_vec3(value: Variant) -> Vector3:
	if not value is Dictionary:
		return Vector3.ZERO
	var data: Dictionary = value
	return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))


func _read_launch_options() -> void:
	if OS.has_feature("web"):
		client_role = (
			str(
				JavaScriptBridge.eval(
					"new URLSearchParams(window.location.search).get('role') || 'display'", true
				)
			)
			. to_lower()
		)
		game_id = str(
			JavaScriptBridge.eval(
				"new URLSearchParams(window.location.search).get('game') || 'TEST001'", true
			)
		)
		local_player_id = str(
			JavaScriptBridge.eval(
				"new URLSearchParams(window.location.search).get('player') || 'player_1'", true
			)
		)
	else:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--role="):
				client_role = arg.trim_prefix("--role=").to_lower()
			elif arg.begins_with("--game="):
				game_id = arg.trim_prefix("--game=")
			elif arg.begins_with("--player="):
				local_player_id = arg.trim_prefix("--player=")
	if client_role != "player":
		client_role = "display"


func _on_presence_error(message: String) -> void:
	push_warning(message)
