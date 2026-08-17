# BGO error diagnostics

BGO keeps normal runtime logging local/in-memory and publishes an error run only when an error is detected.

## Public latest error

During the current Firebase Test Mode prototype, TEST001 exposes the latest uploaded error at:

`https://board-game-online-68c3f-default-rtdb.firebaseio.com/debug_public/latest_error/TEST001.json`

Each payload contains run/game/client IDs, capture timestamp/source, recent structured BGO events, and the browser flight-recorder snapshot. Full history is written under `/debug/<game>/<client>/error_runs/<run_id>`.

This public endpoint is temporary and must be removed or protected when RTDB security is enabled.

## Browser flight recorder

The Web export injects `window.__bgoFlightRecorder` before Godot starts. It records console output, `window.onerror`, and unhandled promise rejections into a bounded in-memory buffer.

Godot polls it frequently and uploads only when an error generation advances. Structured BGO errors trigger an immediate poll. If the recorder is missing, `BgoLogger` publishes a synthetic `WEB_FLIGHT_RECORDER_MISSING` error so the diagnostics failure is itself visible.

## Repeatable Web export

PowerShell:

```powershell
./scripts/export_web.ps1
```

Linux/macOS/CI:

```bash
bash scripts/export_web.sh
```

Both clean `build/web`, import the project, export Godot Web, copy auxiliary Web pages, and run `scripts/validate_web_export.py`.

Validation fails when the main Web files are absent/empty, the flight recorder is missing from `index.html`, TEST001 JSONH is missing from `index.pck`, or `/project-status/` / `/test-launcher/` were not copied.

GitHub Actions uses the same export path. Export may be automated; Firebase deployment remains an explicit owner action:

```bash
firebase deploy --only hosting
```

Never use plain `firebase deploy` for this prototype workflow.
