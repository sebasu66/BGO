class_name FlowState
extends RefCounted

var phase_id: String = "main"
var turn_number: int = 0
var active_participant_ids: Array[String] = []
var turn_order: Array[String] = []
var turn_index: int = -1


static func create(participant_ids: Array[String], initial_phase: String = "main") -> FlowState:
	var flow := FlowState.new()
	flow.phase_id = initial_phase
	flow.turn_order = participant_ids.duplicate()
	return flow


## Starts turn flow with the requested participant, or the first ordered participant.
func start(initial_participant_id: String = "") -> bool:
	if turn_order.is_empty() or turn_number != 0:
		return false
	turn_index = 0 if initial_participant_id.is_empty() else turn_order.find(initial_participant_id)
	if turn_index < 0:
		return false
	turn_number = 1
	active_participant_ids = [turn_order[turn_index]]
	return true


## Returns whether the participant may currently act in this flow.
func is_active(participant_id: String) -> bool:
	return active_participant_ids.has(participant_id)


## Completes the active participant's turn and advances deterministic turn order.
func end_turn(participant_id: String) -> bool:
	if not is_active(participant_id) or turn_order.is_empty():
		return false
	turn_index = (turn_index + 1) % turn_order.size()
	turn_number += 1
	active_participant_ids = [turn_order[turn_index]]
	return true


## Returns a serializable snapshot of phase and turn state.
func to_dictionary() -> Dictionary:
	return {
		"phase_id": phase_id,
		"turn_number": turn_number,
		"active_participant_ids": active_participant_ids.duplicate(),
		"turn_order": turn_order.duplicate(),
		"turn_index": turn_index,
	}
