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

## While you build (cross-repo features)

1. **Server first.** The server is authoritative. Implement state and rules in `Bomberman-2.0-Backend`, then the client mirror and rendering in `Bomberman-2.0`.
2. **Contract in one place.** Every new or changed socket event is added to `docs/socket-contract.md` in the same change. Payload names and shapes must match on both sides.
3. **Listeners:** register with a stored bound handler, remove with the same reference, on scene shutdown. Never `socket.on(x, this.fn.bind(this))` inline.
4. Parallel work on both repos via subagents is allowed only after the contract (events + payloads) is written down; both sides build against it.

## After you finish

Run these in **every repo you touched**. Never skip a step. Never commit with a NEW failure.

`dev` already has Biome and `tsc` errors. Your change must add no NEW errors versus `origin/dev`:

- Biome: run it only on the files you changed yourself. `<changed files>` is that list of paths (for example from `git diff --name-only origin/dev...HEAD` plus your uncommitted files). Never run Biome with `--write` on the whole repo: it rewrites many unrelated files.
- `tsc`: compare the error list with the same command on `origin/dev`. An error that is also on `origin/dev` is not yours.
- Do not fix unrelated errors in the same PR.

### Bomberman-2.0-Backend

```bash
npx biome check --write <changed files>  # Biome lint + format, only your files
npx tsc --noEmit                         # types; compare with origin/dev
npm run build                            # tsc + copy maps
```

### Bomberman-2.0 (frontend)

```bash
npx biome check --write <changed files>  # Biome lint + format, only your files
npx tsc --noEmit                         # types (vite build does NOT type-check); compare with origin/dev
npm run build
```

### Verify in the game

For any gameplay, socket, map or asset change: run the `play-local` skill (`make dev`, local Docker Mongo, two Chrome windows from `make browsers` with **two mocked players**, no Google login). Never run the backend against the production `DB_HOST`. State what you played and what you saw. If you could not verify in the game, say so in the PR.

### Docs

Run `sync-docs`: update `docs/` for anything the change made untrue (events, entity fields, mechanics, maps, assets). Docs describe the code as it is now.

## Pre-PR review (mandatory)

1. Get the full diff per repo: `git diff origin/dev...HEAD`.
2. Self-review the diff against the `game-architecture` rule and the PR checklist. Fix every finding.
3. If the change touches socket events, entities on both sides, or game state: dispatch **`game-contract-reviewer`** with only the target (branch names / "uncommitted"). Do not pass your summary or reasoning. Fix or answer every finding; list deferred ones in the PR.
4. Re-run the checks above after fixes.

## Commits

- Conventional Commits, enforced by commitlint: `type(scope): subject` — lower-case subject, no full stop, header ≤ 100 chars. Types: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test.
- Stage specific files — never `git add -A` / `git add .`.
- One logical change per commit.
- **No AI attribution.** No `Co-Authored-By` trailer and no mention of Claude, Anthropic or an AI assistant. Write the message as the developer.

## Pull requests

- One PR per repo, target **`dev`**. Fill the repo's `pull_request_template.md`.
- Cross-repo feature: each PR links the other ("Requires NickDurnev/Bomberman-2.0-Backend#NN"). Merge order: backend first.
- Include: what changed and why, how it was verified (checks + `play-local` result), deferred review findings.
- **No AI attribution.** No "Generated with Claude Code" footer and no mention of Claude, Anthropic or an AI assistant. Write the title and body as the developer.
- Use the GitHub MCP (`mcp__plugin_github_github__*`) for PRs; fall back to `gh` if it is not available. Git stays on the CLI.
- **Do not merge.** The maintainer reviews, merges, and verifies in DEV. After a PR merges to `dev`, Dependabot (`.github/dependabot.yml`) opens a daily PR in the root that bumps the submodule pointer. The maintainer merges it. For a bump before then, run `git submodule update --remote` in the root and commit `chore: bump submodules`.

## Never

- Commit or push to `dev` or `main` directly in a child repo.
- Force-push a PR branch.
- Commit specs, plans, `.env*`, or anything from `local/`.
- Run against the production database.
- "Fix" the chain reaction by blast — it is intended.
