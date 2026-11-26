# Assets

Where the client's images, sprite sheets and fonts live, the keys `Preload` gives them, the texture packs, and how a player's avatar gets from a Google account into the game. Map files are in [maps.md](maps.md). The backend has no assets except its map copies.

## Folders

All under `Bomberman-2.0/public/`. Vite serves this folder at the site root, so a file at `Bomberman-2.0/public/assets/google.png` is loaded as `assets/google.png` (Phaser, with `load.baseURL = "/"`) or `/assets/google.png` (React).

| Folder | Content | Used by |
| --- | --- | --- |
| `Bomberman-2.0/public/assets/packs/<id>/` | one folder per texture pack: map `tileset.png`, in-game sprite sheets (bomb, blast pieces, spoils, portal, tombstone) and HUD icons. See [Texture packs](#texture-packs) | Phaser `Preload`; `PackImage`; `MapPreview` |
| `Bomberman-2.0/public/assets/images/avatars/` | `avatar-1.png` … `avatar-16.png`, 129 × 129 px | Phaser `Preload` (fallback skins) |
| `Bomberman-2.0/public/assets/maps/` | Tiled maps (JSON) | Phaser `Preload`; `MAPS` in `Bomberman-2.0/src/utils/constants.ts` imports the JSON for the map screen |
| `Bomberman-2.0/public/assets/fonts/` | Outfit font family | `Bomberman-2.0/src/index.css` |
| `Bomberman-2.0/public/assets/` (root files) | `default_avatar.png` (empty lobby slot); `google.png`, `github.svg` | React components |

The map screen has no preview images: `MapPreview` draws each map from its JSON and a pack's `tileset.png` (see [Map preview](#map-preview)).

The HUD icon file name is built from the HUD title: `${title.toLowerCase()}_icon.png` in `Bomberman-2.0/src/routes/game/components/PlayerStats.tsx`, loaded from the room's texture pack through `PackImage`. The titles are `Speed`, `Power`, `Bomb` and `Delay` (`Bomberman-2.0/src/routes/game/hooks/usePlayerInfo.ts`). Renaming a title or an icon breaks it. `explosion.png` and `bomb_logo.png` in `Bomberman-2.0/public/assets/` have no reference in `src/` or `index.html`.

## Preload keys

`Bomberman-2.0/src/game/scenes/Preload.ts` loads everything for a match. The keys in `PACK_TEXTURES` load from the folder of the room's texture pack, `packs/<id>/` (see [Texture packs](#texture-packs)). Every sprite sheet frame is 35 × 35 px (`TILE_SIZE`). Entities refer to these keys by string; a key that is not loaded renders as Phaser's missing texture.

| Key | File (under `Bomberman-2.0/public/assets/`) | Sheet size → frames | Used by |
| --- | --- | --- | --- |
| `tiles` | `packs/<id>/tileset.png` | 210 × 35 → 6 tiles | tilemap layer |
| `arena_map`, `default_map`, `small_map`, `big_map` (every name in `AVAILABLE_MAPS`) | `maps/<name>.json` (tilemap JSON) | — | `Playing.createMap` |
| `bomb_tileset` | `packs/<id>/bombs.png` | 35 × 490 → 14 | `Bomb` (anim `bomb`, frames 0–13, 6 fps, loop) |
| `explosion_center`, `explosion_horizontal`, `explosion_vertical`, `explosion_up`, `explosion_right`, `explosion_down`, `explosion_left` | `packs/<id>/<key>.png` | 175 × 35 → 5 each | `FireBlast` (key = `BlastedCell.type`; anim `blast_<key>`, frames 0–4, 20 fps, once) |
| `spoil_tileset` | `packs/<id>/spoil_tileset.png` | 35 × 140 → 4 | `Spoil` (frame 0 `BOMBS`, 1 `POWER`, 2 `SPEED`, 3 any other type, so `DELAY`) |
| `portal_tileset` | `packs/<id>/portal.png` | 140 × 140 → 16 | `Portal` (anim frames 0–14, 20 fps, loop) |
| `tombstone` | `packs/<id>/tombstone.png` | 35 × 35 → 1 | `Tombstone` |
| `particle` | none: generated in `Preload.startMatch` (4 × 4 white square) | — | `debrisBurst`, `pickupBurst` in `src/game/effects.ts` (pooled emitter per scene, tinted per kind) |
| `avatar-1` … `avatar-16` | `images/avatars/avatar-<n>.png` | single image | avatar fallback |
| `<player id>` | the player's `skin` URL (remote) | single image | the player's avatar |

The `FireBlast` texture key comes from the server: `Bomb.detonate()` builds `type` as `explosion_<direction>`. A new blast piece needs a server change and a new `Preload` key with the same name.

Animations are global. `Preload.createAnimations` creates them once per `Phaser.Game`: `bomb`, `portal`, and one `blast_<type>` per explosion sheet (`BLAST_TYPES`). The entities only call `play(key)`. A pack change on the same `Phaser.Game` removes them first (see [Texture packs](#texture-packs)).

## Texture packs

A texture pack is one set of the map tileset, the in-game sprite sheets and the HUD icons. The pack is a room option, like the map. The host picks it on `/map`: the "Texture pack" field of `MapForm` (`Bomberman-2.0/src/routes/map/components/mapForm.tsx`) starts on `default`, and `create game` sends the choice as `texturePack`. The server stores it in `Game.texturePack` ([entities.md](entities.md#game-server)), so every player of the room draws the same pack. The next pending game after a match keeps it. A missing or unknown id becomes `default` on both sides: `toTexturePack` in `Bomberman-2.0-Backend/src/constants.ts` on the server, `getTexturePack` on the client.

| Id | Name | Folder | Art |
| --- | --- | --- | --- |
| `default` | Default | `Bomberman-2.0/public/assets/packs/default/` | the current art; the fallback for every other pack |
| `classic` | Classic | `Bomberman-2.0/public/assets/packs/classic/` | the original art of the game |

The client registry is `TEXTURE_PACKS` in `Bomberman-2.0/src/utils/texturePacks.ts`. An entry is `{ id, name, basePath }`; `basePath` has no leading or trailing slash. `getTexturePack(id)` returns the `default` pack (`DEFAULT_TEXTURE_PACK_ID`) for an unknown or missing id. Phaser loads `<basePath>/<file>` against `load.baseURL = "/"`; React gets `/<basePath>/<file>` from `packAssetUrl(pack, file)`. The server knows only the ids: `TEXTURE_PACKS` and `DEFAULT_TEXTURE_PACK` in `Bomberman-2.0-Backend/src/constants.ts`. Keep the ids equal on both sides ([entities.md › Shared constants](entities.md#shared-constants)).

Every pack uses the same file names, flat in its folder:

| File | Size → frames | Key or use |
| --- | --- | --- |
| `tileset.png` | 210 × 35 → 6 tiles; id 1 wall, 5 box, 6 floor | `tiles`; `MapPreview`; the pack cards |
| `bombs.png` | 35 × 490 → 14 | `bomb_tileset`; frame 0 on the touch `BombButton` (52 × 52 px) and on the pack cards |
| `explosion_center.png`, `explosion_horizontal.png`, `explosion_vertical.png`, `explosion_up.png`, `explosion_right.png`, `explosion_down.png`, `explosion_left.png` | 175 × 35 → 5 each | the key of the same name |
| `spoil_tileset.png` | 35 × 140 → 4: `BOMBS`, `POWER`, `SPEED`, `DELAY` | `spoil_tileset` |
| `portal.png` | 140 × 140 → 16 | `portal_tileset` |
| `tombstone.png` | 35 × 35 → 1 | `tombstone` |
| `speed_icon.png`, `power_icon.png`, `bomb_icon.png`, `delay_icon.png` | any size; drawn at 25 × 23 px (20 × 18 px in the compact layout) with `object-contain` | HUD, `PlayerStats.tsx` |

`default` has the `classic` art in `portal.png`, `delay_icon.png` and frame 3 (`DELAY`) of `spoil_tileset.png`.

**Where each part reads the pack.**

| Part | Pack | Code |
| --- | --- | --- |
| The match (Phaser) | the room's pack: `texturePack` of the `get current game` ack | `Preload.preload`: `getTexturePack(this.currentGame.texturePack)` |
| The HUD: `PlayerStats` icons, the touch `BombButton` | the active pack (below) | `PackImage` without `packId` |
| The pack cards on `/map` | the pack of each card | `PackImage` with `packId` |
| The map modal on `/map` | the pack selected in the form | `MapPreview` with `packId` |
| The map cards of the `/map` carousel | `default` | `MapPreview` without `packId` |

**Active pack.** The HUD is React, outside Phaser, so `texturePacks.ts` keeps the pack of the current match in a small store. The pending screen (`Bomberman-2.0/src/routes/pending/Pending.tsx`) calls `setActiveTexturePack` with the room's `texturePack` on every `update game`, so the HUD draws the room's pack from its first frame. `PhaserGame` (`Bomberman-2.0/src/game/PhaserGame.tsx`) calls it again with `gameData.texturePack` in the `get current game` ack, before it creates the `Phaser.Game` (a page opened straight on `/game/:id` gets the pack only there). An unknown id sets `default`. `useActiveTexturePack()` (`useSyncExternalStore`) returns the active pack and re-renders on a change. The store starts on `default`. Nothing resets it after a match; the next match sets it again.

**Picker.** `TexturePackPicker` (`Bomberman-2.0/src/components/TexturePackPicker.tsx`, props `{ value, onChange }`) is a radiogroup labelled "Texture pack" with one card per entry of `TEXTURE_PACKS`. Each card is a `<label>` around a visually hidden native radio, so the keyboard and screen readers treat the cards as a radio group. A card previews tiles 1, 5 and 6 of the pack's `tileset.png` and frame 0 of its `bombs.png`, each at 28 × 28 px, above the pack name. The selected card has the `primary` border, a tinted background and a ring; the others have a muted border.

**Fallback.** A file that a pack lacks, or that does not decode, falls back to the `default` file of the same name. So `default` must keep every file of the table.

- Phaser: `Preload.create` lists the `PACK_TEXTURES` keys that `textures.exists` does not find. For a pack other than `default`, it logs the warning `Texture pack "<id>" lacks <keys>: using default`, loads those keys from `default` in a second loader pass, and starts the match (`startMatch`) when that pass completes. A file served as HTML (an SPA fallback for a missing file) emits no `loaderror` and adds no texture, so this check catches it too. A key still missing in `startMatch` logs the error `Texture missing from the default pack: <key>` and renders as Phaser's missing texture.
- React: `PackImage` (`Bomberman-2.0/src/components/PackImage.tsx`) takes a `file` and an optional `packId` (default: the active pack). On the first `onError` it switches to the `default` URL. When the default file fails too it stops, so there is no error loop. `MapPreview` follows the same rule for `tileset.png`.

**Stale-cache guard.** Textures and animations belong to the `Phaser.Game`, and the loader skips a key that already has a texture. So every `Preload` run first removes the `PACK_TEXTURES` textures that exist and the animations in `PACK_ANIMATIONS` (`bomb`, `portal`, every `blast_<type>`) (`Preload.clearPackTextures`), then loads the room's pack. Every match creates a new `Phaser.Game` (`Bomberman-2.0/src/game/PhaserGame.tsx`), so today this is only a guard.

**Texture sources.** `startMatch` stores in the game registry, under `TEXTURE_SOURCES_KEY` (`textureSources`), the pack id each `PACK_TEXTURES` key came from: the room's pack, `default` for a fallback key, `null` for a missing texture. The E2E hook reads it (`textures()`, [e2e-hook.md](e2e-hook.md)).

**Old asset paths.** Before texture packs, the client loaded `assets/maps/tileset.png`, `assets/images/game/<file>` and `/assets/<stat>_icon.png`. `Bomberman-2.0/vercel.json` rewrites those paths to the same file in `packs/classic/`, so a tab still running the old bundle after a deploy keeps its textures until it reloads. The rewrites come before the `/(.*)` → `/index.html` rule.

### Map preview

`MapPreview` (`Bomberman-2.0/src/components/MapPreview.tsx`, props `{ mapName, title, packId?, className? }`; `title` is the menu title of the card, because the id is not the name a player sees) draws a map on a `<canvas>`:

- The cells are the `Blocks` layer (`LAYER`) of the map JSON in `MAPS` (`Bomberman-2.0/src/utils/constants.ts`), the same client copy that Phaser loads.
- The tiles come from `tileset.png` of the pack `packId` (default: `default`). A `tileset.png` that fails to load falls back once to the `default` file.
- The canvas is `width × 35` by `height × 35` px. Each cell with an id above 0 gets the 35 × 35 px tile at source x = (id − 1) × 35. Smoothing is off (`imageSmoothingEnabled = false`, CSS `image-rendering: pixelated`).
- It redraws when the map or the pack changes. A tileset load that ends after a change does not draw.
- It has `role="img"` and the label `<map title> preview, <pack name> pack`, for example `Small map preview, Classic pack`.

The carousel cards (`Card` in `Bomberman-2.0/src/components/ui/apple-cards-carousel.tsx`) draw it with the `default` pack. The map modal draws it above the pack cards with the pack selected in the form, so it redraws as soon as the host picks another pack. A change to a map JSON or to a `tileset.png` shows on the map screen with no other step.

### Adding a pack

1. Create `Bomberman-2.0/public/assets/packs/<id>/` with the files above. A file you leave out falls back to `default`. A sheet is one file, so a sheet that lacks some frames must carry the `default` frames itself.
2. Keep the sizes and the frame order of the table: 35 × 35 px frames, 14 bomb frames, 5 frames in each blast sheet, 16 portal frames, the spoil order `BOMBS`, `POWER`, `SPEED`, `DELAY`, and tile ids 1, 5, 6. The animations (`Preload.createAnimations`) and the frames the entities pick are the same for every pack.
3. Add `{ id, name, basePath: "assets/packs/<id>" }` to `TEXTURE_PACKS` in `Bomberman-2.0/src/utils/texturePacks.ts`. The picker on `/map` lists it.
4. Add the id to `TEXTURE_PACKS` in `Bomberman-2.0-Backend/src/constants.ts`. The server stores `default` for an id that it does not list.
5. Host a room with the pack on `/map` and play a match (`play-local`). The console warning lists the keys that fall back to `default`.

## Avatar and skin pipeline

```
Google login ──▶ localStorage google_user.picture (Google URL)
      │                  │
      │                  └─▶ socket handshake auth.picture ──▶ client.userPicture ──▶ Player.skin
      │
      └─▶ POST /api/v1/auth ──▶ uploadAvatar ──▶ Cloudinary URL in User.picture (DB)
                                                   └─▶ used for Player.skin only when the handshake has no name or picture
Preload: load.image(player.id, player.skin) ──▶ setPlayerAvatar: textures.exists(id) ? skin : random avatar-1..12
```

1. **Login.** `Bomberman-2.0/src/contexts/AuthContext.tsx` reads the Google profile and stores `{ email, name, picture, locale }` in localStorage `google_user`. `picture` is `""` for an account with no photo.
2. **Account.** `Menu.tsx` posts the profile to `/api/v1/auth`. `uploadAvatar` in `Bomberman-2.0-Backend/src/controllers/auth.ts` rewrites a Google URL from `=sNN-c` to `=s460-c`, uploads it to Cloudinary (folder `users`, format `png`) and stores the returned URL in `User.picture`. It never throws: an empty picture gives `""` and a failed upload keeps the source URL, so the avatar can never block account creation. On a later login for an existing user, the server uploads the new image and then deletes the old one by the public id in `User.picture`.
3. **In-game skin.** The socket handshake sends the **Google** URL from localStorage (`Bomberman-2.0/src/utils/socket.ts`). `Game.addPlayer` uses it as `skin` and falls back to the DB user (Cloudinary URL) only when the handshake lacks name or picture. So in practice the game loads the Google URL, and the Cloudinary copy is a fallback.
4. **Load.** `Preload` loads each player's skin under the player id when `skin` is not empty. A failed load only logs `Failed to load asset`.
5. **Render.** `setPlayerAvatar` in `Bomberman-2.0/src/utils/utils.ts`:
   - uses the player id texture when `textures.exists(id)` is true, else a random `avatar-1` … `avatar-12` (13–16 are loaded but never picked);
   - draws that texture once into a round canvas texture `<key>_round` (`makeRoundTexture`: a centred square crop inside a circle clip, at most 128 × 128 px) and uses it as the sprite texture. Phaser 4 does not support `setMask` in WebGL, so there is no mask;
   - sizes the body from the round texture, turns it into a circle and sets the display size to 32 × 32 px (`TILE_SIZE − 3`).

Rules:

- Check a texture with `textures.exists(key)`. `textures.get(key)` always returns an object (the `__MISSING` texture for an unknown key), so a check on it is always true and the fallback never runs; this rendered players as black squares (see [known-traps.md](known-traps.md#black-player-sprite-from-texturesget)).
- The fallback is random on each client, so two clients can show different avatars for the same player. Choose it from the player id if every client must agree.
- React screens show the raw `skin` URL (`PlayersSlots.tsx`) or the Google `picture` (`UserBar.tsx`), not the Phaser fallback.

## Changing assets

1. Put the file in the folder above. The map tileset, the in-game sprite sheets and the HUD icons belong to a texture pack: put the file in `Bomberman-2.0/public/assets/packs/<id>/` of each pack whose art you change, under the file names of [Texture packs](#texture-packs). A new pack file also goes in `packs/default/`, because `default` is the fallback and must stay complete. Keep 35 × 35 px frames for anything on the grid.
2. If the frame count changes, update the `start` / `end` of the animation in `Preload.createAnimations` or the frame the entity picks (`Bomberman-2.0/src/game/entities/`). The same sheet in every pack must then have the new frame count.
3. Add or change the key in `Preload`. A texture that every pack provides is an entry in `PACK_TEXTURES` (`key`, `file`, `sheet`). Keys are strings with no shared list, so search the client for the old key before you rename it.
4. A new avatar file is used as a fallback only if the random range in `setPlayerAvatar` includes it.
5. A new `tileset.png` needs no step for the map screen: `MapPreview` draws it live ([Map preview](#map-preview)).
