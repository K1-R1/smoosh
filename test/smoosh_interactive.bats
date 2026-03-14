#!/usr/bin/env bats
# Tests for Phase 7: Interactive Mode.
#
# Interactive mode requires a real TTY — bats runs in a pipe so [[ -t 0 ]]
# is always false. Tests focus on:
#   1. Non-interactive fallback: any run in bats must not hang or show banner.
#   2. is_interactive() unit test (always false in non-TTY).
#   3. classify_file_ext() and scan_repo_types() unit tests via source.
#   4. _fmt_exts() formatting unit tests via source.
#
# The BASH_SOURCE guard in smoosh lets us source it without executing main().
# shellcheck disable=SC2154 # BATS_TEST_DIRNAME is set by the bats test runner.

load 'test_helper/common-setup'

setup_file() {
  export SCAN_REPO
  SCAN_REPO="$(mktemp -d)"

  # docs: md, rst, txt
  printf '# Readme\n' >"${SCAN_REPO}/README.md"
  printf 'Guide text\n' >"${SCAN_REPO}/guide.rst"
  printf 'plain text\n' >"${SCAN_REPO}/notes.txt"

  # code: py, js, rs
  printf 'def foo(): pass\n' >"${SCAN_REPO}/app.py"
  printf 'const x = 1;\n' >"${SCAN_REPO}/index.js"
  printf 'fn main() {}\n' >"${SCAN_REPO}/lib.rs"

  # config: yml, json
  printf 'key: value\n' >"${SCAN_REPO}/config.yml"
  printf '{"name":"pkg"}\n' >"${SCAN_REPO}/package.json"

  # other: unrecognised extension
  printf 'unknown data\n' >"${SCAN_REPO}/data.xyz"

  git -C "${SCAN_REPO}" init -q
  git -C "${SCAN_REPO}" config user.email "test@example.com"
  git -C "${SCAN_REPO}" config user.name "Test"
  git -C "${SCAN_REPO}" add -A
  git -C "${SCAN_REPO}" commit -q -m "init"
}

teardown_file() {
  [[ -d "${SCAN_REPO-}" ]] && rm -rf "${SCAN_REPO}"
}

setup() {
  rm -rf "${SCAN_REPO}/_smooshes"
}

# ---------------------------------------------------------------------------
# Non-interactive fallback (bats is always non-TTY)
# ---------------------------------------------------------------------------

@test "zero arguments does not crash on unbound variable" {
  # Bash 3.2 set -u treats $@ as unbound when there are no positional params.
  # Running smoosh with no args in a non-TTY falls through to non-interactive
  # mode against the current directory. Use the fixture repo as CWD.
  cd "${SCAN_REPO}"
  run smoosh
  assert_success
}

@test "non-TTY environment runs without hanging" {
  run smoosh "${SCAN_REPO}"
  assert_success
}

@test "non-TTY never shows banner tagline" {
  run smoosh "${SCAN_REPO}"
  refute_output --partial "One command. Every doc. Smooshed."
}

@test "non-TTY never shows interactive menu prompt" {
  run smoosh "${SCAN_REPO}"
  refute_output --partial "What would you like to process?"
}

@test "any flag skips interactive mode" {
  run smoosh --code "${SCAN_REPO}"
  assert_success
  refute_output --partial "What would you like to process?"
}

@test "--no-interactive suppresses interactive mode" {
  run smoosh --no-interactive "${SCAN_REPO}"
  assert_success
  refute_output --partial "One command. Every doc. Smooshed."
}

@test "target argument skips interactive mode" {
  # Providing a target path counts as explicit intent — no menu.
  run smoosh "${SCAN_REPO}"
  refute_output --partial "Choice [1]:"
}

# ---------------------------------------------------------------------------
# Unit tests via source
# ---------------------------------------------------------------------------

# Helper: source smoosh (BASH_SOURCE guard prevents main execution).
_load_smoosh() {
  # shellcheck source=smoosh
  source "${BATS_TEST_DIRNAME}/../smoosh"
  # Initialise visuals so symbol vars are set.
  setup_colours
  setup_symbols
  # Point functions at the fixture repo.
  REPO_ROOT="${SCAN_REPO}"
}

@test "is_interactive returns false in non-TTY" {
  _load_smoosh
  ORIG_ARGC=0
  NO_INTERACTIVE="false"
  # [[ -t 0 ]] is false in bats → is_interactive must return non-zero (false).
  run is_interactive
  assert_failure
}

@test "is_interactive returns false with --no-interactive set" {
  _load_smoosh
  ORIG_ARGC=0
  NO_INTERACTIVE="true"
  run is_interactive
  assert_failure
}

# ---------------------------------------------------------------------------
# classify_file_ext unit tests
# ---------------------------------------------------------------------------

@test "classify_file_ext: md → docs" {
  _load_smoosh
  [[ "$(classify_file_ext md)" == "docs" ]]
}

@test "classify_file_ext: rst → docs" {
  _load_smoosh
  [[ "$(classify_file_ext rst)" == "docs" ]]
}

@test "classify_file_ext: py → code" {
  _load_smoosh
  [[ "$(classify_file_ext py)" == "code" ]]
}

@test "classify_file_ext: rs → code" {
  _load_smoosh
  [[ "$(classify_file_ext rs)" == "code" ]]
}

@test "classify_file_ext: yml → config" {
  _load_smoosh
  [[ "$(classify_file_ext yml)" == "config" ]]
}

@test "classify_file_ext: json → config" {
  _load_smoosh
  [[ "$(classify_file_ext json)" == "config" ]]
}

@test "classify_file_ext: toml → config" {
  _load_smoosh
  [[ "$(classify_file_ext toml)" == "config" ]]
}

@test "classify_file_ext: xyz → other" {
  _load_smoosh
  [[ "$(classify_file_ext xyz)" == "other" ]]
}

@test "classify_file_ext: empty extension → other" {
  _load_smoosh
  [[ "$(classify_file_ext "")" == "other" ]]
}

# ---------------------------------------------------------------------------
# scan_repo_types unit tests
# ---------------------------------------------------------------------------

@test "scan_repo_types counts docs correctly" {
  _load_smoosh
  INCLUDE_HIDDEN="false"
  scan_repo_types
  # README.md, guide.rst, notes.txt → 3 doc files
  [[ "${SCAN_DOCS_COUNT}" -eq 3 ]]
}

@test "scan_repo_types counts code correctly" {
  _load_smoosh
  INCLUDE_HIDDEN="false"
  scan_repo_types
  # app.py, index.js, lib.rs → 3 code files
  [[ "${SCAN_CODE_COUNT}" -eq 3 ]]
}

@test "scan_repo_types counts config correctly" {
  _load_smoosh
  INCLUDE_HIDDEN="false"
  scan_repo_types
  # config.yml, package.json → 2 config files
  [[ "${SCAN_CONFIG_COUNT}" -eq 2 ]]
}

@test "scan_repo_types counts other correctly" {
  _load_smoosh
  INCLUDE_HIDDEN="false"
  scan_repo_types
  # data.xyz → 1 other file
  [[ "${SCAN_OTHER_COUNT}" -eq 1 ]]
}

@test "scan_repo_types total matches sum of categories" {
  _load_smoosh
  INCLUDE_HIDDEN="false"
  scan_repo_types
  local expected=$((SCAN_DOCS_COUNT + SCAN_CODE_COUNT + SCAN_CONFIG_COUNT + SCAN_OTHER_COUNT))
  [[ "${SCAN_TOTAL}" -eq "${expected}" ]]
}

@test "scan_repo_types docs extensions include md" {
  _load_smoosh
  INCLUDE_HIDDEN="false"
  scan_repo_types
  [[ "${SCAN_DOCS_EXTS}" == *"md"* ]]
}

@test "scan_repo_types code extensions include py and rs" {
  _load_smoosh
  INCLUDE_HIDDEN="false"
  scan_repo_types
  [[ "${SCAN_CODE_EXTS}" == *"py"* ]]
  [[ "${SCAN_CODE_EXTS}" == *"rs"* ]]
}

# ---------------------------------------------------------------------------
# _fmt_exts unit tests
# ---------------------------------------------------------------------------

@test "_fmt_exts returns dash for empty input" {
  _load_smoosh
  [[ "$(_fmt_exts "")" == "—" ]]
}

@test "_fmt_exts formats single extension" {
  _load_smoosh
  [[ "$(_fmt_exts " md")" == "md" ]]
}

@test "_fmt_exts separates multiple extensions with commas" {
  _load_smoosh
  result="$(_fmt_exts " md rst txt")"
  [[ "${result}" == *"md"* ]]
  [[ "${result}" == *"rst"* ]]
  [[ "${result}" == *","* ]]
}

@test "_fmt_exts caps at 4 and appends '+N more'" {
  _load_smoosh
  result="$(_fmt_exts " a b c d e f")"
  # 6 extensions, first 4 shown, "+2 more" appended
  [[ "${result}" == *"+2 more"* ]]
}

@test "_fmt_exts shows exactly 4 without overflow annotation" {
  _load_smoosh
  result="$(_fmt_exts " a b c d")"
  [[ "${result}" != *"more"* ]]
}
