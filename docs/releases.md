# Releases and deploys

How a change gets from `dev` to production in `Bomberman-2.0` and `Bomberman-2.0-Backend`. The E2E repo and the workspace repo have no releases.

## Flow

1. A release PR from `dev` to `main` merges (the maintainer merges it, backend first).
2. The push to `main` deploys:
   - Backend: `.github/workflows/ci-cd.yml` deploys to the droplet over SSH.
   - Frontend: Vercel builds `main` (Git integration).
3. The same push runs `.github/workflows/release.yml`. release-please (`googleapis/release-please-action@v4`) reads the Conventional Commits since the last release and opens or updates the release PR (branch `release-please--branches--main`). The PR bumps `package.json`, `package-lock.json` and `.release-please-manifest.json`, and adds the new section to `CHANGELOG.md`.
4. The job `Auto-merge release PR` merges that PR with `--admin`, because `main` needs a code-owner review.
5. The merge is a new push to `main`. release-please creates the tag `vX.Y.Z` and the GitHub Release. This push does not deploy again: the backend deploy job and the Vercel build skip a commit from the release branch (`ci-cd.yml` job `if`, `vercel.json` `ignoreCommand`).
6. The job `Back-merge release commit to dev` merges the release commit into a branch `chore/back-merge-vX.Y.Z` from `dev` (a git merge, so `dev` gets the history of `main`), opens a PR to `dev`, waits for `checks` (`dev` lets nobody bypass it), and merges it with a merge commit and `--admin`. Then `dev` has the same version as `main`, and the next `dev` → `main` PR merges cleanly. If `dev` changed a release-managed line (CHANGELOG, manifest, a `version` line or the line next to it) before the merge, the job stops with an error: merge `main` into `dev` by hand.

## Versions

- Baseline `1.0.0` (tag `v1.0.0`) in both repos. The first release, `v1.1.0`, has the whole earlier history in its CHANGELOG.
- Tags are `vX.Y.Z` (`include-component-in-tag: false`). release-please finds the last release by this tag: never delete or rename a release tag.
- `feat` → minor, `fix` and `perf` → patch, `!` or `BREAKING CHANGE` → major. Only `docs`, `style`, `chore`, `test`, `build` and `ci` commits since the last release give no release PR. The changelog sections are in `release-please-config.json`.
- A major bump is not merged automatically. The release PR gets the label `needs-resolution` and a comment; the maintainer merges it.

## Token

`release.yml` uses the repository secret `RELEASE_PLEASE_TOKEN`: a fine-grained PAT of the admin account with write access to contents, pull requests and issues in the repo. A merge with `GITHUB_TOKEN` would not start the next workflow run, so the tag would never be cut.

## When the automation stops

The job fails and the PR gets the label `needs-resolution` when:

- the release PR proposes a version that is already released (the `main` manifest was rolled back);
- a merge fails;
- the back-merge `checks` fail.

Merge the PR by hand after you fix the cause. If the back-merge never lands, `dev` is behind `main` and the next release overwrites the version: fix it before the next `dev` → `main` PR.
