---
name: add-entity
description: Use when adding a new game object to Bomberman - a new power-up or spoil, portal-like object, hazard, pickup, or any new server class with a client sprite (e.g. "new power-up", "new spoil", "new game object", "add a freeze spoil").
---

# Add an entity

The procedure and file locations live in [docs/entities.md](../../../docs/entities.md#adding-an-entity). Follow it. This skill adds the order and the checks.

Read first: [docs/mechanics.md](../../../docs/mechanics.md), [docs/entities.md](../../../docs/entities.md), `.claude/rules/game-architecture.md`. The server decides outcomes. The client mirrors and renders.

## Procedure

1. Asset: add or pick the sprite. Run `update-assets` if the file is new.
2. Preload key: load the texture in `Preload`. Test it with `textures.exists`, never `textures.get`.
3. Server entity: class in `Bomberman-2.0-Backend/src/entity/`, uuid `id` made on the server, a registry on `Game`, rules and timers on the server. Clear every per-connection timer.
4. Socket events: run `socket-event` for each new or changed event. Write the contract first.
5. Client entity: sprite in `Bomberman-2.0/src/game/entities/`, `id` from the payload, export from `index.ts`.
6. Render and update in `Playing`: group in `createMap`, handler in the `socketHandlers` table, collision in `update`. Client limits (bomb limit, speed) stay client-enforced. The server trusts reported collisions.
7. Docs: run `sync-docs`. `docs/entities.md` and `docs/socket-contract.md` must match the code.

## Verify

- Backend and frontend checks pass in each repo you touched (`.claude/rules/development-workflow.md` › After you finish).
- Backend test added or updated (`docs/testing.md`), `npm test` passes.
- E2E impact checked (`development-workflow` › Keep E2E in sync after behaviour changes); companion E2E PR opened if a spec is affected.
- `./scripts/check-socket-contract.sh` exits 0.
- Run `play-local` with two different accounts. The entity appears for both players, and the server state agrees with the client. State what you played and saw.
- Tell the reviewer: dispatch `game-contract-reviewer` before the PR (`development-workflow` › Pre-PR review).
