# Maintaining smoosh

Operational guide for the maintainer. For contributor instructions, see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Cutting a release

1. **Bump the version** in `smoosh` (line 8: `readonly VERSION="X.Y.Z"`).
2. **Update CHANGELOG.md** — move items from `[Unreleased]` into a new
   `[X.Y.Z] - YYYY-MM-DD` section.
3. **Commit**: `git commit -s -m "chore: prepare vX.Y.Z release"`.
4. **Tag**: `git tag --no-sign vX.Y.Z`.
5. **Push both**: `git push origin main && git push origin vX.Y.Z`.
6. **Verify the release workflow**:
   - Quality gate (ShellCheck, shfmt, bats) must pass.
   - GitHub Release is created with `smoosh`, `smoosh.sha256`, and `install.sh`.
   - Homebrew tap auto-updates (`update-tap` job).
7. **Check the tap** — confirm the formula SHA256 and version match:
   `brew update && brew info K1-R1/tap/smoosh`.

If the `update-tap` job fails, update the formula manually:
download the new tarball, compute `sha256sum`, and commit to
[K1-R1/homebrew-tap](https://github.com/K1-R1/homebrew-tap).

## Pinned dependencies

Dependabot handles GitHub Actions (`uses:` entries) on a monthly cycle.
Everything else needs manual bumping.

### Automated (Dependabot)

| Dependency | File | Current |
|---|---|---|
| `actions/checkout` | `ci.yml`, `release.yml` | v6.0.2 |
| `actions/upload-artifact` | `ci.yml` | v7.0.0 |
| `mislav/bump-homebrew-formula-action` | `release.yml` | v3.6 |

### Manual

| Dependency | File(s) | Current | Check |
|---|---|---|---|
| shfmt | `ci.yml:32`, `release.yml:48` | v3.13.0 | [Releases](https://github.com/mvdan/sh/releases) |
| bats-core | `ci.yml:69,108`, `release.yml:56` | v1.13.0 | [Releases](https://github.com/bats-core/bats-core/releases) |
| actionlint | `ci.yml:41` | 1.7.11 | [Releases](https://github.com/rhysd/actionlint/releases) |
| zizmor | `ci.yml:48` | 1.23.1 | [PyPI](https://pypi.org/project/zizmor/) |
| markdownlint-cli2 | `prek.toml` | v0.21.0 | [npm](https://www.npmjs.com/package/markdownlint-cli2) |
| cspell | `prek.toml` | 9 | [npm](https://www.npmjs.com/package/cspell) |

When bumping a manual dependency: update the version pin, run CI locally
(`prek run && bats test/*.bats`), and commit with
`chore: bump <tool> to vX.Y.Z`.

## Known deprecation

`mislav/bump-homebrew-formula-action` v3.6 uses the Node.js 20 runtime,
which GitHub deprecates in **June 2026**. Watch for a v4 release or plan
a replacement (a shell script in the release workflow that computes the
SHA256 and commits to the tap directly).

## Periodic checks

**Quarterly — dependency audit**

Check the manual dependencies table above for new releases. Bump, test,
commit.

**Semi-annually — README accuracy**

Verify external claims haven't changed:

- NotebookLM source limits (currently: 500k words/source, Free 50 / Plus
  300 / Ultra 600 sources)
- Installation URLs still resolve
- Third-party integration steps (Claude Projects, ChatGPT) still match
  their current UIs

**On issue/PR activity**

Aim to triage new issues within a week. For PRs: check CI passes, DCO is
signed, and changes match the project's scope.

## Repo configuration

These settings are applied via the GitHub UI, not tracked in code:

- **Branch ruleset on `main`**: require PR, block force push, require
  status checks (lint, test, bash32).
- **Tag ruleset**: require tag match `v*`, bypass actor: repository admin.
- **Merge policy**: squash merge only, delete branch on merge.
- **GitHub topics**: `bash`, `cli`, `rag`, `llm`, `notebooklm`,
  `knowledge-base`, `developer-tools`, `context-window`.
- **HOMEBREW_TAP_TOKEN**: fine-grained PAT scoped to `K1-R1/homebrew-tap`
  (Contents: read+write). Stored in the `homebrew` environment on this
  repo.
