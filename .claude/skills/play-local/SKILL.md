---
name: play-local
description: Use to check a Bomberman change in the running game with two mocked players ("play locally", "test multiplayer", "verify in the browser", "play-local").
---

# Play locally with two players

Run the game on the local stack and play one room with two Chrome windows. The players are mocked: the agent seeds each window with a test profile, so no Google login is needed. Match flow: [docs/architecture.md](../../../docs/architecture.md).

The windows are normal Google Chrome with separate profiles (each has its own `localStorage`) in `local/browser-profiles/player1` and `player2`. The MCP servers `player1` and `player2` (Chrome DevTools MCP, see `.mcp.json`) attach to them on debug ports 9223 and 9224.

## Prerequisites

1. Run `make dev`. Wait until `:4000` and `:3000` answer.
2. Run `make browsers`. It opens the two windows on `http://localhost:3000`. It skips a port that is already in use.
3. Start Claude Code from the workspace root, so `.mcp.json` loads. The `player1` and `player2` servers attach when Claude starts or on the first tool call, so Chrome must be up first. If a tool reports that it cannot connect, run `make browsers` and retry.

## Rules

- Never run against the production `DB_HOST`. `make dev` uses local MongoDB.
- The debug ports listen on `127.0.0.1` only. While the windows are open, any local process can control them. Close them after the session (`make browsers-down`).
- Navigate only to `http://localhost:3000`. Never open any other site.
- `local/` is gitignored. Never commit it or paste profile data anywhere (chat, logs, PRs, issues, files).
- Use the two test profiles below. They differ in `email` and `name`. Two players with the same name and picture collapse into one player (see [known-traps.md](../../../docs/known-traps.md#same-account-in-two-sessions-collapses-into-one-player)). Use only the reserved `example.com` test domain (RFC 2606). The backend email check rejects `.local`, and then `POST /api/v1/auth` returns 422 and no `User` is created.

## Seed the mocked players

The app reads the user from `localStorage["google_user"]` on load. The local backend accepts the profile from the client. The `picture` is empty, so the client shows a random avatar.

1. In `player1`, use `navigate_page` to `http://localhost:3000`. Run this with `evaluate_script`, then reload the page:
   `() => localStorage.setItem("google_user", JSON.stringify({ email: "player1@example.com", name: "Player 1", picture: "", locale: "en-US" }))`
2. In `player2`, do the same with this snippet:
   `() => localStorage.setItem("google_user", JSON.stringify({ email: "player2@example.com", name: "Player 2", picture: "", locale: "en-US" }))`
3. Confirm that each window shows the lobby and not the login screen.

The local MongoDB gets the users `Player 1` and `Player 2`. This is fine, because it is local. To clear a window at the end, run `() => localStorage.removeItem("google_user")`. This is not required. `make browsers-reset` deletes both profiles.

Limit: this works because the local backend accepts the profile from the client (`POST /api/v1/auth` does not verify a Google token). If `/auth` starts to verify Google tokens, this step stops working. Then a dev-only backend test login is needed.

Cloudinary: on a repeat login of an existing user, the backend calls `cloudinary.uploader.destroy` only when the stored `User.picture` is not empty (`Bomberman-2.0-Backend/src/controllers/auth.ts`). The mocked players have an empty `picture`, so this caveat does not apply. If you change `picture` to a URL, a repeat login can fail with Cloudinary unset. If it fails, report it. Do not patch product code.

## Procedure

1. In `player1` and `player2`, use `list_pages` and `select_page` to pick the game page. Use `navigate_page` to `http://localhost:3000` if needed. Seed the players first (see above). Confirm each shows the lobby.
2. In `player1`, create a room. In `player2`, join it. Start the match. Use `take_snapshot`, `click` and `fill`.
3. Play the scenario under test with both players. At least: both see each other avatar and name (`Player 1`, `Player 2`), and one bomb is placed and explodes on both screens.
   The game reads keys once per frame (`isDown`). `press_key` sends keydown and keyup at once, so the game can miss the key, and no bomb or move happens. Hold the key with `evaluate_script` instead. This example holds Space for 250 ms. For a move, use `ArrowUp`, `ArrowDown`, `ArrowLeft` or `ArrowRight` (keyCode 38, 40, 37, 39):
   `async () => { const o = { key: ' ', code: 'Space', keyCode: 32, which: 32, bubbles: true }; window.dispatchEvent(new KeyboardEvent('keydown', o)); await new Promise(r => setTimeout(r, 250)); window.dispatchEvent(new KeyboardEvent('keyup', o)); }`
4. Run `list_console_messages` in both players. Read the backend log from `make dev`.
5. Ghosting check. After a restart of the match, run this in each player with `evaluate_script`, for a few game events (for example `show bomb`, `detonate bomb`, `move player`):
   `async () => { const s = (await import('/src/utils/socket.ts')).default; return ['show bomb','detonate bomb','move player'].map(e => [e, s.listeners(e).length]); }`
   `clientSocket` is a module singleton, not a `window` property. This dynamic import returns the same instance on the Vite dev server. Reload the page before the check. Do not run it after a Vite hot update: a hot-update URL (`?t=`) gives a different module instance and a false pass. Restart again and repeat. The counts must not grow. If the import fails, skip this step and say so in the report. Do not change product code.
6. Optional: if the change can affect frame rate, record a trace with `performance_start_trace` and `performance_stop_trace`.
7. Close the windows with `make browsers-down`. Stop `make dev`. Run `make db-down`.

## Report

State what you played and what you saw: room, both avatars and names, the actions, console errors, backend errors, listener counts.

## Verify

- Both players reach the same room. Each sees the other avatar and name.
- One bomb is placed and explodes on both screens.
- Zero console errors in both players. Listener counts do not grow.
- `git status --porcelain` shows nothing under `local/`.
