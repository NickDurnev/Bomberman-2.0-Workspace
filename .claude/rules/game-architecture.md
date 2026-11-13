---
description: Invariants of the Bomberman game that no change may break. Each links to the known trap it prevents.
---

# Game Architecture Invariants

Read [docs/known-traps.md](../../docs/known-traps.md) for the bug history behind each rule.

1. **The server is authoritative for game state.** The client mirrors and renders. Never decide game outcomes on the client. See [docs/socket-contract.md](../../docs/socket-contract.md) and [known-traps](../../docs/known-traps.md).
2. **Register every socket listener with a stored bound handler.** Remove it with the same reference on scene shutdown. Never `socket.on(x, this.fn.bind(this))` inline. Trap: [Event ghosting from a listener leak](../../docs/known-traps.md#event-ghosting-from-a-listener-leak).
3. **Identity travels in the handshake `auth`.** Do not send identity in event payloads. Traps: [Identity handshake race](../../docs/known-traps.md#identity-handshake-race), [Player rendered without name or skin](../../docs/known-traps.md#player-rendered-without-name-or-skin).
4. **Use `textures.exists`, never `textures.get`, to test for a texture.** Trap: [Black player sprite from `textures.get`](../../docs/known-traps.md#black-player-sprite-from-texturesget).
5. **Chain reaction by blast is intended.** Do not "fix" it. Trap: [Chain reaction mistaken for a bug](../../docs/known-traps.md#chain-reaction-mistaken-for-a-bug).
6. **Test multiplayer with distinct accounts.** The same account in two sessions collapses into one player. Trap: [Same account in two sessions collapses into one player](../../docs/known-traps.md#same-account-in-two-sessions-collapses-into-one-player).
7. **Clear per-connection timers on the server.** Trap: [Per-connection timers on the server](../../docs/known-traps.md#per-connection-timers-on-the-server).
8. **Keep shared constants and maps in sync on both sides.** Trap: [Duplicated constants and maps drift](../../docs/known-traps.md#duplicated-constants-and-maps-drift).
9. **Every socket event change updates `docs/socket-contract.md` in the same change.** Run `./scripts/check-socket-contract.sh`.
