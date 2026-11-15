---
description: Run, check, stop, fix, run in CI or extend the Bomberman E2E suite. One entry point with --flag subcommands; bare /e2e prints the menu. The instructions live in Bomberman-2.0-E2E/.claude/skills/e2e/; this command routes there.
---

# /e2e: router to the E2E skill

User invoked: `/e2e $ARGUMENTS`

## Routing

1. Parse `$ARGUMENTS`. The first word is the flag.
2. If `$ARGUMENTS` is empty, `--help`, or does not start with `--`: print the menu below and stop.
3. If the flag is not in the table: print the menu and `Unknown flag: <flag>`, then stop.
4. Otherwise `cd Bomberman-2.0-E2E` (relative to the workspace root), read the file from the table with the Read tool, and follow it. Read `_shared.md` in the same directory when the file refers to it. For `--add`, pass the rest of `$ARGUMENTS` as the description.

| Flag | File |
| --- | --- |
| `--start` | `Bomberman-2.0-E2E/.claude/skills/e2e/start.md` |
| `--status` | `Bomberman-2.0-E2E/.claude/skills/e2e/status.md` |
| `--stop` | `Bomberman-2.0-E2E/.claude/skills/e2e/stop.md` |
| `--fix` | `Bomberman-2.0-E2E/.claude/skills/e2e/fix.md` |
| `--start-ci` | `Bomberman-2.0-E2E/.claude/skills/e2e/start-ci.md` |
| `--add` | `Bomberman-2.0-E2E/.claude/skills/e2e/add.md` |

The rules in `Bomberman-2.0-E2E/.claude/rules/` and `Bomberman-2.0-E2E/.claude/CLAUDE.md` apply. Read them before you change a spec.

## Menu

```
/e2e --start              # fresh stack + full run in the background + progress
/e2e --status             # snapshot of the current run
/e2e --stop               # stop the run and the stack
/e2e --fix                # run, triage each failure, fix, run again (max 3 iterations)
/e2e --start-ci           # run the E2E workflow on GitHub, watch it, triage a failure
/e2e --add <description>  # write one new spec from a description
/e2e                      # this menu
```

## Notes

- If `Bomberman-2.0-E2E/` is missing or empty, run `make setup` in the workspace root.
- `--start-ci` uses `gh` (`gh workflow run`, `gh run view`, `gh run download`): the GitHub MCP has no workflow dispatch. PRs still go through the GitHub MCP, as in `development-workflow`.
- After the workflow, the working directory stays in `Bomberman-2.0-E2E`.
