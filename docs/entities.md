# Entities

The game objects on each side and which side owns what. Server entities are plain classes in `Bomberman-2.0-Backend/src/entity/`; they hold the authoritative state and are sent to clients as JSON. Client entities are Phaser sprites in `Bomberman-2.0/src/game/entities/`; they render that state and run local physics. The two sides share **no code**: payload types are mirrored by hand in `Bomberman-2.0/src/utils/types.ts`, and constants are duplicated (see [Shared constants](#shared-constants)).

## Server class ↔ client class

| Concept | Server (`Bomberman-2.0-Backend/src/`) | Client (`Bomberman-2.0/src/`) | Owner |
| --- | --- | --- | --- |
| Match | `Game` in `entity/game.ts` | no class: `GameData` type in `utils/types.ts`, held as `Playing.currentGame` and in React state | Server |
| Local player | `Player` in `entity/player.ts` | `Player` in `game/entities/player.ts` (keyboard, physics body, sends position and bombs) | Shared, see below |
| Other players | same `Player` | `EnemyPlayer` in `game/entities/enemy_player.ts` (tweens to positions from `move player`) | Server sends, owning client moves |
| Bomb | `Bomb` in `entity/bomb.ts` | `Bomb` in `game/entities/bomb.ts` | Server |
| Blast | no class: `BlastedCell` objects returned by `Bomb.detonate()` | `FireBlast` in `game/entities/fire_blast.ts`, one per blasted cell | Server computes, client detects hits |
| Spoil (power-up) | `Spoil` in `entity/spoil.ts` | `Spoil` in `game/entities/spoil.ts` | Server |
| Portal | `Portal` in `entity/portal.ts` | `Portal` in `game/entities/portal.ts` | Server |
| Tombstone | no class: `{ row, col }` in `Game.tombstones` | `Tombstone` in `game/entities/tombstone.ts` | Server |
| Map | `Game.shadow_map` (built from `maps/<name>.json`) | Tiled tilemap from `public/assets/maps/<name>.json`, layer `Blocks` | Server; client mirrors box removal |

Client sprites carry the server id in `id` so handlers can find them (`findById` / `findAndDestroyById` in `Bomberman-2.0/src/utils/utils.ts`). Bombs, spoils and blasts are also found by grid position (`findByCoordinates`).

## Game (server)

`Game` is one lobby slot and, after start, one match. Created by `Lobby.createPendingGame` from the `create game` payload.

- Identity and settings: `id` (uuid), `name`, `mapName`, `isPortalsEnabled`, `isDelaySpoilEnabled`, `createdAt`.
- Map: `layer_info` (the first layer of the map JSON, including `properties.max_players`, `spawns`, and the tile ids of `wall` and `box`), `max_players`, `shadow_map` (grid of `EMPTY_CELL` 6 / `DESTRUCTIBLE_CELL` 5 / `NON_DESTRUCTIBLE_CELL` 1).
- People: `players: Player[]`, `playerSpawns` (free spawn cells; a spawn is removed on join and returned on leave).
- Live objects: `bombs`, `spoils`, `portals`, `tombstones`, all `Map<id, …>`. These serialise to `{}` in socket payloads; clients learn about them only through events.

Responsibilities: add or remove players (a re-join with the same name and skin replaces the old entry), full/empty checks, map cell reads and writes for the blast, registries of bombs/spoils/portals/tombstones, and `processGameStats` at the end of a match.

## Player

Server `Player` (`entity/player.ts`):

- `id` is the handshake `socketId` (stable UUID from the browser), not the socket.io connection id. It is also the key for `PlayStats.userId` and the Phaser texture key of the skin.
- `name`, `skin` (avatar URL), `spawn` (pixels), `spawnOnGrid` (row/col).
- Match state: `isAlive`, `isTop3`, `kills: string[]` (victim ids), `power`, `delay`.
- `pickSpoil` applies only `POWER` (+1 blast range) and `DELAY` (fuse −200 ms, minimum 200 ms). `processStats` writes kills, win and top-3 points.

Client `Player` (`game/entities/player.ts`) owns movement and input:

- Keyboard: arrows move, space places a bomb. Sends `update player position` every `PING` (100 ms) when the position changed and `create bomb` with its current cell.
- Local counters: `speed`, `bombs` (max bombs at the same time), `activeBombs`, plus `power` and `delay` copies. `pickSpoil` applies all four spoil types.
- `goTo` is used for teleports; `becomesDead` hides it; `resetProperties` and `removeKeyboard` run at match end.

Ownership split: **speed** and **max bombs** exist only on the client (the server ignores `SPEED` and `BOMBS` spoils and does not limit bombs). **Power** and **fuse delay** that matter are the server values, because the server computes the blast and the detonation time; the client copies are not sent anywhere.

`EnemyPlayer` has no input. It tweens to each `move player` position and stops its animation when no move arrived for 200 ms. Both player classes call `setPlayerAvatar`, which must use `textures.exists(id)`: `textures.get(id)` always returns a truthy object (the `__MISSING` texture) and hid failed skin loads.

## Bomb and blast

- Server `Bomb`: `id`, `col`, `row`, `power` and `delay` copied from the owner at creation, and a back-reference `game`. `Play.createBomb` adds it to `Game.bombs` and to the per-connection bomb queue with `detonationTime = now + delay`. `detonate()` walks four directions up to `power` cells: a box is destroyed and stops the blast, a wall stops it, other cells continue. Each blasted cell may get a portal (when portals are enabled and the cell is a portal spawn of the map) or else a spoil (`SPOIL_CHANCE` 50 %).
- Client `Bomb`: sprite at the cell centre with an immovable body, so the local player collides with it. It knows its owner (`getPlayerId()`).
- Client `FireBlast`: one sprite per `BlastedCell`, texture `cell.type` (`explosion_center`, `explosion_up`, …), removes itself when the animation completes. It carries the bomb owner id, which becomes `killerId` when it hits the local player and `playerId` of `detonate bomb by blast` when it hits another bomb. Chain reactions by blast are intended.
- On `detonate bomb` the client also replaces destroyed boxes with tile 6 in the tilemap and adds spoils and portals from the cells.

## Spoil, portal, tombstone

- `Spoil`: `id`, `row`, `col`, `spoil_type` (`SPEED` 0, `POWER` 1, `BOMBS` 2, `DELAY` 3; `DELAY` only when `isDelaySpoilEnabled`). Client frame in `spoil_tileset`: `BOMBS` 0, `POWER` 1, `SPEED` 2, other 3. The client reports a touch with `pick up spoil`; the server removes it, applies it to the server player and broadcasts `spoil was picked`.
- `Portal`: `id`, `row`, `col`. Spawns only at the fixed cells in `SMALL_MAP_PORTAL_SPAWNS` / `DEFAULT_MAP_PORTAL_SPAWNS` (`Bomberman-2.0-Backend/src/constants.ts`) when a blast reaches them. `use portal` makes the server pick a random other portal and broadcast `teleport player`. The client enforces the cooldown (`PORTAL_DELAY`, `PORTAL_DELAY_STEP`).
- Tombstone: the server stores `{ row, col }` under a uuid `tombId` when a player dies and broadcasts `show tombstone`; the client `Tombstone` sprite (id = `tombId`, `playerId`) replaces the dead enemy sprite.

## Shared constants

These values exist in both `Bomberman-2.0-Backend/src/constants.ts` and `Bomberman-2.0/src/utils/constants.ts` and must stay equal: `TILE_SIZE` (35), spoil types (`SPEED`/`POWER`/`BOMBS`/`DELAY`), `INITIAL_POWER`, `STEP_POWER`, `INITIAL_DELAY`, `STEP_DELAY`, `MIN_DELAY`, `GAME_DURATION`, `POINTS_PER_*`, and the lobby room id (`lobbyId` in `lobby.ts`, `LOBBY_ID` on the client, defined but not used). Map files exist in both repos too (`Bomberman-2.0-Backend/src/maps/`, `Bomberman-2.0/public/assets/maps/`); `default_map.json` currently differs in one tile (see [architecture.md](architecture.md#known-discrepancies-in-the-code-dev)). The client hard-codes the empty tile id 6 in `Playing.onDetonateBomb`.

## Adding an entity

1. Create the server class in `Bomberman-2.0-Backend/src/entity/`, with a uuid `id` made on the server, and a registry on `Game` if it lives during a match.
2. Add the server event that announces it, and the client sprite in `Bomberman-2.0/src/game/entities/` (export it from `index.ts`) with `id` set from the payload.
3. Add a group in `Playing.createMap`, a handler in the `socketHandlers` table, and any collision in `Playing.update`.
4. Load its texture in `Preload`, and check existence with `textures.exists`.
5. Update [socket-contract.md](socket-contract.md) and this file, then run `./scripts/check-socket-contract.sh`.
