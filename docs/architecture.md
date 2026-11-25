# Architecture

How the multiplayer Bomberman game is built and how a match flows through it. Written against the `dev` branch of both submodules. For event details see [socket-contract.md](socket-contract.md); for the game objects see [entities.md](entities.md).

## Processes

| Process | Repo | Stack | Local port |
| --- | --- | --- | --- |
| Web client | `Bomberman-2.0` | React (react-router routes), Phaser 4 (the match itself), socket.io-client, zustand, Vite | 3000 (`make frontend`) |
| Game server | `Bomberman-2.0-Backend` | Express + socket.io on one HTTP server, mongoose | 4000 (`make backend`) |
| Database | — | MongoDB (`docker-compose.yml` locally) | 27017 (`make db`) |

The server is one Node process. All lobby and match state is **in memory** in that process, so the server cannot be scaled horizontally and a restart drops every pending and running game. MongoDB holds only users and stats.

Two channels connect client and server:

- **REST** (`Bomberman-2.0-Backend/src/routes/index.ts`, prefix `/api/v1`): `POST /auth` creates or updates the `User` after Google login (avatar upload to Cloudinary, which must never block account creation); `GET /stats` serves the leaderboard. Client side: `Bomberman-2.0/src/services/auth.ts`, `Bomberman-2.0/src/utils/statsAPI.tsx`.
- **socket.io**: everything about lobbies and matches. One singleton socket per tab (`Bomberman-2.0/src/utils/socket.ts`), identity in the handshake `auth`.

A monthly cron job in `Bomberman-2.0-Backend/src/app.ts` deletes all stats.

## Server authority

The server owns shared state: lobby and game membership, all entity ids, bomb timing and blast results, spoil and portal drops, a player's bomb power and fuse delay, win/kill/top-3 results and stats. Clients own their own avatar: they move it locally, detect collisions in Phaser arcade physics, and report results (position, death, spoil pick-up, portal entry, blast hitting a bomb). The server applies these reports without validating them. The full table and the rules for new features are in [socket-contract.md › Authority rule](socket-contract.md#authority-rule).

Why this split: it keeps movement responsive (no server round-trip per frame) while every client sees the same map, bombs and drops, because only the server creates them.

## Where state lives

| State | Location | Lifetime |
| --- | --- | --- |
| Pending games (lobby) | `pendingGames: Map<id, Game>` in `Bomberman-2.0-Backend/src/lobby.ts` | Until started, emptied, or empty for `LOBBY_TIMEOUT` (cleanup every minute) |
| Running games | `runningGames: Map<id, Game>` in `Bomberman-2.0-Backend/src/play.ts` | From `start game` to `end game`; a cleanup every minute removes a game that is empty `GAME_DURATION` after its start, or older than `DELETE_PENDING_GAMES_INTERVAL` from its start |
| Bomb fuses | `bombQueue: Map<game id, items>` in `Bomberman-2.0-Backend/src/play.ts`, one 100 ms interval for the process | Until the bomb explodes or its game leaves `runningGames` |
| Per-connection gameplay handler | `Play` instance on `client.playInstance` (no timers) | Socket connection |
| Player identity on the socket | `client.customId`, `userName`, `userPicture`, `socket_game_id` (`CustomSocket` in `Bomberman-2.0-Backend/src/types.ts`) | Socket connection |
| Users, stats | MongoDB: `User` (`socketID` field links to the player id), `PlayStats` (`userId` = player id) | Persistent (stats wiped monthly) |
| Player id and Google profile | Browser localStorage: `socket_id`, `google_user` | Persistent per browser |
| Result of the last match | React state in `EndGameModal` (`Bomberman-2.0/src/routes/game/components/EndGameModal.tsx`) | Until the route `gameId` changes |
| Game name typed in the menu | zustand `useGameStore` (`Bomberman-2.0/src/hooks/stores.ts`) | Page session |
| Live match view | Phaser `Playing` scene: sprites in groups, `currentGame` | One match |

## Client view and input

- **Canvas.** Phaser uses `Scale.RESIZE` (`Bomberman-2.0/src/game/main.ts`). The canvas fills its flex wrapper in `Bomberman-2.0/src/routes/game/Game.tsx`. The wrapper is at most 1120x735 px in every layout and is centered in the free space.
- **Camera.** In `Playing.create` (`Bomberman-2.0/src/game/scenes/Playing.ts`) the main camera has the map as bounds. It calls `startFollow` on the local player. The zoom stays at the default 1 (no `setZoom`). On a screen smaller than the map, the camera scrolls with the player.
- **Touch input.** The module `Bomberman-2.0/src/game/touchInput.ts` is a singleton of flags: `up`, `down`, `left`, `right`, `bomb`. `Player.handleMoves` and `Player.handleBombs` (`Bomberman-2.0/src/game/entities/player.ts`) read it next to the keyboard keys. Movement is 8-way and digital. A diagonal sets two flags. A stick offset below 15% of the radius (dead zone) sets none.
- **Controls.** The React components `Thumbstick` and `BombButton` (`Bomberman-2.0/src/routes/game/components/`) write the flags. They show only when `(any-pointer: coarse)` matches.
- **Layouts.** `useGameLayout` (`Bomberman-2.0/src/hooks/use-game-layout.ts`) returns `isTouch`, `isCompact` and `isPortrait`. Compact means `(max-width: 1119px), (max-height: 500px)`. `Game.tsx` picks one of three layouts: desktop bar, compact portrait, compact landscape with side rails. The HUD state comes from the hooks `usePlayerInfo` and `useCountdown` (`Bomberman-2.0/src/routes/game/hooks/`).

The server does not know about the camera or touch input. Movement is reported with the same events as keyboard movement.

## Lifecycle of a match

```
Menu (/)  ──host──▶  /map  ──create game──▶  /pending/:id  ──start──▶  /game/:id  ──end game──▶ EndGameModal (same page)  ──launch──▶ /game/:new id
   ▲  enter lobby          ack {game_id}          enter pending game      get current game          enter pending game (new id)          (no reload)
   │                                              update game             Preload → Playing         start timer / start game
   └──────────── join a listed game ─────────────▶
```

1. **Lobby.** `Menu.tsx` listens for `display pending games` and emits `enter lobby`; the server joins the socket to `lobby_room` and answers through the ack. Lobby changes (game created, game full or not full again, game deleted) are broadcast to `lobby_room`.
2. **Create.** The host checks the name (`check game name`, ack), leaves the lobby room, picks a map and a texture pack in `SelectMap.tsx` and emits `create game` with `{ mapName, isPortalsEnabled, isDelaySpoilEnabled, texturePack, gameName }`. The server builds a `Game` from the map JSON in `Bomberman-2.0-Backend/src/maps/` and returns its id. The host is **not** a player yet.
3. **Room.** Every player, the host included, opens `/pending/:id`, which emits `enter pending game`. The server joins the socket to the game room, records `socket_game_id`, adds a `Player` on a random free spawn and broadcasts `update game` to the room.
4. **Start.** With at least two players, any player emits `start timer`; the server echoes it to the room and every client runs the same countdown. When a client's countdown ends it emits `start game` and navigates to `/game/:id`. The first `start game` moves the game from `pendingGames` to `runningGames`, schedules the time-limit end (`GAME_DURATION`, 180 s) and broadcasts `launch game`; later `start game` calls find no pending game and do nothing.
5. **Play.** `PhaserGame.tsx` fetches the running game with `get current game` (ack) and starts Phaser: `Preload` loads the room's texture pack (`Game.texturePack`) and one texture per player (key = player id, URL = skin) and starts `Playing` with the game data. `Playing` creates the local `Player` for the entry whose id equals localStorage `socket_id` and an `EnemyPlayer` for every other entry, then registers its socket handlers. Gameplay events are listed in the contract.
6. **Game over.** The server ends a match in three ways, all through `Play.endGame`:
   - one player left alive after a death: `player win`, then `end game` after 5 s, stats processed with the winner;
   - nobody left alive: `end game` after 2 s, stats processed;
   - time limit, or a leave or disconnect that leaves at most one living player (dead players do not count): `end game`, stats **not** processed. Reason `disconnect` when one living player is left (winner by forfeit), `draw` when none is left.

   A match ends once. The first ending wins, and `endGame` skips every later one (`endingGames`), for example the winner dying or a player leaving during the 5 s win delay, or the time limit after an early end. The time-limit end runs `GAME_DURATION` after the start; by then an ended match is no longer in `runningGames`, so it does nothing.

   Before it emits `end game`, the server creates a fresh pending game with the same settings and sends its id as `new_game_id`.
7. **Results and restart (no reload).** The first of `player win` and `end game` starts the end sequence in `Playing` once per match: a ~1 s board transition (`playEndTransition` in `src/game/endSequence.ts`: a camera Wipe filter on WebGL, a camera fade-out on Canvas), then the EventBus event `show-results`, and `EndGameModal` opens. If `end game` arrives and no `show-results` follows within 1.5 s (no running scene), the modal opens anyway. The modal shows "Winner <name>" (win; disconnect, "by forfeit"), "Draw" (draw; disconnect with no living player) or "Time's up" from `reason` and `prevGameInfo`, then the stats table. On `end game`, `Playing` emits `leave game` and tears itself down, and the modal emits `enter pending game` for `new_game_id` at once and shows the players slots and "Restart Game". "Main Menu" shows from the moment the modal opens. "Restart Game" runs the same timer/start flow as step 4 inside the modal; `launch game` (or the end of the countdown) navigates to `/game/<new id>`. The `Game` route does not remount: `PhaserGame` destroys the old `Phaser.Game` and creates a new one for the new id, and the modal and the HUD hooks reset their state on the `gameId` change.
