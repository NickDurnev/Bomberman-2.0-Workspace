# Docs

Architecture and game docs for the Bomberman workspace. They describe the `dev` branch of both submodules: `Bomberman-2.0` (React + Phaser 4 client) and `Bomberman-2.0-Backend` (Express + socket.io + MongoDB server). Docs explain contracts, invariants and ownership; read the code for details.

## Reading order

Read 1–3 before any change. Then read the docs for the area you touch.

1. [architecture.md](architecture.md): processes, server authority, where state lives, the lifecycle of a match.
2. [known-traps.md](known-traps.md): bug classes this game already had. Most new bugs repeat one.
3. [glossary.md](glossary.md): the terms used in the code and in these docs.
4. [mechanics.md](mechanics.md): bombs, fuse, blast, chain reaction, spoils, portals, death, win conditions, game modes, with values.
5. [entities.md](entities.md): server and client classes for each game object and which side owns what.
6. [socket-contract.md](socket-contract.md): every socket event, the handshake, the authority rule and the listener rule.
7. [maps.md](maps.md): Tiled map format, how each side loads a map, map invariants.
8. [assets.md](assets.md): asset folders, `Preload` keys, sprite sizes, the avatar pipeline.
9. [testing.md](testing.md): the backend test suite, how to run it, the helpers, where a new test goes.
10. [e2e-hook.md](e2e-hook.md): the read-only `window.__e2e` hook that the E2E suite uses, and when it must change.
11. [releases.md](releases.md): the `dev` → `main` release, the deploys, release-please and the back-merge to `dev`.

## By task

| Task | Read |
| --- | --- |
| Change game logic or rules | mechanics, entities, socket-contract, known-traps |
| Add a game object (entity) | entities › Adding an entity, socket-contract, assets |
| Add or change a socket event | socket-contract › Changing the contract, known-traps |
| Edit or add a map | maps › Adding a map, mechanics › Portals |
| Add or replace sprites, avatars | assets › Changing assets |
| Write or change a backend test | testing, mechanics, socket-contract |
| Debug a bug | known-traps first, then the docs of the area |
| Release to production | releases |
| Add a game mode or bots | architecture, mechanics, socket-contract › Authority rule |

## Keeping docs true

- Change the docs in the same change set as the code. `docs/socket-contract.md` is checked by `scripts/check-socket-contract.sh`; run it after any socket change.
- Every value in these docs (timers, ranges, keys, file paths) comes from the code. If code and docs disagree, the code wins: fix the doc. If the code looks wrong, open an issue in the game repo; do not describe bugs in these docs.
- Paths are relative to the workspace root and written in backticks. Links between docs are relative markdown links.
