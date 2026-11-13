# Known traps

Classes of bugs this game has already had, or has open as known gaps. Each entry is **symptom → cause → rule**. Read this before you write new code and before you debug: most new bugs repeat one of these. The status line says what the `dev` code does today.

This is not the list of current bugs. Current code discrepancies are in [architecture.md › Known discrepancies](architecture.md#known-discrepancies-in-the-code-dev) and [mechanics.md › Discrepancies](mechanics.md#discrepancies-found-while-writing).

Sources: the 2026-06 audit (`Bomberman-2.0-BUG-REPORT.md`, outside this repo, items #1–#20) and the fixes merged after it.

## Event ghosting from a listener leak

**Symptom.** After a few rounds, bombs seem to explode faster, explosions multiply, enemies stutter or teleport, a spoil is applied twice, a match ends early. The effect grows with each round in the same tab.

**Cause.** The client socket is a singleton that survives React unmounts and Phaser scene restarts. `Playing` registered handlers with `this.onX.bind(this)` inline and removed them with the unbound `this.onX`. `.bind` makes a new function each call, so `socket.off` matched nothing and every round added one more full set of handlers. One server `detonate bomb` then ran N handlers. The same leak was in `GameOver` (no `off` at all), in `RestartGameModal` (its cleanup called `on` instead of `off`) and in `PhaserGame` (no `destroy()` on unmount). It was **not** the `DELAY` spoil (the bug also happened in games without it) and **not** a server fuse defect (no server path shortens one bomb's timer).

**Rule.** Follow the [Listener rule](socket-contract.md#listener-rule): create each handler once, pass the same reference to `on` and `off`, never `.bind` or an arrow inline in `on`/`off`, hang Phaser cleanup on the scene `SHUTDOWN` and `DESTROY` events. When a timing bug "grows over time", count listeners (`clientSocket.listeners(event).length`) before you touch game logic.

**Status.** Fixed in `Bomberman-2.0/src/game/scenes/Playing.ts` (the `socketHandlers` table), `Bomberman-2.0/src/game/scenes/GameOver.ts`, `Bomberman-2.0/src/routes/game/components/RestartGameModal.tsx` and `Bomberman-2.0/src/game/PhaserGame.tsx`. Two violations remain open in `Pending.tsx` and `PlayerWinModal.tsx` (listed in the Listener rule).

## Per-connection timers on the server

**Symptom.** Server CPU and memory grow with uptime. No visible game effect.

**Cause.** Each socket connection creates a `Play` instance whose constructor starts a 100 ms `setInterval` for the bomb queue. Nothing cleared it, so every connection and reconnect leaked one timer.

**Rule.** Anything a connection starts (timers, intervals, subscriptions) must be released in the `disconnect` handler in `Bomberman-2.0-Backend/src/app.ts`, also for sockets that never joined a game. Do not keep shared match state on a per-connection object: it dies with that connection (today a disconnected player's bombs lose their fuse, see [mechanics.md](mechanics.md#discrepancies-found-while-writing)).

**Status.** Fixed: `Play.destroy()` clears the interval and runs on every disconnect.

## Identity handshake race

**Symptom.** A player joins with no name, a join fails, or ghost and duplicate players appear after a network blip or a reconnect.

**Cause.** The client sent its identity with an `updateUserSocketId` emit after `connect`. Routes emitted `enter lobby`, `enter pending game` and `get current game` at once, so the server could handle them before it knew who the socket was. On reconnect the identity was not reliably sent again, and `Socket.tsx` re-subscribed its connection listeners on every state change.

**Rule.** Identity comes from the socket.io handshake `auth` (`socketId`, `email`, `name`, `picture`; see [socket-contract.md › Handshake auth](socket-contract.md#handshake-auth)). The player id is the localStorage `socket_id` UUID (`client.customId`), never socket.io's `client.id`, which changes on every reconnect. A new per-player field that the server needs before the first event goes in the handshake too. Do not make a handler depend on an earlier emit having been processed.

**Status.** Fixed. Limits: `auth` is built once when `Bomberman-2.0/src/utils/socket.ts` is imported, so a user who logs in later still depends on `updateUserSocketId`. Closing a tab emits nothing; the server's `disconnect` handler removes the player, and that was judged enough (no `pagehide` emit was added).

## Player rendered without name or skin

**Symptom.** A player who joins appears as a black sprite with no nickname, on some clients or all.

**Cause.** `Game.addPlayer` read name and skin from MongoDB with `getUserBySocketId`. That returned `null` when `User.socketID` had been overwritten by another session of the same account (the field holds one id per user) or when the write from `storeSocketID` had not landed yet. The player was created with empty name and skin.

**Rule.** Data needed to render a player travels with the connection (handshake `name` and `picture` on `client.userName` / `client.userPicture`), not through a DB lookup keyed by socket id at join time. Treat `User.socketID` as "last session wins".

**Status.** Fixed. `addPlayer` still falls back to the DB when the handshake has no name or picture.

## Black player sprite from `textures.get`

**Symptom.** A player whose avatar failed to load (or who has no photo) renders as a black square instead of a fallback avatar.

**Cause.** `setPlayerAvatar` checked `textures.get(id)`. Phaser returns the `__MISSING` texture for an unknown key, which is truthy, so the fallback branch never ran.

**Rule.** Use `textures.exists(key)` to test for a texture. Never use the result of `textures.get` as an existence check. See [assets.md › Avatar and skin pipeline](assets.md#avatar-and-skin-pipeline).

**Status.** Fixed in `Bomberman-2.0/src/utils/utils.ts`.

## Same account in two sessions collapses into one player

**Symptom.** Two windows join the same game but the lobby shows one player, or one player disappears when the other joins. Stats or names attach to the wrong session.

**Cause.** `Game.addPlayer` treats a player with the same `name` **and** `skin` as a re-join and replaces the old entry. Two sessions of one Google account match. Two tabs in one browser profile also share the localStorage `socket_id`, so they are the same player id. And the second session overwrites `User.socketID`.

**Rule.** Test multiplayer with distinct Google accounts in separate browser profiles. Do not change the dedup key without a replacement for the re-join case it covers.

**Status.** Intended behaviour; keep it in mind when testing.

## New users silently not created (`/auth` 422)

**Symptom.** A new Google user can play but has no `User` document: no stats, no DB fallback for name or skin.

**Cause.** The Joi schema for `POST /api/v1/auth` rejected the signup with 422: `socketID` was `null`, `picture` was `""` for accounts without a photo, `name` could be empty. The client's `addUser` ignored the failed response.

**Rule.**

- The validator runs with `allowUnknown: false` (`Bomberman-2.0-Backend/src/middlewares/validationMiddleware.ts`). A new field in the request body must be added to the schema in `Bomberman-2.0-Backend/src/middlewares/validation/schemas.ts`, or every request fails with 422.
- Optional profile data must allow `null` and `""`. Only `name` and `email` are required.
- Optional external steps (Cloudinary upload) must never block account creation.
- A client call must not swallow a non-OK response.

**Status.** Fixed: the schema allows `null` / `""` for `socketID`, `locale`, `picture`; `uploadAvatar` never throws; the client always sends a non-empty name and a socket id; `addUser` in `Bomberman-2.0/src/services/auth.ts` logs a non-OK response. Its caller in `Menu.tsx` still does nothing with the result.

## Chain reaction mistaken for a bug

**Symptom.** A bomb explodes before its fuse ends.

**Cause.** Another blast reached it. This is the intended chain reaction ([mechanics.md › Chain reaction](mechanics.md#chain-reaction-intended)).

**Rule.** Never add a grace period or ignore `detonate bomb by blast`. If bombs explode early with no blast nearby, look for event ghosting first.

## Duplicated constants and maps drift

**Symptom.** Client and server disagree: a box is drawn where the server sees empty, a HUD value does not match the effect, a timer shows the wrong time.

**Cause.** The repos share no code. Constants and both map files exist twice and nothing checks that they agree.

**Rule.** When you change a shared constant or a map, change both repos in the same change set. The list is in [entities.md › Shared constants](entities.md#shared-constants) and [maps.md](maps.md#invariants).

**Status.** `default_map.json` differs in one tile today (see [architecture.md](architecture.md#known-discrepancies-in-the-code-dev)).

## Known gaps (deferred)

These are open on purpose: each needs a focused design and review. Do not make them worse, and do not build features that assume they are solved.

### Unvalidated socket payloads

Audit item #9. **Symptom:** none visible in normal play; a buggy or hostile client can act for another player or another game, send `NaN` coordinates, or crash a handler. **Cause:** the server reads every socket payload as is. Nothing checks that `playerId` is the sender (`client.customId`) or that the sender is in `gameId`. `mapName` from `create game` goes into a `require` path. **Rule:** a new or changed handler validates the payload shape and checks ownership (`playerId === client.customId`, sender is a player of the game). Do not widen what a client can claim (see [socket-contract.md › Authority rule](socket-contract.md#authority-rule)).

### No `/auth` token verification

Audit item #10. **Symptom:** none in normal play. **Cause:** `POST /api/v1/auth` trusts the `email` and `picture` in the body; there is no Google token check. Anyone can create a user or replace an existing user's picture. **Rule:** do not treat a `User` document or `email` as verified identity, and do not attach anything sensitive to it until the endpoint verifies a Google ID token.

### Silent error swallows

Audit item #11. **Symptom:** an operation fails and nothing tells the caller; the bug shows up later somewhere else. **Cause:** `storeSocketID`, `getUserBySocketId` (`Bomberman-2.0-Backend/src/services/socket.ts`) and `updatePlayerStats` (`Bomberman-2.0-Backend/src/services/stats.ts`) catch errors, log them and return normally. `getUserBySocketId` then returns `undefined` although callers treat the result as a user. **Rule:** new code returns or throws errors so the caller can act, and its types say when a value can be missing. Do not add new catch-and-log blocks.
