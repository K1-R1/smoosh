---
title: "fix: Resolve acceptance test findings"
type: fix
status: completed
date: 2026-03-17
---

# fix: Resolve acceptance test findings

## Overview

Acceptance testing (human walkthrough + agent walkthrough) surfaced 2 bugs,
security hardening items, and documentation gaps. A follow-up audit expanded the
raw findings to ~25. This plan resolves all actionable findings to best practices
before promotional activity begins.

## Triage

Each dismissed finding was re-evaluated with justification:

**Excluded (with rationale):**

| Finding | Verdict | Justification |
|---------|---------|---------------|
| `--output-dir` path traversal | Dismissed | User controls all inputs on a local CLI tool. Rejecting `..` would break legitimate `--output-dir ../shared-output`. No privilege boundary crossed. |
| `mktemp` explicit error handling | Dismissed | `set -euo pipefail` (line 6) already propagates `mktemp` failures from `$()` substitution. Adding `\|\| die` to 8 callsites is redundant. |
| Remote clone symlink race condition | Dismissed | Two-pass remove+verify is sound. The "race" requires attacker write access to a `mktemp -d` dir — meaning they already have the user's UID. |
| `sed` injection in release.yml | Dismissed | `tarball_url` comes from `github.ref_name` (git tags can't contain `&` or `\`). `sha256` is hex from `sha256sum`. Neither can contain sed specials. |
| Token in git clone URL | Dismissed | Standard cross-repo GH Actions pattern. Fine-grained PAT, scoped to one repo. GitHub auto-masks secrets in logs. |
| Pre-release binary validation | Dismissed | smoosh is a bash script. Suggested `file \| grep ELF` check would actually fail. SHA256 checksum IS the integrity check. |
| Troubleshooting section | Dismissed | No user reports yet. Shadow binary issue covered by uninstall section (D2). Add when real issues arrive. |
| `LC_ALL=C` documentation | Dismissed | Set internally by smoosh for consistent sorting. Not consumed from user's environment. Documenting it would confuse. |

**Included:** everything below.

## Bugs

### B1. `.gitignore` write crashes on read-only repos

- **File:** `smoosh:710-745`
- **Symptom:** When an agent uses `--output-dir /external/path` on a local repo
  it has read-only access to, `mktemp` in `REPO_ROOT` fails with exit 1.
- **Root cause:** Line 710-711 warns when output-dir is outside the repo, but
  execution falls through to line 733 which creates a temp file in REPO_ROOT.
  The `.gitignore` entry would be meaningless anyway — it would contain an
  absolute external path.
- **Fix:** After the "outside repo" warning on line 711, add `return 0`.
- **Test:** New bats test — run smoosh with `--output-dir` pointing outside the
  repo fixture. Assert success. Assert `.gitignore` in the repo is unchanged.
  (Existing test `smoosh_edge_cases.bats:251` asserts only the warning message;
  it doesn't verify that `.gitignore` is left untouched.)

### B2. README curl install pinned to v1.0.0

- **File:** `README.md:97,104`
- **Symptom:** New users following README install v1.0.0 instead of latest.
- **Fix:** Change from tag-pinned URL to `main` branch:
  ```
  https://raw.githubusercontent.com/K1-R1/smoosh/main/install.sh
  ```
  The install.sh script already resolves the latest release version at runtime
  via GitHub API — the tag in the URL only controls which version of
  `install.sh` itself is fetched, not which smoosh version is installed.
  Using `main` means users always get the latest install script.
- **Test:** Not testable in bats (documentation).

### B2b. install.sh header comment pinned to v1.0.0

- **File:** `install.sh:5`
- **Fix:** Update to match README (use `main`).
- **Test:** Not testable in bats (documentation comment).

## Security hardening

### S1. `.gitignore` symlink check

- **File:** `smoosh:722-743`
- **Issue:** `.gitignore` modification doesn't verify it's a regular file. If
  `.gitignore` is a symlink, the `cp` + `mv` pattern would overwrite the
  symlink target.
- **Fix:** Add before line 730:
  ```bash
  if [[ -L "${gitignore}" ]]; then
    warn ".gitignore is a symlink — skipping auto-update"
    return 0
  fi
  ```
- **Test:** New bats test — create a repo fixture with `.gitignore` as a
  symlink to another file. Run smoosh. Assert the symlink target is unchanged.
  Assert warning message is emitted.

### S2. README manual install lacks checksum verification

- **File:** `README.md:109-113`
- **Issue:** Manual install downloads binary without integrity check. The
  `install.sh` path has SHA256 verification, but the "manual" shortcut bypasses
  it entirely.
- **Fix:** Add checksum step to the manual install instructions:
  ```bash
  curl -fsSL https://github.com/K1-R1/smoosh/releases/latest/download/smoosh -o smoosh
  curl -fsSL https://github.com/K1-R1/smoosh/releases/latest/download/smoosh.sha256 -o smoosh.sha256
  sha256sum -c smoosh.sha256
  chmod +x smoosh
  sudo mv smoosh /usr/local/bin/
  ```
- **Test:** Not testable in bats (documentation).

### S3. release.yml uses /tmp instead of $RUNNER_TEMP

- **File:** `.github/workflows/release.yml:126,132`
- **Issue:** Files written to world-readable `/tmp`. GitHub provides
  `$RUNNER_TEMP` as a per-job temp directory.
- **Fix:** Replace `/tmp/smoosh-src.tar.gz` with `"$RUNNER_TEMP/smoosh-src.tar.gz"`
  and `/tmp/homebrew-tap` with `"$RUNNER_TEMP/homebrew-tap"`.
- **Test:** Not testable in bats (CI workflow).

### S4. install.sh sudo escalation without notice

- **File:** `install.sh:158-166`
- **Issue:** Script tries `install -m 755` silently, then falls back to `sudo`
  without notice. On systems with NOPASSWD sudo, this escalates without any
  user-visible indication. In the `curl | bash` context, the user can't inspect
  what happens before execution.
- **Fix:** Add `warn` before the sudo fallback:
  ```bash
  if install -m 755 "${tmp_bin}" "${INSTALL_DIR}/${BINARY_NAME}" 2>/dev/null; then
    : # success without sudo
  else
    warn "Writing to ${INSTALL_DIR} requires elevated privileges (sudo)."
    if sudo install -m 755 "${tmp_bin}" "${INSTALL_DIR}/${BINARY_NAME}"; then
      : # success with sudo
    else
      die "Installation failed. Try: SMOOSH_INSTALL_DIR=\$HOME/.local/bin bash install.sh"
    fi
  fi
  ```
- **Test:** Not deterministically testable without mocking filesystem
  permissions. The fix is a single `warn` line — low risk, no test needed.

## Documentation improvements

### D1. Add table of contents to README

- **File:** `README.md` (top, after logo/tagline)
- **Content:** Linked section headings for Quick Start, Why smoosh, Features,
  Installation, Usage, AI Tools, Config Reference, FAQ, Contributing, Licence.

### D2. Add uninstall instructions

- **File:** `README.md` (new section after Installation)
- **Content:**
  - Homebrew: `brew uninstall smoosh`
  - curl/manual: `rm /usr/local/bin/smoosh` (or `which smoosh` to find it)
  - Note: if you installed via both methods, check `which smoosh` after removing
    one — a shadow binary may remain.

### D3. Add `--no-color` to README config reference

- **File:** `README.md:247-267`
- **Issue:** Flag exists in `--help` and code but missing from README table.
- **Fix:** Add row: `--no-color | — | Disable colour output`

### D4. Document colour environment variables

- **File:** `README.md` (in or near config reference)
- **Content:** Precedence: `--no-color` flag > `NO_COLOR` > `FORCE_COLOR` >
  `CLICOLOR` > TTY auto-detect. Link to https://no-color.org/.

### D5. Add agent/CI usage section

- **File:** `README.md` (expand "Using smoosh with AI tools" or new subsection)
- **Content:**
  - Recommended agent pre-flight: `smoosh --json --dry-run --all .`
  - Recommended agent execution: `smoosh --no-interactive --json --all .`
  - JSON output schema example (show actual structure from dry-run)
  - Exit codes for programmatic decision-making
  - Note: `--json` goes to stdout, status to stderr — safe to pipe

### D6. Add agent example to `--help`

- **File:** `smoosh` (help text, Examples section)
- **Add:**
  ```
  smoosh --no-interactive --json .  # agent / CI pipeline
  ```
- **Test:** Assert `--help` output contains `--no-interactive --json`.

### D7. Document install.sh env vars in README

- **File:** `README.md` (near curl install section)
- **Content:** Brief mention of `SMOOSH_VERSION`, `SMOOSH_INSTALL_DIR`,
  `SMOOSH_NO_CONFIRM`, `SMOOSH_NO_VERIFY` with one-line descriptions.

## New tests summary

| Test | File | What it asserts |
|------|------|-----------------|
| External output-dir skips .gitignore | `smoosh_edge_cases.bats` | `--output-dir /tmp/ext` succeeds; repo `.gitignore` unchanged |
| Symlink .gitignore skipped with warning | `smoosh_edge_cases.bats` | `.gitignore` symlink target unchanged; warning emitted |
| `--help` includes agent example | `smoosh_args.bats` | Output contains `--no-interactive --json` |

## Implementation phases

### Phase 1: Bug fixes + security hardening (smoosh script)

1. Fix B1 — add early return in `ensure_output_dir` when output is outside repo
2. Fix S1 — add symlink check before `.gitignore` modification
3. Fix S4 — add sudo warning in install.sh
4. Add agent example to `--help` (D6)
5. Write 3 new bats tests
6. Run: `shellcheck smoosh && shfmt -d -i 2 smoosh && bats test/*.bats`

### Phase 2: Version pinning + CI fixes

7. Fix B2 — update README curl URLs from `v1.0.0` to `main`
8. Fix B2b — update install.sh header comment
9. Fix S2 — add checksum verification to README manual install
10. Fix S3 — use `$RUNNER_TEMP` in release.yml

### Phase 3: README documentation

11. Add table of contents (D1)
12. Add uninstall section (D2)
13. Add `--no-color` to config reference (D3)
14. Document colour env vars (D4)
15. Add agent/CI usage section with JSON schema example (D5)
16. Document install.sh env vars (D7)

### Phase 4: Verify

17. `shellcheck smoosh`
18. `shfmt -d -i 2 smoosh`
19. `bats test/*.bats`
20. `prek run`

## Acceptance criteria

- [x] `smoosh --output-dir /tmp/ext --no-interactive .` succeeds on a repo
      without crashing (B1 fix + test)
- [x] `.gitignore` symlink is not followed (S1 fix + test)
- [x] `--help` output contains agent example (D6 + test)
- [x] README curl install references `main` branch, not a version tag
- [x] README manual install includes SHA256 verification step
- [x] install.sh warns before sudo escalation
- [x] release.yml uses `$RUNNER_TEMP`
- [x] README has table of contents, uninstall section, `--no-color` in config
      table, colour env vars, agent usage section, install.sh env vars
- [x] All checks pass: shellcheck, shfmt, bats, prek
