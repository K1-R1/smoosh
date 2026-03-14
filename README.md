<div align="center">

![smoosh logo](demo-logo.gif)

[![CI](https://github.com/K1-R1/smoosh/actions/workflows/ci.yml/badge.svg)](https://github.com/K1-R1/smoosh/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/K1-R1/smoosh)](https://github.com/K1-R1/smoosh/releases/latest)
[![Bash 3.2+](https://img.shields.io/badge/Bash-3.2%2B-blue)](https://www.gnu.org/software/bash/)
[![macOS](https://img.shields.io/badge/macOS-supported-brightgreen)](#installation)
[![Linux](https://img.shields.io/badge/Linux-supported-brightgreen)](#installation)

Turn any git repo into AI-ready context — for NotebookLM, Claude Projects,
ChatGPT, or your own RAG pipeline. Pure bash, zero dependencies.

![smoosh interactive demo](demo.gif)

</div>

## Quick Start

```bash
# Install
brew install K1-R1/tap/smoosh

# In any git repo:
smoosh           # docs only (default)
smoosh --code    # docs + code files
smoosh --all     # everything tracked by git
```

Output lands in `_smooshes/` — chunked, verified `.md` files ready to
drop into your AI tool of choice.

## Why smoosh?

AI tools are powerful when they have the right context. The hard part is
getting an entire codebase into them — in the right format, within token
limits, without accidentally including secrets. smoosh handles all of that
in one command.

**Understand your codebase in plain English.** Upload smoosh output to
NotebookLM and ask questions about architecture, module boundaries, or what
that obscure utility actually does. Technical knowledge becomes accessible to
everyone on the team — not just the people who wrote the code. Product,
design, and leadership get answers without reading source files.

**Give AI real context, not guesswork.** Drop the output into Claude Projects
or ChatGPT and get an assistant that actually knows your codebase. No
hallucinated function signatures, no "I don't have access to that file." It
can answer questions about any file, understand cross-module relationships,
and suggest changes that fit your existing patterns.

**Onboard in hours, not weeks.** New team members get a searchable snapshot
of the entire codebase before they even clone the repo. Pair it with
NotebookLM and they can ask the codebase questions on day one.

**Ground your agents in fact.** smoosh output is optimised for
retrieval-augmented generation (RAG) — chunked within token limits, with
file path metadata preserved. Instead of hallucinating, your agents retrieve
real context from your actual code.

**Private by default.** Everything runs locally. Your code never leaves your
machine unless you choose to upload it. No API keys, no SaaS accounts, no
telemetry. Private repos need this. Public ones benefit too.

| | smoosh | doing it by hand |
| --- | --- | --- |
| **Stays within AI token limits** | automatic chunking | manual splitting and counting |
| **Every file accounted for** | 100% verified — exits on mismatch | hope for the best |
| **Secrets excluded** | detected and flagged | easy to forget |
| **Works on remote repos** | one command | clone, navigate, copy |
| **Agent/CI ready** | `--json`, exit codes 0–7 | custom scripting |
| **Dependencies** | git + bash | — |

## Features

- **File type presets** — `--docs` (default: md, rst, txt, adoc), `--code` (adds all code extensions), `--all` (everything)
- **Smart chunking** — stays within word limits; names chunks `project_part1.md`, `project_part2.md`
- **100% verification** — every chunk is integrity-checked against the expected file list; exits 4 on mismatch
- **Interactive mode** — guided first-run experience: scans your repo, shows a breakdown, lets you pick a mode
- **Remote repositories** — `smoosh https://github.com/user/repo` — clones and processes in one step
- **Secrets detection** — warns about AWS keys, GitHub PATs, PEM private key blocks; honest about scope
- **Output formats** — Markdown (default), plain text, XML with CDATA sections
- **Table of contents** — `--toc` generates a per-chunk file index with word counts
- **Line numbers** — `--line-numbers` for code review workflows
- **Dry run** — `--dry-run` shows what would be included with word counts, no files written
- **Agent-native** — designed to be called by AI agents and CI pipelines, not just humans. `--json` for structured output, `--no-interactive` for headless runs, exit codes 0–7 for programmatic decision-making

### Power user workflow

Preview, filter, and pipe — all from flags:

![smoosh power user demo](demo-power.gif)

## Installation

### Homebrew (macOS / Linux)

```bash
brew install K1-R1/tap/smoosh
```

### curl (macOS / Linux / Git Bash)

```bash
curl -fsSL https://raw.githubusercontent.com/K1-R1/smoosh/v1.0.0/install.sh | bash
```

Installs to `/usr/local/bin`. Override with:

```bash
SMOOSH_INSTALL_DIR="$HOME/.local/bin" curl -fsSL .../install.sh | bash
```

### Manual

```bash
curl -fsSL https://github.com/K1-R1/smoosh/releases/latest/download/smoosh -o smoosh
chmod +x smoosh
sudo mv smoosh /usr/local/bin/
```

## Usage

### Basics

```bash
smoosh                              # interactive mode when run with no args
smoosh .                            # current directory (docs mode)
smoosh /path/to/repo                # specific local repo
smoosh https://github.com/user/repo # remote repo — clone + process in one step
```

### File types

```bash
smoosh --docs    # markdown, rst, txt, adoc, asciidoc, org, tex (default)
smoosh --code    # docs + py, js, ts, rs, go, java, rb, and many more
smoosh --all     # everything tracked by git (binary files excluded via MIME check)
```

### Filtering

```bash
smoosh --only "*.py"                   # Python files only (overrides mode)
smoosh --include "*.vue,*.graphql"     # add extensions to current mode
smoosh --exclude "vendor/*,test/*"     # exclude matching paths
smoosh --include-hidden                # include .github/, .env.example, dotfiles
```

### Output options

```bash
smoosh --format md             # Markdown with ### File: headers (default)
smoosh --format text           # plain text with === separators
smoosh --format xml            # XML with CDATA sections (for structured pipelines)
smoosh --toc                   # table of contents in each chunk
smoosh --line-numbers          # prefix each line with its number
smoosh --max-words 200000      # custom chunk size (default: 450,000)
smoosh --output-dir ./context  # write to a custom directory
```

### Preview and automation

```bash
smoosh --dry-run               # show file list + word counts, no output written
smoosh --quiet                 # print output paths only, one per line (for piping)
smoosh --json                  # structured JSON to stdout
smoosh --no-interactive        # skip interactive mode, use flag defaults
smoosh --no-check-secrets      # skip the secrets scan
```

### Combining flags

```bash
# Full code review context with TOC and line numbers
smoosh --code --toc --line-numbers

# Python-only export for a RAG pipeline
smoosh --only "*.py" --format xml --output-dir ./pipeline-input

# Preview what a remote repo contains before processing
smoosh --dry-run https://github.com/user/repo

# Quiet mode for scripting
files=$(smoosh --quiet --code .)
echo "Generated: ${files}"
```

## Using smoosh with AI tools

### NotebookLM

**Step 1 — Install smoosh** (30 seconds)

```bash
brew install K1-R1/tap/smoosh
```

**Step 2 — Run smoosh in your repo** (seconds to a minute)

```bash
cd your-project
smoosh          # docs only — usually the right start
```

Output lands in `your-project/_smooshes/`. For code too:

```bash
smoosh --code
```

**Step 3 — Upload to NotebookLM**

1. Go to [notebooklm.google.com](https://notebooklm.google.com) and create a notebook.
2. Click **Add source** → **Upload file**.
3. Upload each `.md` file from `_smooshes/`.
4. For large repos with multiple chunks, upload all of them.

**Step 4 — Chat with your codebase**

Ask about architecture, find functions, generate onboarding guides, or get
plain-English explanations of complex modules.

**NotebookLM limits (as of early 2026):**

| Plan | Sources per notebook | Words per source |
| --- | --- | --- |
| Free | 50 | 500,000 |
| Plus | 300 | 500,000 |
| Ultra | 600 | 500,000 |

smoosh warns you when your repo produces more chunks than your plan allows.

### Claude Projects

1. Run `smoosh --code` in your repo.
2. Create a new [Claude Project](https://claude.ai) and open the project knowledge panel.
3. Upload the files from `_smooshes/`.

Claude now has full context over your codebase — ask about any file, request
changes that fit your existing patterns, or get architecture explanations
grounded in your actual code.

### ChatGPT

1. Run `smoosh --code` in your repo.
2. Open a ChatGPT conversation and attach the files from `_smooshes/`.
3. For ongoing use, add them as knowledge files in a
   [custom GPT](https://chatgpt.com/gpts/editor).

Works with any ChatGPT plan that supports file uploads.

## Configuration Reference

| Flag | Default | Description |
| --- | --- | --- |
| `--docs` | yes | Include markdown, RST, TXT, AsciiDoc, Org, TeX |
| `--code` | — | Include docs + all code file types |
| `--all` | — | Include everything tracked by git |
| `--only GLOB` | — | Restrict to matching extensions (overrides mode) |
| `--include GLOB` | — | Add extensions to the current mode |
| `--exclude GLOB` | — | Exclude matching paths (comma-separated) |
| `--include-hidden` | — | Include dotfiles and dot-directories |
| `--max-words N` | 450000 | Words per output chunk |
| `--format FORMAT` | `md` | Output format: `md`, `text`, or `xml` |
| `--toc` | — | Add a table of contents to each chunk |
| `--line-numbers` | — | Prefix each line with its line number |
| `--output-dir PATH` | `_smooshes` | Directory for output files |
| `--dry-run` | — | Preview only — no output files written |
| `--quiet` | — | Print output paths only (stdout) |
| `--json` | — | Structured JSON to stdout |
| `--no-interactive` | — | Skip interactive mode even in a TTY |
| `--no-check-secrets` | — | Skip the basic secrets scan |
| `--version` | — | Print version and exit 0 |
| `--help` | — | Print full usage and exit 0 |

**Exit codes:**

| Code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | Invalid flags or arguments |
| 2 | Path not found or not a git repository |
| 3 | No matching files for current mode/filters |
| 4 | Verification failed — expected/actual file list mismatch |
| 5 | Remote clone failed (network, auth) |
| 7 | Write permission denied |
| 130 | Interrupted (Ctrl-C) |

## FAQ

**Does smoosh respect `.gitignore`?**
Yes. It uses `git ls-files` which honours `.gitignore`. Untracked,
ignored files are excluded by default.

**What about large repos?**
smoosh chunks output at `--max-words` (default 450,000 words). Large repos
produce multiple files named `project_part1.md`, `project_part2.md`, and so on.

**Is the secrets detection reliable?**
No — it catches common patterns (AWS access keys, GitHub PATs, PEM private key
blocks) but is not a substitute for dedicated tools like
[gitleaks](https://github.com/gitleaks/gitleaks) or
[truffleHog](https://github.com/trufflesecurity/trufflehog). smoosh says this
clearly when it warns.

**Can I use smoosh with other AI tools?**
Yes — Gemini, Copilot, local models, custom pipelines. The output is plain
Markdown, compatible with anything that accepts text files. Use
`--format text` or `--format xml` if your tool prefers a different format.

**Does it work on Windows?**
smoosh is tested on macOS and Linux. On Windows, use Git Bash or WSL.

**The `_smooshes/` directory appeared in my git status — is that normal?**
smoosh adds `_smooshes/` to your `.gitignore` automatically on first run.
If it still appears, check that your `.gitignore` syntax is correct.

**Why is my word count different from what I expected?**
smoosh counts words using `wc -w`, which splits on whitespace. Code files
with dense syntax (JSON, minified JS) count differently than prose.

**Is it overengineered for a shell script?**
Absolutely. 198 tests, 100% file inclusion verification, CDATA escaping for
XML output, and a box-drawing letter logo. But your codebase deserves to be
smooshed properly.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style,
and the PR process.

## License

MIT — see [LICENSE](LICENSE).
