#!/usr/bin/env bats
# Tests for Phase 9: UX Polish — dry run, quiet mode, progress, JSON output.
# shellcheck disable=SC2154 # BATS_TEST_DIRNAME is set by the bats test runner.

load 'test_helper/common-setup'

setup_file() {
  export DISP_REPO
  DISP_REPO="$(mktemp -d)"

  printf '# Doc One\n\n%s\n' "$(printf 'word%.0s ' {1..100})" >"${DISP_REPO}/doc1.md"
  printf '# Doc Two\n\n%s\n' "$(printf 'word%.0s ' {1..150})" >"${DISP_REPO}/doc2.md"
  printf '# Doc Three\n\n%s\n' "$(printf 'word%.0s ' {1..200})" >"${DISP_REPO}/doc3.md"

  git -C "${DISP_REPO}" init -q
  git -C "${DISP_REPO}" config user.email "test@example.com"
  git -C "${DISP_REPO}" config user.name "Test"
  git -C "${DISP_REPO}" add -A
  git -C "${DISP_REPO}" commit -q -m "init"
}

teardown_file() {
  [[ -d "${DISP_REPO-}" ]] && rm -rf "${DISP_REPO}"
}

setup() {
  rm -rf "${DISP_REPO}/_smooshes"
}

# ---------------------------------------------------------------------------
# Dry run
# ---------------------------------------------------------------------------

@test "--dry-run shows file list without creating output files" {
  run smoosh --dry-run "${DISP_REPO}"
  assert_success
  assert_output --partial "doc1.md"
  assert_output --partial "doc2.md"
  assert_output --partial "doc3.md"
  # No output directory should have been created.
  [[ ! -d "${DISP_REPO}/_smooshes" ]]
}

@test "--dry-run shows word counts" {
  run smoosh --dry-run "${DISP_REPO}"
  assert_success
  # Each file line shows a word count.
  assert_output --partial "words"
}

@test "--dry-run shows total word count" {
  run smoosh --dry-run "${DISP_REPO}"
  assert_success
  assert_output --partial "Words"
}

@test "--dry-run shows chunk estimate" {
  run smoosh --dry-run "${DISP_REPO}"
  assert_success
  assert_output --partial "Chunks"
}

@test "--dry-run does not create output files" {
  smoosh --dry-run "${DISP_REPO}" >/dev/null 2>&1
  local files=("${DISP_REPO}/_smooshes/"*.md)
  # If glob didn't match, the single entry is the literal pattern (no files).
  [[ ! -e "${files[0]}" ]]
}

# ---------------------------------------------------------------------------
# Quiet mode
# ---------------------------------------------------------------------------

@test "--quiet outputs file paths to stdout" {
  run smoosh --quiet "${DISP_REPO}"
  assert_success
  # stdout must contain a .md path (the chunk file).
  assert_output --partial ".md"
}

@test "--quiet suppresses summary table" {
  run smoosh --quiet "${DISP_REPO}"
  refute_output --partial "Files processed"
  refute_output --partial "Total words"
}

@test "--quiet suppresses banner/ready message" {
  run smoosh --quiet "${DISP_REPO}"
  refute_output --partial "Ready for:"
}

@test "--quiet still shows errors to stderr" {
  # Run against a non-existent path — error must appear despite --quiet.
  run smoosh --quiet "/nonexistent/path/$(date +%s)"
  assert_failure
  assert_output --partial "Path not found"
}

@test "--quiet and --json together produce an error" {
  run smoosh --quiet --json "${DISP_REPO}"
  assert_failure
  assert_output --partial "mutually exclusive"
}

# ---------------------------------------------------------------------------
# JSON output
# ---------------------------------------------------------------------------

@test "--json output is valid JSON" {
  # Use direct capture (not bats run) so stdout is isolated from stderr.
  local json_out
  json_out="$(smoosh --json "${DISP_REPO}" 2>/dev/null)"
  printf '%s' "${json_out}" | jq . >/dev/null
}

@test "--json output contains repo field" {
  run smoosh --json "${DISP_REPO}"
  assert_success
  assert_output --partial '"repo"'
}

@test "--json output contains files_processed field" {
  run smoosh --json "${DISP_REPO}"
  assert_success
  assert_output --partial '"files_processed"'
}

@test "--json output contains total_words field" {
  run smoosh --json "${DISP_REPO}"
  assert_success
  assert_output --partial '"total_words"'
}

@test "--json output contains chunks array" {
  run smoosh --json "${DISP_REPO}"
  assert_success
  assert_output --partial '"chunks"'
}

@test "--json output contains exit_code field" {
  run smoosh --json "${DISP_REPO}"
  assert_success
  assert_output --partial '"exit_code"'
}

@test "--json sends only JSON to stdout; all other output to stderr" {
  # Capture stdout and stderr separately.
  local stdout_file stderr_file
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"
  smoosh --json "${DISP_REPO}" >"${stdout_file}" 2>"${stderr_file}"
  local exit_code=$?

  # stdout must be valid JSON.
  jq . <"${stdout_file}" >/dev/null 2>&1
  local jq_exit=$?

  rm -f "${stdout_file}" "${stderr_file}"
  [[ "${exit_code}" -eq 0 ]]
  [[ "${jq_exit}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Dry run + JSON
# ---------------------------------------------------------------------------

@test "--dry-run --json produces valid JSON" {
  run smoosh --dry-run --json "${DISP_REPO}"
  assert_success
  printf '%s' "${output}" | jq . >/dev/null 2>&1
}

@test "--dry-run --json includes dry_run: true" {
  run smoosh --dry-run --json "${DISP_REPO}"
  assert_success
  assert_output --partial '"dry_run": true'
}

@test "--dry-run --json includes files array with paths" {
  run smoosh --dry-run --json "${DISP_REPO}"
  assert_success
  assert_output --partial '"files"'
  assert_output --partial 'doc1.md'
}

@test "--dry-run --json includes total_words" {
  run smoosh --dry-run --json "${DISP_REPO}"
  assert_success
  assert_output --partial '"total_words"'
}

@test "--dry-run --json does not create output files" {
  smoosh --dry-run --json "${DISP_REPO}" >/dev/null 2>&1
  [[ ! -d "${DISP_REPO}/_smooshes" ]]
}

# ---------------------------------------------------------------------------
# json_escape unit test (via source)
# ---------------------------------------------------------------------------

@test "json_escape handles double quotes" {
  _load_smoosh
  [[ "$(json_escape 'say "hello"')" == 'say \"hello\"' ]]
}

@test "json_escape handles backslashes" {
  _load_smoosh
  [[ "$(json_escape 'path\to\file')" == 'path\\to\\file' ]]
}

@test "json_escape handles newlines" {
  _load_smoosh
  result="$(json_escape $'line1\nline2')"
  [[ "${result}" == 'line1\nline2' ]]
}

# ---------------------------------------------------------------------------
# Chunk count warnings
# ---------------------------------------------------------------------------

@test "chunk count warning at >50 mentions free limit" {
  # Use --max-words=1 to force one chunk per file; need >50 files.
  # Instead test via source by manipulating GENERATED_CHUNKS.
  _load_smoosh
  GENERATED_CHUNKS=()
  PROCESSED_FILES=()
  local i
  for i in $(seq 1 51); do
    local f="${TMPDIR:-/tmp}/smoosh_fake_chunk_${i}.md"
    printf 'word\n' >"${f}"
    GENERATED_CHUNKS+=("${f}")
    PROCESSED_FILES+=("fake${i}.md")
  done
  run show_summary
  # Clean up fake files.
  for i in $(seq 1 51); do
    rm -f "${TMPDIR:-/tmp}/smoosh_fake_chunk_${i}.md"
  done
  assert_output --partial "50"
}
