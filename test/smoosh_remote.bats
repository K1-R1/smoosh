#!/usr/bin/env bats
# Tests for Phase 8: Remote Repos.
#
# URL detection and normalisation tests run in all environments (no network).
# Actual clone tests require network — skipped unless SMOOSH_NETWORK_TESTS=1.
# shellcheck disable=SC2154 # BATS_TEST_DIRNAME is set by the bats test runner.

load 'test_helper/common-setup'

# ---------------------------------------------------------------------------
# _normalise_url unit tests (no network required)
# ---------------------------------------------------------------------------

@test "_normalise_url: github.com shorthand becomes HTTPS URL" {
  _load_smoosh
  [[ "$(_normalise_url "github.com/user/repo")" == "https://github.com/user/repo" ]]
}

@test "_normalise_url: gitlab.com shorthand becomes HTTPS URL" {
  _load_smoosh
  [[ "$(_normalise_url "gitlab.com/user/repo")" == "https://gitlab.com/user/repo" ]]
}

@test "_normalise_url: bitbucket.org shorthand becomes HTTPS URL" {
  _load_smoosh
  [[ "$(_normalise_url "bitbucket.org/user/repo")" == "https://bitbucket.org/user/repo" ]]
}

@test "_normalise_url: full HTTPS URL is unchanged" {
  _load_smoosh
  [[ "$(_normalise_url "https://github.com/user/repo")" == "https://github.com/user/repo" ]]
}

@test "_normalise_url: SSH URL is unchanged" {
  _load_smoosh
  [[ "$(_normalise_url "git@github.com:user/repo.git")" == "git@github.com:user/repo.git" ]]
}

# ---------------------------------------------------------------------------
# clone_remote error handling via fake git (no network required)
# ---------------------------------------------------------------------------

# Write a fake git that exits 128 on clone (simulates auth/network failure).
_setup_failing_git() {
  FAKE_GIT_DIR="$(mktemp -d)"
  # shellcheck disable=SC2016 # Intentional: writing literal $1/$@ into a script file.
  printf '%s\n' '#!/bin/sh' \
    'if [ "$1" = "clone" ]; then printf "fatal: unable to access\n" >&2; exit 128; fi' \
    'exec git "$@"' \
    >"${FAKE_GIT_DIR}/git"
  chmod +x "${FAKE_GIT_DIR}/git"
}

@test "failed clone exits with code 5" {
  _setup_failing_git
  local smoosh_script="${BATS_TEST_DIRNAME}/../smoosh"
  # Run in a subshell with the fake git first in PATH.
  run env PATH="${FAKE_GIT_DIR}:${PATH}" bash "${smoosh_script}" \
    "https://example.com/repo.git" 2>&1
  rm -rf "${FAKE_GIT_DIR}"
  [[ "${status}" -eq 5 ]]
}

@test "failed clone shows actionable error message" {
  _setup_failing_git
  local smoosh_script="${BATS_TEST_DIRNAME}/../smoosh"
  run env PATH="${FAKE_GIT_DIR}:${PATH}" bash "${smoosh_script}" \
    "https://example.com/repo.git" 2>&1
  rm -rf "${FAKE_GIT_DIR}"
  assert_output --partial "Failed to clone"
}

# ---------------------------------------------------------------------------
# Network tests (skipped unless SMOOSH_NETWORK_TESTS=1)
# ---------------------------------------------------------------------------

@test "clones a public HTTPS repo and produces output (network)" {
  if [[ "${SMOOSH_NETWORK_TESTS-}" != "1" ]]; then
    skip "set SMOOSH_NETWORK_TESTS=1 to enable network tests"
  fi
  local out_dir
  out_dir="$(mktemp -d)"
  run smoosh --output-dir "${out_dir}" "https://github.com/nicowillis/smoosh-test-fixture.git"
  assert_success
  local files=("${out_dir}"/*.md)
  [[ -e "${files[0]}" ]]
  rm -rf "${out_dir}"
}
