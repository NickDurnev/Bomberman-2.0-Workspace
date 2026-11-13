---
description: Commit message format and staging rules. No AI attribution in commits.
---

# Commit Conventions

- Conventional Commits, enforced by commitlint: `type(scope): subject`.
- Lower-case subject, no full stop, header at most 100 characters.
- Types: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test.
- Review the repository style first: `git log --oneline -10`.
- Stage specific files. Never use `git add -A` or `git add .`.
- One logical change per commit.
- Never commit `local/`, `.superpowers/` or `.env*` files.

## No AI attribution

Write the message as the developer. Do NOT include:

- a `Co-Authored-By` trailer
- a "Generated with Claude Code" footer
- any mention of Claude, Anthropic or an AI assistant
