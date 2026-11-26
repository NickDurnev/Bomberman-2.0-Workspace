# Maps

How a map is stored, how each side loads it, and what must stay true when you edit or add one. Map semantics in play (blast, portals, spawns) are in [mechanics.md](mechanics.md).

## Files

Each map is a Tiled JSON file. There are two copies of every map, one per repo, and both are read at run time:

| Map | Server copy | Client copy |
| --- | --- | --- |
| `default_map` | `Bomberman-2.0-Backend/src/maps/default_map.json` | `Bomberman-2.0/public/assets/maps/default_map.json` |
| `arena_map` | `Bomberman-2.0-Backend/src/maps/arena_map.json` | `Bomberman-2.0/public/assets/maps/arena_map.json` |
| `small_map` | `Bomberman-2.0-Backend/src/maps/small_map.json` | `Bomberman-2.0/public/assets/maps/small_map.json` |
| `big_map` | `Bomberman-2.0-Backend/src/maps/big_map.json` | `Bomberman-2.0/public/assets/maps/big_map.json` |
| tileset image | `Bomberman-2.0-Backend/src/maps/tileset.png` (not read by server code) | `Bomberman-2.0/public/assets/packs/<id>/tileset.png`, one per texture pack ([assets.md › Texture packs](assets.md#texture-packs)) |

The server builds its collision grid from its copy; the client draws from its copy. For a map built with `scripts/build-map.py`, `--check` compares both copies, and the portal list in `constants.ts`, with the drawn grid; nothing checks `default_map` and `small_map`. `arena_map` and `big_map` are built from `scripts/maps/<name>.txt`. The server `tileset.png` is not byte-identical to any pack tileset; only the client draws a tileset: the room's texture pack in a match, and a pack chosen per view on the map screen ([assets.md › Texture packs](assets.md#texture-packs)).

## Format

All maps use the same structure:

- Orthogonal map, `tilewidth` / `tileheight` 35. `arena_map` is 28 × 18 cells, `default_map` and `small_map` are 32 × 21, `big_map` is 40 × 24.
- One tileset named `tiles`, `firstgid` 1, image `tileset.png` (210 × 35 px = six 35 px tiles, ids 1–6). The client does not read the image name: it draws the texture `tiles`, which is the `tileset.png` of the room's texture pack.
- One tile layer named `Blocks` (`layers[0]`), `data` is a flat array of `width × height` tile ids in row-major order.

Tile ids used in `data`:

| Id | Meaning | Server `shadow_map` | Client |
| --- | --- | --- | --- |
| 1 | wall | `NON_DESTRUCTIBLE_CELL` 1, stops a blast | solid |
| 5 | box | `DESTRUCTIBLE_CELL` 5, destroyed by a blast | solid, replaced by tile 6 when destroyed |
| 6 | empty | `EMPTY_CELL` 6 | passable |

Ids 2–4 are in the tileset but not used by the maps. The client makes ids 1–5 solid.

### Layer properties

Custom properties on the `Blocks` layer:

| Property | Read by | Use |
| --- | --- | --- |
| `max_players` | server `Game` (lobby full check); client `SelectMap.tsx`, through `MAPS` (the "Players" text in the map modal) | 12 on `arena_map`, 14 on `default_map`, 8 on `small_map`, 20 on `big_map` |
| `spawns` | server `Game` | list of `{ col, row }`, one per player slot |
| `wall`, `box` | server `Game.createMapData` | tile ids for wall (1) and box (5); every other id becomes empty |
| `empty` | nothing | 6 |
| `collisionTiles` | nothing | `[1, 5]`; the client hard-codes its own collision list |

**Spawn offset.** The server sets the spawn pixel position to `(col × 35, row × 35)`, and the client puts the sprite centre half a tile up and left of that. The player therefore appears in cell `(row − 1, col − 1)`. In both maps every `spawns` entry minus one is an empty cell, and many raw entries are walls or boxes. Keep this offset when you add spawns. Portal cells (`*_PORTAL_SPAWNS` in `Bomberman-2.0-Backend/src/constants.ts`) do **not** have this offset: they are the real `(row, col)` of the cell.

## Server: load and use

1. `create game` carries `mapName`. `Game`'s constructor (`Bomberman-2.0-Backend/src/entity/game.ts`) runs ``require(`../maps/${mapName}.json`)`` and keeps `layers[0]` as `layer_info`. A new map name must also be added to the names the client offers (see [Adding a map](#adding-a-map)).
2. `require` caches the JSON, so every `Game` of one map shares the same `layer_info` object. Copy before you mutate anything from it (the constructor already copies `spawns` into `playerSpawns`).
3. `createMapData` turns `data` into `shadow_map[row][col]` using the `wall` and `box` properties. Blasts read and change only `shadow_map`.
4. `Bomb` gets the portal cells from `portalSpawnsFor(mapName)` (`Bomberman-2.0-Backend/src/constants.ts`): a lookup by map name (`DEFAULT_MAP_PORTAL_SPAWNS`, `ARENA_MAP_PORTAL_SPAWNS`, `SMALL_MAP_PORTAL_SPAWNS`, `BIG_MAP_PORTAL_SPAWNS`). An unknown name gets `DEFAULT_MAP_PORTAL_SPAWNS`.

**Build step.** `tsc` does not copy JSON. The backend `postbuild` script (`copyfiles -u 1 src/maps/* dist`, run after `npm run build`) copies the maps to `dist/maps/`, where the compiled `dist/entity/game.js` finds them. `make backend` runs this build on every change in `src/`, so local runs also read the maps from `dist/maps/`. A new map file in `src/maps/` reaches production only through this step.

## Client: get and draw

The client does not draw from server data. `Game.layer_info` and `shadow_map` arrive in the `get current game` payload, but the client ignores them for drawing.

1. `Preload` (`Bomberman-2.0/src/game/scenes/Preload.ts`) loads every map in `AVAILABLE_MAPS` up front: the `tileset.png` of the room's texture pack as key `tiles` (falling back to the `default` pack's file) and each JSON with `tilemapTiledJSON` under its map name.
2. `Playing.createMap` makes the tilemap with key `currentGame.mapName` (fallback `default_map`), adds the tileset image `TILESET` = `tiles` and creates the layer `LAYER` = `Blocks` (`Bomberman-2.0/src/utils/constants.ts`).
3. On `detonate bomb` the client puts tile 6 on every cell with `destroyed: true` (hard-coded id in `Playing.onDetonateBomb`).

The map screen (`/map`) draws the maps without Phaser. `MAPS` in `Bomberman-2.0/src/utils/constants.ts` imports the client copies, and `AVAILABLE_MAPS` is `Object.keys(MAPS)`, in that order. `MapPreview` draws the `Blocks` layer of a map from `MAPS` with a pack's `tileset.png` on a canvas ([assets.md › Map preview](assets.md#map-preview)), so a map edit shows on the map screen at once.

## Invariants

- The two copies of a map must be equal in `data`, size and layer properties.
- The layer must be named `Blocks`, the tileset `tiles`, and the tileset must be the first one (`firstgid` 1), so ids 1, 5, 6 keep their meaning.
- Every texture pack's `tileset.png` keeps the same layout: 210 × 35 px, id 1 wall, 5 box, 6 floor (`Bomberman-2.0/public/assets/packs/<id>/tileset.png`).
- A map id names one layout for good. Both repos deploy separately (backend first), so a client one deploy behind still sends the old id and draws its own copy. Give a new layout a new id; change only the menu title of an old one. The menu titles are in `MAP_TITLES` (`Bomberman-2.0/src/utils/constants.ts`), which the map screen, the lobby list and the pending screen read: `arena_map` is "Default map", `default_map` is "Classic map" ([known-traps.md](known-traps.md#a-map-id-reused-for-a-new-layout)).
- Tiles stay 35 px. The map size is free: the Phaser game uses `Scale.RESIZE` (`Bomberman-2.0/src/game/main.ts`), `Game.tsx` caps the game view at 1120 × 735 px (32 × 21 tiles) on every device, and `Playing` sets the camera bounds to the map and follows the local player. A bigger map scrolls; a smaller map is centred in the view (`Playing.fitCameraToMap` grows the camera bounds to the view, on create and on every resize); every player sees a view of the same maximum size.
- The playable area must be enclosed by walls. A blast reads `shadow_map[row][col]` without bounds checks; a row outside the grid throws inside the server's bomb-queue timer.
- `spawns` must have at least `max_players` entries. `addPlayer` takes a random free spawn and does not check that one exists.
- Portal cells must be inside the playable area. They are boxes today, so a portal appears when the box breaks.

## Adding a map

1. Draw the map as a text grid in `scripts/maps/<name>.txt` in the workspace root: `#` wall, `o` box, `.` empty, `S` spawn cell, `P` portal cell (a box). Spawns are drawn where the player stands; the script adds the +1 spawn offset.
2. Run `python3 scripts/build-map.py <name> --players <max_players>`. The script checks the grid (walls round the border, every non-wall cell connected, at least `max_players` spawns, an escape cell next to each spawn, spawns at least 5 tiles apart), writes the server and client JSON copies and prints the portal cells. `--check` compares the two committed copies with the grid. Tests: `python3 -m unittest scripts/test_build_map.py`.
3. Server: add the printed portal cells as a list in `Bomberman-2.0-Backend/src/constants.ts`, add it to `PORTAL_SPAWNS_BY_MAP` and add the name to `MAP_NAMES` (the server loads only the maps listed there; any other name becomes `default_map`).
4. Client: import the JSON in `Bomberman-2.0/src/utils/constants.ts` and add it to `MAPS` under the map name (`AVAILABLE_MAPS` follows, and `Preload` loads every name in it); add its menu title to `MAP_TITLES` in the same file (without an entry the lobby shows the raw id); add a card to the `data` array in `SelectMap.tsx` at the **same index** (the card index selects the name from `AVAILABLE_MAPS`), with `title: MAP_TITLES.<name>`. There is no preview image to add: `MapPreview` draws the map from its JSON, on the map screen, in the lobby and on the pending screen.
5. Run the backend build once to confirm `dist/maps/` gets the file.
6. Update this file and [assets.md](assets.md).
