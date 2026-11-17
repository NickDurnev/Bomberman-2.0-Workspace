# Mechanics

The game rules as the code implements them on `dev`: what a bomb does, how long things take, what spoils change, and how a match is won. Values come from `Bomberman-2.0-Backend/src/constants.ts` (server) and `Bomberman-2.0/src/utils/constants.ts` (client). Which side owns each value is in [entities.md](entities.md); the events named here are in [socket-contract.md](socket-contract.md); the match lifecycle is in [architecture.md](architecture.md#lifecycle-of-a-match).

## Grid

- One cell is `TILE_SIZE` = 35 px on both sides. `default_map` and `small_map` are 32 × 21 cells, `big_map` is 40 × 24. The game view is capped at 1120 × 735 px (32 × 21 cells) by `Bomberman-2.0/src/routes/game/Game.tsx`; on a bigger map the camera follows the local player (see [maps.md](maps.md#invariants)).
- Cell of a sprite: `col = floor(x / 35)`, `row = floor(y / 35)` (`currentCol` / `currentRow` in `Bomberman-2.0/src/game/entities/player.ts`). Shared entities sit at the cell centre: `col * 35 + 17.5`.
- The server keeps a `shadow_map` per game: wall (1), box (5), empty (6). Bombs, spoils and players are not in it. See [maps.md](maps.md).

## Movement

Client only. The server relays positions and does not check them.

| Value | Constant | Amount |
| --- | --- | --- |
| Start speed (Arcade velocity, px/s) | `INITIAL_SPEED` | 150 |
| Per `SPEED` spoil | `STEP_SPEED` | +25 |
| Max speed | `MAX_SPEED` | 400 (10 pick-ups) |
| Position report interval | `PING` | 100 ms, only when the position changed |

Arrow keys move; diagonal movement is allowed (both axes can be set in the same frame). Walls and boxes collide on the client: tile ids 1–5 are solid (`this.map.setCollision([1, 2, 3, 4, 5])` in `Playing.createMap`). Other players' sprites tween to each `move player` position over `PING` ms.

## Bombs and fuse

1. **Place.** Space emits `create bomb` with the player's current cell. The client allows it only when `activeBombs < bombs`, no bomb sprite is already on that cell, and the press cooldown has passed. Cooldown = `100 + ((MAX_SPEED − speed) / STEP_SPEED) × 10` ms: 200 ms at start speed, 100 ms at max speed. The server checks none of this.
2. **Create.** The server copies the owner's current `power` and `delay` into the `Bomb`, stores it in `Game.bombs`, queues it with `detonationTime = now + delay`, and broadcasts `show bomb`.
3. **Fuse.** The queue is per game, not per connection, so a bomb still explodes after its owner leaves or disconnects. It is checked every 100 ms, so a bomb detonates up to 100 ms after its `delay`. Fuse `delay` starts at `INITIAL_DELAY` 2000 ms; each `DELAY` spoil subtracts `STEP_DELAY` 200 ms while the value is above `MIN_DELAY` 200 ms (minimum reached after 9 pick-ups). A bomb keeps the delay it had when placed.
4. **Visual fuse.** The client bomb sprite scales to 1.2× over the server fuse `delay` (ms) from `show bomb`. If the payload has no `delay`, it uses `EXPLOSION_TIME` (2000 ms). The 14-frame animation loops at 6 fps. If the `fuseWarning` player setting is on, the bomb flashes (white/red FILL tint pulse) in the last 500 ms of the fuse. On the Canvas renderer, the bomb blinks its alpha (0.4 and 1) instead. If `delay` is 500 ms or less, the flash starts at once. The sprite is removed only on `detonate bomb`.
5. **Detonate.** The server computes the blast (below), deletes the bomb from `Game.bombs` and broadcasts `detonate bomb`. The owner's client decrements `activeBombs`.

A bomb is a solid, immovable body for the local player on the client. The server keeps no bomb cells in `shadow_map`.

## Blast

`Bomb.detonate()` in `Bomberman-2.0-Backend/src/entity/bomb.ts`:

- The bomb cell (`explosion_center`) is always blasted.
- In each of the four directions the blast walks up to `power` cells. `power` starts at `INITIAL_POWER` 1 and each `POWER` spoil adds `STEP_POWER` 1, with no cap.
- An **empty** cell is blasted and the walk continues (sprite `explosion_vertical` / `explosion_horizontal`). Bombs and players do not stop a blast.
- A **box** cell is blasted, becomes empty (`destroyed: true`) and stops the walk (sprite `explosion_up` / `_right` / `_down` / `_left`).
- A **wall** cell is also put in `blastedCells` (end sprite drawn over the wall, `destroyed: false`) and stops the walk.
- The end sprites are used only where a box or wall stops the blast. A blast that reaches its full range in open space ends with a straight piece.

On the client each blasted cell becomes a `FireBlast` sprite (body 27 × 27 px, 5 frames at 20 fps, so about 250 ms), and destroyed boxes become tile 6 in the tilemap.

### Chain reaction (intended)

A blast that touches another bomb detonates it. The client detects the overlap of a `FireBlast` and a `Bomb` sprite and emits `detonate bomb by blast` (every frame while they overlap, from every client in the game); the server detonates the bomb once, because the first call deletes it from `Game.bombs`. The chained bomb's queue entry later finds nothing. This is a game mechanic. Do not "fix" it with a grace period or by ignoring early detonations. A chain makes a bomb explode before its fuse ends, which players can read as "bombs got faster"; the real past bug of that name was listener ghosting (see [known-traps.md](known-traps.md#event-ghosting-from-a-listener-leak)).

## Death and tombstones

- The client checks the local player against every `FireBlast` each frame. When the intersection is at least 10 % of the player's body area, it emits `player died` with its current cell and the blast owner as `killerId`, and hides itself (`becomesDead`).
- Overlaps run only while the local player is `active`. A dead player and a player in the 500 ms portal transit (below) cannot be hit.
- Your own blast kills you. The server records the death but gives no kill for it (`Player.kill` ignores its own id).
- The server marks the player dead, credits the kill to `killerId`, stores a tombstone at the reported cell and broadcasts `show tombstone`. Clients draw a `Tombstone` sprite and remove that enemy sprite. Dead players stay in `Game.players`.
- On the client of the dead player only, the view dips to black for ~300 ms (camera fade) and then stays grey (camera ColorMatrix grayscale, WebGL only) until the match scene stops. The board stays visible. This is `deathEffect` in `Bomberman-2.0/src/game/effects.ts`; it is always on.

## Spoils (power-ups)

Drop: for every destroyed box that is not a portal cell, the server rolls `SPOIL_CHANCE` 50 % and creates a `Spoil` with a uniform random type. The type is one of `SPEED`, `POWER`, `BOMBS`, plus `DELAY` when the game has `isDelaySpoilEnabled`.

Display: the client draws a spoil only when the cell has `destroyed: true` (a box was broken). A blast through a cell that already shows a spoil removes that sprite on every client, and the server deletes that spoil from `Game.spoils`.

Pick-up: the local player overlaps a spoil sprite → emits `pick up spoil` and destroys the sprite at once → the server deletes the spoil, applies it to its `Player` and broadcasts `spoil was picked` → each client removes the sprite, and the picker's client applies it to its local `Player`.

| Type (value) | Effect | Applied on |
| --- | --- | --- |
| `SPEED` (0) | speed +25 px/s, max 400 | client only |
| `POWER` (1) | blast range +1 cell, no cap | server (counts for the blast) and client copy |
| `BOMBS` (2) | bombs at the same time +1, no cap | client only |
| `DELAY` (3) | fuse −200 ms, min 200 ms | server (counts for the fuse) and client copy |

`Bomberman-2.0/src/routes/game/components/PlayerInfo.tsx` shows the picker's counts in the HUD. Values reset at match end.

## Portals

Only when the game has `isPortalsEnabled`.

- Portal cells are fixed per map: `DEFAULT_MAP_PORTAL_SPAWNS`, `SMALL_MAP_PORTAL_SPAWNS`, `BIG_MAP_PORTAL_SPAWNS` in `Bomberman-2.0-Backend/src/constants.ts` (four cells each, all covered by boxes). `Bomb` gets the list from `portalSpawnsFor(mapName)`; an unknown map name gets the default list.
- A blast on a portal cell creates a `Portal` there instead of a spoil. A cell gets one portal: a later blast on it adds no second one.
- Entering a portal: the client emits `use portal`, hides the player and disables its body and movement for `PORTAL_DELAY_STEP` 500 ms. The server needs at least two portals; it picks a random other portal and broadcasts `teleport player` with that cell's centre.
- Cooldown: after the player enters a portal, the client ignores portal overlaps for `PORTAL_DELAY` 3000 ms.

## Starting, ending and winning

- **Players:** a game starts with at least 2 players (`players.length > 1` in `Pending.tsx` and `EndGameModal.tsx`). The maximum is the map's `max_players`: 14 on `default_map`, 8 on `small_map`, 20 on `big_map`.
- **Start countdown:** 3 s, run on each client after `start timer`.
- **Time limit:** `GAME_DURATION` 180 s. The client shows its own countdown (`CountdownTimer.tsx`), which is not synced to the server.
- **End conditions** and their delays (5 s after a win, 2 s when nobody is left, 0 s when a leave or disconnect leaves at most one living player, 180 s time limit) are in [architecture.md › Lifecycle](architecture.md#lifecycle-of-a-match). Stats are processed only for the two death-based endings.

### Points

| Result | Constant | Points |
| --- | --- | --- |
| Kill | `POINTS_PER_KILL` | 1 per victim |
| Win (last alive) | `POINTS_PER_WIN` | 3 |
| Top 3 | `POINTS_PER_TOP3` | 1 |

Top 3: when a death leaves exactly 3 players alive, the server marks those 3 living players (`Game.markTop3`), and they get the top-3 point. In a game that starts with 3 players, nobody gets it.

## Game modes

Chosen by the host on `/map` (`Bomberman-2.0/src/routes/map/SelectMap.tsx` and its `MapForm`) and sent in `create game`:

| Option | Values | Effect |
| --- | --- | --- |
| `mapName` | `default_map`, `small_map`, `big_map` | grid, spawns, max players, portal cells |
| `isPortalsEnabled` | default off | portals can appear |
| `isDelaySpoilEnabled` | default off | `DELAY` joins the spoil pool |

After a match the server creates the next pending game with the same three options. There is no singleplayer or bot mode on `dev`.
