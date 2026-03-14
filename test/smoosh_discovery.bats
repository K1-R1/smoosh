#!/usr/bin/env bats
# Tests for file discovery (Phase 3): discover_files(), resolve_target(),
# get_extensions_for_mode(), resolve_extensions().

load 'test_helper/common-setup'

# All fixture repos are created in setup_file() as temp directories so we
# don't commit nested git repos.

setup_file() {
  # ---- simple-repo: 3 markdown files in nested dirs ----
  SIMPLE_REPO="$(mktemp -d)"
  export SIMPLE_REPO
  mkdir -p "${SIMPLE_REPO}/docs"
  printf '# README\n\nHello world.\n' >"${SIMPLE_REPO}/README.md"
  printf '# Guide\n\nThis is the guide.\n' >"${SIMPLE_REPO}/docs/guide.md"
  printf '# API\n\nAPI reference.\n' >"${SIMPLE_REPO}/docs/api.md"
  printf '*.log\nbuild/\n' >"${SIMPLE_REPO}/.gitignore"
  printf 'ignored content\n' >"${SIMPLE_REPO}/ignored.log"
  git -C "${SIMPLE_REPO}" init -q
  git -C "${SIMPLE_REPO}" config user.email "test@example.com"
  git -C "${SIMPLE_REPO}" config user.name "Test"
  git -C "${SIMPLE_REPO}" add -A
  git -C "${SIMPLE_REPO}" commit -q -m "init"

  # ---- mixed-repo: docs + code + binary + ignored ----
  MIXED_REPO="$(mktemp -d)"
  export MIXED_REPO
  mkdir -p "${MIXED_REPO}/src"
  printf '# README\n' >"${MIXED_REPO}/README.md"
  printf '# print("hello")\n' >"${MIXED_REPO}/src/main.py"
  printf 'const x = 1;\n' >"${MIXED_REPO}/src/index.ts"
  printf 'fn main() {}\n' >"${MIXED_REPO}/src/lib.rs"
  printf 'key: value\n' >"${MIXED_REPO}/config.yml"
  printf '{"name":"pkg"}\n' >"${MIXED_REPO}/package.json"
  # Create a minimal PNG (valid 1x1 pixel binary file)
  printf '\x89PNG\r\n\x1a\n' >"${MIXED_REPO}/image.png"
  printf 'ignored\n' >"${MIXED_REPO}/.gitignore_content"
  printf '.gitignore_content\n' >"${MIXED_REPO}/.gitignore"
  git -C "${MIXED_REPO}" init -q
  git -C "${MIXED_REPO}" config user.email "test@example.com"
  git -C "${MIXED_REPO}" config user.name "Test"
  git -C "${MIXED_REPO}" add -A
  git -C "${MIXED_REPO}" commit -q -m "init"

  # ---- edge-repo: files with spaces, hidden files, empty file ----
  EDGE_REPO="$(mktemp -d)"
  export EDGE_REPO
  mkdir -p "${EDGE_REPO}/.github/workflows"
  printf '# Normal\n' >"${EDGE_REPO}/normal.md"
  printf '# Space name\n' >"${EDGE_REPO}/file with spaces.md"
  printf '' >"${EDGE_REPO}/empty.md"
  printf '# Hidden config\n' >"${EDGE_REPO}/.hidden.md"
  printf '# Workflow\n' >"${EDGE_REPO}/.github/workflows/ci.yml"
  printf '# Env example\n' >"${EDGE_REPO}/.env.example"
  git -C "${EDGE_REPO}" init -q
  git -C "${EDGE_REPO}" config user.email "test@example.com"
  git -C "${EDGE_REPO}" config user.name "Test"
  git -C "${EDGE_REPO}" add -A
  git -C "${EDGE_REPO}" commit -q -m "init"

  # ---- symlink-repo: repo with a tracked symlink ----
  SYMLINK_REPO="$(mktemp -d)"
  export SYMLINK_REPO
  printf '# Real file\n\nContent here.\n' >"${SYMLINK_REPO}/real.md"
  ln -s real.md "${SYMLINK_REPO}/link.md"
  git -C "${SYMLINK_REPO}" init -q
  git -C "${SYMLINK_REPO}" config user.email "test@example.com"
  git -C "${SYMLINK_REPO}" config user.name "Test"
  git -C "${SYMLINK_REPO}" add -A
  git -C "${SYMLINK_REPO}" commit -q -m "init"
}

teardown_file() {
  [[ -d "${SIMPLE_REPO-}" ]] && rm -rf "${SIMPLE_REPO}"
  [[ -d "${MIXED_REPO-}" ]] && rm -rf "${MIXED_REPO}"
  [[ -d "${EDGE_REPO-}" ]] && rm -rf "${EDGE_REPO}"
  [[ -d "${SYMLINK_REPO-}" ]] && rm -rf "${SYMLINK_REPO}"
}

# ---------------------------------------------------------------------------
# Basic discovery — docs mode (default)
# ---------------------------------------------------------------------------

@test "discovers .md files in simple repo" {
  run smoosh --dry-run "${SIMPLE_REPO}"
  assert_success
  assert_output --partial "README.md"
}

@test "docs mode finds all 3 markdown files" {
  run smoosh --dry-run "${SIMPLE_REPO}"
  assert_success
  # Should list 3 files
  [[ "$(printf '%s\n' "${output}" | grep -c '\.md')" -ge 3 ]]
}

@test "respects .gitignore — ignored.log not included" {
  run smoosh --dry-run "${SIMPLE_REPO}"
  refute_output --partial "ignored.log"
}

# ---------------------------------------------------------------------------
# Mode switching
# ---------------------------------------------------------------------------

@test "--code mode includes .py files" {
  run smoosh --code --dry-run "${MIXED_REPO}"
  assert_success
  assert_output --partial "main.py"
}

@test "--code mode includes .ts files" {
  run smoosh --code --dry-run "${MIXED_REPO}"
  assert_output --partial "index.ts"
}

@test "--code mode includes .rs files" {
  run smoosh --code --dry-run "${MIXED_REPO}"
  assert_output --partial "lib.rs"
}

@test "--docs mode excludes .py files" {
  run smoosh --docs --dry-run "${MIXED_REPO}"
  refute_output --partial "main.py"
}

@test "--all mode includes yml files" {
  run smoosh --all --dry-run "${MIXED_REPO}"
  assert_success
  assert_output --partial "config.yml"
}

# ---------------------------------------------------------------------------
# --include / --only / --exclude
# ---------------------------------------------------------------------------

@test "--only restricts to specified extension" {
  run smoosh --only "*.py" --dry-run "${MIXED_REPO}"
  assert_success
  assert_output --partial "main.py"
  refute_output --partial "README.md"
}

@test "--include adds extension to docs mode" {
  run smoosh --include "*.yml" --dry-run "${MIXED_REPO}"
  assert_output --partial "config.yml"
  assert_output --partial "README.md"
}

@test "--exclude removes matching paths" {
  run smoosh --code --exclude "src/*" --dry-run "${MIXED_REPO}"
  refute_output --partial "main.py"
  refute_output --partial "index.ts"
}

# ---------------------------------------------------------------------------
# Hidden files
# ---------------------------------------------------------------------------

@test "hidden files are excluded by default" {
  run smoosh --dry-run "${EDGE_REPO}"
  refute_output --partial ".hidden.md"
  refute_output --partial ".env.example"
}

@test "--include-hidden includes dotfiles" {
  run smoosh --include-hidden --dry-run "${EDGE_REPO}"
  assert_output --partial ".hidden.md"
}

@test "--include-hidden includes .github directory files" {
  run smoosh --include-hidden --all --dry-run "${EDGE_REPO}"
  assert_output --partial ".github"
}

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

@test "files with spaces in names are handled" {
  run smoosh --dry-run "${EDGE_REPO}"
  assert_output --partial "file with spaces.md"
}

@test "empty files are included" {
  run smoosh --dry-run "${EDGE_REPO}"
  assert_output --partial "empty.md"
}

@test "output directory is excluded from discovery" {
  # Create output, then rediscover
  smoosh --dry-run "${SIMPLE_REPO}" >/dev/null 2>&1 || true
  run smoosh --dry-run "${SIMPLE_REPO}"
  refute_output --partial "_smooshes"
}

# ---------------------------------------------------------------------------
# Error cases
# ---------------------------------------------------------------------------

@test "non-git directory produces exit 2" {
  local tmp
  tmp="$(mktemp -d)"
  run smoosh --dry-run "${tmp}"
  assert_failure
  [[ "${status}" -eq 2 ]]
  rm -rf "${tmp}"
}

@test "non-existent path produces exit 2" {
  run smoosh --dry-run "/nonexistent/path/$(date +%s)"
  assert_failure
  [[ "${status}" -eq 2 ]]
}

# ---------------------------------------------------------------------------
# Symlink exclusion (local repos)
# ---------------------------------------------------------------------------

@test "symlinks in local repo are excluded from discovery" {
  run smoosh --dry-run "${SYMLINK_REPO}"
  assert_success
  assert_output --partial "real.md"
  refute_output --partial "link.md"
}
