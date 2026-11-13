---
name: map-change
description: Use when editing a Bomberman map or tile, adding a new map, changing spawns, walls, boxes or portal cells ("edit map", "change tile", "new map", "move spawn").
---

# Change a map

Format, invariants and the add-a-map steps: [docs/maps.md](../../../docs/maps.md) (see [Invariants](../../../docs/maps.md#invariants) and [Adding a map](../../../docs/maps.md#adding-a-map)). Portal rules: [docs/mechanics.md](../../../docs/mechanics.md).

## Procedure

1. Read the Invariants section. Edit the Tiled JSON.
2. Apply the same edit to both copies: `Bomberman-2.0-Backend/src/maps/` and `Bomberman-2.0/public/assets/maps/`. The copies must match. One tile of `default_map.json` already differs (backend issue #46); do not copy that drift, and do not "fix" it unless the task asks. `small_map.json` matches by content.
3. For a new map, follow Adding a map in `docs/maps.md` (portal cells, `Preload`, `AVAILABLE_MAPS`, `SelectMap.tsx` at the same index, preview image).
4. Compare the copies: `diff Bomberman-2.0-Backend/src/maps/<map>.json Bomberman-2.0/public/assets/maps/<map>.json`. For a drift you did not make, report it.
5. Run the backend `npm run build`. `dist/maps/` must contain the file.
6. Run `sync-docs`.

## Verify

- Backend and frontend checks pass in each repo you touched (`.claude/rules/development-workflow.md` › After you finish).
- The diff in step 4 shows no new difference.
- Walls enclose the playable area. `spawns` has at least `max_players` entries.
- Run `play-local` with two different accounts on the map. Check spawns, boxes, and portal cells.
