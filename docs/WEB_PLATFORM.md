# BGO Web Platform

This document defines the public-facing web application that surrounds the BGO game runtime.

The web platform is a separate client/product surface from the Godot runtime. It may be implemented with conventional web technology and developed in parallel, including with AI-assisted tools such as Replit. It should share identity, session metadata, billing state, catalog data, and product configuration with the rest of BGO without forcing those concerns into Godot scenes.

## Responsibilities

The web platform owns product and account workflows that are better served by a normal web application:

- landing / product explanation
- registration, login, account recovery
- profile and account settings
- subscription / billing UI
- plan and entitlement explanations
- game catalog and discovery
- owned/installed/favorite game packages
- create / join / resume session flows
- invite links and room codes
- device-role selection (player, display, spectator, host where allowed)
- download/install links for native clients
- documentation, FAQ, changelog, release notes
- mod/package author and publishing workflows later
- admin/support tooling later

The Godot runtime owns gameplay rendering and interaction. It should not become the primary implementation for billing, account management, marketing pages, or other normal SaaS/web flows.

## Shared platform boundary

The web app and game clients should communicate through shared backend contracts rather than through each other's implementation details.

Conceptually:

```text
                       BGO backend / Firebase
                      identity + sessions + data
                               |
          +--------------------+--------------------+
          |                    |                    |
   Web Platform          Godot Web/TV         Native Godot PC
 accounts/catalog         gameplay client       gameplay client
 billing/lobby            display/player        richer graphics
```

No web page should need to understand Godot scene nodes, and Godot should not need to understand billing-provider UI.

## Authentication and identity

Use one user identity across the ecosystem. The web platform is expected to be the main place for account creation and account management, while Godot clients consume authenticated identity/tokens through a stable integration contract.

Do not couple the domain model directly to one authentication SDK. Firebase Auth is an initial provider, not the game-domain API.

## Plans, billing, and entitlements

Billing and entitlement checks must be represented as explicit backend/product capabilities, for example:

- account tier
- active subscription status
- feature entitlements
- package ownership/access
- host/session limits
- storage/publishing limits later

Gameplay code should ask for an entitlement or permission rather than embed pricing-plan names throughout the runtime.

Billing-provider secrets and webhook processing must remain server-side. Never trust client-provided subscription state.

## Session launcher

A major responsibility of the web platform is to turn product navigation into a concrete game launch.

A session launch should resolve enough information to open the appropriate runtime, for example:

```text
session_id
game_package id/version/hash
user/player identity
device role
short-lived authorization/session context
preferred graphics/client mode when applicable
```

The launcher can route to:

- Godot Web player
- Godot Web display
- installed native desktop client
- installed Android/TV client later

Deep-linking/native launch can be added after the web flow is stable.

## Game catalog

The catalog should describe external GamePackages, not bake games into the web frontend.

Catalog metadata can include:

- package ID and version
- title / description
- publisher/author
- player count
- supported capabilities/components
- supported client/graphics profiles
- screenshots/video
- locale support
- package manifest URL
- asset/package size estimates
- access/ownership requirements

Actual game definition and runtime assets remain governed by the GamePackage and AssetResolver contracts.

## Technology/repository strategy

Treat this as a separate application boundary even if it initially lives in the same monorepo.

A practical structure could later be:

```text
/apps/web-platform/      # web frontend
/apps/game-runtime/      # Godot project, or current repo root during migration
/packages/contracts/     # shared schemas/types generated where useful
/docs/
```

Alternatively, the web platform can move to its own repository once backend/contracts are stable. The important rule is logical separation, not repository count.

The web frontend may use React/Next.js, another conventional web framework, or an AI-generated stack such as Replit's application workflow. The exact framework should remain replaceable behind stable backend/schema contracts.

## Design iteration

The web platform should be expected to iterate continuously. Unlike core game-state semantics, its visual design and onboarding copy do not need to be frozen early.

Keep a small design system so iterative work does not become inconsistent:

- typography
- spacing
- color tokens
- buttons/forms
- cards/panels
- navigation
- responsive breakpoints
- loading/error/empty states

Early design goal: clear, polished, fast, and understandable before maximizing visual novelty.

## Parallel implementation checkpoints

This track can progress alongside the core runtime without blocking it.

### Web W0 — Product shell

- responsive landing page
- navigation
- sign-in/sign-up placeholders or initial Firebase Auth
- visual design tokens
- deployment preview

Checkpoint: usable from desktop and phone, independently deployable.

### Web W1 — Identity and account

- real login/registration
- profile/account page
- protected routes
- logout/recovery flows

Checkpoint: one user identity can be recognized consistently by web/backend and prepared for game launch.

### Web W2 — Lobby/session UX

- create session
- join by code/link
- list resumable/recent sessions
- choose player/display role
- launch Godot Web runtime with explicit session context

Checkpoint: a user can go from the normal website to an active TEST/conformance game without manually editing URLs.

### Web W3 — Catalog and GamePackages

- game/package listing
- package details
- capability/client compatibility display
- launch selected package

Checkpoint: catalog metadata is independent of the BGO executable and points to GamePackage identities.

### Web W4 — Billing/entitlements

- plan comparison
- checkout/customer portal integration
- backend-verified entitlements
- feature gating

Checkpoint: no gameplay client trusts billing state supplied by the browser alone.

### Web W5 — Creator/admin surfaces

Later:

- package publishing
- validation reports
- asset status
- version management
- moderation/support/admin

## AI-assisted development contract

AI-generated web code must follow the same project discipline as the Godot side:

- inspect `AGENTS.md` first
- use backend contracts, do not invent incompatible schemas
- keep secrets server-side
- do not bypass authorization for convenience
- add automated tests for important auth/session/entitlement flows
- keep gameplay logic out of the web frontend
- update documentation when shared contracts change

The web platform may iterate visually much faster than the game core, but changes to identity, session, package, or entitlement contracts must be coordinated and versioned.
