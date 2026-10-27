# Universal Windows 11 Agent Guidelines & Safety Guardrails

## 1. Command Execution Protocol (Verify Before Execute)

- **Do Not Guess Command Syntax**: NEVER rely on model memory or unverified assumptions for CLI parameters, flags, or syntax. Always verify using `<tool> --help` or official documentation before execution.
- **Subshell Stdin Protection**: Automated background processes pipe standard input. Never invoke commands that wait for stdin stream when omitted with arguments (e.g., ALWAYS specify search paths explicitly: use `rg -n "pattern" .` instead of bare `rg "pattern"`).
- **Prioritize Installed Modern CLI Binaries**: Always prefer modern high-performance CLI tools over legacy Windows/PowerShell commands (`findstr`, `Select-String`, `Get-ChildItem -Recurse`, `sed`):
  - Webpage & documentation extraction: `webread <url>` or `webread --llms <url>`
  - Codebase statistics: `tokei .` (instant SLOC and language breakdown with < 100 tokens)
  - Code search: `rg -n -M 200 "PATTERN" .` (always use `-M 200` to prevent minified bloat; use `-g "!dist/**"` or `-g "!node_modules/**"`)
  - File finding: `fd -e <ext>` (or `fd "PATTERN" .`)
  - Syntax AST search: `ast-grep run -p "PATTERN" -l <lang> <file>`
  - File preview with line ranges: `bat --paging=never --style=plain -r <start>:<end> <file>`
  - In-place text replacement: `sd "pattern" "replacement" <file>` (STRICTLY avoid `sed`)
  - Tabular data analysis: `xsv headers <file.csv>` / `xsv slice -i 1-5 <file.csv>` or `duckdb -c "<SQL>"` (never dump raw CSV)
  - Embedded database querying: `sqlite3 <file.db> ".schema"` / `sqlite3 -header -column <file.db> "SELECT ... LIMIT 5"`
  - Fast HTTP API probing: `xh --headers GET <url>` / `xh POST <url> <key>=<val>` (avoids verbose curl flags)
  - Directory & disk space analysis: `dust -d 2 -p` (tree visualization of disk usage)
  - JSON inspection & transformation: `jq -c "<filter>" <file>` (prefer compact `-c` output)
  - YAML / XML / TOML inspection & editing: `yq "<filter>" <file>` (supports `-i` for in-place updates)
  - PDF text inspection: `pdftotext -f <start> -l <end> <file.pdf> -`
  - Shell script formatting: `shfmt -i 2 -ci -w <file>`
  - CI workflow validation: `actionlint` locally before staging `.github/workflows/*.yml`
  - Unified Node.js & Frontend Toolchain: `vp`, `vpx <tool>` (e.g., `vpx oxfmt`, `vpx oxlint`), `vpr <script>`
- **Zero Throwaway Script Policy (No Scratch File Pollution)**:
  - NEVER generate ephemeral script files (e.g. `temp.py`, `scratch.js`, `test.ps1`, `query.sh`) on disk for basic data transformations, string parsing, or multi-command glue tasks.
  - Execute multi-command automation strictly in-memory via `pwsh -NoLogo -NoProfile -Command '...'` (Tier 2) or direct CLI pipes (Tier 1).
  - Reserve Python and Node.js strictly for project-native workflows or tasks requiring specialized external dependencies (e.g. pandas, torch, AST parsers).

---

## 2. Git Collaboration & Safety Gate

- **Global Pre-Commit Hook Invariant**:
  - The system enforces a global Git hook (`~/.config/git/hooks/pre-commit`) via `core.hooksPath` that blocks direct commits when `ANTIGRAVITY_AGENT=1`.
- **Staging Allowed**: You MAY assist the user with `git status`, `git diff`, and `git add <files>` to prepare changes cleanly.
- **Strictly Prohibit `git commit` / `git push`**: You are STRICTLY FORBIDDEN from executing `git commit`, `git push`, or modifying git history.
- **Human Collaboration Output**: When changes are staged and ready to commit, summarize the changes and provide a copy-pasteable Conventional Commit command block for the human developer to review and execute:
  ```bash
  git commit -m "feat(scope): concise description of changes"
  ```

---

## 3. Token Efficiency Discipline

- **Line Length Truncation (`-M 200`)**: Always specify `-M 200` (or `--max-columns 200`) when invoking `rg` to prevent single-line minified bundles, lockfiles, or data rows from consuming tens of thousands of tokens.
- **Hierarchical Progressive Search**: Prioritize `rg -l "PATTERN" .` (list files with matches) or `rg -c` (match counts) before executing verbose line searches.
- **Bat Style Stripping**: Always invoke `bat` with `--style=plain` or `--style=numbers` (combined with `--paging=never`) to strip token-costly border decorations.
- **Compact Structured Outputs**: Prefer `jq -c` (compact output) and project necessary fields (`jq '{field1, field2}'`) rather than dumping full multi-level JSON structures.
- **Terminal Output Circuit Breakers**: When running test suites, build tasks, or git queries with risk of voluminous logs, pipe through truncation filters (e.g. `| Select-Object -First 50` or `git diff --stat` before detailed diffs).
- **Ignore Build Artifacts**: Never read build output folders (`dist/`, `build/`, `out/`, `node_modules/`), compiled binaries, or lockfiles unless explicitly requested.
- **Targeted File Inspection**: Use `read_file` with explicit `StartLine` and `EndLine` (< 100 lines) or `bat --paging=never --style=plain -r <start>:<end> <file>` instead of full-file dumps.

---

## 4. Mandatory Post-Edit Formatting Protocol

- **Immediate Formatting After File Edits**:
  - Whenever you create or modify Markdown (`*.md`) or JSON (`*.json`) files via file tools (`edit_file`, `write_file`, `sd`), you MUST immediately format those files using `vpx oxfmt <files>` before taking any further action, running checks, or responding to the user.
- **Zero Unformatted Files Policy**:
  - Never leave modified Markdown or JSON files unformatted on disk.

---

## 5. PowerShell 7 (`pwsh`) Execution & Automation Protocol

- **Runtime Isolation**:
  - Strictly distinguish between legacy in-box **Windows PowerShell 5.1** (`powershell.exe`) and high-performance **PowerShell 7+** (`pwsh.exe`).
  - NEVER modify, replace, or symlink `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`.
- **Modern PowerShell 7 Invocations**:
  - Whenever parallel processing, modern language operators, or UTF-8 non-ASCII output streams are required, explicitly invoke `pwsh -NoLogo -NoProfile -Command '...'`.
  - **Outer Shell Quoting**: Always wrap `pwsh -Command` parameters in single quotes (`'...'`) when called from an outer shell to prevent premature variable expansion.
  - **Native UTF-8 Stream Enforcement**: PowerShell 7 defaults to UTF-8 without BOM. Use `pwsh` for scripts producing non-ASCII terminal outputs to prevent legacy CP950/Big5 mojibake. Ensure outer console decoding guard: `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)`.
  - **Modern Syntax Utilization (PS 7+ Only)**: Leverage ternary operators (`$cond ? $a : $b`), null-coalescing (`$a ?? $b`, `$a ??= $b`), and pipeline chain operators (`&&`, `||`) in `pwsh` scripts (note: for bootstrap scripts like `scripts/install.ps1` that must also run on Windows PowerShell 5.1, stick to PS 5.1-compatible syntax).
  - **Array Unrolling & Indexing Guard**: Pipeline outputs unroll single items into scalar values. Indexing `[0]` on a scalar string extracts `[char]` (e.g. `'https://...'[0] == 'h'`). ALWAYS wrap pipeline or split outputs with `@(...)` before accessing `[0]`.
  - **Dual-Style CLI Flag Binding**: PowerShell scripts expecting cross-platform invocation should declare `[Parameter(ValueFromRemainingArguments = $true)] [string[]]$RemainingArgs` to parse GNU-style `--flag` options without throwing positional parameter errors.
  - **Parallel Batch Processing**: Utilize `ForEach-Object -Parallel` with `-ThrottleLimit` for batch operations (e.g. multi-file queries, hash calculation, multi-repo git sync) to minimize execution latency.
