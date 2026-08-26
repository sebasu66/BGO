class_name GithubBridgeUiTest

const SESSION_STATE = preload("res://src/core/session_state.gd")
const TRANSPORT = preload("res://src/network/github_jobs_transport.gd")
const ADAPTER = preload("res://src/runtime/runtime_session_adapter.gd")

static func run(check: Callable) -> void:
	var session := SESSION_STATE.create_lobby("match-ui", "host")
	session.assign_participant("host", "seat-1", "player")
	session.start_session()
	session.github_jobs_enabled = true
	var snapshot: Dictionary = session.to_dictionary()
	check.call(bool(snapshot.get("github_jobs_enabled", false)), "bridge setting persists in session state")

	var restored := ADAPTER.new()
	var definition := {
		"players": [{"id": "host"}],
		"table": {"width": 1.0, "depth": 1.0, "areas": []},
		"setup": {"objects": []},
	}
	var loaded := restored.load_session("match-ui", definition, {"session": snapshot})
	check.call(bool(loaded.get("ok", false)), "session with bridge setting reloads")
	check.call(bool(restored.gameplay_state.session.github_jobs_enabled), "reloaded session keeps bridge setting")

	check.call(
		TRANSPORT.status(false, "client-a", {}, 100) == TRANSPORT.STATUS_DISABLED,
		"bridge status derives disabled"
	)
	check.call(
		TRANSPORT.status(true, "client-a", {"holder_id": "client-a", "expires_at": 110}, 100) == TRANSPORT.STATUS_LEADER_POLLING,
		"bridge status derives leader polling"
	)
	check.call(
		TRANSPORT.status(true, "client-a", {"holder_id": "client-b", "expires_at": 110}, 100) == TRANSPORT.STATUS_STANDBY,
		"bridge status derives standby"
	)
	check.call(
		TRANSPORT.status(true, "client-a", {}, 100, "network") == TRANSPORT.STATUS_ERROR,
		"bridge status derives error"
	)
