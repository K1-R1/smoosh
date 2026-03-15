# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.1] - 2026-03-15

### Fixed

- `install.sh` now aborts (exit 1) when the `.sha256` checksum file is absent,
  rather than warning and continuing with an unverified binary. Set
  `SMOOSH_NO_VERIFY=1` to opt out in restricted environments.
- `--all` mode now exits with a clear error when the `file` command is not
  found, rather than silently including all files without MIME filtering.
- Exit codes 4 and 130 added to `--help` output (were documented in README
  but missing from the inline reference).

### Added

- 30 golden file tests covering byte-for-byte output across all mode and
  format combinations (`test/smoosh_golden.bats`).
- `test/ACCEPTANCE.md` — manual acceptance test scenarios for interactive
  mode, remote repos, AI tool integrations, and secrets detection.
- `MAINTAINING.md` — operational guide covering release procedure, pinned
  dependency inventory, and periodic maintenance schedule.
- Bash 3.2 syntax-check CI job on macOS (`/bin/bash -n smoosh`).
- Dependabot configured for monthly GitHub Actions SHA updates.

### Changed

- CI and release workflow install shfmt via `go install` (Go module sum
  database) instead of a raw binary download, which had no integrity check.
- Homebrew tap update replaced `mislav/bump-homebrew-formula-action` with a
  shell script — removes the Node.js 20 runtime dependency and works
  reliably with fine-grained PATs.
- Demo GIFs and VHS tape moved to `assets/` directory.

## [1.0.0] - 2026-03-14

### Added

- Core file aggregation with smart chunking at configurable word limits (default: 450,000 words)
- File type presets: `--docs` (md, rst, txt, adoc, org, tex), `--code` (adds all code extensions), `--all`
- Flexible filtering: `--include`, `--only`, `--exclude`, `--include-hidden`
- Interactive mode with repo scanning, category breakdown, and guided mode selection
- Remote repository support — pass any HTTPS, SSH, or bare `github.com/user/repo` URL
- Table of contents generation (`--toc`) with per-chunk file index and word counts
- Line numbers in output (`--line-numbers`)
- Multiple output formats: Markdown (default), plain text, XML with CDATA sections
- Basic secrets detection with clear scope messaging (AWS keys, GitHub PATs, PEM blocks)
- 100% file inclusion verification — exits 4 on any mismatch, never leaves partial output
- Dry run preview (`--dry-run`) with accurate per-file word counts
- Agent-native output: `--json` for structured JSON, `--no-interactive` for CI/scripts
- Differentiated exit codes (0–7, 130) for programmatic consumption
- Homebrew tap and curl installer (`install.sh`) with SHA256 verification
- 198 tests across 8 bats files
- CI: ShellCheck + shfmt lint + bats tests on Ubuntu and macOS
- GitHub Actions release workflow — auto-publishes release artefacts on tag push
- 256-colour sunset palette in interactive mode with box-drawing letter banner
- Output path shown relative to repo root
- Demo recordings: interactive mode flow and power-user flags

[Unreleased]: https://github.com/K1-R1/smoosh/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/K1-R1/smoosh/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/K1-R1/smoosh/releases/tag/v1.0.0
