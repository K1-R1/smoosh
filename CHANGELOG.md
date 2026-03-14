# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/K1-R1/smoosh/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/K1-R1/smoosh/releases/tag/v1.0.0
