---
description: Run the project's build, test, and formatting checks
---

# Build and Test Workflow

Use this workflow to run all tests, formatters, and linters for the `smoosh` project.

// turbo-all

1. Run pre-commit checks (lint, format, spelling):

   ```bash
   prek run
   ```

2. Run all tests:

   ```bash
   bats test/*.bats
   ```

3. Lint the bash script:

   ```bash
   shellcheck smoosh
   ```

4. Format check the bash script:

   ```bash
   shfmt -d -i 2 smoosh
   ```

5. Verify usage output:

   ```bash
   ./smoosh --help
   ```
