#!/usr/bin/env bats
# Tests for Phase 4: file processing, chunking, verification, summary.

load 'test_helper/common-setup'

setup_file() {
  PROC_REPO="$(mktemp -d)"
  export PROC_REPO

  # Create files with known word counts for deterministic chunk testing.
  printf '# Doc One\n\n%s\n' "$(printf 'word%.0s ' {1..100})" >"${PROC_REPO}/doc1.md"
  printf '# Doc Two\n\n%s\n' "$(printf 'word%.0s ' {1..150})" >"${PROC_REPO}/doc2.md"
  printf '# Doc Three\n\n%s\n' "$(printf 'word%.0s ' {1..200})" >"${PROC_REPO}/doc3.md"

  git -C "${PROC_REPO}" init -q
  git -C "${PROC_REPO}" config user.email "test@example.com"
  git -C "${PROC_REPO}" config user.name "Test"
  git -C "${PROC_REPO}" add -A
  git -C "${PROC_REPO}" commit -q -m "init"
}

teardown_file() {
  [[ -d "${PROC_REPO-}" ]] && rm -rf "${PROC_REPO}"
}

# Clean up any _smooshes/ output between tests.
setup() {
  rm -rf "${PROC_REPO}/_smooshes"
}

# ---------------------------------------------------------------------------
# Basic output generation
# ---------------------------------------------------------------------------

@test "produces output file in _smooshes/" {
  run smoosh "${PROC_REPO}"
  assert_success
  local files=("${PROC_REPO}/_smooshes/"*.md)
  [[ -e "${files[0]}" ]]
}

@test "output file contains file headers" {
  smoosh "${PROC_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${PROC_REPO}/_smooshes/"*.md)"
  [[ "${out}" == *"doc1.md"* ]]
  [[ "${out}" == *"doc2.md"* ]]
  [[ "${out}" == *"doc3.md"* ]]
}

@test "output file contains file content" {
  smoosh "${PROC_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${PROC_REPO}/_smooshes/"*.md)"
  [[ "${out}" == *"Doc One"* ]]
}

# ---------------------------------------------------------------------------
# Output formats
# ---------------------------------------------------------------------------

@test "--format md produces markdown headers" {
  smoosh --format md "${PROC_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${PROC_REPO}/_smooshes/"*.md)"
  [[ "${out}" == *"### File:"* ]]
}

@test "--format text produces text separators" {
  smoosh --format text "${PROC_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${PROC_REPO}/_smooshes/"*.txt)"
  [[ "${out}" == *"File:"* ]]
}

@test "--format xml produces XML structure" {
  smoosh --format xml "${PROC_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${PROC_REPO}/_smooshes/"*.xml)"
  [[ "${out}" == *"<smoosh"* ]]
  [[ "${out}" == *"<file path="* ]]
  [[ "${out}" == *"CDATA"* ]]
}

# ---------------------------------------------------------------------------
# Chunking
# ---------------------------------------------------------------------------

@test "chunking triggers at --max-words boundary" {
  # With max-words=200 and ~450 total words, expect 3 chunks.
  smoosh --max-words 200 "${PROC_REPO}" >/dev/null 2>&1
  local files=("${PROC_REPO}/_smooshes/"*.md)
  [[ "${#files[@]}" -ge 2 ]]
}

@test "multiple chunks are numbered part1, part2, etc." {
  smoosh --max-words 200 "${PROC_REPO}" >/dev/null 2>&1
  local files=("${PROC_REPO}/_smooshes/"*part1*)
  assert_file_exists "${files[0]}"
  local part2=("${PROC_REPO}/_smooshes/"*part2*)
  [[ -e "${part2[0]}" ]]
}

# ---------------------------------------------------------------------------
# Output directory
# ---------------------------------------------------------------------------

@test "_smooshes/ directory is created if missing" {
  [[ ! -d "${PROC_REPO}/_smooshes" ]]
  run smoosh "${PROC_REPO}"
  assert_success
  assert_dir_exists "${PROC_REPO}/_smooshes"
}

@test "_smooshes/ is added to .gitignore" {
  smoosh "${PROC_REPO}" >/dev/null 2>&1
  grep -q "_smooshes/" "${PROC_REPO}/.gitignore"
}

@test "--output-dir uses custom directory" {
  local custom_dir
  custom_dir="$(mktemp -d)"
  run smoosh --output-dir "${custom_dir}" "${PROC_REPO}"
  assert_success
  assert_dir_exists "${custom_dir}"
  rm -rf "${custom_dir}"
}

# ---------------------------------------------------------------------------
# Line numbers
# ---------------------------------------------------------------------------

@test "--line-numbers adds line numbers to output" {
  smoosh --line-numbers "${PROC_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${PROC_REPO}/_smooshes/"*.md)"
  # nl produces "  1 | " style prefixes
  [[ "${out}" == *" | "* ]]
}

# ---------------------------------------------------------------------------
# Empty file handling
# ---------------------------------------------------------------------------

@test "empty files are included in output" {
  printf '' >"${PROC_REPO}/empty.md"
  git -C "${PROC_REPO}" add -A && git -C "${PROC_REPO}" commit -q -m "add empty"
  smoosh "${PROC_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${PROC_REPO}/_smooshes/"*.md)"
  [[ "${out}" == *"empty.md"* ]]
}

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

@test "exits 0 on successful verification" {
  run smoosh "${PROC_REPO}"
  assert_success
}

@test "verification passes and confirms 100% inclusion" {
  run smoosh "${PROC_REPO}"
  assert_output --partial "Verified"
}
