# Maps

How a map is stored, how each side loads it, and what must stay true when you edit or add one. Map semantics in play (blast, portals, spawns) are in [mechanics.md](mechanics.md).

## Files

Each map is a Tiled JSON file. There are two copies of every map, one per repo, and both are read at run time:

| Map | Server copy | Client copy |
| --- | --- | --- |
| `default_map` | `Bomberman-2.0-Backend/src/maps/default_map.json` | `Bomberman-2.0/public/assets/maps/default_map.json` |
| `small_map` | `Bomberman-2.0-Backend/src/maps/small_map.json` | `Bomberman-2.0/public/assets/maps/small_map.json` |
| tileset image | `Bomberman-2.0-Backend/src/maps/tileset.png` (not read by server code) | `Bomberman-2.0/public/assets/maps/tileset.png` |

The server builds its collision grid from its copy; the client draws from its copy. Nothing checks that they agree. The two `tileset.png` files are not byte-identical; only the client one is drawn.

## Format

Both maps use the same structure:

- Orthogonal map, 32 × 21 cells, `tilewidth` / `tileheight` 35.
- One tileset named `tiles`, `firstgid` 1, image `tileset.png` (210 × 35 px = six 35 px tiles, ids 1–6).
- One tile layer named `Blocks` (`layers[0]`), `data` is a flat array of 672 tile ids in row-major order.

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
| `max_players` | server `Game` (lobby full check); client `SelectMap.tsx` (the "Players" text on the map card) | 14 on `default_map`, 8 on `small_map` |
| `spawns` | server `Game` | list of `{ col, row }`, one per player slot |
| `wall`, `box` | server `Game.createMapData` | tile ids for wall (1) and box (5); every other id becomes empty |
| `empty` | nothing | 6 |
| `collisionTiles` | nothing | `[1, 5]`; the client hard-codes its own collision list |

**Spawn offset.** The server sets the spawn pixel position to `(col × 35, row × 35)`, and the client puts the sprite centre half a tile up and left of that. The player therefore appears in cell `(row − 1, col − 1)`. In both maps every `spawns` entry minus one is an empty cell, and many raw entries are walls or boxes. Keep this offset when you add spawns. Portal cells (`*_PORTAL_SPAWNS` in `Bomberman-2.0-Backend/src/constants.ts`) do **not** have this offset: they are the real `(row, col)` of the cell.

## Server: load and use

1. `create game` carries `mapName`. `Game`'s constructor (`Bomberman-2.0-Backend/src/entity/game.ts`) runs ``require(`../maps/${mapName}.json`)`` and keeps `layers[0]` as `layer_info`. A new map name must also be added to the names the client offers (see [Adding a map](#adding-a-map)).
2. `require` caches the JSON, so every `Game` of one map shares the same `layer_info` object. Copy before you mutate anything from it (the constructor already copies `spawns` into `playerSpawns`).
3. `createMapData` turns `data` into `shadow_map[row][col]` using the `wall` and `box` properties. Blasts read and change only `shadow_map`.
4. `Bomb` chooses the portal cell list by name: `small_map` → `SMALL_MAP_PORTAL_SPAWNS`, any other name → `DEFAULT_MAP_PORTAL_SPAWNS`.

**Build step.** `tsc` does not copy JSON. The backend `postbuild` script (`copyfiles -u 1 src/maps/* dist`, run after `npm run build`) copies the maps to `dist/maps/`, where the compiled `dist/entity/game.js` finds them. `make backend` runs this build on every change in `src/`, so local runs also read the maps from `dist/maps/`. Only a plain `npm run dev` (`ts-node`) reads them from `src/maps/`. A new map file in `src/maps/` reaches production only through this step.

## Client: get and draw

The client does not draw from server data. `Game.layer_info` and `shadow_map` arrive in the `get current game` payload, but the client ignores them for drawing.

1. `Preload` (`Bomberman-2.0/src/game/scenes/Preload.ts`) loads every map up front: the tileset image as key `tiles` and each JSON with `tilemapTiledJSON` under its map name.
2. `Playing.createMap` makes the tilemap with key `currentGame.mapName` (fallback `default_map`), adds the tileset image `TILESET` = `tiles` and creates the layer `LAYER` = `Blocks` (`Bomberman-2.0/src/utils/constants.ts`).
3. On `detonate bomb` the client puts tile 6 on every cell with `destroyed: true` (hard-coded id in `Playing.onDetonateBomb`).

## Invariants

- The two copies of a map must be equal in `data`, size and layer properties.
- The layer must be named `Blocks`, the tileset `tiles`, and the tileset must be the first one (`firstgid` 1), so ids 1, 5, 6 keep their meaning.
- Size must stay 32 × 21 with 35 px tiles unless you also change the Phaser canvas (1120 × 735 in `Bomberman-2.0/src/game/main.ts`).
- The playable area must be enclosed by walls. A blast reads `shadow_map[row][col]` without bounds checks; a row outside the grid throws inside the server's bomb-queue timer.
- `spawns` must have at least `max_players` entries. `addPlayer` takes a random free spawn and does not check that one exists.
- Portal cells must be inside the playable area. They are boxes today, so a portal appears when the box breaks.

## Adding a map

1. Create the Tiled JSON with the format above. Put the same file in `Bomberman-2.0-Backend/src/maps/` and `Bomberman-2.0/public/assets/maps/`.
2. Server: if the map needs its own portal cells, add a list in `Bomberman-2.0-Backend/src/constants.ts` and select it in `Bomberman-2.0-Backend/src/entity/bomb.ts` (today the choice is `small_map` or default).
3. Client: load the JSON in `Preload` under the map name; add the name to `AVAILABLE_MAPS` in `Bomberman-2.0/src/utils/constants.ts` and a card to the `data` array in `SelectMap.tsx` at the **same index** (the card index selects the name); add a preview image in `Bomberman-2.0/public/assets/images/menu/`.
4. Run the backend build once to confirm `dist/maps/` gets the file.
5. Update this file and [assets.md](assets.md).
