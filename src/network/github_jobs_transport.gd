class_name BgoGithubJobsTransport
extends RefCounted

const STATUS_DISABLED := "disabled"
const STATUS_LEADER_POLLING := "leader/polling"
const STATUS_STANDBY := "standby"
const STATUS_ERROR := "error"

## Derives the bridge state from the persisted match setting and Phase 1 lease.
static func status(enabled: bool, client_id: String, lease: Dictionary, now: int, error_message: String = "") -> String:
	if not enabled:
		return STATUS_DISABLED
	if not error_message.is_empty() or client_id.is_empty():
		return STATUS_ERROR
	if LEASE.owns(lease, client_id, now):
		return STATUS_LEADER_POLLING
	return STATUS_STANDBY

const JOB_SCHEMA = preload("res://src/network/github_job_schema.gd")
const LEASE = preload("res://src/network/github_job_lease.gd")

## Transport-neutral GitHub Actions job projection. GitHub is an input source;
## the persisted match remains authoritative and the supplied processor owns
## command semantics.
static func process_pending(
	session: Dictionary,
	client_id: String,
	processor: RefCounted,
	game_definition: Dictionary,
	now: int
) -> Dictionary:
	var lease_result := LEASE.candidate(session.get("github_lease", {}), client_id, now)
	if not bool(lease_result.get("acquired", false)):
		return {"ok": true, "should_patch_lease": false, "patch": {}, "reason": lease_result.get("reason", "")}
	var patch: Dictionary = {"github_lease": lease_result.get("lease", {})}
	var jobs: Dictionary = session.get("github_jobs", {})
	var processed := 0
	for job_id_variant in jobs:
		var job_id := str(job_id_variant)
		var job: Dictionary = jobs[job_id_variant]
		if str(job.get("status", "")) != JOB_SCHEMA.STATUS_PENDING:
			continue
		var validation := JOB_SCHEMA.validate_job(job, str(session.get("session_id", "")))
		var result: Dictionary
		if not bool(validation.get("ok", false)):
			result = {"ok": false, "reason": validation.get("reason", "invalid_job")}
		else:
			var command := {
				"tool": str(job.get("tool", "")),
				"context": job.get("context", {}).duplicate(true),
				"arguments": job.get("arguments", {}).duplicate(true),
			}
			result = processor.process(command, session, game_definition)
		var accepted := bool(result.get("ok", false))
		var stored := JOB_SCHEMA.create_result(job_id, result, now)
		stored["status"] = JOB_SCHEMA.STATUS_COMPLETED if accepted else JOB_SCHEMA.STATUS_REJECTED
		patch["github_jobs/%s/status" % job_id] = stored["status"]
		patch["github_jobs/%s/result" % job_id] = stored
		patch["github_jobs/%s/processed_by" % job_id] = client_id
		var piece_id := str(result.get("piece_id", ""))
		var piece_state: Dictionary = result.get("piece_state", {})
		if accepted and not piece_id.is_empty() and not piece_state.is_empty():
			patch["pieces/%s" % piece_id] = piece_state
		if accepted and result.has("definition_update"):
			var definition_patch: Dictionary = result.get("definition_patch", {})
			for path_variant in definition_patch:
				patch["definition/%s" % str(path_variant)] = definition_patch[path_variant]
			var updated_definition: Dictionary = result.get("definition_update", {})
			if not updated_definition.is_empty():
				game_definition.clear()
				game_definition.merge(updated_definition, true)
		processed += 1
	return {"ok": true, "should_patch_lease": true, "patch": patch, "processed": processed}

static func duplicate_result(session: Dictionary, job_id: String) -> Dictionary:
	var job: Dictionary = (session.get("github_jobs", {}) as Dictionary).get(job_id, {})
	if str(job.get("status", "")) in [JOB_SCHEMA.STATUS_COMPLETED, JOB_SCHEMA.STATUS_REJECTED]:
		return {"ok": true, "duplicate": true, "result": job.get("result", {})}
	return {"ok": false, "duplicate": false, "reason": "job_not_processed"}
