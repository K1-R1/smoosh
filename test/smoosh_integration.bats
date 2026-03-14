#!/usr/bin/env bats
# Tests for Phase 10: Integration — full end-to-end workflows.
# shellcheck disable=SC2154,SC2034 # SC2154: bats vars; SC2034: globals used by sourced smoosh.

load 'test_helper/common-setup'

setup_file() {
  export INT_REPO
  INT_REPO="$(mktemp -d)"

  # Docs
  printf '# README\n\nThis is the readme.\n' >"${INT_REPO}/README.md"
  printf '# Guide\n\nThis is the guide.\n' >"${INT_REPO}/guide.md"

  # Code
  printf 'def hello(): return "world"\n' >"${INT_REPO}/app.py"
  printf 'const x = 1;\n' >"${INT_REPO}/index.js"

  # Config (present but not included in docs or code mode)
  printf '{"name": "test"}\n' >"${INT_REPO}/package.json"

  mkdir -p "${INT_REPO}/src"
  printf 'fn main() {}\n' >"${INT_REPO}/src/lib.rs"

  git -C "${INT_REPO}" init -q
  git -C "${INT_REPO}" config user.email "test@example.com"
  git -C "${INT_REPO}" config user.name "Test"
  git -C "${INT_REPO}" add -A
  git -C "${INT_REPO}" commit -q -m "init"
}

teardown_file() {
  [[ -d "${INT_REPO-}" ]] && rm -rf "${INT_REPO}"
}

setup() {
  rm -rf "${INT_REPO}/_smooshes"
}

# ---------------------------------------------------------------------------
# Full end-to-end: docs mode (default)
# ---------------------------------------------------------------------------

@test "default run produces output with all markdown files" {
  run smoosh "${INT_REPO}"
  assert_success
  local out
  out="$(cat "${INT_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" == *"README.md"* ]]
  [[ "${out}" == *"guide.md"* ]]
}

@test "default run excludes code files from output" {
  smoosh "${INT_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${INT_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" != *"app.py"* ]]
  [[ "${out}" != *"index.js"* ]]
}

# ---------------------------------------------------------------------------
# Mode switching
# ---------------------------------------------------------------------------

@test "--code mode includes both docs and code files" {
  smoosh --code "${INT_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${INT_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" == *"README.md"* ]]
  [[ "${out}" == *"app.py"* ]]
  [[ "${out}" == *"lib.rs"* ]]
}

@test "--docs mode excludes python files" {
  smoosh --docs "${INT_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${INT_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" != *"app.py"* ]]
}

@test "--all mode includes config files" {
  smoosh --all "${INT_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${INT_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" == *"package.json"* ]]
}

# ---------------------------------------------------------------------------
# Flag combinations
# ---------------------------------------------------------------------------

@test "--code --toc --line-numbers combination works" {
  smoosh --code --toc --line-numbers "${INT_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${INT_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" == *"Table of Contents"* ]]
  [[ "${out}" == *" | "* ]] # line number separator
  local files=("${INT_REPO}/_smooshes/"*.md)
  assert_file_exists "${files[0]}"
}

@test "--code --format xml produces valid XML structure" {
  smoosh --code --format xml "${INT_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${INT_REPO}/_smooshes/"*.xml 2>/dev/null)"
  [[ "${out}" == *"<smoosh"* ]]
  [[ "${out}" == *"</smoosh>"* ]]
  [[ "${out}" == *"<file path="* ]]
}

@test "--only restricts output to specified extension only" {
  smoosh --only "*.py" "${INT_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${INT_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" == *"app.py"* ]]
  [[ "${out}" != *"README.md"* ]]
  [[ "${out}" != *"lib.rs"* ]]
}

# ---------------------------------------------------------------------------
# Chunking with known word counts
# ---------------------------------------------------------------------------

@test "chunking with --max-words splits into multiple files" {
  local chunk_repo
  chunk_repo="$(mktemp -d)"

  # Create 3 files each ~200 words — total ~600, so max-words=250 forces splits.
  printf '# A\n\n%s\n' "$(printf 'word%.0s ' {1..200})" >"${chunk_repo}/a.md"
  printf '# B\n\n%s\n' "$(printf 'word%.0s ' {1..200})" >"${chunk_repo}/b.md"
  printf '# C\n\n%s\n' "$(printf 'word%.0s ' {1..200})" >"${chunk_repo}/c.md"

  git -C "${chunk_repo}" init -q
  git -C "${chunk_repo}" config user.email "t@t.com"
  git -C "${chunk_repo}" config user.name "T"
  git -C "${chunk_repo}" add -A
  git -C "${chunk_repo}" commit -q -m "init"

  smoosh --max-words 250 "${chunk_repo}" >/dev/null 2>&1
  local count
  local files=("${chunk_repo}/_smooshes/"*.md)
  local count="${#files[@]}"
  rm -rf "${chunk_repo}"
  [[ "${count}" -ge 2 ]]
}

# ---------------------------------------------------------------------------
# Verification integrity check
# ---------------------------------------------------------------------------

@test "verify_output passes for normal run" {
  run smoosh "${INT_REPO}"
  assert_success
  assert_output --partial "Verified"
}

@test "tampered output file causes verify_output to fail with exit 4" {
  smoosh "${INT_REPO}" >/dev/null 2>&1
  local chunk_file
  local chunks=("${INT_REPO}/_smooshes/"*.md)
  chunk_file="${chunks[0]}"

  # Source smoosh so we can call verify_output directly — running smoosh again
  # would regenerate the output files before verifying, defeating the test.
  _load_smoosh
  REPO_ROOT="${INT_REPO}"
  FORMAT="md"
  QUIET="false"

  # Point GENERATED_CHUNKS at the real chunk.
  GENERATED_CHUNKS=("${chunk_file}")

  # PROCESSED_FILES = what smoosh claims it wrote.  Add a phantom file that is
  # NOT present in the chunk — verify_output must detect this mismatch.
  PROCESSED_FILES=()
  local line
  while IFS= read -r line; do
    PROCESSED_FILES+=("${line#'### File: '}")
  done < <(grep '^### File:' "${chunk_file}")
  PROCESSED_FILES+=("__phantom_test_file__.md")

  # verify_output should detect the mismatch and exit 4.
  run verify_output
  [[ "${status}" -eq 4 ]]
}

# ---------------------------------------------------------------------------
# Secrets + exclusion integration
# ---------------------------------------------------------------------------

@test "files with secrets are excluded from output content" {
  local sec_repo
  sec_repo="$(mktemp -d)"
  printf '# Guide\n\nContent.\n' >"${sec_repo}/guide.md"
  printf 'ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"\n' >"${sec_repo}/aws.py"

  git -C "${sec_repo}" init -q
  git -C "${sec_repo}" config user.email "t@t.com"
  git -C "${sec_repo}" config user.name "T"
  git -C "${sec_repo}" add -A
  git -C "${sec_repo}" commit -q -m "init"

  smoosh --code "${sec_repo}" >/dev/null 2>&1
  local out
  out="$(cat "${sec_repo}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" != *"AKIAIOSFODNN7EXAMPLE"* ]]
  [[ "${out}" == *"guide.md"* ]]

  rm -rf "${sec_repo}"
}
