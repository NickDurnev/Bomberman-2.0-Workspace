# Bomberman workspace

Multiplayer Bomberman. This root repo holds docs and agent configuration only. The game code lives in two git submodules.

**Start at `docs/README.md`.** Read its reading order before any change.

## Repos

| Path | Repo | Stack | Role |
| --- | --- | --- | --- |
| `Bomberman-2.0/` | `NickDurnev/Bomberman-2.0` | React, Phaser 3, Vite | Client: mirrors state and renders |
| `Bomberman-2.0-Backend/` | `NickDurnev/Bomberman-2.0-Backend` | Express, socket.io, MongoDB | Server: authoritative for game state |

Both child repos use the `dev` branch as the base for PRs. The root repo uses `main`.

## Layout

- `docs/` - architecture, mechanics, entities, socket contract, maps, assets, known traps.
- `scripts/check-socket-contract.sh` - checks `docs/socket-contract.md` against the code.
- `Makefile`, `docker-compose.yml` - local dev (Mongo in Docker).
- `.claude/rules/` - rules loaded in every session (see below).
- `local/` - specs and plans. Gitignored. Never commit it.

## Make targets

Run `make help` to list them.

| Target | Action |
| --- | --- |
| `make setup` | Init submodules, install deps, build backend `dist` |
| `make db` / `make db-down` | Start / stop local MongoDB |
| `make backend` | Backend on :4000 against local MongoDB |
| `make frontend` | Frontend on :3000 against local backend |
| `make dev` | MongoDB, backend and frontend |

## Local dev

- On a fresh clone, run `make setup` first.
- The backend `package.json` `_moduleAliases` point at `./dist`. `make setup` builds `dist`.
- If you change source in an aliased module, you may need `npm run build` in the backend.
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

Tested with `claude -p` from `Bomberman-2.0-Backend/` (a submodule):

- Root `CLAUDE.md` loads (found by walking up the directory tree).
- Root `.claude/rules/` load: all 4 rules.
- The child `.claude/rules/` load too. The child `commit-conventions` and `pr-conventions` duplicate the root rules.
- Root project skills do NOT load from a child directory (tested after Task 6: the session listed no project skills).

To use root skills or agents, start Claude Code from the workspace root.

