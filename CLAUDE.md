# Bomberman workspace

Multiplayer Bomberman. This root repo holds docs and agent configuration only. The game code lives in two git submodules; the E2E suite lives in a third.

**Start at `docs/README.md`.** Read its reading order before any change.

## Repos

| Path | Repo | Stack | Role |
| --- | --- | --- | --- |
| `Bomberman-2.0/` | `NickDurnev/Bomberman-2.0` | React, Phaser 4, Vite | Client: mirrors state and renders |
| `Bomberman-2.0-Backend/` | `NickDurnev/Bomberman-2.0-Backend` | Express, socket.io, MongoDB | Server: authoritative for game state |
| `Bomberman-2.0-E2E/` | `NickDurnev/Bomberman-2.0-E2E` | Playwright | E2E suite: two players play real matches against the local stack |

`Bomberman-2.0` and `Bomberman-2.0-Backend` use the `dev` branch as the base for PRs. `Bomberman-2.0-E2E` and the root repo use `main`.

Each child repo runs a `checks` CI job (Biome, `tsc`, build; the backend job also runs `npm test`) on PRs to `dev` (E2E repo: Biome and `tsc` on PRs to `main`). A red `checks` blocks the merge. The E2E suite runs only by hand: the `E2E` workflow (`workflow_dispatch`) or `/e2e`.

Dependabot in each child repo (`.github/dependabot.yml`) opens weekly grouped version PRs: frontend and backend to `dev`, E2E to `main`. It ignores Phaser majors (frontend) and `@types/node` majors (backend, E2E: it must match the Node 22 runtime).

Rulesets in all child repos: `dev` and `main` accept changes only through a PR, for everyone (no direct push, no force-push). A PR needs 1 approval from a code owner (`.github/CODEOWNERS`: the maintainer); only the repository admin can bypass the approval. `checks` must pass on `dev` (E2E repo: on `main`), and nobody can bypass it.

## Layout

- `docs/` - architecture, mechanics, entities, socket contract, maps, assets, known traps.
- `scripts/check-socket-contract.sh` - checks `docs/socket-contract.md` against the code.
- `scripts/build-map.py` - builds a map from a hand-drawn grid in `scripts/maps/` (checks, both JSON copies). See `docs/maps.md` › Adding a map.
- `Makefile`, `docker-compose.yml` - local dev (Mongo in Docker).
- `.claude/rules/` - rules loaded in every session (see below).
- `.claude/commands/e2e.md` - `/e2e`: routes to the E2E skill in `Bomberman-2.0-E2E/.claude/skills/e2e/` (run, status, stop, fix, CI run, add a spec).
- `.github/dependabot.yml` - daily PR that bumps the submodule pointers to the latest `dev`.
- `local/` - specs and plans. Gitignored. Never commit it.

## Make targets

Run `make help` to list them.

| Target | Action |
| --- | --- |
| `make setup` | Init submodules, install deps (and Playwright Chromium), build backend `dist` |
| `make db` / `make db-down` | Start / stop local MongoDB |
| `make backend` | Backend on :4000 against local MongoDB. Rebuilds `dist` and restarts on every `src/` change |
| `make frontend` | Frontend on :3000 against local backend |
| `make dev` | MongoDB, backend and frontend |
| `make ci` | Every step of the `checks` CI job in every repo. Required before opening a PR |
| `make e2e` | The E2E suite against a fresh local stack (stop `make dev` first) |
| `make browsers` / `make browsers-down` | Start / close the two Chrome windows (debug ports 9223, 9224) for `play-local` |
| `make browsers-reset` | Close the windows and delete both `play-local` profiles |

## Local dev

- On a fresh clone, run `make setup` first.
- The backend `package.json` `_moduleAliases` point at `./dist`. Aliased imports (`@/entity/game`, `@/constants`, ...) load from `dist`, not `src`.
- So `make backend` runs nodemon, which runs `npm run build && node dist/app.js` on every change in `src/`.
- Local runs always use Docker Mongo. Never use the production `DB_HOST`.

## Rules

Rules in `.claude/rules/`:

- `development-workflow` - the end-to-end guide: context, build, checks, play-local, docs, review, commit, PR.
- `game-architecture` - invariants that you must not break.
- `commit-conventions` - Conventional Commits. No AI attribution.
- `pr-conventions` - PRs go to `dev`. No AI attribution.

## Specs and plans

Write specs and plans to `local/specs/` and `local/plans/`. Never commit them.

## Working in one repo

Behaviour of `claude -p` started in `Bomberman-2.0-Backend/` (a submodule):

- Root `CLAUDE.md` loads (found by walking up the directory tree).
- Root `.claude/rules/` load: all 4 rules.
- The child `.claude/rules/` load too. The child `commit-conventions` and `pr-conventions` duplicate the root rules.
- Root project skills do NOT load from a child directory. The session lists no root project skills.

To use root skills or agents, start Claude Code from the workspace root.

