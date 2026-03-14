#!/usr/bin/env bash
# Common test setup loaded by all smoosh bats test files.
# Usage: load 'test_helper/common-setup'

# shellcheck disable=SC2154 # BATS_TEST_DIRNAME is set by the bats test runner.
SMOOSH_ROOT="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"

# Add smoosh to PATH so tests can invoke it directly by name.
export PATH="${SMOOSH_ROOT}:${PATH}"

# Disable commit signing for all fixture repos.
# The sandbox blocks ~/.ssh reads, so SSH-signed commits fail with status 128.
# GIT_CONFIG_COUNT overrides global gpg.format=ssh without touching user config.
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=commit.gpgsign
export GIT_CONFIG_VALUE_0=false

# Load bats helper libraries (installed as git submodules).
load "${SMOOSH_ROOT}/test/test_helper/bats-support/load"
load "${SMOOSH_ROOT}/test/test_helper/bats-assert/load"
load "${SMOOSH_ROOT}/test/test_helper/bats-file/load"

# ---------------------------------------------------------------------------
# Source helper
# ---------------------------------------------------------------------------

# _load_smoosh
# Source smoosh without executing main, then initialise colour and symbol vars.
_load_smoosh() {
  # shellcheck disable=SC2154 source=smoosh
  source "${BATS_TEST_DIRNAME}/../smoosh"
  setup_colours
  setup_symbols
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

# create_simple_repo DIR
# Create a minimal git repo with 3 markdown files for basic discovery tests.
create_simple_repo() {
  local dir="${1}"
  mkdir -p "${dir}/docs"
  printf '# README\n\nThis is the readme.\n' >"${dir}/README.md"
  printf '# Guide\n\nThis is the guide.\n' >"${dir}/docs/guide.md"
  printf '# API\n\nThis is the API reference.\n' >"${dir}/docs/api.md"
  git -C "${dir}" init -q
  git -C "${dir}" config user.email "test@example.com"
  git -C "${dir}" config user.name "Test"
  git -C "${dir}" add -A
  git -C "${dir}" commit -q -m "init"
}
