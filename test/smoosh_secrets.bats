#!/usr/bin/env bats
# Tests for Phase 6: secrets detection.

load 'test_helper/common-setup'

# Fixture files use officially sanctioned placeholder values (not real credentials).
#   AWS: AKIAIOSFODNN7EXAMPLE (official AWS documentation placeholder)
#   GitHub PAT: ghp_ + 36 alphanumeric chars (structural placeholder)
#   Private key: truncated/invalid PEM block header only (no actual key material)

setup_file() {
  SECRETS_REPO="$(mktemp -d)"
  export SECRETS_REPO
  SAFE_REPO="$(mktemp -d)"
  export SAFE_REPO

  # ---- secrets-repo ----

  # safe.md — normal markdown prose, no patterns
  printf '# Guide\n\nThis is a guide about configuration.\n' \
    >"${SECRETS_REPO}/safe.md"

  # safe.py — Python code with no secrets
  printf '#!/usr/bin/env python3\ndef greet():\n    return "hello"\n' \
    >"${SECRETS_REPO}/safe.py"

  # aws_config.py — AWS Access Key ID (official documentation placeholder)
  printf '# AWS config\nACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"\n' \
    >"${SECRETS_REPO}/aws_config.py"

  # keys.txt — private key block header (structural, no key material)
  printf '%s\n' '-----BEGIN RSA PRIVATE KEY-----' '(placeholder)' \
    '-----END RSA PRIVATE KEY-----' >"${SECRETS_REPO}/keys.txt"

  # github_ci.sh — GitHub PAT structural placeholder (ghp_ + 36 alnum chars)
  printf '#!/bin/bash\nGH_TOKEN="ghp_1234567890abcdefghijklmnopqrstuvwxyz"\n' \
    >"${SECRETS_REPO}/github_ci.sh"

  # anthropic_key.sh — Anthropic API key placeholder (sk-ant-api + 2 digits + 95 alnum chars)
  printf '#!/bin/bash\nANTHROPIC_API_KEY="sk-ant-api01-%s"\n' \
    "$(printf 'x%.0s' {1..95})" \
    >"${SECRETS_REPO}/anthropic_key.sh"

  # docs/password-guide.md — "password" in documentation prose (must NOT flag)
  mkdir -p "${SECRETS_REPO}/docs"
  printf '# Password Management Guide\n\nAlways choose a strong password.\n' \
    >"${SECRETS_REPO}/docs/password-guide.md"

  git -C "${SECRETS_REPO}" init -q
  git -C "${SECRETS_REPO}" config user.email "test@example.com"
  git -C "${SECRETS_REPO}" config user.name "Test"
  git -C "${SECRETS_REPO}" add -A
  git -C "${SECRETS_REPO}" commit -q -m "init"

  # ---- safe-repo: no secrets at all ----
  printf '# README\n\nThis repo has no secrets.\n' >"${SAFE_REPO}/README.md"
  printf '#!/usr/bin/env python3\nprint("hello")\n' >"${SAFE_REPO}/main.py"

  git -C "${SAFE_REPO}" init -q
  git -C "${SAFE_REPO}" config user.email "test@example.com"
  git -C "${SAFE_REPO}" config user.name "Test"
  git -C "${SAFE_REPO}" add -A
  git -C "${SAFE_REPO}" commit -q -m "init"
}

teardown_file() {
  [[ -d "${SECRETS_REPO-}" ]] && rm -rf "${SECRETS_REPO}"
  [[ -d "${SAFE_REPO-}" ]] && rm -rf "${SAFE_REPO}"
}

setup() {
  rm -rf "${SECRETS_REPO}/_smooshes"
  rm -rf "${SAFE_REPO}/_smooshes"
}

# ---------------------------------------------------------------------------
# Pattern detection
# ---------------------------------------------------------------------------

@test "detects AWS Access Key ID pattern" {
  run smoosh --code "${SECRETS_REPO}"
  assert_output --partial "AWS Access Key"
}

@test "detects private key block" {
  run smoosh --all "${SECRETS_REPO}"
  assert_output --partial "Private Key Block"
}

@test "detects GitHub PAT" {
  run smoosh --code "${SECRETS_REPO}"
  assert_output --partial "GitHub PAT"
}

@test "detects Anthropic API key" {
  run smoosh --code "${SECRETS_REPO}"
  assert_output --partial "Anthropic API Key"
}

@test "warning output includes disclaimer" {
  run smoosh --code "${SECRETS_REPO}"
  assert_output --partial "not a security guarantee"
}

@test "warning mentions gitleaks" {
  run smoosh --code "${SECRETS_REPO}"
  assert_output --partial "gitleaks"
}

# ---------------------------------------------------------------------------
# False positive prevention
# ---------------------------------------------------------------------------

@test "markdown docs with password word are not flagged" {
  # docs/password-guide.md has no credential assignment — prose only.
  # The generic pattern (password = "...") should not match plain prose.
  run smoosh --docs "${SECRETS_REPO}"
  # Neither safe.md nor password-guide.md match any pattern.
  refute_output --partial "password-guide.md: line"
  refute_output --partial "safe.md: line"
}

# ---------------------------------------------------------------------------
# File exclusion
# ---------------------------------------------------------------------------

@test "flagged files are excluded from output" {
  # --code finds safe.py, aws_config.py, github_ci.sh.
  # After secrets scan: aws_config.py and github_ci.sh are removed.
  # Only safe.py goes into the chunk.
  smoosh --code "${SECRETS_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${SECRETS_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" != *"### File: aws_config.py"* ]]
  [[ "${out}" != *"### File: github_ci.sh"* ]]
  [[ "${out}" == *"safe.py"* ]]
}

@test "--no-check-secrets includes flagged files" {
  smoosh --code --no-check-secrets "${SECRETS_REPO}" >/dev/null 2>&1
  local out
  out="$(cat "${SECRETS_REPO}/_smooshes/"*.md 2>/dev/null)"
  [[ "${out}" == *"aws_config.py"* ]]
}

@test "--no-check-secrets suppresses warning" {
  run smoosh --code --no-check-secrets "${SECRETS_REPO}"
  refute_output --partial "Potential secrets"
}

@test "--json --no-check-secrets emits secrets_scan_skipped true" {
  run smoosh --code --json --no-check-secrets "${SAFE_REPO}"
  assert_output --partial '"secrets_scan_skipped": true'
}

@test "--json with scan emits secrets_excluded not secrets_scan_skipped" {
  run smoosh --code --json "${SAFE_REPO}"
  assert_output --partial '"secrets_excluded"'
  refute_output --partial '"secrets_scan_skipped"'
}

# ---------------------------------------------------------------------------
# Safe repo — no false alarms
# ---------------------------------------------------------------------------

@test "safe repo produces no secrets warning" {
  run smoosh --all "${SAFE_REPO}"
  assert_success
  refute_output --partial "Potential secrets"
}

# ---------------------------------------------------------------------------
# Secret values never printed
# ---------------------------------------------------------------------------

@test "actual secret value is not printed in warning" {
  run smoosh --code "${SECRETS_REPO}"
  # The AWS placeholder value must never appear in the warning output.
  refute_output --partial "AKIAIOSFODNN7EXAMPLE"
}

@test "GitHub PAT value is not printed in warning" {
  run smoosh --code "${SECRETS_REPO}"
  refute_output --partial "ghp_1234567890abcdefghijklmnopqrstuvwxyz"
}
