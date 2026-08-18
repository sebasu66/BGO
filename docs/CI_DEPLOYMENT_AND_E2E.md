# BGO CI deployment and browser E2E

## Goal

Normal development should not require a local Godot export or manual Firebase Hosting deploy.

The automated development loop is:

```text
commit / push
    ↓
GitHub Actions
    ↓
Godot import + domain tests
    ↓
validated Web export
    ↓
Playwright smoke tests against the exported build
    ↓
Firebase DEV preview-channel deploy (develop only)
    ↓
Playwright smoke tests against the deployed URL
    ↓
artifacts + project-status CI metadata
```

PROD remains outside this automatic path. No ordinary feature/develop commit may deploy to the Firebase live channel.

## Current implementation

`.github/workflows/quality-gate.yml` now:

- installs pinned Godot and Web export templates;
- runs existing structure/lint/import/domain checks;
- creates the validated Godot Web export;
- installs Playwright/Chromium;
- runs browser smoke tests locally against `build/web`;
- preserves screenshots, videos, traces, JSON results and the HTML Playwright report under the `bgo-e2e-*` workflow artifact;
- when the branch is `develop`, deploys only to the Firebase Hosting preview channel named `dev`;
- runs the same browser tests again against the deployed DEV URL;
- records `e2e_local`, `deploy_dev` and `e2e_dev` outcomes in `project-status/ci.json`.

The named `dev` preview channel is intentional: it cannot overwrite the Hosting `live` channel used for the stable/public build.

## One-time owner setup

The repository cannot safely contain Firebase deployment credentials. Before the first automatic `develop` deployment, the repository owner must configure two GitHub Actions values:

### Secret

`FIREBASE_DEV_SERVICE_ACCOUNT`

Value: the JSON service-account credential authorized to deploy Firebase Hosting for the chosen DEV Firebase project.

Store it as a GitHub Actions repository secret. Never commit the JSON key to the repository.

Firebase can create/configure the Hosting GitHub integration with:

```text
firebase init hosting:github
```

The official Firebase setup flow creates a Hosting-capable service account and stores its JSON key as an encrypted GitHub secret. If that command generates additional workflow files, BGO should keep its curated quality-gate workflow as the source of truth rather than adopting a second competing deployment pipeline.

### Repository variable

`FIREBASE_DEV_PROJECT_ID`

Value: the explicit Firebase project ID used for DEV.

Do not invent this value in code. During the prototype transition it may intentionally point at the existing project, but the deployment remains isolated from the live channel by using Hosting preview channel `dev`. Separate Firebase DEV/PROD projects remain the preferred long-term backend isolation model.

## Browser evidence

Playwright configuration lives in:

- `package.json`
- `playwright.config.mjs`
- `tests/e2e/`
- `scripts/serve_web.mjs`

The initial suite checks:

- project-status dashboard loads;
- test launcher loads;
- Godot Web creates a canvas;
- the browser flight recorder exists before/while Godot runs;
- the public error-viewer surface loads;
- uncaught page errors fail relevant checks.

Successful landmark screenshots are kept for inspection. Failures additionally retain Playwright trace/video/screenshots. This is deliberate observability: automated steps must produce evidence sufficient to diagnose what happened rather than only reporting `failed`.

## Near-term E2E growth

After SessionState and stable semantic state exist, add deterministic scenarios for:

1. open launcher;
2. create/join a fixture session;
3. open Display, P1 and P2 browser contexts;
4. verify seat/role identity;
5. select and move an object;
6. verify logical state transition through the BGO Semantic Interface;
7. verify the other clients converge;
8. capture screenshots and semantic snapshots at meaningful milestones.

Visual screenshots should complement semantic assertions rather than replace them. Pixel-perfect comparison of the 3D canvas should be introduced only where it is stable enough to avoid GPU/render false positives.

## Failure evidence target

A mature failed browser run should make available:

- commit SHA and tested URL;
- GitHub Action step outcomes;
- browser console and page errors;
- network failures where relevant;
- Playwright trace;
- screenshots/video;
- BGO flight-recorder snapshot;
- semantic session state before/after the failing action;
- legal actions visible to the test participant.

This same evidence should later be consumable by AI debugging agents.
