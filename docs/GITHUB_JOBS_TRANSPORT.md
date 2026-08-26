# GitHub Jobs transport

Phase 1 adds a transport abstraction for GitHub-originated work without adding
UI or changing the existing MCP transport.

Jobs are persisted below the match/session path:

```text
<match>/github_jobs/<job_id>
<match>/github_lease
```

Each job has a schema version, session id, stable job id, canonical tool name,
context, arguments, status, attempt count, and a structured result. A job is
processed only by the current single-client lease holder. The lease is renewed
on each session poll and expires so another client can take over after failure.
The job id and persisted terminal status provide duplicate suppression.

`BgoGithubJobsTransport` converts the job into the existing command envelope
and delegates to `BgoMcpCommandProcessor`. It does not implement Game, Match,
or System command semantics.

Declarative authoring uses the same path with logical entities such as
`Game.table.instances.main_board`. The canonical processor validates component
configuration through the registry and returns a definition patch. The
repository projects that patch below the shared session `definition` node;
clients observing the updated definition apply it to the already composed
runtime component.

Godot Web must not contain a GitHub PAT. `BgoGithubJobRelay` is the boundary for
authenticated GitHub dispatch: a server-side relay may submit work and persist
the resulting job, while the client only consumes the persisted session data.

Every public BGO API invocation records a structured `PUBLIC_API_INVOCATION`
entry through the `BgoActivityLog` autoload. The authoritative bounded history
is persisted in the shared match/session state at
`activity_log/events/<event_id>` through the existing realtime repository, so
another client can recover it. JSONL under `user://logs/bgo-activity.jsonl`
remains optional local diagnostics only. Keyed child patches and repository-side
pruning keep concurrent clients convergent without logging the persistence write
back into the activity stream.

This phase intentionally includes no toasts, timeline or panel UI, bridge
settings UI, styling, or GitHub authentication in the client.
