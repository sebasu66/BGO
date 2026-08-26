class_name BgoGithubJobSchema
extends RefCounted

const RESULT_PROJECTION = preload("res://src/mcp/mcp_result_projection.gd")
const SCHEMA_VERSION := 1
const STATUS_PENDING := "pending"
const STATUS_COMPLETED := "completed"
const STATUS_REJECTED := "rejected"

static func create_job(
	session_id: String,
	job_id: String,
	tool: String,
	context: Dictionary,
	arguments: Dictionary,
	created_at: int = 0
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"job_id": job_id,
		"session_id": session_id,
		"transport": "github",
		"tool": tool,
		"context": context.duplicate(true),
		"arguments": arguments.duplicate(true),
		"status": STATUS_PENDING,
		"attempt": 0,
		"created_at": created_at,
	}

static func create_result(job_id: String, result: Dictionary, processed_at: int) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"job_id": job_id,
		"ok": bool(result.get("ok", false)),
		"result": RESULT_PROJECTION.for_persistence(result),
		"processed_at": processed_at,
	}

static func validate_job(job: Dictionary, expected_session_id: String = "") -> Dictionary:
	for field in ["job_id", "session_id", "tool", "context", "arguments", "status"]:
		if not job.has(field):
			return {"ok": false, "reason": "missing_field:%s" % field}
	if int(job.get("schema_version", 0)) != SCHEMA_VERSION:
		return {"ok": false, "reason": "unsupported_schema_version"}
	if expected_session_id != "" and str(job.get("session_id", "")) != expected_session_id:
		return {"ok": false, "reason": "session_mismatch"}
	if str(job.get("status", "")) != STATUS_PENDING:
		return {"ok": false, "reason": "job_not_pending"}
	if not job.get("context", {}) is Dictionary or not job.get("arguments", {}) is Dictionary:
		return {"ok": false, "reason": "invalid_payload"}
	return {"ok": true}
