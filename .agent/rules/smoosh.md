# smoosh

Pure bash CLI tool. Zero external dependencies beyond git and standard POSIX tools.

## Constraints

- Bash 3.2 compatible (macOS ships 3.2). No associative arrays, no mapfile, no `${var,,}`, no named references.
- Single file (`smoosh`). No sourced libraries. Everything in one script.
- 2-space indentation. Functions <= 100 lines.
- All warnings from shellcheck must be resolved.
- Never use `echo "$var"` for filenames — use `printf '%s\n' "$var"`.
- Never use `sed -i` — write to temp file, then `mv`.
- Always use `--` before file arguments in commands.
- All non-content output goes to stderr.

## Testing

- Framework: bats-core with bats-assert and bats-support
- Fixtures in `test/fixtures/` — small git repos for each test scenario
- Every feature must have tests. Every edge case must have tests.

## Commits

- Use conventional commits: `feat:`, `fix:`, `test:`, `docs:`, `chore:`, `refactor:`.
- Sign every commit with `-s` (DCO requirement): `git commit -s`.
