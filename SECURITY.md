# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in smoosh, please report it
responsibly.

**Do not open a public issue.** Instead:

- Open a [private security advisory](https://github.com/K1-R1/smoosh/security/advisories/new)
  on GitHub.

## Scope

smoosh is a local CLI tool that reads files and writes output to disk.
It does not run a server, accept network connections, or process
untrusted input beyond the filenames and contents of git-tracked files.

Security-relevant areas:

- **Secrets detection** — smoosh includes a basic pattern scanner for
  common secret formats (AWS keys, GitHub PATs, PEM blocks). This is a
  convenience feature, not a security guarantee. For thorough scanning,
  use [gitleaks](https://github.com/gitleaks/gitleaks) or
  [truffleHog](https://github.com/trufflesecurity/trufflehog).
- **Remote clone** — `smoosh <url>` clones a repository into a temp
  directory with `core.hooksPath=/dev/null` to disable post-checkout
  hooks. The temp directory is cleaned up on exit.
- **Filename handling** — all filenames are handled with `printf '%s'`
  (never `echo`) and `--` before file arguments to prevent injection
  via crafted filenames.

## Supported Versions

Only the latest release is supported with security fixes.
