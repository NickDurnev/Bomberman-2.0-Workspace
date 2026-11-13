---
name: play-local
description: Use to check a Bomberman change in the running game with two real players ("play locally", "test multiplayer", "verify in the browser", "play-local").
---

# Play locally with two players

Run the game on the local stack and play one room with two Chrome windows. Match flow: [docs/architecture.md](../../../docs/architecture.md).

The windows are normal Google Chrome with separate profiles in `local/browser-profiles/player1` and `player2`. The MCP servers `player1` and `player2` (Chrome DevTools MCP, see `.mcp.json`) attach to them on debug ports 9223 and 9224.

## Prerequisites

1. Run `make dev`. Wait until `:4000` and `:3000` answer.
2. Run `make browsers`. It opens the two windows on `http://localhost:3000`. It skips a port that is already in use.
3. Start Claude Code from the workspace root, so `.mcp.json` loads.

## Rules

- Never run against the production `DB_HOST`. `make dev` uses local MongoDB.
- The debug ports listen on `127.0.0.1` only. While the windows are open, any local process can control them. Close them after the session (`make browsers-down`).
- Navigate only to `http://localhost:3000`, and to Google sign-in pages during login. Never open any other site.
- `local/` is gitignored. The profiles hold live Google session cookies. Never commit them, copy them, or paste cookies, tokens or profile data anywhere (chat, logs, PRs, issues, files).
- Use two different throwaway Google accounts. Never use a personal or work account. Two players with one account collapse into one player (see [known-traps.md](../../../docs/known-traps.md#same-account-in-two-sessions-collapses-into-one-player)).

## First run (maintainer)

1. In each window, log in by hand with Google. Use account A in `player1` and a different account B in `player2`.
2. The sessions stay in the profile directories. Do this once per profile.
3. If Google still refuses the login, stop and report it. Use the backend log and one manual check by the maintainer. Do not add a login bypass.

Known limit: on a repeat login of an existing user, the backend calls `cloudinary.uploader.destroy` without a guard (`Bomberman-2.0-Backend/src/controllers/auth.ts`). Local runs have Cloudinary unset, so this can fail. If it fails, report it. Do not patch product code.

## Procedure

1. In `player1` and `player2`, use `list_pages` and `select_page` to pick the game page. Use `navigate_page` to `http://localhost:3000` if needed. Confirm each is logged in.
2. In `player1`, create a room. In `player2`, join it. Start the match. Use `take_snapshot`, `click` and `fill`.
3. Play the scenario under test with both players. At least: both see each other avatar and name, and one bomb is placed and explodes on both screens.
4. Run `list_console_messages` in both players. Read the backend log from `make dev`.
5. Ghosting check. After a restart of the match, run this in each player with `evaluate_script`, for a few game events (for example `show bomb`, `detonate bomb`, `move player`):
   `async () => { const s = (await import('/src/utils/socket.ts')).default; return ['show bomb','detonate bomb','move player'].map(e => [e, s.listeners(e).length]); }`
   `clientSocket` is a module singleton, not a `window` property. This dynamic import returns the same instance on the Vite dev server. Restart again and repeat. The counts must not grow. If the import fails, skip this step and say so in the report. Do not change product code.
6. Optional: if the change can affect frame rate, record a trace with `performance_start_trace` and `performance_stop_trace`.
7. Close the windows with `make browsers-down`. Stop `make dev`. Run `make db-down`.

## Report

State what you played and what you saw: room, both avatars and names, the actions, console errors, backend errors, listener counts.

## Verify

- Both players reach the same room. Each sees the other avatar and name.
- One bomb is placed and explodes on both screens.
- Zero console errors in both players. Listener counts do not grow.
- `git status --porcelain` shows nothing under `local/`.
