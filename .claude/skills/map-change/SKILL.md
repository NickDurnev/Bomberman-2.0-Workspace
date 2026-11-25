---
name: map-change
description: Use when editing a Bomberman map or tile, adding a new map, changing spawns, walls, boxes or portal cells ("edit map", "change tile", "new map", "move spawn").
---

# Change a map

Format, invariants and the add-a-map steps: [docs/maps.md](../../../docs/maps.md) (see [Invariants](../../../docs/maps.md#invariants) and [Adding a map](../../../docs/maps.md#adding-a-map)). Portal rules: [docs/mechanics.md](../../../docs/mechanics.md).

## Procedure

1. Read the Invariants section. Edit the Tiled JSON.
2. Apply the same edit to both copies: `Bomberman-2.0-Backend/src/maps/` and `Bomberman-2.0/public/assets/maps/`. The copies must match by content (parsed JSON), not byte for byte: their formatting differs. If they already differ in content, report it; do not "fix" it unless the task asks. Never give an existing map id a new layout: add a new id and change only menu titles (`docs/known-traps.md` › A map id reused for a new layout).
3. For a new map, follow Adding a map in `docs/maps.md` (portal cells, `MAP_NAMES` on the server, `Preload`, `MAPS` in `Bomberman-2.0/src/utils/constants.ts`, `SelectMap.tsx` at the same index). There is no preview image: the map screen draws it from the JSON.
4. Compare the copies by content: `python3 -c 'import json,sys; a,b=(json.load(open(p)) for p in sys.argv[1:]); sys.exit(a!=b)' Bomberman-2.0-Backend/src/maps/<map>.json Bomberman-2.0/public/assets/maps/<map>.json` (exit 0 = equal), or `python3 scripts/build-map.py <map> --players <n> --check` for a map built from `scripts/maps/`. For a drift you did not make, report it.
5. Run the backend `npm run build`. `dist/maps/` must contain the file.
6. Run `sync-docs`.

## Verify

- Backend and frontend checks pass in each repo you touched (`.claude/rules/development-workflow.md` › After you finish).
- Backend test added or updated (`docs/testing.md`), `npm test` passes.
- E2E impact checked (`development-workflow` › Keep E2E in sync after behaviour changes); companion E2E PR opened if a spec is affected.
- The diff in step 4 shows no new difference.
- Walls enclose the playable area. `spawns` has at least `max_players` entries.
- Run `play-local` with two different accounts on the map. Check spawns, boxes, and portal cells.
