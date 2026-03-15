# smoosh Acceptance Test Runbook

This document describes the manual acceptance tests for smoosh. Run these
before any major release or when the automated tests are insufficient to
verify a change — for example, when interactive mode, network behaviour, or
AI tool integration is involved.

All automated tests can be run with `bats test/*.bats`. The scenarios below
cover what cannot be automated: interactive TTY behaviour and end-to-end
upload flows with real AI tools.

---

## Setup

Install smoosh or build from source:

    brew install K1-R1/tap/smoosh   # installed release
    # or
    ./smoosh --version              # local dev build (run from repo root)

Pick a real git repository to test against — the smoosh repo itself works
well. All examples below use `.` for the current directory.

---

## 1. Interactive Mode

smoosh opens an interactive guided experience when called with no arguments
in a real terminal (TTY).

**Steps:**

1. Open a terminal (not inside a script or pipe).
2. Change into any git repository: `cd /path/to/some/repo`
3. Run `smoosh` with no arguments.

**Expected behaviour:**

- The logo and tagline appear.
- smoosh scans the repo and shows a summary table: docs, code, config, and
  other file counts with example extensions.
- A prompt asks which mode to use (`docs`, `code`, `all`, or `q` to quit).
- After selecting a mode, smoosh processes and writes output to `_smooshes/`.
- A summary table shows file count, word count, token estimate, and chunk count.

**Pass criteria:**

- [ ] Interactive prompt appears (not skipped)
- [ ] Repo scan table shows plausible file counts
- [ ] Selecting `docs` produces `.md` output files
- [ ] Output lands in `_smooshes/`
- [ ] No error messages or stack traces

---

## 2. Remote Repository

smoosh can clone and process a remote repo in a single command.

**Steps:**

    smoosh https://github.com/K1-R1/smoosh

**Expected behaviour:**

- smoosh clones the repo to a temp directory.
- Processes it in docs mode (default).
- Writes output to `_smooshes/` in the current directory (not inside the
  clone).
- Cleans up the temp clone on exit.

**Pass criteria:**

- [ ] Clone succeeds (no "Remote clone failed" error)
- [ ] Output files appear in `_smooshes/` of the working directory
- [ ] Output contains smoosh's own `README.md` content
- [ ] Temp clone is removed after the run

---

## 3. NotebookLM Upload

Verify that smoosh output can be uploaded to NotebookLM and queried.

**Steps:**

1. Run smoosh on a real codebase:

       cd /path/to/some/repo
       smoosh --code

2. Go to [notebooklm.google.com](https://notebooklm.google.com) and create
   a new notebook.
3. Click **Add source → Upload file**.
4. Upload each `.md` file from `_smooshes/`.
5. Wait for processing (usually 30–60 seconds).
6. Ask a question that can only be answered with the uploaded content, for
   example:
   - "What functions are defined in this codebase?"
   - "What does the main entry point do?"
   - "List all the files included in this upload."

**Pass criteria:**

- [ ] Upload succeeds (no error from NotebookLM)
- [ ] NotebookLM answers questions using specific file content (cites sources)
- [ ] Answer is not a hallucination (verifiable against the actual code)
- [ ] Word count per file is within NotebookLM's 500,000-word limit per source

**NotebookLM plan limits (early 2026):**

| Plan  | Max sources | Max words/source |
|-------|-------------|------------------|
| Free  | 50          | 500,000          |
| Plus  | 300         | 500,000          |
| Ultra | 600         | 500,000          |

---

## 4. Claude Projects Upload

Verify that smoosh output can be added to a Claude Project and queried.

**Steps:**

1. Run smoosh:

       smoosh --code

2. Go to [claude.ai](https://claude.ai) and open or create a Project.
3. Open the project knowledge panel.
4. Upload the files from `_smooshes/`.
5. Start a conversation and ask a code-specific question, for example:
   - "What language is the main entry point written in?"
   - "Are there any tests in this codebase?"

**Pass criteria:**

- [ ] Upload succeeds
- [ ] Claude answers using specific content from the uploaded files
- [ ] Claude does not claim it cannot access the files

---

## 5. ChatGPT Upload

Verify that smoosh output can be attached to a ChatGPT conversation.

**Steps:**

1. Run smoosh:

       smoosh --code

2. Open [chatgpt.com](https://chatgpt.com) and start a new conversation.
3. Attach the files from `_smooshes/` using the paperclip icon.
4. Ask a specific question about the uploaded codebase.

**Pass criteria:**

- [ ] Files attach without errors
- [ ] ChatGPT answers using content from the uploaded files
- [ ] For repos with multiple chunks: all chunks can be attached

---

## 6. Secrets Detection

Verify that secrets are flagged and excluded from output.

**Steps:**

1. Create a temporary test repo:

       mkdir /tmp/secrets-test && cd /tmp/secrets-test
       git init && git config user.email "t@t.com" && git config user.name "T"
       echo '# Docs' > README.md
       echo 'AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"' > creds.py
       git add -A && git commit -m "init"

2. Run smoosh:

       smoosh --code .

**Expected behaviour:**

- smoosh prints a secrets warning mentioning `creds.py`.
- The warning includes a disclaimer ("basic pattern matching only").
- `creds.py` does not appear in the output files.
- `README.md` appears in the output files.
- Exit code is 0 (secrets detected is a warning, not a failure).

**Pass criteria:**

- [ ] Warning appears on stderr
- [ ] `creds.py` content is absent from `_smooshes/` output
- [ ] `README.md` content is present in `_smooshes/` output
- [ ] Exit code is 0

---

## 7. Agent / CI Usage

Verify that smoosh works in a headless, non-interactive environment.

**Steps:**

    smoosh --code --no-interactive --json --quiet . 2>/dev/null

**Expected behaviour:** an error — `--json` and `--quiet` cannot be combined.

Then:

    smoosh --code --no-interactive --json . 2>/dev/null | jq .

**Expected behaviour:**

- Valid JSON is printed to stdout.
- JSON includes `repo`, `files_processed`, `total_words`, `chunks`, and
  `exit_code` fields.
- Exit code is 0.

**Pass criteria:**

- [ ] `--json` and `--quiet` together print an error and exit 1
- [ ] `--json` alone produces valid, parseable JSON
- [ ] `exit_code` in JSON matches the actual process exit code

---

## 8. Regression: Golden File Tests

The automated golden file tests (run as part of `bats test/*.bats`) verify
that smoosh output is byte-for-byte identical to the checked-in expected
files. Run them to confirm no regressions:

    bats test/smoosh_golden.bats

All 17 tests should pass.

If you intentionally change smoosh's output format (for example, adding a
new header field), regenerate the golden files:

    UPDATE_GOLDEN=1 bats test/smoosh_golden.bats

Then review `git diff test/golden/` to confirm the changes are intentional
before committing.

---

## Completing a Release Acceptance Run

Tick every checkbox above, then record the result:

| Scenario | Result | Notes |
|----------|--------|-------|
| 1. Interactive mode | Pass / Fail | |
| 2. Remote repository | Pass / Fail | |
| 3. NotebookLM upload | Pass / Fail | |
| 4. Claude Projects upload | Pass / Fail | |
| 5. ChatGPT upload | Pass / Fail | |
| 6. Secrets detection | Pass / Fail | |
| 7. Agent / CI usage | Pass / Fail | |
| 8. Golden file tests | Pass / Fail | |
