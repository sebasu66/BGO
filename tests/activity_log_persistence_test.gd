class_name ActivityLogPersistenceTest
extends RefCounted

const ACTIVITY_LOG = preload("res://src/core/bgo_activity_log.gd")
const SESSION_REPOSITORY = preload("res://src/network/game_session_repository.gd")

class FakeRepository extends Node:
	var persisted: Array[Dictionary] = []

	func persist_activity_event(event: Dictionary) -> void:
		persisted.append(event.duplicate(true))


static func run(check: Callable) -> void:
	var logger := ACTIVITY_LOG.new()
	logger.file_enabled = false
	var repository := FakeRepository.new()
	logger.bind_session_repository(repository, "match-shared")
	logger.record_invocation(
		"Match.objects.token.moveToPoint",
		"mcp",
		{
			"session_id": "match-shared",
			"participant_id": "player-1",
			"role": "host",
			"entity": "Match.objects.token",
			"arguments": {"x": 2, "y": 3},
		},
		{"ok": true, "object_id": "token"},
	)
	check.call(repository.persisted.size() == 1, "API event is persisted through the session repository")
	var persisted: Dictionary = repository.persisted[0]
	check.call(str(persisted.get("session_id", "")) == "match-shared", "event carries session identity")
	check.call(str(persisted.get("transport", "")) == "mcp", "event carries transport source")
	check.call(str(persisted.get("actor", {}).get("participant_id", "")) == "player-1", "event carries actor metadata")
	check.call(persisted.get("arguments_summary", {}).get("x", -1) == 2, "event carries summarized arguments")
	check.call(bool(persisted.get("result_summary", {}).get("ok", false)), "event carries result summary")
	var event_patch := SESSION_REPOSITORY.activity_event_patch(persisted)
	check.call(event_patch.keys().size() == 1 and event_patch.keys()[0].begins_with("activity_log/events/"), "repository writes one keyed shared event child")

	var recovered := ACTIVITY_LOG.new()
	recovered.file_enabled = false
	recovered.recover_shared_events({str(persisted["event_id"]): persisted})
	check.call(recovered.entries.size() == 1, "shared activity event is recoverable into a new client")
	check.call(recovered.entries[0].get("method") == persisted.get("method"), "recovery preserves method")

	var many := {}
	for index in range(4):
		many["event-%02d" % index] = {"event_id": "event-%02d" % index}
	var bounded := SESSION_REPOSITORY.bounded_activity_events(many, 2)
	check.call(bounded.keys() == ["event-02", "event-03"], "bounded history keeps the newest event ids")
	var merged := SESSION_REPOSITORY.merge_activity_events({"event-02": many["event-02"]}, {"event-03": many["event-03"]})
	check.call(merged.keys() == ["event-02", "event-03"], "separate clients converge by merging keyed session events")
	var prune := SESSION_REPOSITORY.activity_prune_patch(many, 2)
	check.call(prune.get("activity_log/events/event-00") == null, "bounded history emits deletions for stale events")
	check.call(prune.get("activity_log/events/event-02", "missing") == "missing", "bounded history retains current events")
