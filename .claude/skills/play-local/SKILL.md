---
name: play-local
description: Use to check a Bomberman change in the running game with two real players ("play locally", "test multiplayer", "verify in the browser", "play-local").
---

# Play locally with two players

Run the game on the local stack and play one room with two browser profiles. Match flow: [docs/architecture.md](../../../docs/architecture.md).

## Rules

- Start the stack only with `make dev`. It uses local MongoDB. Never run against the production `DB_HOST`.
- Start Claude at the workspace root. `.mcp.json` uses the relative path `local/browser-profiles/player1|player2`, which resolves from the current directory.
- `local/` is gitignored. The profiles hold Google session cookies. Never commit them.
- The browsers are headed. The MCP servers are `player1` and `player2`.

## One-time first run (maintainer)

Login is Google OAuth only. The two profiles must use **two different Google accounts**. Two players with one account collapse into one player (see [known-traps.md](../../../docs/known-traps.md#same-account-in-two-sessions-collapses-into-one-player)).

1. Run `make dev`. Wait for `:4000` and `:3000`.
2. In `player1`, open `http://localhost:3000`. Log in by hand with Google account A.
3. In `player2`, open `http://localhost:3000`. Log in by hand with Google account B.
4. The sessions stay in the profile directories. Do this once per profile.

If Google refuses the browser ("This browser or app may not be secure"):

1. Change the server args in `.mcp.json` to add `--browser chrome`. Restart Claude. Try again.
2. If Google still refuses, stop. Record the limit in this section. Use server logs and one manual check by the maintainer. Do not add a login bypass.

Known limit: on a repeat login of an existing user, the backend calls `cloudinary.uploader.destroy` without a guard (`Bomberman-2.0-Backend/src/controllers/auth.ts`, about lines 23-26). Local runs have Cloudinary unset, so this can fail. If it fails, report it. Do not patch product code.

## Procedure

1. Run `make dev` in the background. Wait until `curl -s -o /dev/null http://localhost:4000` and `curl -s -o /dev/null http://localhost:3000` both connect.
2. Open `http://localhost:3000` in `player1` and in `player2`. Confirm each profile is logged in.
3. In `player1`, create a game. In `player2`, join the same room. Start the match.
4. Play the scenario under test. Use both players.
5. Read the browser console errors from both players. Read the backend log from `make dev`.
6. Stop `make dev`. Run `make db-down`.
7. Report what you played and what you saw: room, both avatars and names, the actions, the console errors, the backend errors.

## Verify

- Both players reach the same room. Each sees the other avatar and name.
- One bomb is placed and explodes on both screens.
- Zero console errors in both players.
- `git status --porcelain` shows nothing under `local/`.
