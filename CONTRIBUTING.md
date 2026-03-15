# Contributing to smoosh

Thank you for your interest in contributing!

## Prerequisites

- Bash 3.2+ (test with `bash --version`)
- git
- bats-core (`brew install bats-core` or see <https://bats-core.readthedocs.io>)
- ShellCheck (`brew install shellcheck`)
- shfmt (`brew install shfmt`)

## Development Setup

```bash
git clone https://github.com/K1-R1/smoosh
cd smoosh
git submodule update --init --recursive
cargo install prek  # pre-commit hooks (Rust, one-time install)
prek install        # activate hooks for this repo
```

## Pre-commit Hooks

This project uses [prek](https://github.com/nicholasgasior/prek) for
pre-commit hooks. Run `prek install` once after cloning. The hooks run
automatically on `git commit` and check:

- Trailing whitespace and missing final newlines
- Markdown formatting (markdownlint-cli2)
- Spelling — British English (cspell)
- ShellCheck lint
- shfmt formatting

To check all files manually: `prek run --all-files`

## Running Tests

```bash
bats test/*.bats          # all tests
bats test/smoosh_args.bats  # specific file
```

## Golden File Tests

The golden file suite (`test/smoosh_golden.bats`) verifies that smoosh output
is byte-for-byte correct across all modes, formats, and feature combinations.

If you intentionally change smoosh's output format (for example, adding a new
header field or changing the section separator), regenerate the expected files:

```bash
UPDATE_GOLDEN=1 bats test/smoosh_golden.bats
```

Then review the diff to confirm the changes are intentional before committing:

```bash
git diff test/golden/
```

The golden files live in `test/golden/expected/`. Never edit them by hand —
always use `UPDATE_GOLDEN=1` to regenerate them from a passing smoosh run.

## Updating the Demos

The demos are recorded with [VHS](https://github.com/charmbracelet/vhs)
(`brew install vhs`). There are three tape files:

| Tape | Output | Shows |
| --- | --- | --- |
| `demo-logo.tape` | `demo-logo.gif` | Banner logo (README hero) |
| `demo.tape` | `demo.gif` | Interactive mode flow |
| `demo-power.tape` | `demo-power.gif` | Power-user flags |

Re-record after the relevant change:

| When to re-record | Tapes affected |
| --- | --- |
| Visual style changes (colours, banner, symbols) | `demo-logo.tape`, `demo.tape` |
| Interactive mode UI changes | `demo.tape` |
| New major flags or output format changes | `demo-power.tape` |

```bash
vhs demo-logo.tape    # logo — re-record when visual style changes
vhs demo.tape         # interactive flow — re-record when UI changes
vhs demo-power.tape   # power-user flags — re-record when flags change
```

Commit the updated `.gif` files alongside the code change that prompted the
re-record. The tapes are the source of truth — never edit the GIFs by hand.

## Code Style

- 2-space indentation
- `shellcheck smoosh` must pass with zero warnings
- `shfmt -d -i 2 smoosh` must show no diff
- Functions must be <= 100 lines
- Use `printf '%s\n' "$var"` not `echo "$var"` for filenames
- All non-content output to stderr
- Never use `sed -i` — write to temp file then `mv`
- Always use `--` before file arguments

## Bash 3.2 Compatibility

macOS ships Bash 3.2. Keep the script compatible:

- No `declare -A` (associative arrays)
- No `readarray` or `mapfile`
- No `${var,,}` (lowercase expansion)
- No named references (`declare -n`)
- Use `tr '[:upper:]' '[:lower:]'` for case conversion

## Commit Messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/).
Prefix every commit subject with a type:

| Type | When |
| --- | --- |
| `feat:` | New feature or user-visible change |
| `fix:` | Bug fix |
| `test:` | Adding or updating tests |
| `docs:` | Documentation only |
| `chore:` | Maintenance (CI, deps, tooling) |
| `refactor:` | Code change that doesn't fix a bug or add a feature |

Examples: `feat: add --format csv`, `fix: handle empty repo gracefully`.

Keep the subject line under 72 characters; use the body for detail.

## Sign Your Work (DCO)

This project uses the [Developer Certificate of Origin](https://developercertificate.org/)
(DCO). Every commit in your PR must carry a `Signed-off-by` trailer certifying
that you have the right to submit it under the project's MIT licence.

Git adds the trailer automatically with the `-s` flag:

```bash
git commit -s -m "feat: add widget support"
```

The [DCO GitHub App](https://github.com/apps/dco) checks every PR. Unsigned
commits will fail the check. If you forget, amend and force-push your branch:

```bash
git commit --amend -s --no-edit
git push --force-with-lease
```

## Submitting a Pull Request

1. Fork the repo and create a branch: `git checkout -b feat/your-feature`
2. Make your changes with tests
3. Run `prek run` and `bats test/*.bats`
4. Sign your commits (`git commit -s`)
5. Open a PR against `main`

PRs that break CI or have unsigned commits will not be merged.

## First-time contributors

Look for issues labelled `good first issue` — these are intentionally small
and well-scoped entry points.

## Questions

Open an issue — no question is too small.
