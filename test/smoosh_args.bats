#!/usr/bin/env bats
# Tests for argument parsing and CLI interface.

load 'test_helper/common-setup'

# ---------------------------------------------------------------------------
# --help
# ---------------------------------------------------------------------------

@test "--help exits 0" {
  run smoosh --help
  assert_success
}

@test "-h exits 0" {
  run smoosh -h
  assert_success
}

@test "--help output contains Usage:" {
  run smoosh --help
  assert_output --partial "Usage:"
}

@test "--help output contains smoosh" {
  run smoosh --help
  assert_output --partial "smoosh"
}

@test "--help documents all modes" {
  run smoosh --help
  assert_output --partial "--docs"
  assert_output --partial "--code"
  assert_output --partial "--all"
}

@test "--help documents output options" {
  run smoosh --help
  assert_output --partial "--toc"
  assert_output --partial "--format"
  assert_output --partial "--output-dir"
}

@test "--help includes agent/CI example" {
  run smoosh --help
  assert_output --partial "--no-interactive --json"
}

# ---------------------------------------------------------------------------
# --version
# ---------------------------------------------------------------------------

@test "--version exits 0" {
  run smoosh --version
  assert_success
}

@test "--version prints version string" {
  run smoosh --version
  assert_output --partial "smoosh "
  assert_output --regexp "^smoosh [0-9]+\.[0-9]+\.[0-9]+$"
}

# ---------------------------------------------------------------------------
# Unknown flags
# ---------------------------------------------------------------------------

@test "unknown flag exits 1" {
  run smoosh --not-a-real-flag
  assert_failure
}

@test "unknown flag error message mentions the flag" {
  run smoosh --not-a-real-flag
  assert_output --partial "--not-a-real-flag"
}

# ---------------------------------------------------------------------------
# Mode flags
# ---------------------------------------------------------------------------

@test "--docs flag is accepted" {
  run smoosh --docs --dry-run .
  # Will fail past arg parsing in Phase 3, but should not fail on flag parsing
  # For now just check it doesn't exit 1 with "unknown option"
  refute_output --partial "Unknown option"
}

@test "--code flag is accepted" {
  run smoosh --code --dry-run .
  refute_output --partial "Unknown option"
}

@test "--all flag is accepted" {
  run smoosh --all --dry-run .
  refute_output --partial "Unknown option"
}

# ---------------------------------------------------------------------------
# Value-requiring flags
# ---------------------------------------------------------------------------

@test "--max-words requires a value" {
  run smoosh --max-words
  assert_failure
}

@test "--max-words rejects non-numeric value" {
  run smoosh --max-words abc
  assert_failure
  assert_output --partial "--max-words"
}

@test "--max-words rejects zero" {
  run smoosh --max-words 0
  assert_failure
  assert_output --partial "positive integer"
}

@test "--max-words rejects negative number" {
  run smoosh --max-words -5
  assert_failure
  assert_output --partial "positive integer"
}

@test "--max-words accepts numeric value" {
  run smoosh --max-words 100000 --dry-run .
  refute_output --partial "Unknown option"
}

@test "--format rejects invalid value" {
  run smoosh --format pdf
  assert_failure
  assert_output --partial "md, text, xml"
}

@test "--format accepts md" {
  run smoosh --format md --dry-run .
  refute_output --partial "Unknown option"
}

@test "--format accepts text" {
  run smoosh --format text --dry-run .
  refute_output --partial "Unknown option"
}

@test "--format accepts xml" {
  run smoosh --format xml --dry-run .
  refute_output --partial "Unknown option"
}

@test "--include accepts a value" {
  run smoosh --include "*.vue" --dry-run .
  refute_output --partial "Unknown option"
}

@test "--include rejects empty string" {
  run smoosh --include ""
  assert_failure
  assert_output --partial "non-empty"
}

@test "--include rejects whitespace-only string" {
  run smoosh --include "   "
  assert_failure
  assert_output --partial "non-empty"
}

@test "--exclude accepts a value" {
  run smoosh --exclude "vendor/*" --dry-run .
  refute_output --partial "Unknown option"
}

@test "--exclude rejects empty string" {
  run smoosh --exclude ""
  assert_failure
  assert_output --partial "non-empty"
}

@test "--only accepts a value" {
  run smoosh --only "*.py" --dry-run .
  refute_output --partial "Unknown option"
}

@test "--only rejects empty string" {
  run smoosh --only ""
  assert_failure
  assert_output --partial "non-empty"
}

@test "--output-dir accepts a path" {
  run smoosh --output-dir /tmp/out --dry-run .
  refute_output --partial "Unknown option"
}

@test "--output-dir rejects filesystem root" {
  run smoosh --output-dir /
  assert_failure
  assert_output --partial "filesystem root"
}

# ---------------------------------------------------------------------------
# Boolean flags
# ---------------------------------------------------------------------------

@test "--no-color is accepted" {
  run smoosh --no-color --version
  assert_success
}

@test "--quiet is accepted" {
  run smoosh --quiet --dry-run .
  refute_output --partial "Unknown option"
}

@test "--json is accepted" {
  run smoosh --json --dry-run .
  refute_output --partial "Unknown option"
}

@test "--no-interactive is accepted" {
  run smoosh --no-interactive --dry-run .
  refute_output --partial "Unknown option"
}

@test "--include-hidden is accepted" {
  run smoosh --include-hidden --dry-run .
  refute_output --partial "Unknown option"
}

@test "--toc is accepted" {
  run smoosh --toc --dry-run .
  refute_output --partial "Unknown option"
}

@test "--line-numbers is accepted" {
  run smoosh --line-numbers --dry-run .
  refute_output --partial "Unknown option"
}

@test "--dry-run is accepted" {
  run smoosh --dry-run .
  refute_output --partial "Unknown option"
}

@test "--no-check-secrets is accepted" {
  run smoosh --no-check-secrets --dry-run .
  refute_output --partial "Unknown option"
}

# ---------------------------------------------------------------------------
# Mutual exclusivity
# ---------------------------------------------------------------------------

@test "--json and --quiet together produce an error" {
  run smoosh --json --quiet .
  assert_failure
  assert_output --partial "mutually exclusive"
}

# ---------------------------------------------------------------------------
# Flag combinations
# ---------------------------------------------------------------------------

@test "multiple flags can be combined" {
  run smoosh --code --toc --line-numbers --dry-run .
  refute_output --partial "Unknown option"
}

@test "--format=VALUE syntax is accepted" {
  run smoosh --format=xml --dry-run .
  refute_output --partial "Unknown option"
}

@test "--max-words=VALUE syntax is accepted" {
  run smoosh --max-words=100000 --dry-run .
  refute_output --partial "Unknown option"
}

@test "-- end-of-options sentinel is accepted" {
  run smoosh -- .
  refute_output --partial "Unknown option"
}
