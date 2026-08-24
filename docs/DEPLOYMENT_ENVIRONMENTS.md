# BGO — Development and Production Environments

This document defines how BGO separates ongoing development from the stable publicly accessible build.

The immediate goal is **not** enterprise release management. The goal is to let development move quickly without losing a known stable version that can always be opened and demonstrated.

## Terminology

For the current prototype stage:

- **DEV** means the actively changing integration build used for current testing.
- **PROD** means the manually promoted stable/public build.

`PROD` does **not** yet imply that authentication, billing, security rules, support processes, or commercial infrastructure are production-ready. Until those checkpoints are explicitly implemented, it simply means "the stable build we choose to expose publicly".

## Git branch model

Target branch structure:

```text
feature/*
    ↓
develop
    ↓  manual promotion only
main
```

### `develop`

- integration branch for current development
- receives completed feature/fix work after its quality checks pass
- source of the DEV deployment
- may change frequently
- must still remain runnable; DEV is not permission to commit knowingly broken code

### `main`

- stable branch corresponding to PROD
- must remain deployable
- is **never automatically advanced from `develop`**
- promotion from `develop` to `main` is a deliberate release decision

The project owner decides when DEV is good enough to become PROD. CI or an AI agent may recommend promotion, but must not make that product decision autonomously.

During the current prototype, work may temporarily continue on existing feature branches such as `feature/godot-core-prototype`. The branch model above is the intended steady state and should be introduced without disrupting active work.

## Promotion policy

Normal flow:

```text
feature/fix
    ↓
quality gate
    ↓
develop
    ↓
automatic DEV deploy
    ↓
manual validation
    ↓
OWNER DECIDES TO PROMOTE
    ↓
merge/promote develop → main
    ↓
quality gate again
    ↓
PROD deploy
```

A DEV commit passing CI is **not** sufficient authorization to publish it as PROD.

Production promotion should be explicit and auditable, preferably through a pull request or a manually triggered release workflow.

## Deployment behavior

Both builds should remain accessible at the same time through different URLs.

Conceptually:

```text
DEV URL  → current `develop` build
PROD URL → current `main` build
```

This lets us:

- test new functionality without replacing the stable demo
- compare regressions between DEV and PROD
- show the stable product while continuing active development
- roll forward deliberately rather than deploying every experiment publicly

## Firebase environment strategy

Firebase Hosting supports multiple sites, but Firebase documentation recommends **separate Firebase projects for actual DEV and PROD environments** because multiple Hosting sites in one project share the project's backend resources. For BGO, separate projects are therefore the target architecture once backend isolation matters.

### Preferred target

```text
Firebase DEV project
  Hosting DEV
  RTDB DEV
  Auth DEV later
  Storage DEV later

Firebase PROD project
  Hosting PROD
  RTDB PROD
  Auth PROD later
  Storage PROD later
```

This provides real isolation between test sessions/data and stable/public sessions.

### Prototype transition

Do not block current development on creating the full duplicated Firebase infrastructure.

The existing Firebase project (`board-game-online-68c3f`) may continue to serve the current prototype while the environment split is introduced incrementally.

If two Hosting sites are temporarily used inside one Firebase project, treat that as **content deployment separation, not backend isolation**. Shared RTDB/Auth/Storage resources must not be mistaken for independent DEV/PROD environments.

Until separate Firebase projects exist, any shared backend state that needs DEV/PROD separation should use an explicit environment namespace or equivalent adapter configuration rather than silently mixing sessions.

## Configuration

Client code must not hard-code one deployment environment throughout the domain.

Use environment-specific configuration for values such as:

- Firebase project ID
- RTDB URL
- Hosting/runtime base URL
- package/catalog endpoints later
- logging/debug flags
- feature flags where needed

Domain logic should remain environment-independent.

Conceptually:

```text
EnvironmentConfig
  ├── dev
  └── prod
```

Do not duplicate gameplay code to create DEV and PROD builds.

## Authentication during early development

Authentication is deliberately **not required to implement the current technical prototype**.

During early DEV/PROD-stable testing:

- anonymous/test access may be used where currently required for rapid iteration
- do not block game-runtime or web-shell work on account registration UX
- do not introduce fake production-grade authentication merely to satisfy a future requirement

Before a broader public beta, the web-platform checkpoint may introduce account-required access. At that point, DEV should remain easy to test through an explicit development/test authentication path or Firebase emulator/test setup rather than forcing developers through normal end-user onboarding for every test.

## CI/CD rules

Eventually CI should implement:

### Feature branches

- lint
- tests
- architecture checks
- headless Godot validation
- Web export smoke test
- no permanent deploy required

### `develop`

- full quality gate
- deploy DEV only after green checks

### `main`

- full quality gate again
- deploy PROD only from an explicit promotion to `main`

Never allow a feature branch or ordinary `develop` push to overwrite PROD.

## Firebase deploy safety

Current repository safety rule remains:

```text
firebase deploy --only hosting
```

The DEV MCP prototype adds one equally scoped exception:

```text
firebase deploy --only functions:bgo-mcp-dev:bgoMcpDev --project board-game-online-68c3f
```

It deploys neither Hosting nor RTDB rules. The `develop` workflow may execute
this named function deployment after its quality gate; it must never substitute
an unrestricted `firebase deploy`.

Do not use unrestricted `firebase deploy` while RTDB rules and other Firebase resources are intentionally in prototype state.

When multiple projects/targets are introduced, deployment scripts must make the destination environment explicit. A command should make it difficult to accidentally deploy DEV output to PROD.

Prefer commands/workflows conceptually equivalent to:

```text
deploy-dev
promote-prod
```

over a generic ambiguous `deploy` command.

## Checkpoint for introducing the branch/deploy split

The DEV/PROD deployment model is considered established when:

- `develop` and `main` responsibilities are documented and enforced
- DEV and PROD builds have distinct persistent URLs
- both can be opened independently
- DEV deployment cannot overwrite PROD
- promoting DEV to PROD requires an explicit owner action
- both builds come from known Git commits
- environment configuration is explicit rather than scattered through code
- CI reports which commit is deployed to each environment

Authentication, billing, and commercial hardening are separate checkpoints and must not be pulled into this work prematurely.
