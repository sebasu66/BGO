class_name PlayerPresenceRepository
extends Node

signal players_received(players: Dictionary)
signal presence_error(message: String)

var game_id := "TEST001"
var poll_interval_seconds := 1.0

var _adapter: FirebaseRestAdapter
var _poll_timer: Timer
var _read_in_flight := false


func _ready() -> void:
	_adapter = FirebaseRestAdapter.new()
	add_child(_adapter)
	_adapter.request_succeeded.connect(_on_request_succeeded)
	_adapter.request_failed.connect(_on_request_failed)

	_poll_timer = Timer.new()
	_poll_timer.wait_time = poll_interval_seconds
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(refresh)
	add_child(_poll_timer)


## Starts repository synchronization for the current session context.
func start(target_game_id: String) -> void:
	game_id = target_game_id
	refresh()
	_poll_timer.start()


## Refreshes repository state from the remote source.
func refresh() -> void:
	if _read_in_flight:
		return
	_read_in_flight = true
	_adapter.read(_players_path())


## Publishes the current player's presence metadata.
func publish_player(
	player_id: String,
	player_name: String,
	color: String,
	role: String = "player",
	spectator := false,
	seat_id: String = ""
) -> void:
	var path := "%s/%s" % [_players_path(), _sanitize_key(player_id)]
	(
		_adapter
		. patch(
			path,
			{
				"id": player_id,
				"name": player_name,
				"color": color,
				"role": role,
				"spectator": spectator,
				"seat_id": seat_id,
				"connected": true,
				"last_seen": Time.get_unix_time_from_system(),
			}
		)
	)


## Publishes the current player's latest presence pose.
func publish_pose(player_id: String, position: Vector3, forward: Vector3) -> void:
	var path := "%s/%s" % [_players_path(), _sanitize_key(player_id)]
	(
		_adapter
		. patch(
			path,
			{
				"connected": true,
				"last_seen": Time.get_unix_time_from_system(),
				"camera_pose":
				{
					"position": _vec3(position),
					"forward": _vec3(forward),
				},
			}
		)
	)


func _players_path() -> String:
	return "games/%s/players" % _sanitize_key(game_id)


func _on_request_succeeded(operation: StringName, path: String, data: Variant) -> void:
	if operation != &"read" or path != _players_path():
		return
	_read_in_flight = false
	if data == null:
		players_received.emit({})
	elif data is Dictionary:
		players_received.emit(data)
	else:
		presence_error.emit("Unexpected player presence payload.")


func _on_request_failed(
	operation: StringName, path: String, http_code: int, message: String
) -> void:
	if operation == &"read" and path == _players_path():
		_read_in_flight = false
	presence_error.emit(
		"Firebase presence %s %s failed (%d): %s" % [operation, path, http_code, message]
	)


func _vec3(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _sanitize_key(value: String) -> String:
	var result := value
	for forbidden in [".", "#", "$", "[", "]", "/"]:
		result = result.replace(forbidden, "_")
	return result
