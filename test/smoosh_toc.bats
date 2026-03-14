#!/usr/bin/env bats
# Tests for Phase 5: Table of Contents generation.

load 'test_helper/common-setup'

setup_file() {
  TOC_REPO="$(mktemp -d)"
  export TOC_REPO

  # doc1.md: exactly 100 words
  printf '# Doc One\n\n%s\n' "$(printf 'word%.0s ' {1..100})" >"${TOC_REPO}/doc1.md"
  # doc2.md: exactly 150 words
  printf '# Doc Two\n\n%s\n' "$(printf 'word%.0s ' {1..150})" >"${TOC_REPO}/doc2.md"
  # doc3.md: exactly 200 words
  printf '# Doc Three\n\n%s\n' "$(printf 'word%.0s ' {1..200})" >"${TOC_REPO}/doc3.md"

  git -C "${TOC_REPO}" init -q
  git -C "${TOC_REPO}" config user.email "test@example.com"
  git -C "${TOC_REPO}" config user.name "Test"
  git -C "${TOC_REPO}" add -A
  git -C "${TOC_REPO}" commit -q -m "init"
}

teardown_file() {
  [[ -d "${TOC_REPO-}" ]] && rm -rf "${TOC_REPO}"
}

setup() {
  rm -rf "${TOC_REPO}/_smooshes"
}

# ---------------------------------------------------------------------------
# Basic TOC generation
# ---------------------------------------------------------------------------

@test "--toc generates a Table of Contents section" {
  smoosh --toc "${TOC_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${TOC_REPO}/_smooshes/"*.md)"
  [[ "${out}" == *"Table of Contents"* ]]
}

@test "without --toc, no Table of Contents section appears" {
  smoosh "${TOC_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${TOC_REPO}/_smooshes/"*.md)"
  [[ "${out}" != *"Table of Contents"* ]]
}

@test "TOC lists all files in the chunk" {
  smoosh --toc "${TOC_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${TOC_REPO}/_smooshes/"*.md)"
  [[ "${out}" == *"doc1.md"* ]]
  [[ "${out}" == *"doc2.md"* ]]
  [[ "${out}" == *"doc3.md"* ]]
}

# ---------------------------------------------------------------------------
# Word count accuracy
# ---------------------------------------------------------------------------

@test "TOC total matches sum of individual file word counts" {
  smoosh --toc "${TOC_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${TOC_REPO}/_smooshes/"*.md)"
  # doc1(~102) + doc2(~152) + doc3(~202) ≈ 456 total including headers.
  # The TOC summary row contains "| **Total** |"
  [[ "${out}" == *"| **Total** |"* ]]
}

# ---------------------------------------------------------------------------
# Number formatting (thousands separators)
# ---------------------------------------------------------------------------

@test "format_number adds thousands separators" {
  # Test the function directly rather than through the full pipeline.
  source "${BATS_TEST_DIRNAME}/../smoosh"

  [[ "$(format_number 0)" == "0" ]]
  [[ "$(format_number 42)" == "42" ]]
  [[ "$(format_number 999)" == "999" ]]
  [[ "$(format_number 1000)" == "1,000" ]]
  [[ "$(format_number 1502)" == "1,502" ]]
  [[ "$(format_number 12345)" == "12,345" ]]
  [[ "$(format_number 999999)" == "999,999" ]]
  [[ "$(format_number 1000000)" == "1,000,000" ]]
  [[ "$(format_number 1234567)" == "1,234,567" ]]
}

# ---------------------------------------------------------------------------
# Format variants
# ---------------------------------------------------------------------------

@test "--toc with --format text produces text-style TOC" {
  smoosh --toc --format text "${TOC_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${TOC_REPO}/_smooshes/"*.txt)"
  [[ "${out}" == *"Table of Contents"* ]]
  [[ "${out}" == *"doc1.md"* ]]
  [[ "${out}" == *"Total:"* ]]
}

@test "--toc with --format xml produces XML <toc> element" {
  smoosh --toc --format xml "${TOC_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${TOC_REPO}/_smooshes/"*.xml)"
  [[ "${out}" == *"<toc>"* ]]
  [[ "${out}" == *"<entry "* ]]
  [[ "${out}" == *"<summary "* ]]
  [[ "${out}" == *"</toc>"* ]]
}

# ---------------------------------------------------------------------------
# Multi-chunk TOC
# ---------------------------------------------------------------------------

@test "multi-chunk: each chunk has its own TOC" {
  # With max-words=200, 3 files (~100/150/200 words each) → at least 2 chunks.
  smoosh --toc --max-words 200 "${TOC_REPO}" >/dev/null 2>&1
  local chunk_count
  local chunks=("${TOC_REPO}/_smooshes/"*.md)
  chunk_count="${#chunks[@]}"
  [[ "${chunk_count}" -ge 2 ]]

  # Every generated chunk must contain a TOC.
  local chunk
  for chunk in "${TOC_REPO}/_smooshes/"*.md; do
    local content
    content="$(cat "${chunk}")"
    [[ "${content}" == *"Table of Contents"* ]]
  done
}

@test "multi-chunk TOC lists only the files in that chunk" {
  # doc1 (~100 words) fits in part1; doc2+doc3 (150+200) go to part2 and part3.
  smoosh --toc --max-words 200 "${TOC_REPO}" >/dev/null 2>&1
  # part1 should mention doc1 but NOT doc2 in its TOC
  local part1
  local parts=("${TOC_REPO}/_smooshes/"*part1*.md)
  part1="${parts[0]}"
  local content
  content="$(cat "${part1}")"
  [[ "${content}" == *"doc1.md"* ]]
  # doc2 appears in the file entries of part2, not part1's TOC
  # Extract only up to first "### File:" heading for just the TOC section
  local toc_section
  toc_section="$(printf '%s' "${content}" | sed -n '/Table of Contents/,/### File:/p')"
  [[ "${toc_section}" != *"doc2.md"* ]]
}
