extends RefCounted

const TRANSPORT = preload("res://src/network/github_jobs_transport.gd")
const LEASE = preload("res://src/network/github_job_lease.gd")
const SCHEMA = preload("res://src/network/github_job_schema.gd")

class FakeProcessor:
	func process(command: Dictionary, _session: Dictionary, _definition: Dictionary) -> Dictionary:
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
	var completed := session.duplicate(true)
	completed["github_jobs"]["job-1"]["status"] = "completed"
	completed["github_jobs"]["job-1"]["result"] = {"ok": true}
	var duplicate := TRANSPORT.duplicate_result(completed, "job-1")
	check.call(bool(duplicate.get("duplicate", false)), "completed GitHub jobs are suppressed idempotently")
