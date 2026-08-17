# BGO Web Platform

This document defines the public-facing web application that surrounds the BGO game runtime.

The web platform is a separate client/product surface from the Godot runtime. It may be implemented with conventional web technology and developed in parallel, including with AI-assisted tools such as Replit. It should share identity, session metadata, catalog data, and product configuration with the rest of BGO without forcing those concerns into Godot scenes.

Deployment/environment policy is defined separately in `docs/DEPLOYMENT_ENVIRONMENTS.md`.

## Responsibilities

The web platform owns product workflows that are better served by a normal web application:

- landing / product explanation
- game catalog and discovery
- create / join / resume session flows
- invite links and room codes
- device-role selection (player, display, spectator, host where allowed)
- download/install links for native clients
- documentation, FAQ, changelog, release notes
- registration/login/account management later, when the access-control checkpoint begins
- owned/installed/favorite game packages later if the product model requires them
- mod/package author and publishing workflows later
- admin/support tooling later

The Godot runtime owns gameplay rendering and interaction. It should not become the primary implementation for account management, marketing pages, or other normal web/product flows.

## Current prototype access policy

The current implementation stage intentionally optimizes for rapid testing.

For now:

- do **not** block runtime, lobby, package, or web-shell testing on user registration/login
- anonymous/test access is acceptable during the technical prototype
- there is no checkout flow
- there are no paid plans
- there are no advertising requirements
- there are no Patreon/supporter entitlements in the runtime
- gameplay code must not contain assumptions about a future commercial model

The intended broader public-beta policy may later require a BGO account before entering protected application/session surfaces, but that is a separate checkpoint. Authentication must be implemented when it adds real product/security value, not merely because it will eventually exist.

The eventual commercialization model is deliberately deferred until the platform has enough real usage data to make a sensible decision. Candidate models may later include, separately or in combination:

- free / donation-supported access
- Patreon or supporter membership
- freemium plans
- paid subscriptions
- paid creator/publishing features
- advertising-supported free access
- package/game purchases or marketplace fees
- other models discovered during product validation

Do not implement monetization infrastructure merely because one of these possibilities exists.

## Shared platform boundary

The web app and game clients should communicate through shared backend contracts rather than through each other's implementation details.

Conceptually:

```text
                       BGO backend / Firebase
                      sessions + data + identity later
                               |
          +--------------------+--------------------+
          |                    |                    |
   Web Platform          Godot Web/TV         Native Godot PC
 catalog/lobby            gameplay client       gameplay client
 launcher                 display/player        richer graphics
```

No web page should need to understand Godot scene nodes, and Godot should not need to understand future commercial-provider UI.

## Authentication and identity — deferred checkpoint

A unified user identity remains the intended long-term design, but it is **not a prerequisite for the current prototype**.

When authentication is introduced:

- the web platform should be the primary place for account creation and account management
- Godot clients should consume authenticated identity/tokens through a stable integration contract
- the domain model must not couple directly to one authentication SDK
- Firebase Auth may be an initial provider rather than the game-domain API
- DEV must retain a low-friction test path so normal development is not slowed by repetitive end-user login flows

Until that checkpoint, code should preserve a clean seam for future identity without inventing fake account/profile machinery.

## Future monetization and entitlements

Monetization is intentionally **not part of the initial implementation checkpoint**.

When a commercial model is eventually selected, model access as explicit backend/product capabilities rather than embedding pricing-plan names throughout gameplay code. Possible future concepts include:

- account tier
- supporter status
- active subscription state
- feature entitlements
- package ownership/access
- host/session limits
- storage/publishing limits

The important architectural rule is already known even though the commercial model is not: gameplay code should ask whether an identity has a capability or permission, not know whether that capability came from Patreon, ads, a subscription, a purchase, a promotion, or another mechanism.

Any future billing-provider secrets, payment verification, ad-entitlement verification, or webhook processing must remain server-side. Never trust client-provided commercial state.

## Session launcher

A major responsibility of the web platform is to turn product navigation into a concrete game launch.

A session launch should resolve enough information to open the appropriate runtime, for example:

```text
session_id
game_package id/version/hash
player/guest or authenticated identity context
device role
session authorization context when introduced
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
- access requirements if such requirements exist in a future product model

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

### Web W0 — Product shell, no auth dependency

- responsive landing page
- navigation
- basic catalog/demo entry points
- visual design tokens
- DEV deployment preview / persistent DEV URL
- ability to launch current test runtime without requiring account plumbing

Checkpoint: usable from desktop and phone, independently deployable, and does not slow core testing with registration/login requirements.

### Web W1 — Lobby/session UX

- create session
- join by code/link
- list or expose current test sessions where appropriate
- choose player/display role
- launch Godot Web runtime with explicit session context

Checkpoint: a tester can go from the normal website to an active TEST/conformance game without manually editing URLs.

### Web W2 — Catalog and GamePackages

- game/package listing
- package details
- capability/client compatibility display
- launch selected package

Checkpoint: catalog metadata is independent of the BGO executable and points to GamePackage identities.

### Web W3 — Authentication/account gate (later)

Do not pull this into W0/W1 merely for completeness.

When broader public access makes it worthwhile:

- real login/registration
- account recovery
- protected routes
- logout
- minimal profile/account surface only where useful
- consistent identity passed into game launch
- explicit DEV/test authentication path

Checkpoint: public protected surfaces require a valid user identity without making normal development/testing cumbersome.

### Web W4 — Commercial model decision (deferred)

Do not implement this during the initial MVP.

Before adding monetization infrastructure:

- measure actual usage and hosting/runtime costs
- decide whether the product benefits more from supporter, freemium, ads, subscription, marketplace, or another model
- document the selected model and privacy/product implications
- design provider-neutral entitlement contracts if needed

Only after that decision should implementation-specific payment/ad/supporter integrations be scheduled.

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
- read `docs/DEPLOYMENT_ENVIRONMENTS.md` before changing deploy behavior
- use backend contracts, do not invent incompatible schemas
- keep secrets server-side
- do not introduce authentication/profile plumbing before its checkpoint unless a current security requirement demands it
- do not introduce billing, ads, or paid-plan assumptions before the commercial model is explicitly selected
- add automated tests for important session flows, and auth flows once auth exists
- keep gameplay logic out of the web frontend
- update documentation when shared contracts change

The web platform may iterate visually much faster than the game core, but changes to session, package, identity, deployment, or future entitlement contracts must be coordinated and versioned.
