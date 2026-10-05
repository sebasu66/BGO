# BGO agent contract

Many coding agents look for `AGENTS.md` by convention, so this file stays, but it holds no rules of its own. The project has three maintained documents:

- `SKILL.md`: the engineering contract, workflow and machine-enforced policy every agent follows. Read it first.
- `README.md`: what BGO is, its architecture, the decided rules and the repository structure.
- `TODO.md`: how to resume, pending work, the progress log and open decisions.

Nothing else is authoritative. The long earlier version of this file and the former `docs/` folder were folded into those three on 2026-10-05 and remain in Git history.

Hard rules in one place (details in `SKILL.md` and `README.md`):

- Core domain code never depends on rendering, Firebase or any single transport; every authoritative change goes through the one canonical command path.
- Game packages are declarative data that reference stable component IDs; never download and execute remote code.
- Deploy only with `firebase deploy --only hosting` (plus the named DEV MCP function exception); never an unrestricted `firebase deploy`. Promoting to PROD is the owner's decision.
- Do not pull later-phase work forward, add tests for public behavior, keep the quality gate green, and update `README.md` and `TODO.md` in the same change as the work.
