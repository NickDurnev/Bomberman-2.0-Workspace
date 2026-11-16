# Assets

Where the client's images, sprite sheets and fonts live, the keys `Preload` gives them, and how a player's avatar gets from a Google account into the game. Map files are in [maps.md](maps.md). The backend has no assets except its map copies.

## Folders

All under `Bomberman-2.0/public/`. Vite serves this folder at the site root, so a file at `Bomberman-2.0/public/assets/google.png` is loaded as `assets/google.png` (Phaser, with `load.baseURL = "/"`) or `/assets/google.png` (React).

| Folder | Content | Used by |
| --- | --- | --- |
| `Bomberman-2.0/public/assets/images/game/` | in-game sprite sheets (bomb, blast pieces, spoils, portal, tombstone) | Phaser `Preload` |
| `Bomberman-2.0/public/assets/images/avatars/` | `avatar-1.png` … `avatar-16.png`, 129 × 129 px | Phaser `Preload` (fallback skins) |
| `Bomberman-2.0/public/assets/maps/` | Tiled maps and `tileset.png` | Phaser `Preload`; `SelectMap.tsx` imports the JSON |
| `Bomberman-2.0/public/assets/images/menu/` | map preview images | `SelectMap.tsx` |
| `Bomberman-2.0/public/assets/fonts/` | Outfit font family | `Bomberman-2.0/src/index.css` |
| `Bomberman-2.0/public/assets/` (root files) | HUD icons `speed_icon.png`, `power_icon.png`, `bomb_icon.png`, `delay_icon.png`; `default_avatar.png` (empty lobby slot); `google.png`, `github.svg` | React components |

The HUD icon path is built from the HUD title: `/assets/${title.toLowerCase()}_icon.png` in `Bomberman-2.0/src/routes/game/components/PlayerInfo.tsx`. Renaming a title or an icon breaks it. `explosion.png` and `bomb_logo.png` in `Bomberman-2.0/public/assets/` have no reference in `src/` or `index.html`.

## Preload keys

`Bomberman-2.0/src/game/scenes/Preload.ts` loads everything for a match. Every sprite sheet frame is 35 × 35 px (`TILE_SIZE`). Entities refer to these keys by string; a key that is not loaded renders as Phaser's missing texture.

| Key | File (under `Bomberman-2.0/public/assets/`) | Sheet size → frames | Used by |
| --- | --- | --- | --- |
| `tiles` | `maps/tileset.png` | 210 × 35 → 6 tiles | tilemap layer |
| `default_map`, `small_map` | `maps/<name>.json` (tilemap JSON) | — | `Playing.createMap` |
| `bomb_tileset` | `images/game/bombs.png` | 35 × 490 → 14 | `Bomb` (anim `bomb`, frames 0–13, 6 fps, loop) |
| `explosion_center`, `explosion_horizontal`, `explosion_vertical`, `explosion_up`, `explosion_right`, `explosion_down`, `explosion_left` | `images/game/<key>.png` | 175 × 35 → 5 each | `FireBlast` (key = `BlastedCell.type`; anim `blast_<key>`, frames 0–4, 20 fps, once) |
| `spoil_tileset` | `images/game/spoil_tileset.png` | 35 × 140 → 4 | `Spoil` (frame 0 `BOMBS`, 1 `POWER`, 2 `SPEED`, 3 any other type, so `DELAY`) |
| `portal_tileset` | `images/game/portal.png` | 140 × 140 → 16 | `Portal` (anim frames 0–14, 20 fps, loop) |
| `tombstone` | `images/game/tombstone.png` | 35 × 35 → 1 | `Tombstone` |
| `particle` | none: generated in `Preload.create` (4 × 4 white square) | — | `debrisBurst`, `pickupBurst` in `src/game/effects.ts` (pooled emitter per scene, tinted per kind) |
| `avatar-1` … `avatar-16` | `images/avatars/avatar-<n>.png` | single image | avatar fallback |
| `<player id>` | the player's `skin` URL (remote) | single image | the player's avatar |

The `FireBlast` texture key comes from the server: `Bomb.detonate()` builds `type` as `explosion_<direction>`. A new blast piece needs a server change and a new `Preload` key with the same name.

Animations are global. `Preload.createAnimations` creates them once per `Phaser.Game`: `bomb`, `portal`, and one `blast_<type>` per explosion sheet (`BLAST_TYPES`). The entities only call `play(key)`.

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
   - draws that texture once into a round canvas texture `<key>_round` (`makeRoundTexture`: a centred square crop inside a circle clip) and uses it as the sprite texture. Phaser 4 does not support `setMask` in WebGL, so there is no mask;
   - sizes the body from the round texture, turns it into a circle and sets the display size to 32 × 32 px (`TILE_SIZE − 3`).

Rules:

- Check a texture with `textures.exists(key)`. `textures.get(key)` always returns an object (the `__MISSING` texture for an unknown key), so a check on it is always true and the fallback never runs; this rendered players as black squares (see [known-traps.md](known-traps.md#black-player-sprite-from-texturesget)).
- The fallback is random on each client, so two clients can show different avatars for the same player. Choose it from the player id if every client must agree.
- React screens show the raw `skin` URL (`PlayersSlots.tsx`) or the Google `picture` (`UserBar.tsx`), not the Phaser fallback.

## Changing assets

1. Put the file in the folder above. Keep 35 × 35 px frames for anything on the grid.
2. If the frame count changes, update the `start` / `end` of the animation in the entity (`Bomberman-2.0/src/game/entities/`).
3. Add or change the key in `Preload`. Keys are strings with no shared list, so search the client for the old key before you rename it.
4. A new avatar file is used as a fallback only if the random range in `setPlayerAvatar` includes it.
