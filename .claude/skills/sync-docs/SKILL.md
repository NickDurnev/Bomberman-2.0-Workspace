---
name: sync-docs
description: Use after any code change to Bomberman-2.0 or Bomberman-2.0-Backend, before the PR, to update docs that the change made untrue ("update docs after a change", "sync docs", "docs are stale").
---

# Sync docs

Docs describe the code as it is now. Index and ownership: [docs/README.md](../../../docs/README.md).

## Procedure

1. In each touched submodule, list the change: `git -C <submodule> diff origin/dev...HEAD` (add `--stat` first). Include uncommitted work with `git -C <submodule> diff HEAD`.
2. Map each change to its doc:
   - socket event or payload: [socket-contract.md](../../../docs/socket-contract.md)
   - entity class or field: [entities.md](../../../docs/entities.md)
   - rules, values, modes: [mechanics.md](../../../docs/mechanics.md)
   - map file or loading: [maps.md](../../../docs/maps.md)
   - asset or `Preload` key: [assets.md](../../../docs/assets.md)
   - structure or flow: [architecture.md](../../../docs/architecture.md)
   - a fixed or new bug class: [known-traps.md](../../../docs/known-traps.md)
3. Edit each affected doc. Change only what the diff made untrue. Link to the doc that owns a fact; do not copy it.
4. Run `./scripts/check-socket-contract.sh` from the workspace root.
5. Check that links and paths resolve (below).
6. Commit the doc change in the root repo (`docs: ...`, see `.claude/rules/commit-conventions.md`).

## Verify

- `./scripts/check-socket-contract.sh` exits 0.
- Every relative `.md` link in the docs you edited resolves, and every `Bomberman-2.0*/...` path you wrote exists. Check a path with `ls`.
- Every changed event, entity field, mechanic value, map and asset in the diff is covered by a doc.
