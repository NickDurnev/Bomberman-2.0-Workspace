# E2E test hook

The E2E suite (`Bomberman-2.0-E2E`) cannot see into the Phaser canvas. The frontend gives it a small read-only hook, `window.__e2e`.

## When it exists

- Only in a frontend build with `VITE_E2E=true`. `src/main.tsx` installs it under `if (import.meta.env.VITE_E2E === "true")`, so other builds do not contain it.
- The E2E stack builds the frontend with this flag. `make dev`, CI `checks` and production builds do not set it.

The code is in `Bomberman-2.0/src/utils/e2e.ts`. `Bomberman-2.0/src/game/PhaserGame.tsx` gives the hook the current `Phaser.Game` with `setCurrentGame`.

## Interface

```ts
window.__e2e: {
  // clientSocket.listeners(event).length for each event, app-wide.
  // No argument: every event in E2E_SOCKET_EVENTS.
  listenerCounts(events?: string[]): Record<string, number>;
  // Keys of the active Phaser scenes. [] when no game exists.
  scenes(): string[];
  // Snapshot of the Playing scene. null when Playing is not active.
  state(): {
    me: { name: string; x: number; y: number; alive: boolean } | null;
    enemies: { name: string; x: number; y: number }[];
    bombs: number; // active bomb sprites
  } | null;
  // Pack id each texture-pack key was loaded from: the room's pack,
  // "default" for a fallback, null when missing. {} before Preload is done.
  textures(): Record<string, string | null>;
}
```

- `E2E_SOCKET_EVENTS` lists every event the client registers on `clientSocket`. A new `clientSocket.on` adds its event to this list.
- `textures()` copies the game registry value that `Preload` writes (`TEXTURE_SOURCES_KEY` in `Bomberman-2.0/src/utils/texturePacks.ts`, see [assets.md](assets.md) › Texture packs). Its keys are the `PACK_TEXTURES` keys of `Preload.ts`.
- `name` is the text above the player sprite. `alive` is the local player's `active` flag (`becomesDead` clears it).
- The hook only reads. It never emits, never changes game objects and never calls game methods.

## Changing the hook

A change to the interface, to `E2E_SOCKET_EVENTS` or to the client listeners updates, in the same change:

- this doc;
- `Bomberman-2.0-E2E`: `tests/global.d.ts`, the fixtures and `tests/fixtures/expected-listeners.ts`.

See `.claude/rules/development-workflow.md` › Keep E2E in sync after behaviour changes.
