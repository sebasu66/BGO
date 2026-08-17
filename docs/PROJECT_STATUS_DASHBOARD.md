# BGO Project Status Dashboard

The project status dashboard is a lightweight static page intended to provide a fixed overview of BGO development health.

Target Firebase Hosting path:

```text
/project-status/
```

With the current Hosting site this is expected to become:

```text
https://board-game-online-68c3f.web.app/project-status/
```

The dashboard source lives in:

```text
web/project-status/
```

It must not be authored directly inside `build/web`, because Godot Web export output is generated and may be replaced.

Before deploying Hosting, copy the dashboard into the generated Web output with:

```powershell
./scripts/sync_project_status.ps1
```

Then deploy Hosting only:

```text
firebase deploy --only hosting
```

Do not use an unrestricted `firebase deploy` during the current prototype.

## Purpose

The dashboard should answer, at a glance:

- What is the active checkpoint?
- What is the next implementation step?
- Which roadmap phases are complete, active, or planned?
- What is progressing in the parallel Web Platform track?
- Are there known blockers or risks?
- Did lint/tests/build/export pass?
- Which commit/build does the displayed health result refer to?

## Data contract

The first implementation reads:

```text
web/project-status/status.json
```

This is intentionally plain JSON so it can be updated by humans, coding agents, scripts, or GitHub Actions without rebuilding a frontend application.

Primary fields include:

- `overall`
- `current_checkpoint`
- `health_checks`
- `blockers`
- `core_roadmap`
- `web_roadmap`
- `ci`

The dashboard presentation must remain tolerant of missing/unknown automated data. A missing CI integration is shown as unknown/pending rather than pretending the project is healthy.

## Source of truth

`docs/IMPLEMENTATION_ROADMAP.md` remains the authoritative architectural roadmap.

`status.json` is the operational projection used by the dashboard. When a checkpoint, blocker, or implementation order changes materially, update both the roadmap/documentation and the dashboard projection.

Do not silently mark work complete because code was committed. Completion should follow the checkpoint rules in the roadmap.

## CI integration

Phase 1 should extend GitHub Actions so the quality workflow can produce/update machine-readable health information for the dashboard.

Useful automated fields include:

- commit SHA
- branch/environment
- workflow run identifier
- format result
- gdlint result
- structure/architecture checks
- Godot headless import/parse result
- unit/domain test counts
- conformance test counts
- Web export result
- timestamp

A practical implementation can generate a CI result JSON and merge it into `status.json` during the build/deploy job, without requiring CI to commit generated runtime status back into Git.

The source `status.json` should continue to carry roadmap/checkpoint/blocker information. CI owns transient test/build results.

## DEV / PROD

Eventually both DEV and PROD should expose their own dashboard route and clearly identify the branch/commit they represent.

For example:

```text
DEV  /project-status/ -> develop commit + latest DEV quality result
PROD /project-status/ -> manually promoted main commit + stable quality result
```

A DEV failure must not modify the PROD dashboard.

## Agent rule

When an agent completes a checkpoint, discovers a material blocker, changes implementation order, or introduces/removes a project-health risk, it must update the status dashboard data/documentation as part of the same coherent change.

Cosmetic code changes do not require status updates.
