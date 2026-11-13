# Socket contract

Every socket.io event exchanged between the client (`Bomberman-2.0`) and the server (`Bomberman-2.0-Backend`). This seam is where past production bugs came from, so treat this file as the contract: change it in the same PR that changes an event.

`scripts/check-socket-contract.sh` compares the table below with the event names used in both repos (string literals, constants and handler tables). Run it after any socket change; it exits 1 and prints the difference when the two disagree. It checks event **names** only; see [Check limits](#check-limits).

## Transport and identity

- One socket per browser tab. The client creates it once at module load in `Bomberman-2.0/src/utils/socket.ts` and every React component and Phaser scene imports that singleton. The socket outlives route changes and Phaser scene restarts, so a listener that is not removed keeps firing in the next round (see [Listener rule](#listener-rule)).
- The server wires all handlers per connection in `Bomberman-2.0-Backend/src/app.ts`. Lobby handlers live in `Bomberman-2.0-Backend/src/lobby.ts`; gameplay handlers live on a per-connection `Play` instance (`Bomberman-2.0-Backend/src/play.ts`).

### Handshake `auth`

Identity travels in the socket.io handshake, so the server knows who the player is before any event handler runs and again on every reconnect. This replaced an earlier race where a player could join a game before `updateUserSocketId` was processed.

| `auth` field | Source on the client | Use on the server (`app.ts`) |
| --- | --- | --- |
| `socketId` | `getOrCreateSocketId()`: a UUID stored in localStorage under `socket_id`, created once and reused | `client.customId`. This is the player id everywhere in game state; it is **not** socket.io's `client.id`. |
| `email` | `google_user` in localStorage | `storeSocketID(email, socketId)` writes the id to the `User` document in MongoDB |
| `name` | `google_user` in localStorage | `client.userName`, used as the player name when joining a game |
| `picture` | `google_user` in localStorage | `client.userPicture`, used as the player skin URL |

The `auth` object is built once, when `utils/socket.ts` is first imported. A user who logs in later sends the same fields with `updateUserSocketId`; the server overwrites `customId`, `userName` and `userPicture` from it. `Game.addPlayer` prefers the handshake profile and falls back to a DB lookup by socket id only when name or picture is missing.

### Rooms

| Room | Joined by | Used for |
| --- | --- | --- |
| `lobby_room` | `enter lobby` | `display pending games` broadcasts |
| `<game id>` | `enter pending game` | all per-game broadcasts (`update game`, `launch game`, gameplay events, `end game`) |
| `<socket.io client.id>` | automatic | `Play.broadcast`; combined with the game room for `move player` |

## Events

Direction: `C→S` client to server, `S→C` server to client, `both` when the same name is used each way. "ack" means the client passes a socket.io acknowledgement callback as the last argument and the server answers through it instead of with a separate event. Paths are relative to the workspace root.

<!-- socket-contract:begin -->
| event | direction | payload shape | emitter file | handler file(s) |
| --- | --- | --- | --- | --- |
| `updateUserSocketId` | C→S | `{ email, name, picture, socket_id }` | `Bomberman-2.0/src/components/Socket.tsx` (on login and on every `connect`) | `Bomberman-2.0-Backend/src/app.ts` (inline; `storeSocketID` in `Bomberman-2.0-Backend/src/services/socket.ts`) |
| `enter lobby` | C→S | no data; ack `(games: Game[])` with the pending games that are not full | `Bomberman-2.0/src/routes/menu/Menu.tsx` | `Bomberman-2.0-Backend/src/lobby.ts` `onEnterLobby` (joins `lobby_room`) |
| `leave lobby` | C→S | none | `Bomberman-2.0/src/routes/menu/Menu.tsx`, `Bomberman-2.0/src/routes/menu/components/GameForm.tsx` | `Bomberman-2.0-Backend/src/lobby.ts` `onLeaveLobby` |
| `check game name` | C→S | `gameName: string`; ack `({ isAvailable: boolean })` | `Bomberman-2.0/src/routes/menu/components/GameForm.tsx` | `Bomberman-2.0-Backend/src/lobby.ts` `onCheckNameAvailable` |
| `create game` | C→S | `{ mapName, isPortalsEnabled, isDelaySpoilEnabled, gameName }`; ack `({ game_id })` | `Bomberman-2.0/src/routes/map/SelectMap.tsx` | `Bomberman-2.0-Backend/src/lobby.ts` `onCreateGame` (creator is not added; it navigates to the pending page and sends `enter pending game`) |
| `display pending games` | S→C | `Game[]` (pending games that are not full), to `lobby_room` | `Bomberman-2.0-Backend/src/lobby.ts` `updateLobbyGames` | `Bomberman-2.0/src/routes/menu/Menu.tsx` |
| `enter pending game` | C→S | `game_id: string` | `Bomberman-2.0/src/routes/pending/Pending.tsx`, `Bomberman-2.0/src/routes/game/components/RestartGameModal.tsx` | `Bomberman-2.0-Backend/src/lobby.ts` `onEnterPendingGame` (joins game room, `addPlayer`) |
| `leave pending game` | C→S | none (server uses `socket.socket_game_id`) | `Bomberman-2.0/src/routes/pending/Pending.tsx`, `Bomberman-2.0/src/routes/game/components/RestartGameModal.tsx`, `Bomberman-2.0/src/components/UserBar.tsx` | `Bomberman-2.0-Backend/src/lobby.ts` `onLeavePendingGame` (also called on `disconnect` from `Bomberman-2.0-Backend/src/app.ts`) |
| `update game` | S→C | `{ current_game: Game }`, to the game room | `Bomberman-2.0-Backend/src/lobby.ts` `updateCurrentGame` | `Bomberman-2.0/src/routes/pending/Pending.tsx`, `Bomberman-2.0/src/routes/game/components/RestartGameModal.tsx` |
| `start timer` | both | C→S: `game_id: string`. S→C: no payload, to the game room | C→S: `Bomberman-2.0/src/routes/pending/Pending.tsx`, `Bomberman-2.0/src/routes/game/components/RestartGameModal.tsx`; S→C: `Bomberman-2.0-Backend/src/play.ts` `onStartTimer` | S: `Bomberman-2.0-Backend/src/play.ts` `onStartTimer`; C: `Bomberman-2.0/src/routes/pending/Pending.tsx`, `Bomberman-2.0/src/routes/game/components/RestartGameModal.tsx` |
| `start game` | C→S | `game_id: string` | `Bomberman-2.0/src/routes/pending/Pending.tsx`, `Bomberman-2.0/src/routes/game/components/RestartGameModal.tsx` | `Bomberman-2.0-Backend/src/play.ts` `onStartGame` (moves the game from pending to running, schedules the time-limit `endGame`) |
| `launch game` | S→C | `Game`, to the game room | `Bomberman-2.0-Backend/src/play.ts` `onStartGame` | `Bomberman-2.0/src/routes/pending/Pending.tsx`, `Bomberman-2.0/src/routes/game/components/RestartGameModal.tsx`, `Bomberman-2.0/src/game/scenes/GameOver.ts` |
| `get current game` | C→S | `game_id: string`; ack `(game: Game or undefined)` from the running games | `Bomberman-2.0/src/game/PhaserGame.tsx` | `Bomberman-2.0-Backend/src/app.ts` → `Bomberman-2.0-Backend/src/play.ts` `onGetCurrentGame` |
| `update player position` | C→S | `{ playerId, gameId, x, y }` (pixels), every `PING` ms while moving | `Bomberman-2.0/src/game/entities/player.ts` `positionUpdaterLoop` | `Bomberman-2.0-Backend/src/play.ts` `updatePlayerPosition` |
| `move player` | S→C | `{ player_id, x, y }`, to the sender's own room and the game room (the sender receives it too and ignores it) | `Bomberman-2.0-Backend/src/play.ts` `updatePlayerPosition` | `Bomberman-2.0/src/game/scenes/Playing.ts` `onMovePlayer` |
| `create bomb` | C→S | `{ playerId, gameId, col, row }` | `Bomberman-2.0/src/game/entities/player.ts` `handleBombs` | `Bomberman-2.0-Backend/src/play.ts` `createBomb` |
| `show bomb` | S→C | `{ bomb_id, playerId, col, row }`, to the game room | `Bomberman-2.0-Backend/src/play.ts` `createBomb` | `Bomberman-2.0/src/game/scenes/Playing.ts` `onShowBomb` |
| `detonate bomb` | S→C | `{ bomb_id, playerId, blastedCells: BlastedCell[] }`; `BlastedCell = { row, col, type: "explosion_<center/up/right/down/left/horizontal/vertical>", destroyed, spoil: Spoil or null, portal: Portal or null }` | `Bomberman-2.0-Backend/src/play.ts` `detonateBomb` (from the bomb queue or `onBlastVsBomb`) | `Bomberman-2.0/src/game/scenes/Playing.ts` `onDetonateBomb` |
| `detonate bomb by blast` | C→S | `{ bomb_id, gameId, playerId }` (`playerId` is the bomb owner) | `Bomberman-2.0/src/game/scenes/Playing.ts` `onBombVsBlast` | `Bomberman-2.0-Backend/src/play.ts` `onBlastVsBomb` |
| `pick up spoil` | C→S | `{ spoil_id, playerId, gameId }` | `Bomberman-2.0/src/game/scenes/Playing.ts` `onPlayerVsSpoil` | `Bomberman-2.0-Backend/src/play.ts` `onPickUpSpoil` |
| `spoil was picked` | S→C | `{ player_id, spoil_id, spoil_type }`, to the game room | `Bomberman-2.0-Backend/src/play.ts` `onPickUpSpoil` | `Bomberman-2.0/src/game/scenes/Playing.ts` `onSpoilWasPicked`, `Bomberman-2.0/src/routes/game/components/PlayerInfo.tsx` |
| `use portal` | C→S | `{ portal_id, playerId, gameId }` | `Bomberman-2.0/src/game/scenes/Playing.ts` `onPlayerVsPortal` | `Bomberman-2.0-Backend/src/play.ts` `onUsePortal` |
| `teleport player` | S→C | `{ player_id, x, y }` (pixel centre of a random other portal), to the game room | `Bomberman-2.0-Backend/src/play.ts` `onUsePortal` | `Bomberman-2.0/src/game/scenes/Playing.ts` `onTeleportPlayer` |
| `player died` | C→S | `{ col, row, playerId, killerId, gameId }` (`killerId` is the blast owner; can equal `playerId`) | `Bomberman-2.0/src/game/scenes/Playing.ts` `onPlayerVsBlast` | `Bomberman-2.0-Backend/src/play.ts` `onPlayerDied` |
| `show tombstone` | S→C | `{ player_id, tombId, col, row }`, to the game room | `Bomberman-2.0-Backend/src/play.ts` `onPlayerDied` | `Bomberman-2.0/src/game/scenes/Playing.ts` `onShowTombstone`, `Bomberman-2.0/src/routes/game/components/PlayerInfo.tsx` |
| `player win` | S→C | `{ winner: Player, prevGameInfo }`, to the game room, when one player is left alive | `Bomberman-2.0-Backend/src/play.ts` `onPlayerDied` | `Bomberman-2.0/src/routes/game/components/PlayerWinModal.tsx` |
| `end game` | S→C | `{ game_id, new_game_id, prevGameInfo }`, to the game room, after the delay of `endGame` | `Bomberman-2.0-Backend/src/play.ts` `endGame` | `Bomberman-2.0/src/game/scenes/Playing.ts` `onEndGame`, `Bomberman-2.0/src/routes/game/components/RestartGameModal.tsx`, `Bomberman-2.0/src/routes/game/components/PlayerWinModal.tsx` |
| `leave game` | C→S | none | `Bomberman-2.0/src/game/scenes/Playing.ts` `onEndGame` | `Bomberman-2.0-Backend/src/play.ts` `onLeaveGame` |
| `player disconnect` | both | C→S: `{ player_id }` (the sender's own socket id). S→C: `{ player_id }`, to the game room | C→S: `Bomberman-2.0/src/routes/game/components/PlayerInfo.tsx` `backToMenu`; S→C: `Bomberman-2.0-Backend/src/play.ts` `onDisconnectFromGame` | S: `Bomberman-2.0-Backend/src/app.ts` → `Bomberman-2.0-Backend/src/play.ts` `onDisconnectFromGame`; C: `Bomberman-2.0/src/game/scenes/Playing.ts` `onPlayerDisconnect` |
| `joinRoom` | C→S | `{ room_id }` | none (no client emits it) | `Bomberman-2.0-Backend/src/app.ts` (inline `client.join`) |
| `leaveRoom` | C→S | `{ room_id }` | none (no client emits it) | `Bomberman-2.0-Backend/src/app.ts` (inline `client.leave`) |
<!-- socket-contract:end -->

socket.io built-in events are not in the table and the check script ignores them: the server uses `connection` and `disconnect` (`Bomberman-2.0-Backend/src/app.ts` releases the `Play` bomb-queue timer and removes the player from a pending or running game); the client uses `connect` and `disconnect` in `Bomberman-2.0/src/components/Socket.tsx`.

### Check limits

`scripts/check-socket-contract.sh` compares only the **set of event names** in the table with the set in code. It does not check the direction, payload, emitter or handler columns; keep those correct by hand. It finds names on these receivers: `clientSocket`, `socket`, `client`, `sockets`, `broadcast`, `serverSocket`, `io` (plus `.to(...)`/`.in(...)` chains). It reads string, single-quoted and template literals, UPPER_CASE constants, handler-table variables, and a name on the line after a call that opens with `.on(` at the end of a line. It does not see a socket held in a variable with another name, or a name more than one line after the opening `(`. A template literal with `${...}` or an unreadable first argument fails the check instead of being guessed.

`Game`, `Player`, `Spoil` and `Portal` in payloads are the server entity objects serialised to JSON (see [entities.md](entities.md)). The `Map` fields of `Game` (`spoils`, `bombs`, `portals`, `tombstones`) serialise to `{}`; the client must not read them. `prevGameInfo` is the `Game` with each player that has no kills given a `noKillPhrase` string. The client mirrors these shapes in `Bomberman-2.0/src/utils/types.ts` (`GameData`, `EndGame`, `PlayerWin`, `ICell`, `ITombStone`, `pickedSpoilSocketData`); the types are not shared, so a payload change must update both repos.

## Authority rule

The server owns shared state; clients own their own avatar and report what they see.

| Decision | Owner | Where |
| --- | --- | --- |
| Lobby and game membership, spawn points | Server | `Bomberman-2.0-Backend/src/lobby.ts`, `Bomberman-2.0-Backend/src/entity/game.ts` |
| All ids (game, bomb, spoil, portal, tombstone) | Server (`uuid`) | `Bomberman-2.0-Backend/src/entity/*` |
| Bomb timing, blast shape, destroyed boxes, spoil and portal drops | Server | `Bomberman-2.0-Backend/src/play.ts` bomb queue, `Bomberman-2.0-Backend/src/entity/bomb.ts` |
| Bomb power and fuse delay of a player | Server (`Player.power`, `Player.delay`) | `Bomberman-2.0-Backend/src/entity/player.ts` |
| Win, top-3, kills, stats | Server | `Bomberman-2.0-Backend/src/play.ts` `onPlayerDied`, `Bomberman-2.0-Backend/src/services/stats.ts` |
| Own position and movement speed | Client | `Bomberman-2.0/src/game/entities/player.ts` |
| Max number of bombs at the same time | Client (`bombs` vs `activeBombs`); the server does not limit it | `Bomberman-2.0/src/game/entities/player.ts` |
| Collision results: death, spoil pick-up, portal entry, blast hits a bomb | Client detects, server applies | `Bomberman-2.0/src/game/scenes/Playing.ts` `update` |

Rules for new features:

1. The client sends an intent or a collision report; the server decides the outcome and broadcasts it to the game room. The client renders shared entities only from server events. (Existing exceptions: the picker destroys a spoil sprite before `spoil was picked` arrives; the dying player hides itself before `show tombstone`.)
2. The server must create the ids of new shared entities and send them in the payload, so every client can find the same sprite later.
3. A chain reaction by blast (`detonate bomb by blast`) is an intended mechanic. Several clients can report the same bomb; the server detonates it once because `detonateBomb` deletes the bomb from `Game.bombs` and later reports find nothing.
4. The server does not check that `playerId` in a payload is the sender. Any client can act for any player. Do not build features that rely on this being safe.

## Listener rule

The client socket is a singleton that survives React unmounts and Phaser scene restarts. `socket.off(event, fn)` removes a listener only when `fn` is the **same function object** that was passed to `socket.on`. If it is not, `off` does nothing, the old listener stays, and the next round runs every handler twice ("event ghosting"). This happened in production: handlers were registered with `this.handler.bind(this)` inline and removed with the unbound `this.handler`.

- Create the handler function once and keep the reference. Use the same reference in `on` and `off`.
- Never write `.bind(this)` or an arrow function inline inside `socket.on(...)` or `socket.off(...)`.
- Phaser scenes: bind in `create()`, store the pairs (see the `socketHandlers` table in `Bomberman-2.0/src/game/scenes/Playing.ts` and `boundLaunchGame` in `Bomberman-2.0/src/game/scenes/GameOver.ts`), and remove them in a handler registered with `this.events.once` for both `Phaser.Scenes.Events.SHUTDOWN` and `DESTROY`. `scene.remove()` does not call your own end-of-game code, so cleanup must hang on the scene events.
- React: register in `useEffect` and remove the same `const` handlers in the effect cleanup.
- Register a listener before you emit the event that triggers the reply (for example `Menu.tsx` registers `display pending games` before it emits `enter lobby`).

Known violations on `dev` (not fixed here, the submodules are read-only for this doc):

- `Bomberman-2.0/src/routes/pending/Pending.tsx` registers `start timer` with an inline arrow and passes a different new arrow to `off`, so that listener is never removed.
- `Bomberman-2.0/src/routes/game/components/PlayerWinModal.tsx` registers `end game` and `player win` inside a 3-second `setTimeout`. If the component unmounts within 3 seconds, the cleanup runs first and the listeners are added later and never removed.

## Changing the contract

1. Change the emitter and every handler in both repos in the same change set (one PR per repo).
2. Update the row above (name, payload, files) and the mirrored type in `Bomberman-2.0/src/utils/types.ts` or `Bomberman-2.0-Backend/src/types.ts`.
3. Run `./scripts/check-socket-contract.sh` from the workspace root.
