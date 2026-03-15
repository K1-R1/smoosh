#!/usr/bin/env bash
# smoosh installer — https://github.com/K1-R1/smoosh
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/K1-R1/smoosh/v1.0.0/install.sh | bash
#
# Options (set via environment variables):
#   SMOOSH_INSTALL_DIR  — installation directory (default: /usr/local/bin)
#   SMOOSH_VERSION      — specific version to install (default: latest)
#   SMOOSH_NO_CONFIRM   — set to 1 to skip the confirmation prompt
#   SMOOSH_NO_VERIFY    — set to 1 to skip checksum verification (unsafe)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

readonly REPO="K1-R1/smoosh"
readonly BINARY_NAME="smoosh"

INSTALL_DIR="${SMOOSH_INSTALL_DIR:-/usr/local/bin}"
REQUESTED_VERSION="${SMOOSH_VERSION:-}"
NO_CONFIRM="${SMOOSH_NO_CONFIRM:-0}"
NO_VERIFY="${SMOOSH_NO_VERIFY:-0}"

# ---------------------------------------------------------------------------
# Terminal colours — disabled when not a TTY
# ---------------------------------------------------------------------------

if [[ -t 1 ]]; then
  BOLD="$(printf '\033[1m')"
  GREEN="$(printf '\033[32m')"
  YELLOW="$(printf '\033[33m')"
  RED="$(printf '\033[31m')"
  RESET="$(printf '\033[0m')"
else
  BOLD="" GREEN="" YELLOW="" RED="" RESET=""
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info() { printf '%s\n' "${GREEN}info${RESET}  ${*}"; }
warn() { printf '%s\n' "${YELLOW}warn${RESET}  ${*}" >&2; }
error() { printf '%s\n' "${RED}error${RESET} ${*}" >&2; }
die() { error "${@}"; exit 1; }

need_cmd() {
  command -v "${1}" >/dev/null 2>&1 || die "Required command not found: ${1}"
}

# ---------------------------------------------------------------------------
# Cleanup — runs on EXIT to remove temp files
# ---------------------------------------------------------------------------

TMP_DIR=""
cleanup() {
  [[ -n "${TMP_DIR}" ]] && rm -rf -- "${TMP_DIR}"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------

OS=""
ARCH=""

detect_platform() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "${os}" in
  Darwin) OS="macOS" ;;
  Linux) OS="Linux" ;;
  MINGW* | MSYS* | CYGWIN*) OS="Windows" ;;
  *) die "Unsupported operating system: ${os}" ;;
  esac

  case "${arch}" in
  x86_64 | amd64) ARCH="x86_64" ;;
  arm64 | aarch64) ARCH="arm64" ;;
  *) die "Unsupported architecture: ${arch}" ;;
  esac
}

# ---------------------------------------------------------------------------
# Version resolution
# ---------------------------------------------------------------------------

VERSION=""

resolve_version() {
  if [[ -n "${REQUESTED_VERSION}" ]]; then
    [[ "${REQUESTED_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
      die "SMOOSH_VERSION must be a semantic version (e.g. 1.0.0), got: ${REQUESTED_VERSION}"
    VERSION="${REQUESTED_VERSION}"
    return
  fi

  need_cmd curl
  info "Fetching latest version..."
  local latest
  latest="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" |
    grep '"tag_name"' |
    sed 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/')"
  [[ -n "${latest}" ]] || die "Could not determine latest version. Check https://github.com/${REPO}/releases"
  VERSION="${latest}"
}

# ---------------------------------------------------------------------------
# Download and verify
# ---------------------------------------------------------------------------

sha256_verify() {
  local file="${1}" expected="${2}"
  local actual

  if command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "${file}" | awk '{print $1}')"
  elif command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "${file}" | awk '{print $1}')"
  else
    warn "No SHA256 tool found (shasum/sha256sum) — skipping checksum verification"
    return 0
  fi

  [[ "${expected}" == "${actual}" ]] || die "Checksum mismatch — download may be corrupted. Aborting."
}

download_and_install() {
  local base_url="https://github.com/${REPO}/releases/download/v${VERSION}"
  local download_url="${base_url}/${BINARY_NAME}"
  local checksum_url="${base_url}/${BINARY_NAME}.sha256"

  TMP_DIR="$(mktemp -d)"
  local tmp_bin="${TMP_DIR}/${BINARY_NAME}"
  local tmp_sha="${TMP_DIR}/${BINARY_NAME}.sha256"

  info "Downloading ${BINARY_NAME} v${VERSION}..."
  curl -fsSL --progress-bar "${download_url}" -o "${tmp_bin}" ||
    die "Download failed. Check your connection or visit https://github.com/${REPO}/releases"

  info "Verifying checksum..."
  if curl -fsSL "${checksum_url}" -o "${tmp_sha}" 2>/dev/null; then
    local expected
    expected="$(awk '{print $1}' "${tmp_sha}")"
    sha256_verify "${tmp_bin}" "${expected}"
  elif [[ "${NO_VERIFY}" == "1" ]]; then
    warn "SMOOSH_NO_VERIFY=1 set — skipping checksum verification (unsafe)"
  else
    die "No .sha256 file found for v${VERSION} — aborting to protect against an unverified install. Set SMOOSH_NO_VERIFY=1 to skip (unsafe)."
  fi

  # Install: try without sudo first, fall back to sudo.
  info "Installing to ${INSTALL_DIR}/${BINARY_NAME}..."
  if install -m 755 "${tmp_bin}" "${INSTALL_DIR}/${BINARY_NAME}" 2>/dev/null; then
    : # success without sudo
  elif sudo install -m 755 "${tmp_bin}" "${INSTALL_DIR}/${BINARY_NAME}"; then
    : # success with sudo
  else
    die "Installation failed. Try: SMOOSH_INSTALL_DIR=\$HOME/.local/bin bash install.sh"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  need_cmd git
  need_cmd curl

  detect_platform
  resolve_version

  # Check for existing installation.
  local existing=""
  if command -v "${BINARY_NAME}" >/dev/null 2>&1; then
    existing="$("${BINARY_NAME}" --version 2>/dev/null |
      grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
  fi

  printf '\n'
  printf '%s\n' "${BOLD}smoosh installer${RESET}"
  printf '  Version   : %s\n' "${VERSION}"
  printf '  Install to: %s/%s\n' "${INSTALL_DIR}" "${BINARY_NAME}"
  printf '  Platform  : %s %s\n' "${OS}" "${ARCH}"
  if [[ -n "${existing}" ]]; then
    printf '  Upgrading : v%s → v%s\n' "${existing}" "${VERSION}"
  fi
  printf '\n'

  if [[ "${NO_CONFIRM}" != "1" && -t 0 ]]; then
    printf 'Proceed with installation? [y/N] '
    read -r answer
    case "${answer}" in
    [yY] | [yY][eE][sS]) ;;
    *) printf 'Installation cancelled.\n'; exit 0 ;;
    esac
    printf '\n'
  fi

  download_and_install

  printf '\n'
  printf '%s\n' "${GREEN}✔ smoosh v${VERSION} installed successfully!${RESET}"
  printf '\n'
  printf '  Get started:\n'
  printf '    smoosh              — interactive mode (run inside a git repo)\n'
  printf '    smoosh --help       — full usage reference\n'
  printf '    smoosh --code .     — include code files\n'
  printf '    smoosh --dry-run    — preview without writing files\n'
  printf '\n'
}

main ${1+"${@}"}
