#!/usr/bin/env bats
# Tests for Phase 10: edge cases, adversarial filenames, XML safety.
# shellcheck disable=SC2154,SC2034 # SC2154: bats vars; SC2034: globals used by sourced smoosh.

load 'test_helper/common-setup'

setup_file() {
  export EDGE_REPO
  EDGE_REPO="$(mktemp -d)"

  # Adversarial filenames that could break naive shell handling.
  printf '# dash-start\n' >"${EDGE_REPO}/-leading-dash.md"
  printf '# dollar\n' >"${EDGE_REPO}/dollar-\$HOME.md"
  printf '# backtick\n' >"${EDGE_REPO}/back\`tick.md"
  printf '# single quote\n' >"${EDGE_REPO}/it'\''s-a-file.md"
  printf '# brackets\n' >"${EDGE_REPO}/file[1].md"

  # XML content that could break CDATA sections.
  printf '# CDATA break test\n\nThis has ]]> in it which must be escaped.\n' \
    >"${EDGE_REPO}/cdata-break.md"

  # File without a trailing newline.
  printf 'no newline at end' >"${EDGE_REPO}/no-newline.md"

  # Empty file.
  printf '' >"${EDGE_REPO}/empty.md"

  # Normal file.
  printf '# Normal\n\nThis is fine.\n' >"${EDGE_REPO}/normal.md"

  git -C "${EDGE_REPO}" init -q
  git -C "${EDGE_REPO}" config user.email "test@example.com"
  git -C "${EDGE_REPO}" config user.name "Test"
  git -C "${EDGE_REPO}" add -A
  git -C "${EDGE_REPO}" commit -q -m "init"

  # Separate repo with only binary files (for --all MIME filter test).
  export BINARY_REPO
  BINARY_REPO="$(mktemp -d)"
  printf '\x89PNG\r\n\x1a\n' >"${BINARY_REPO}/image.png"
  printf '# Normal\n' >"${BINARY_REPO}/doc.md"
  git -C "${BINARY_REPO}" init -q
  git -C "${BINARY_REPO}" config user.email "test@example.com"
  git -C "${BINARY_REPO}" config user.name "Test"
  git -C "${BINARY_REPO}" add -A
  git -C "${BINARY_REPO}" commit -q -m "init"
}

teardown_file() {
  [[ -d "${EDGE_REPO-}" ]] && rm -rf "${EDGE_REPO}"
  [[ -d "${BINARY_REPO-}" ]] && rm -rf "${BINARY_REPO}"
}

setup() {
  rm -rf "${EDGE_REPO}/_smooshes"
  rm -rf "${BINARY_REPO}/_smooshes"
}

# ---------------------------------------------------------------------------
# Adversarial filenames
# ---------------------------------------------------------------------------

@test "file starting with dash is processed safely" {
  run smoosh "${EDGE_REPO}"
  assert_success
  local out
  out="$(cat "${EDGE_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" == *"leading-dash.md"* ]]
}

@test "file with dollar sign in name is processed" {
  run smoosh "${EDGE_REPO}"
  assert_success
  local out
  out="$(cat "${EDGE_REPO}/_smooshes/"*.md 2>/dev/null)"
  # shellcheck disable=SC2016 # Intentional: checking literal $HOME in filename.
  [[ "${out}" == *'$HOME'* ]]
}

@test "file with backtick in name is processed" {
  run smoosh "${EDGE_REPO}"
  assert_success
  local out
  out="$(cat "${EDGE_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" == *'back`tick'* ]]
}

@test "file with bracket in name is processed" {
  run smoosh "${EDGE_REPO}"
  assert_success
  local out
  out="$(cat "${EDGE_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" == *"file[1].md"* ]]
}

# ---------------------------------------------------------------------------
# XML CDATA safety
# ---------------------------------------------------------------------------

@test "--format xml escapes ]]> in file content" {
  smoosh --format xml "${EDGE_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${EDGE_REPO}/_smooshes/"*.xml 2>/dev/null)"
  # The raw sequence ]]> must not appear unescaped inside a CDATA section.
  # It should be replaced with ]]]]><![CDATA[>
  [[ "${out}" != *"]]>"* ]] || [[ "${out}" == *"]]]]><![CDATA[>"* ]]
}

@test "--format xml output contains valid CDATA wrappers" {
  smoosh --format xml "${EDGE_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${EDGE_REPO}/_smooshes/"*.xml 2>/dev/null)"
  [[ "${out}" == *"<![CDATA["* ]]
  [[ "${out}" == *"]]>"* ]] # closing CDATA
}

@test "--format xml --line-numbers escapes ]]> in file content" {
  smoosh --format xml --line-numbers "${EDGE_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${EDGE_REPO}/_smooshes/"*.xml 2>/dev/null)"
  # Raw ]]> must not appear unescaped; it should be split as ]]]]><![CDATA[>
  [[ "${out}" != *"]]>"* ]] || [[ "${out}" == *"]]]]><![CDATA[>"* ]]
}

# ---------------------------------------------------------------------------
# Binary file handling
# ---------------------------------------------------------------------------

@test "--all mode excludes binary PNG via MIME check" {
  smoosh --all "${BINARY_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${BINARY_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" != *"image.png"* ]]
}

@test "--all mode includes text file alongside binary" {
  smoosh --all "${BINARY_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${BINARY_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" == *"doc.md"* ]]
}

# ---------------------------------------------------------------------------
# Empty file handling
# ---------------------------------------------------------------------------

@test "empty file appears in output" {
  smoosh "${EDGE_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${EDGE_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" == *"empty.md"* ]]
}

@test "file without trailing newline is included" {
  run smoosh "${EDGE_REPO}"
  assert_success
  local out
  out="$(cat "${EDGE_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" == *"no-newline.md"* ]]
}

# ---------------------------------------------------------------------------
# Empty repository (no matching files)
# ---------------------------------------------------------------------------

@test "repo with no matching files exits 3" {
  local empty_repo
  empty_repo="$(mktemp -d)"
  printf 'not-markdown\n' >"${empty_repo}/data.bin"
  git -C "${empty_repo}" init -q
  git -C "${empty_repo}" config user.email "t@t.com"
  git -C "${empty_repo}" config user.name "T"
  git -C "${empty_repo}" add -A
  git -C "${empty_repo}" commit -q -m "init"

  run smoosh "${empty_repo}"
  rm -rf "${empty_repo}"
  [[ "${status}" -eq 3 ]]
}

@test "empty repo error message suggests --code or --all" {
  local empty_repo
  empty_repo="$(mktemp -d)"
  printf 'data\n' >"${empty_repo}/data.bin"
  git -C "${empty_repo}" init -q
  git -C "${empty_repo}" config user.email "t@t.com"
  git -C "${empty_repo}" config user.name "T"
  git -C "${empty_repo}" add -A
  git -C "${empty_repo}" commit -q -m "init"

  run smoosh "${empty_repo}"
  rm -rf "${empty_repo}"
  assert_output --partial "--code"
}

# ---------------------------------------------------------------------------
# Batch word count accuracy
# ---------------------------------------------------------------------------

@test "batch word count matches individual wc -w for fixture files" {
  _load_smoosh
  REPO_ROOT="${EDGE_REPO}"
  INCLUDE_HIDDEN="false"
  EXCLUDE_PATTERNS=""
  ONLY_PATTERNS=""
  INCLUDE_PATTERNS=""
  MODE="docs"
  OUTPUT_DIR=""

  resolve_extensions
  discover_files
  batch_word_counts

  local i mismatches=0
  for i in "${!FILES[@]}"; do
    local abs="${REPO_ROOT}/${FILES[i]}"
    local expected
    expected="$(wc -w <"${abs}" 2>/dev/null | tr -d ' ')"
    local got="${WORD_COUNTS[i]-0}"
    if [[ "${expected}" != "${got}" ]]; then
      mismatches=$((mismatches + 1))
    fi
  done
  [[ "${mismatches}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Output directory already exists
# ---------------------------------------------------------------------------

@test "running smoosh twice does not fail (output dir already exists)" {
  smoosh "${EDGE_REPO}" >/dev/null 2>&1
  run smoosh "${EDGE_REPO}"
  assert_success
}

# ---------------------------------------------------------------------------
# Output directory error paths
# ---------------------------------------------------------------------------

@test "--output-dir creation failure exits 7" {
  # Create a file where the output directory should be — mkdir -p will fail.
  local blocker
  blocker="$(mktemp -d)/not-a-dir"
  printf '' >"${blocker}"
  run smoosh --output-dir "${blocker}/subdir" "${EDGE_REPO}"
  rm -f "${blocker}"
  [[ "${status}" -eq 7 ]]
}

@test "--output-dir outside repo root prints warning" {
  local ext_dir
  ext_dir="$(mktemp -d)"
  run smoosh --output-dir "${ext_dir}" "${EDGE_REPO}"
  rm -rf "${ext_dir}"
  assert_output --partial "outside the repository root"
}

@test "--output-dir outside repo does not modify .gitignore" {
  local ext_dir
  ext_dir="$(mktemp -d)"
  local before=""
  [[ -f "${EDGE_REPO}/.gitignore" ]] && before="$(cat "${EDGE_REPO}/.gitignore")"
  run smoosh --output-dir "${ext_dir}" "${EDGE_REPO}"
  assert_success
  local after=""
  [[ -f "${EDGE_REPO}/.gitignore" ]] && after="$(cat "${EDGE_REPO}/.gitignore")"
  [[ "${before}" == "${after}" ]]
  rm -rf "${ext_dir}"
}

@test "symlink .gitignore is not followed during auto-update" {
  local sym_repo
  sym_repo="$(mktemp -d)"
  printf '# test\n' >"${sym_repo}/readme.md"
  local target="${sym_repo}/real-gitignore"
  printf 'existing\n' >"${target}"
  ln -sf "real-gitignore" "${sym_repo}/.gitignore"
  git -C "${sym_repo}" init -q
  git -C "${sym_repo}" config user.email "test@example.com"
  git -C "${sym_repo}" config user.name "Test"
  git -C "${sym_repo}" add -A
  git -C "${sym_repo}" commit -q -m "init"
  local before
  before="$(cat "${target}")"
  run smoosh "${sym_repo}"
  assert_success
  assert_output --partial ".gitignore is a symlink"
  local after
  after="$(cat "${target}")"
  [[ "${before}" == "${after}" ]]
  rm -rf "${sym_repo}"
}

# ---------------------------------------------------------------------------
# Unreadable file during processing
# ---------------------------------------------------------------------------

@test "unreadable file is skipped with warning" {
  local unread_repo
  unread_repo="$(mktemp -d)"
  printf '# A\n' >"${unread_repo}/a.md"
  printf '# B\n' >"${unread_repo}/b.md"
  git -C "${unread_repo}" init -q
  git -C "${unread_repo}" config user.email "t@t.com"
  git -C "${unread_repo}" config user.name "T"
  git -C "${unread_repo}" add -A
  git -C "${unread_repo}" commit -q -m "init"

  # Make one file unreadable after git tracks it.
  chmod 000 "${unread_repo}/b.md"
  run smoosh "${unread_repo}"
  chmod 644 "${unread_repo}/b.md"
  rm -rf "${unread_repo}"
  assert_output --partial "not readable"
}
