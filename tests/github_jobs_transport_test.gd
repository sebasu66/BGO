extends RefCounted

const TRANSPORT = preload("res://src/network/github_jobs_transport.gd")
const LEASE = preload("res://src/network/github_job_lease.gd")
const SCHEMA = preload("res://src/network/github_job_schema.gd")

class FakeProcessor:
	func process(command: Dictionary, _session: Dictionary, _definition: Dictionary) -> Dictionary:
		if str(command.get("tool", "")) == "bgo_set_properties":
			return {
				"ok": true,
				"entity": "Game.table.instances.main_board",
				"definition_update": {"table": {"instances": [{"id": "main_board", "config": {"columns": 8, "rows": 8}}]}},
				"definition_patch": {"table/instances/0/config/rows": 8},
			}
		return {"ok": true, "piece_id": str(command.get("arguments", {}).get("object_id", "job-piece")), "piece_state": {"from": "github"}}

static func run(check: Callable) -> void:
	var first := LEASE.candidate({}, "client-a", 100)
	check.call(bool(first.get("acquired", false)), "GitHub lease elects the first client")
	var blocked := LEASE.candidate(first.get("lease", {}), "client-b", 101)
	check.call(not bool(blocked.get("acquired", false)), "live lease blocks a second client")
	var failover := LEASE.candidate(first.get("lease", {}), "client-b", 116)
	check.call(bool(failover.get("acquired", false)), "expired lease fails over to another client")
	var job := SCHEMA.create_job("MATCH-1", "job-1", "bgo_move_object_to_point", {"session_id": "MATCH-1", "role": "host", "participant_id": "host"}, {"object_id": "piece-1"}, 100)
	var session := {"session_id": "MATCH-1", "github_jobs": {"job-1": job}}
	var processed := TRANSPORT.process_pending(session, "client-a", FakeProcessor.new(), {}, 101)
	var patch: Dictionary = processed.get("patch", {})
	check.call(int(processed.get("processed", 0)) == 1, "GitHub job routes through the supplied canonical processor")
	check.call(str(patch.get("github_jobs/job-1/status", "")) == "completed", "GitHub job receives a structured result status")
	var definition_job := SCHEMA.create_job("MATCH-1", "job-definition", "bgo_set_properties", {"session_id": "MATCH-1", "role": "host", "participant_id": "host"}, {"entity": "Game.table.instances.main_board", "changes": {"configuration": {"rows": 8}}}, 100)
	var definition_session := {"session_id": "MATCH-1", "github_jobs": {"job-definition": definition_job}}
	var definition_processed := TRANSPORT.process_pending(definition_session, "client-a", FakeProcessor.new(), {"table": {"instances": [{"id": "main_board", "config": {"columns": 8, "rows": 6}}]}}, 101)
	var definition_patch: Dictionary = definition_processed.get("patch", {})
	check.call(
		int(definition_patch.get("definition/table/instances/0/config/rows", 0)) == 8,
		"GitHub definition jobs project their patch below the shared session definition"
	)
	var stored_result: Dictionary = definition_patch.get("github_jobs/job-definition/result", {})
	var public_result: Dictionary = stored_result.get("result", {})
	check.call(
		not public_result.has("definition_update") and not public_result.has("definition_patch"),
		"GitHub job confirmation omits internal definition snapshots and slash-key patches"
	)
	var changes: Array = public_result.get("definition_changes", [])
	check.call(
		changes == [{"path": "table/instances/0/config/rows", "value": 8}],
		"GitHub job confirmation serializes definition changes as Firebase-safe path/value entries"
	)
	var completed := session.duplicate(true)
	completed["github_jobs"]["job-1"]["status"] = "completed"
	completed["github_jobs"]["job-1"]["result"] = {"ok": true}
	var duplicate := TRANSPORT.duplicate_result(completed, "job-1")
	check.call(bool(duplicate.get("duplicate", false)), "completed GitHub jobs are suppressed idempotently")
