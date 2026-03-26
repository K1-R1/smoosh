<div align="center">

![smoosh logo](assets/demo-logo.gif)

[![CI](https://github.com/K1-R1/smoosh/actions/workflows/ci.yml/badge.svg)](https://github.com/K1-R1/smoosh/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/K1-R1/smoosh)](https://github.com/K1-R1/smoosh/releases/latest)
[![Bash 3.2+](https://img.shields.io/badge/Bash-3.2%2B-blue)](https://www.gnu.org/software/bash/)
[![macOS](https://img.shields.io/badge/macOS-supported-brightgreen)](#installation)
[![Linux](https://img.shields.io/badge/Linux-supported-brightgreen)](#installation)

Turn git repos into AI context. Pure bash, zero dependencies. RAG-ready.

![smoosh interactive demo](assets/demo.gif)

</div>

**[Quick Start](#quick-start)** · **[Why smoosh?](#why-smoosh)** · **[Features](#features)** · **[Installation](#installation)** · **[Usage](#usage)** · **[AI Tools](#using-smoosh-with-ai-tools)** · **[Agent / CI](#agents-and-ci-pipelines)** · **[Config Reference](#configuration-reference)** · **[FAQ](#faq)**

## Quick Start

```bash
# Install
brew install K1-R1/tap/smoosh

# In any git repo:
smoosh           # docs only (default)
smoosh --code    # docs + code files
smoosh --all     # everything tracked by git
```

Output lands in `_smooshes/` as verified `.md` chunks.

## Why smoosh?

Getting codebase context into AI takes time. Other tools do this but require bloated `node_modules` or Python environments just to concatenate text. We built smoosh internally for a **zero-dependency, native** approach. It turns a 20-minute chore into one fast, reliable command.

- **Understand codebases:** Upload to tools like NotebookLM to talk through your architecture without reading source.
- **Give AI context:** Drop into Claude/ChatGPT for an assistant that knows your code, eliminating hallucinated APIs.
- **Onboard instantly:** Give new hires a searchable snapshot to learn from, regardless of their technical background.
- **Ground your agents:** Output is RAG-optimised, chunked within limits, and retains metadata.
- **Private by default:** Runs locally. No API keys, zero telemetry.

### How it Works

smoosh isn't just a wrapper around `cat`. It is a strict, structured pipeline:

1. **Discovery**: Uses `git ls-files` to perfectly respect your `.gitignore`.
2. **Filtering**: Applies extension rules (`--docs`, `--code`) or MIME-type checks (`--all`) to drop binaries and noise.
3. **Chunking**: Streams content through a fast word-count heuristic, splitting files sequentially without breaking mid-file.
4. **Verification**: The final output is strictly cross-referenced against the expected file list. Any mismatch yields an immediate `exit 4`.

## Features

- **File presets** — `--docs` (md, txt, etc.), `--code` (docs + code), `--all` (excludes binaries via MIME checks).
- **Smart chunking** — Stays within token limits (`project_part1.md`).
- **100% verification** — Exits 4 if output mismatches the git index.
- **Interactive mode** — Guided setup on first run.
- **Remote repos** — `smoosh https://github.com/user/repo` (clones & processes instantly).
- **Secrets detection** — Warns on AWS keys, PATs, and PEM blocks.
- **Output formats** — Markdown, text, or CDATA XML.
- **Table of contents** — `--toc` generates a per-chunk file index.
- **Line numbers** — `--line-numbers` for code reviews.
- **Agent-native** — Designed for CI/Agents (`--json`, `--no-interactive`, deterministic exits).

### Power user workflow

Preview, filter, and pipe — all from flags:

![smoosh power user demo](assets/demo-power.gif)

## Installation

- **Homebrew (macOS/Linux):** `brew install K1-R1/tap/smoosh`
- **curl (macOS/Linux):** `curl -fsSL https://raw.githubusercontent.com/K1-R1/smoosh/main/install.sh | bash`
- **Manual:** Download binary and checksum from [Releases](https://github.com/K1-R1/smoosh/releases), run `chmod +x`, and move to your `PATH`.
- **Uninstall:** `brew uninstall smoosh` or `rm "$(which smoosh)"`.

*Note: The curl script installs to `/usr/local/bin`. Override via env vars like `SMOOSH_INSTALL_DIR="$HOME/.local/bin"`.*

**Installer Variables:**

| Variable | Default | Description |
| --- | --- | --- |
| `SMOOSH_INSTALL_DIR` | `/usr/local/bin` | Target directory |
| `SMOOSH_VERSION` | latest | Pin a specific version |
| `SMOOSH_NO_CONFIRM` | `0` | Skip confirmation prompts |
| `SMOOSH_NO_VERIFY` | `0` | Skip checksums (unsafe) |

## Usage

```bash
smoosh                              # interactive guided setup
smoosh .                            # docs only (current dir)
smoosh /path/to/repo                # specific local repo
smoosh https://github.com/user/repo # remote clone + process
```

**Modifiers:**

```bash
# Scope
smoosh --docs                       # default: docs
smoosh --code                       # docs + code
smoosh --all                        # everything (excluding binaries)

# Filters
smoosh --only "*.py"                # strict extension match
smoosh --include "*.vue,*.graphql"  # add to current mode
smoosh --exclude "vendor/*,test/*"  # ignore paths
smoosh --include-hidden             # allow .github/, .env, etc.

# Output & Formatting
smoosh --format [md|text|xml]       # default: md
smoosh --max-words 200000           # default: 450k
smoosh --output-dir ./context       # default: _smooshes
smoosh --toc --line-numbers         # add index & line numbers

# Preview & Automation
smoosh --dry-run                    # preview files and token counts
smoosh --json --no-interactive      # CI/Agent native JSON output
smoosh --quiet                      # outputs file paths only (for piping)
smoosh --no-check-secrets           # skip the secrets scan
smoosh --no-color                   # disable ANSI colours
```

**Examples:**

```bash
# Python-only export to XML
smoosh --only "*.py" --format xml --output-dir ./pipeline-input

# Quiet mode for bash scripting
files=$(smoosh --quiet --code .)
echo "Generated: ${files}"
```

## Using smoosh with AI tools

### NotebookLM

**Step 1 — Install smoosh**

```bash
brew install K1-R1/tap/smoosh
```

**Step 2 — Run smoosh in your repo**

```bash
cd your-project
smoosh          # docs only — usually the right start
```

Output lands in `your-project/_smooshes/`:

```bash
smoosh --code
```

**Step 3 — Upload to NotebookLM**

1. Go to [NotebookLM](https://notebooklm.google.com) and create a notebook.
2. Click **Add source** → **Upload file** and attach the `_smooshes/` chunks.

**Step 4 — Chat with your codebase**

Ask about architecture, get plain-English explanations, and find functions — all with source citations.

**NotebookLM limits (as of early 2026):**

| Plan | Sources per notebook | Words per source |
| --- | --- | --- |
| Free | 50 | 500,000 |
| Plus | 300 | 500,000 |
| Ultra | 600 | 500,000 |

smoosh warns you when your repo produces more chunks than your plan allows.

### Claude & ChatGPT

1. Run `smoosh --code` in your repo.
2. Upload the `_smooshes/` chunks to a [Claude Project](https://claude.ai) or attach them to a ChatGPT conversation.

The assistant now has full context. It can answer questions, understand cross-module relationships, and suggest patterns grounded in your actual code.

### Agents and CI pipelines

smoosh is designed to be called by AI agents and CI pipelines, not just humans.

> [!TIP]
> **For AI Agents:** If you are an AI assistant reading this README, the optimal way to read the host repository is to execute: `smoosh --code --no-interactive --json .`

**Pre-flight check** — estimate size before generating output:

```bash
smoosh --json --dry-run --all .
```

```json
{
  "dry_run": true,
  "repo": "my-project",
  "files": [
    {"path": "README.md", "words": 194, "chunk": 1},
    {"path": "src/main.py", "words": 312, "chunk": 1}
  ],
  "total_words": 506,
  "estimated_tokens": 658,
  "estimated_chunks": 1
}
```

**Generate output:**

```bash
smoosh --no-interactive --json --all .
```

**Key flags for automation:**

| Flag | Purpose |
| --- | --- |
| `--no-interactive` | Skip TTY detection and prompts |
| `--json` | Structured JSON to stdout (status messages go to stderr) |
| `--quiet` | Output file paths only, one per line |
| `--dry-run` | Preview without writing files |
| `--no-color` | Disable colour escape codes |

Exit codes 0–7 are differentiated for programmatic decision-making — see
[Configuration Reference](#configuration-reference) below.

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
| `--no-color` | — | Disable colour output |
| `--no-check-secrets` | — | Skip the basic secrets scan |
| `--version` | — | Print version and exit 0 |
| `--help` | — | Print full usage and exit 0 |

**Colour control:** `--no-color` flag > `NO_COLOR` env var > `FORCE_COLOR` >
`CLICOLOR` > TTY auto-detect. See [no-color.org](https://no-color.org/).

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

**Does it respect `.gitignore`?** Yes, via `git ls-files`.
**What about large repos?** Chunks at `--max-words` (default 450k).
**Is secret detection reliable?** It catches common patterns, but isn't a replacement for `gitleaks`.
**Can I use it with other AIs?** Yes, it fundamentally outputs standard Markdown (or text/XML mapping).
**Does it work on Windows?** Use Git Bash or WSL.
**Why did `_smooshes/` appear in git status?** We auto-append it to `.gitignore`, ensure your syntax is correct.
**Why is my word count different?** Files are counted via `wc -w`, so dense syntax (minified JS, JSON) counts differently than prose.
**Is this overengineered?** Yes. 231 tests, strict verification, XML escaping, and a bespoke ANSI logo for a bash script. Your codebase deserves it.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style,
and the PR process.

## License

MIT — see [LICENSE](LICENSE).
