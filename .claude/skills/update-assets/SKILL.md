---
name: update-assets
description: Use when adding or replacing a Bomberman sprite, tileset, spritesheet, avatar or other image/audio asset ("new sprite", "new tileset", "new avatar", "replace spritesheet").
---

# Update assets

Folders, `Preload` keys, sizes, texture packs and the avatar pipeline: [docs/assets.md](../../../docs/assets.md). The steps are in [Changing assets](../../../docs/assets.md#changing-assets).

## Procedure

1. Put the file in the folder that `docs/assets.md` names. Use 35 x 35 px frames for anything on the grid.
2. The map tileset, the in-game sprite sheets and the HUD icons live per texture pack in `Bomberman-2.0/public/assets/packs/<id>/`, under the same file name in every pack ([Texture packs](../../../docs/assets.md#texture-packs)). Change the file in each pack whose art you change. A new file also goes in `packs/default/`: a file missing from another pack falls back to `default`, so `default` must stay complete.
3. If the frame count changed, update `start` and `end` in `Preload.createAnimations` or the frame the entity picks in `Bomberman-2.0/src/game/entities/`. Give every pack's copy of the sheet the same frame count.
4. Add or change the key in `Preload`. A texture that every pack provides is an entry in `PACK_TEXTURES`. Keys have no shared list: grep the client for the old key before a rename.
5. For a new avatar, check the random range in `setPlayerAvatar`. Test textures with `textures.exists`.
6. A pack's `tileset.png` keeps 210 x 35 px and ids 1 wall, 5 box, 6 floor. The tileset key stays `tiles`, first in the map (`docs/maps.md` › Invariants). The map screen draws its previews live from it (`MapPreview`), so there is no preview image to update. For a map change, use `map-change`.
7. For a new texture pack, follow [Adding a pack](../../../docs/assets.md#adding-a-pack).
8. Run `sync-docs`.

## Verify

- Frontend checks pass (`.claude/rules/development-workflow.md` › After you finish).
- No `textures.get` is used to test a texture. No old key remains in the client.
- Run `play-local` with each pack you changed: the host picks it in the "Texture pack" field on `/map`. The asset renders at the right size, animates, and shows no black square. The console has no `Texture pack "<id>" lacks` warning for a file you added.
