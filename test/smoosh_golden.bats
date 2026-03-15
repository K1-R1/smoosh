#!/usr/bin/env bats
# Golden file acceptance tests — verify smoosh output is byte-for-byte correct
# across all modes, formats, and feature flag combinations.
#
# Usage:
#   bats test/smoosh_golden.bats           # run all golden tests
#   UPDATE_GOLDEN=1 bats test/smoosh_golden.bats  # regenerate all golden files
#
# shellcheck disable=SC2154,SC2034 # SC2154: bats vars; SC2034: globals used by sourced smoosh.

load 'test_helper/common-setup'

# Paths (set at load time, before setup_file).
GOLDEN_SRC="${BATS_TEST_DIRNAME}/fixtures/golden-repo"
GOLDEN_DIR="${BATS_TEST_DIRNAME}/golden/expected"

setup_file() {
  export GOLDEN_REPO GOLDEN_OUT
  GOLDEN_REPO="$(mktemp -d)"
  GOLDEN_OUT="$(mktemp -d)"

  # Create a real git repo from the static fixture files.
  # The fixture files in GOLDEN_SRC are plain source files (no .git/);
  # we create the git repo here at test time.
  cp -r "${GOLDEN_SRC}/." "${GOLDEN_REPO}/"

  # Create a symlink to exercise the symlink exclusion code path (line 642
  # in smoosh). Created at test time rather than in the fixture directory
  # because git's core.symlinks setting varies across platforms.
  ln -s README.md "${GOLDEN_REPO}/link-to-readme"

  git -C "${GOLDEN_REPO}" init -q
  git -C "${GOLDEN_REPO}" config user.email "test@example.com"
  git -C "${GOLDEN_REPO}" config user.name "Test"
  git -C "${GOLDEN_REPO}" add -A
  git -C "${GOLDEN_REPO}" commit -q -m "init"
}

teardown_file() {
  [[ -d "${GOLDEN_REPO-}" ]] && rm -rf "${GOLDEN_REPO}"
  [[ -d "${GOLDEN_OUT-}" ]] && rm -rf "${GOLDEN_OUT}"
}

setup() {
  # Clear output dir between tests so each test starts with a clean slate.
  rm -rf "${GOLDEN_OUT:?}/"*
}

# ---------------------------------------------------------------------------
# Normalisation — strips non-deterministic content before comparison.
# ---------------------------------------------------------------------------

# normalise CONTENT — print normalised version to stdout.
#
# Replaces:
#   - temp dir paths (GOLDEN_REPO, GOLDEN_OUT) with fixed placeholders
#   - random mktemp dir name in chunk headers and filenames → "golden-repo"
#   - timestamps in all three format headers (md text, XML attribute)
#   - timestamp prefixes in output filenames
#   - JSON fields that contain absolute paths or timestamps
normalise() {
  local content="${1}"
  local repo_basename
  repo_basename="$(basename "${GOLDEN_REPO}")"
  printf '%s' "${content}" | sed \
    -e "s|${GOLDEN_REPO}|REPO_ROOT|g" \
    -e "s|${GOLDEN_OUT}|OUTPUT_DIR|g" \
    -e "s|${repo_basename}|golden-repo|g" \
    -e 's/Generated: [0-9-]* [0-9:]*/Generated: TIMESTAMP/g' \
    -e 's/generated="[^"]*"/generated="TIMESTAMP"/g' \
    -e 's/[0-9_]*_golden-repo_part/TIMESTAMP_golden-repo_part/g' \
    -e 's|"generated":"[^"]*"|"generated":"TIMESTAMP"|g' \
    -e 's|"output_dir":"[^"]*"|"output_dir":"OUTPUT_DIR"|g' \
    -e 's|"path":"[^"]*TIMESTAMP_golden-repo_part|"path":"OUTPUT_DIR/TIMESTAMP_golden-repo_part|g'
}

# golden_compare GOLDEN_NAME ACTUAL
#
# If UPDATE_GOLDEN=1: write ACTUAL to the golden file and skip the test.
# Otherwise: diff ACTUAL against the golden file and fail on any difference.
golden_compare() {
  local golden_name="${1}" actual="${2}"
  if [[ "${UPDATE_GOLDEN:-}" == "1" ]]; then
    printf '%s\n' "${actual}" >"${GOLDEN_DIR}/${golden_name}"
    skip "Golden file updated: ${golden_name}"
  fi
  if [[ ! -f "${GOLDEN_DIR}/${golden_name}" ]]; then
    fail "Golden file missing: ${golden_name}. Run UPDATE_GOLDEN=1 bats test/smoosh_golden.bats to generate."
  fi
  local expected
  expected="$(cat "${GOLDEN_DIR}/${golden_name}")"
  if [[ "${actual}" != "${expected}" ]]; then
    diff <(printf '%s\n' "${expected}") <(printf '%s\n' "${actual}") >&2
    fail "Output differs from ${golden_name}. Run UPDATE_GOLDEN=1 bats test/smoosh_golden.bats to regenerate."
  fi
}

# _concat_chunks EXT — concatenate chunk files with boundary markers.
# Bash 3.2-compatible: uses find + while loop instead of mapfile.
_concat_chunks() {
  local ext="${1}"
  local result="" first=true chunk_file
  while IFS= read -r chunk_file; do
    if [[ "${first}" == "true" ]]; then
      first=false
    else
      result="${result}
--- CHUNK BOUNDARY ---
"
    fi
    result="${result}$(cat "${chunk_file}")"
  done < <(find "${GOLDEN_OUT}" -maxdepth 1 -name "*.${ext}" | LC_ALL=C sort)
  printf '%s' "${result}"
}

# ---------------------------------------------------------------------------
# Docs mode — all three output formats
# ---------------------------------------------------------------------------

@test "golden: docs-md" {
  smoosh --docs --no-interactive --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.md)")"
  golden_compare "docs-md.golden" "${actual}"
}

@test "golden: docs-text" {
  smoosh --docs --no-interactive --format text --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.txt)")"
  golden_compare "docs-text.golden" "${actual}"
}

@test "golden: docs-xml" {
  smoosh --docs --no-interactive --format xml --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.xml)")"
  golden_compare "docs-xml.golden" "${actual}"
}

# ---------------------------------------------------------------------------
# Docs mode — feature flags: TOC, line numbers, combined (all 3 formats)
# ---------------------------------------------------------------------------

@test "golden: docs-md-toc" {
  smoosh --docs --no-interactive --toc --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.md)")"
  golden_compare "docs-md-toc.golden" "${actual}"
}

@test "golden: docs-md-line-numbers" {
  smoosh --docs --no-interactive --line-numbers --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.md)")"
  golden_compare "docs-md-line-numbers.golden" "${actual}"
}

@test "golden: docs-md-toc-line-numbers" {
  smoosh --docs --no-interactive --toc --line-numbers --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.md)")"
  golden_compare "docs-md-toc-line-numbers.golden" "${actual}"
}

@test "golden: docs-text-toc" {
  smoosh --docs --no-interactive --toc --format text --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.txt)")"
  golden_compare "docs-text-toc.golden" "${actual}"
}

@test "golden: docs-text-line-numbers" {
  smoosh --docs --no-interactive --line-numbers --format text --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.txt)")"
  golden_compare "docs-text-line-numbers.golden" "${actual}"
}

@test "golden: docs-text-toc-line-numbers" {
  smoosh --docs --no-interactive --toc --line-numbers --format text --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.txt)")"
  golden_compare "docs-text-toc-line-numbers.golden" "${actual}"
}

@test "golden: docs-xml-line-numbers" {
  smoosh --docs --no-interactive --line-numbers --format xml --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.xml)")"
  golden_compare "docs-xml-line-numbers.golden" "${actual}"
}

@test "golden: docs-xml-toc-line-numbers" {
  smoosh --docs --no-interactive --toc --line-numbers --format xml --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.xml)")"
  golden_compare "docs-xml-toc-line-numbers.golden" "${actual}"
}

# ---------------------------------------------------------------------------
# Code mode — markdown and XML+TOC
# ---------------------------------------------------------------------------

@test "golden: code-md" {
  # aws-creds.py is a .py file in code mode — secrets detection excludes it.
  smoosh --code --no-interactive --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.md)")"
  golden_compare "code-md.golden" "${actual}"
}

@test "golden: code-xml-toc" {
  smoosh --code --no-interactive --toc --format xml --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.xml)")"
  golden_compare "code-xml-toc.golden" "${actual}"
}

# ---------------------------------------------------------------------------
# Code mode — secrets variant: --no-check-secrets includes aws-creds.py
# ---------------------------------------------------------------------------

@test "golden: no-check-secrets-code-md" {
  smoosh --code --no-interactive --no-check-secrets --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.md)")"
  golden_compare "no-check-secrets-code-md.golden" "${actual}"
}

# ---------------------------------------------------------------------------
# All mode
# ---------------------------------------------------------------------------

@test "golden: all-md" {
  smoosh --all --no-interactive --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.md)")"
  golden_compare "all-md.golden" "${actual}"
}

# ---------------------------------------------------------------------------
# Filter flags: --only, --exclude, --include
# ---------------------------------------------------------------------------

@test "golden: only-py-md" {
  # app.py included; aws-creds.py excluded by secrets detection.
  smoosh --only "*.py" --no-interactive --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.md)")"
  golden_compare "only-py-md.golden" "${actual}"
}

@test "golden: exclude-deep-md" {
  # deep/nested/path/doc.md excluded; all other docs present.
  smoosh --docs --no-interactive --exclude "deep/*" --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.md)")"
  golden_compare "exclude-deep-md.golden" "${actual}"
}

@test "golden: exclude-multi-md" {
  # Comma-separated excludes: deep paths and .txt files both excluded.
  smoosh --docs --no-interactive --exclude "deep/*,*.txt" --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.md)")"
  golden_compare "exclude-multi-md.golden" "${actual}"
}

@test "golden: include-json-md" {
  # package.json added to docs mode via --include.
  smoosh --docs --no-interactive --include "*.json" --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.md)")"
  golden_compare "include-json-md.golden" "${actual}"
}

# ---------------------------------------------------------------------------
# Chunking: --max-words 100 across all three formats
# ---------------------------------------------------------------------------

@test "golden: chunked-md" {
  smoosh --docs --no-interactive --max-words 100 --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(_concat_chunks md)")"
  golden_compare "chunked-md.golden" "${actual}"
}

@test "golden: chunked-text" {
  smoosh --docs --no-interactive --max-words 100 --format text --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(_concat_chunks txt)")"
  golden_compare "chunked-text.golden" "${actual}"
}

@test "golden: chunked-xml" {
  smoosh --docs --no-interactive --max-words 100 --format xml --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(_concat_chunks xml)")"
  golden_compare "chunked-xml.golden" "${actual}"
}

# ---------------------------------------------------------------------------
# Hidden files: --include-hidden
# ---------------------------------------------------------------------------

@test "golden: include-hidden-md" {
  # .github/ci.yml and .env.example included alongside all tracked files.
  smoosh --all --no-interactive --include-hidden --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" >/dev/null 2>&1
  local actual
  actual="$(normalise "$(cat "${GOLDEN_OUT}/"*.md)")"
  golden_compare "include-hidden-md.golden" "${actual}"
}

# ---------------------------------------------------------------------------
# Stdout / stderr output tests
# ---------------------------------------------------------------------------

@test "golden: dry-run" {
  # --dry-run writes its file listing to stderr; nothing is written to disk.
  local actual exit_code
  actual="$(smoosh --docs --no-interactive --dry-run "${GOLDEN_REPO}" 2>&1 >/dev/null)"
  exit_code=$?
  [[ "${exit_code}" -eq 0 ]] || fail "smoosh exited with code ${exit_code}"
  actual="$(normalise "${actual}")"
  golden_compare "dry-run.golden" "${actual}"
}

@test "golden: json" {
  # --json writes structured JSON to stdout; all progress goes to stderr.
  local actual exit_code
  actual="$(smoosh --docs --no-interactive --json --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" 2>/dev/null)"
  exit_code=$?
  [[ "${exit_code}" -eq 0 ]] || fail "smoosh exited with code ${exit_code}"
  actual="$(normalise "${actual}")"
  golden_compare "json.golden" "${actual}"
}

@test "golden: json-dry-run" {
  # --json --dry-run: different JSON structure (file list, no chunks).
  local actual exit_code
  actual="$(smoosh --docs --no-interactive --json --dry-run "${GOLDEN_REPO}" 2>/dev/null)"
  exit_code=$?
  [[ "${exit_code}" -eq 0 ]] || fail "smoosh exited with code ${exit_code}"
  actual="$(normalise "${actual}")"
  golden_compare "json-dry-run.golden" "${actual}"
}

@test "golden: code-json" {
  # --code --json: secrets_excluded array is populated (aws-creds.py flagged).
  local actual exit_code
  actual="$(smoosh --code --no-interactive --json --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" 2>/dev/null)"
  exit_code=$?
  [[ "${exit_code}" -eq 0 ]] || fail "smoosh exited with code ${exit_code}"
  actual="$(normalise "${actual}")"
  golden_compare "code-json.golden" "${actual}"
}

@test "golden: quiet" {
  # --quiet writes output file paths to stdout, one per line.
  local actual exit_code
  actual="$(smoosh --docs --no-interactive --quiet --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" 2>/dev/null)"
  exit_code=$?
  [[ "${exit_code}" -eq 0 ]] || fail "smoosh exited with code ${exit_code}"
  actual="$(normalise "${actual}")"
  golden_compare "quiet.golden" "${actual}"
}

@test "golden: chunked-quiet" {
  # --quiet with chunking: outputs one path per chunk.
  local actual exit_code
  actual="$(smoosh --docs --no-interactive --quiet --max-words 100 --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" 2>/dev/null)"
  exit_code=$?
  [[ "${exit_code}" -eq 0 ]] || fail "smoosh exited with code ${exit_code}"
  actual="$(normalise "${actual}")"
  golden_compare "chunked-quiet.golden" "${actual}"
}

@test "golden: chunked-json" {
  # --json with chunking: chunks[] array has multiple entries.
  local actual exit_code
  actual="$(smoosh --docs --no-interactive --json --max-words 100 --output-dir "${GOLDEN_OUT}" "${GOLDEN_REPO}" 2>/dev/null)"
  exit_code=$?
  [[ "${exit_code}" -eq 0 ]] || fail "smoosh exited with code ${exit_code}"
  actual="$(normalise "${actual}")"
  golden_compare "chunked-json.golden" "${actual}"
}
