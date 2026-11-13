---
name: update-assets
description: Use when adding or replacing a Bomberman sprite, tileset, spritesheet, avatar or other image/audio asset ("new sprite", "new tileset", "new avatar", "replace spritesheet").
---

# Update assets

Folders, `Preload` keys, sizes and the avatar pipeline: [docs/assets.md](../../../docs/assets.md). The steps are in [Changing assets](../../../docs/assets.md#changing-assets).

## Procedure

1. Put the file in the folder that `docs/assets.md` names. Use 35 x 35 px frames for anything on the grid.
2. If the frame count changed, update the animation `start` and `end` in `Bomberman-2.0/src/game/entities/`.
3. Add or change the key in `Preload`. Keys have no shared list: grep the client for the old key before a rename.
4. For a new avatar, check the random range in `setPlayerAvatar`. Test textures with `textures.exists`.
5. For a new map tileset, use `map-change`. The tileset key stays `tiles`, first in the map (`docs/maps.md` › Invariants).
6. Run `sync-docs`.

## Verify

- Frontend checks pass (`.claude/rules/development-workflow.md` › After you finish).
- No `textures.get` is used to test a texture. No old key remains in the client.
- Run `play-local`. The asset renders at the right size, animates, and shows no black square.
