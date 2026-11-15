---
description: How to work on any change in the Bomberman workspace — before you start (context, size, plan), while you build (both repos, server first), and after you finish (checks, local play, docs, pre-PR review, commit, PR).
---

# Development Workflow

## Before you start

- **Read the context.** Start at `docs/README.md`. For game changes, read `docs/mechanics.md`, `docs/entities.md` and `docs/socket-contract.md`, and the `game-architecture` rule. Cheap to skim, expensive to skip.
- **Size the change.**
  - Small fix or tweak in one repo → plan as a short TODO list, then build.
  - New feature, new entity, new socket event, new game mode → superpowers flow: `brainstorming` → `writing-plans` → `subagent-driven-development`. Specs and plans go in `local/specs/` and `local/plans/` (gitignored). Never commit them.
- **Pick the skill.** New game object → `add-entity`. Socket event → `socket-event`. Map → `map-change`. Sprites/tilesets → `update-assets`.
- **Decide deliberately.** When more than one approach works (where logic lives, server vs client), state the options and pick one before writing code.
- **Don't overengineer.** Grep before adding. No premature abstractions. Match the surrounding code.
- **Bugs:** use `superpowers:systematic-debugging` before proposing a fix. Check `docs/known-traps.md` first — most past bugs repeat a known trap.

## Branches

- Branch from `origin/dev` in each submodule you touch: `type/short-name` (e.g. `feat/bot-player`).
- Cross-repo feature → **same branch name in both repos**.
- The root repo (`main`) changes only for docs, `.claude/`, `.github/`, Makefile, and submodule pointer bumps.
- `Bomberman-2.0-E2E` has no `dev`: branch from `origin/main`, PRs target `main`.

## While you build (cross-repo features)

1. **Server first.** The server is authoritative. Implement state and rules in `Bomberman-2.0-Backend`, then the client mirror and rendering in `Bomberman-2.0`.
2. **Contract in one place.** Every new or changed socket event is added to `docs/socket-contract.md` in the same change. Payload names and shapes must match on both sides.
3. **Listeners:** register with a stored bound handler, remove with the same reference, on scene shutdown. Never `socket.on(x, this.fn.bind(this))` inline.
4. Parallel work on both repos via subagents is allowed only after the contract (events + payloads) is written down; both sides build against it.

## After you finish

Run these in **every repo you touched**. Never skip a step. Never commit with a failing check.

If you changed `Bomberman-2.0` or `Bomberman-2.0-Backend`, also audit `Bomberman-2.0-E2E` for impacted specs and prepare a companion E2E PR if needed (see [Keep E2E in sync](#keep-e2e-in-sync-after-behaviour-changes)).

Each child repo runs a `checks` CI job (Biome, `tsc`, build) and the backend tests on every PR to `dev`. A red check blocks the merge. Run the same commands locally while you work; each must exit 0. Before the PR, `make ci` runs all of them in every repo (see Pre-PR review):

- Fix lint and format in the files you changed: `npx biome check --write <changed files>` (`<changed files>` is, for example, `git diff --name-only origin/dev...HEAD` plus your uncommitted files). Never run `--write` on files you did not change.
- `npm run check` is `biome ci .` on the whole repo, with no writes.
- `npm run typecheck` is `tsc --noEmit`.

### Bomberman-2.0-Backend

```bash
npx biome check --write <changed files>  # fix lint + format in your files
npm run check                            # biome ci . — must exit 0
npm run typecheck                        # tsc --noEmit — must exit 0
npm test                                 # vitest — must exit 0
npm run build                            # tsc + copy maps
```

### Bomberman-2.0 (frontend)

```bash
npx biome check --write <changed files>  # fix lint + format in your files
npm run check                            # biome ci . — must exit 0
npm run typecheck                        # tsc --noEmit — must exit 0 (vite build does NOT type-check)
npm run build
```

A change to backend game logic, a socket event or an HTTP route adds or updates a test in the same PR. TDD applies in the backend; the frontend still has no tests. See `docs/testing.md`.

No tests in the frontend app. Do not add a test runner (Vitest, Jest, Testing Library) or test files to `Bomberman-2.0`, even when a skill (TDD, writing-plans) asks for tests. Verify frontend changes with the checks above, `play-local`, and the E2E suite in `Bomberman-2.0-E2E` (`/e2e --start` or `make e2e`).

### Bomberman-2.0-E2E (Playwright)

```bash
npx biome check --write <changed files>  # fix lint + format in your files
npm run check                            # biome ci . — must exit 0
npm run typecheck                        # tsc --noEmit — must exit 0
npx playwright test tests/<changed>.spec.ts --repeat-each 3   # with the stack up (/e2e --start)
```

The rules for specs are in `Bomberman-2.0-E2E/.claude/rules/`. The `E2E` workflow runs only by hand (`/e2e --start-ci`).

### Verify in the game

For any gameplay, socket, map or asset change: run the `play-local` skill (`make dev`, local Docker Mongo, two Chrome windows from `make browsers` with **two mocked players**, no Google login). Never run the backend against the production `DB_HOST`. State what you played and what you saw. If you could not verify in the game, say so in the PR.

### Keep E2E in sync after behaviour changes

The E2E suite asserts things that lint, types and the backend tests cannot see: the screens of the match flow, button names, the hook state and the exact socket listener counts. A change to user-visible behaviour in `Bomberman-2.0` or `Bomberman-2.0-Backend` can make it red, and nobody sees it until the next E2E run. **Before you open a PR in a game repo, audit the E2E suite.**

| Change | What the E2E suite asserts on it |
| --- | --- |
| Match flow, routes, scene keys, the restart flow | `waitForURL`, `waitForScene`, the steps in `tests/fixtures/lobby.ts` |
| Lobby, map, pending, modal copy and buttons | `getByRole` names, `getByPlaceholder`, `data-testid` |
| Client socket listeners (add, remove, move a `clientSocket.on`) | `tests/fixtures/expected-listeners.ts` (exact counts per checkpoint) |
| Socket event names or payloads that change what the client shows | `state()` fields: players, names, bombs |
| The test hook (`src/utils/e2e.ts`, `E2E_SOCKET_EVENTS`) | `tests/global.d.ts`, `tests/fixtures/hook.ts`, `docs/e2e-hook.md` |
| A new overlay, modal or toast over the game or the lobby | Clicks that the overlay now catches |
| Timers: fuse, countdown, end-of-match delays | Test timeouts and the waits in the fixtures |

How to audit:

1. Read your diff for the change classes above. If none applies, you are done.
2. Search the suite for the words your change touches: `grep -rn "<button name|event|route>" Bomberman-2.0-E2E/tests`.
3. If a spec matches, open a companion PR in `Bomberman-2.0-E2E` (to `main`) in the same session. Link the two PRs. Merge order: the game PR first, then the E2E PR, in the same window (`E2E` runs against `dev` by default).
4. If you are not sure, run the suite against your branch: `/e2e --start` with your branch checked out, or `/e2e --start-ci` with `frontend_ref` / `backend_ref` set to your branch.

Rule of thumb: if the PR changes anything a player sees or clicks, or any client listener, assume the E2E suite asserts on it.

### Docs

Run `sync-docs`: update `docs/` for anything the change made untrue (events, entity fields, mechanics, maps, assets). Docs describe the code as it is now.

## Pre-PR review (mandatory)

1. Get the full diff per repo: `git diff origin/dev...HEAD`.
2. Self-review the diff against the `game-architecture` rule and the PR checklist. Fix every finding.
3. If the change touches socket events, entities on both sides, or game state: dispatch **`game-contract-reviewer`** with only the target (branch names / "uncommitted"). Do not pass your summary or reasoning. Fix or answer every finding; list deferred ones in the PR.
4. Re-run the checks above after fixes.
5. **Run `make ci` in the workspace root and get it green before you open any PR**, also when you changed only one repo. It runs every step of the `checks` CI job (lint, format, types, build, and tests where the job has them) in **every** repo (`Bomberman-2.0`, `Bomberman-2.0-Backend`, `Bomberman-2.0-E2E`). It does not run the E2E suite. If a step fails, fix it before you open the PR. If you changed a lockfile, run `make setup` first so the installed packages match it.

## Commits

- Conventional Commits, enforced by commitlint: `type(scope): subject` — lower-case subject, no full stop, header ≤ 100 chars. Types: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test.
- Stage specific files — never `git add -A` / `git add .`.
- One logical change per commit.
- **No AI attribution.** No `Co-Authored-By` trailer and no mention of Claude, Anthropic or an AI assistant. Write the message as the developer.

## Pull requests

- One PR per repo, target **`dev`** (`Bomberman-2.0-E2E`: **`main`**). Fill the repo's `pull_request_template.md` if it has one.
- Cross-repo feature: each PR links the other ("Requires NickDurnev/Bomberman-2.0-Backend#NN"). Merge order: backend first.
- Include: what changed and why, how it was verified (checks + `play-local` result), deferred review findings.
- **No AI attribution.** No "Generated with Claude Code" footer and no mention of Claude, Anthropic or an AI assistant. Write the title and body as the developer.
- Use the GitHub MCP (`mcp__plugin_github_github__*`) for PRs; fall back to `gh` if it is not available. Git stays on the CLI.
- **Do not merge.** The maintainer reviews, merges, and verifies in DEV. After a PR merges to `dev`, Dependabot (`.github/dependabot.yml`) opens a daily PR in the root that bumps the submodule pointer. The maintainer merges it. For a bump before then, run `git submodule update --remote` in the root and commit `chore: bump submodules`.
- **Dependabot PRs.** Each child repo gets weekly grouped version PRs (frontend and backend to `dev`, E2E to `main`). Review them like any PR: `checks` green, and the `E2E` workflow for a runtime, build or test-tool change. A Dependabot security PR on `main` is closed; fix the package through `dev`.

## Never

- Commit or push to `dev` or `main` directly in a child repo (`Bomberman-2.0`, `Bomberman-2.0-Backend`, `Bomberman-2.0-E2E`).
- Force-push a PR branch.
- Commit specs, plans, `.env*`, or anything from `local/`.
- Run against the production database.
- "Fix" the chain reaction by blast — it is intended.
