---
name: socket-event
description: Use when adding, renaming, removing or changing the payload of a socket.io event between the Bomberman client and server ("add socket event", "rename event", "new emit", "change payload").
---

# Change a socket event

The contract is [docs/socket-contract.md](../../../docs/socket-contract.md). The change steps are in its [Changing the contract](../../../docs/socket-contract.md#changing-the-contract) section. The listener rule is in its [Listener rule](../../../docs/socket-contract.md#listener-rule) section.

## Procedure

1. Decide who emits and who handles the event. The server owns game state. Identity comes from the handshake `auth`, never from the payload.
2. Write the new or changed row in the event table of `docs/socket-contract.md` first: name, payload, emitter, handler files. Keep the table between the `socket-contract` markers.
3. Server: emit and handle in `Bomberman-2.0-Backend` (start with the server, then the client). Update the mirrored type in `src/types.ts`.
4. Client: handle in `Bomberman-2.0`. Update the mirrored type in `src/utils/types.ts`.
5. Register each listener with a stored bound handler. Remove it with the same reference on scene shutdown or effect cleanup. No inline `.bind(this)` or arrow in `socket.on` or `socket.off`.
6. For a rename or removal, grep both repos for the old name until nothing remains.
7. Run `./scripts/check-socket-contract.sh` from the workspace root.

## Verify

- `./scripts/check-socket-contract.sh` exits 0.
- Backend and frontend checks pass in each repo you touched (`.claude/rules/development-workflow.md` › After you finish).
- Backend test added or updated (`docs/testing.md`), `npm test` passes.
- Every listener has a matching `off` with the same function reference.
- Run `play-local` with two different accounts. Trigger the event twice in a row. Each handler runs once per event (no ghosting).
- Dispatch `game-contract-reviewer` before the PR.
