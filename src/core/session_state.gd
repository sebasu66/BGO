class_name SessionState
extends RefCounted

## Logical lifecycle phases of a BGO session.
enum Lifecycle {
	LOBBY,
	ACTIVE,
	ENDED,
}

## Stable session identity (opaque string).
var session_id: String = ""

## Current lifecycle phase of the session.
var lifecycle: int = Lifecycle.LOBBY

## Participant id that currently holds host capabilities.
var host_participant_id: String = ""

## Ordered seat ids that define turn order when the session is active.
var seat_order: Array[String] = []

## Map of participant_id -> seat_id for assigned participants.
var participant_seats: Dictionary = {}

## Map of participant_id -> role string (e.g. "player", "spectator").
var participant_roles: Dictionary = {}

## Participant id whose turn is currently active (empty when not applicable).
var active_participant_id: String = ""

## 1-based turn counter; 0 means turns have not started.
var turn_number: int = 0

## Optional result payload when the session has ended.
## Expected shape: {"outcome": String, "winner_participant_ids": Array[String]}
var result: Dictionary = {}


## Creates a new lobby session with the given identity and optional host.
static func create_lobby(p_session_id: String, p_host_participant_id: String = "") -> SessionState:
	var state := SessionState.new()
	state.session_id = p_session_id
	state.lifecycle = Lifecycle.LOBBY
	state.host_participant_id = p_host_participant_id
	if not p_host_participant_id.is_empty():
		state.participant_roles[p_host_participant_id] = "player"
	return state


## Returns whether the given participant currently holds host capability.
func is_host(participant_id: String) -> bool:
	return not participant_id.is_empty() and participant_id == host_participant_id


## Returns whether the session is in the active gameplay lifecycle.
func is_active() -> bool:
	return lifecycle == Lifecycle.ACTIVE


## Returns whether the session has ended and carries a final result.
func is_ended() -> bool:
	return lifecycle == Lifecycle.ENDED


## Assigns a participant to a seat with an optional role.
## Rejects empty ids and duplicate seat occupancy. Returns true on success.
func assign_participant(participant_id: String, seat_id: String, role: String = "player") -> bool:
	if participant_id.is_empty() or seat_id.is_empty():
		return false
	for existing_participant in participant_seats:
		if participant_seats[existing_participant] == seat_id and existing_participant != participant_id:
			return false
	participant_seats[participant_id] = seat_id
	participant_roles[participant_id] = role
	if not seat_order.has(seat_id):
		seat_order.append(seat_id)
	return true


## Removes a participant assignment without mutating host unless the host leaves.
func remove_participant(participant_id: String) -> void:
	if participant_id.is_empty():
		return
	var seat_id := str(participant_seats.get(participant_id, ""))
	participant_seats.erase(participant_id)
	participant_roles.erase(participant_id)
	if participant_id == host_participant_id:
		host_participant_id = ""
	if participant_id == active_participant_id:
		active_participant_id = ""
	if not seat_id.is_empty() and not _seat_still_occupied(seat_id):
		seat_order.erase(seat_id)


## Sets or clears the host identity. Empty string clears host capability.
func set_host(participant_id: String) -> void:
	host_participant_id = participant_id


## Transitions a lobby session into the active lifecycle with an initial turn.
## Requires at least one seated participant. Returns true on success.
func start_session(initial_participant_id: String = "") -> bool:
	if lifecycle != Lifecycle.LOBBY:
		return false
	if participant_seats.is_empty():
		return false
	var starter := initial_participant_id
	if starter.is_empty():
		starter = str(participant_seats.keys()[0])
	elif not participant_seats.has(starter):
		return false
	lifecycle = Lifecycle.ACTIVE
	active_participant_id = starter
	turn_number = 1
	result = {}
	return true


## Records an ended lifecycle with an explicit outcome and optional winners.
## Returns true when the transition is accepted.
func end_session(outcome: String, winner_participant_ids: Array = []) -> bool:
	if lifecycle == Lifecycle.ENDED:
		return false
	if outcome.is_empty():
		return false
	lifecycle = Lifecycle.ENDED
	active_participant_id = ""
	var winners: Array[String] = []
	for winner in winner_participant_ids:
		winners.append(str(winner))
	result = {
		"outcome": outcome,
		"winner_participant_ids": winners,
	}
	return true


## Returns a deep-copy dictionary of the logical session state for tests/persistence.
func to_dictionary() -> Dictionary:
	return {
		"session_id": session_id,
		"lifecycle": _lifecycle_name(lifecycle),
		"host_participant_id": host_participant_id,
		"seat_order": seat_order.duplicate(),
		"participant_seats": participant_seats.duplicate(true),
		"participant_roles": participant_roles.duplicate(true),
		"active_participant_id": active_participant_id,
		"turn_number": turn_number,
		"result": result.duplicate(true),
	}


func _seat_still_occupied(seat_id: String) -> bool:
	for participant_id in participant_seats:
		if participant_seats[participant_id] == seat_id:
			return true
	return false


func _lifecycle_name(value: int) -> String:
	match value:
		Lifecycle.LOBBY:
			return "lobby"
		Lifecycle.ACTIVE:
			return "active"
		Lifecycle.ENDED:
			return "ended"
		_:
			return "unknown"
