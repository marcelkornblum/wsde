# justfile — wsde task runner
# Install: curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin
# Usage: just <recipe>  (just --list to see all)

set shell := ["bash", "-euo", "pipefail", "-c"]

ALPINE_VERSION := "3.14.8"
HTMX_VERSION   := "2.0.4"
TW_VERSION     := "4.2.2"
JS_DIR         := "src/static/js"
TAILWIND       := "./bin/tailwindcss"
TW_INPUT       := "src/styles/input.css"
TW_OUTPUT      := "src/static/css/output.css"
TW_CONTENT     := "src/**/templates/**/*.html"

# Show available recipes
default:
    @just --list

# ── Setup ────────────────────────────────────────────────────────────────────

# Full local setup: venv, hooks, vendor JS, Tailwind
setup:
    @echo "── Installing Python dependencies ──"
    uv sync
    @echo ""
    @echo "── Installing git hooks ──"
    just install-hooks
    @echo ""
    @echo "── Downloading vendor JS ──"
    just js-vendor
    @echo ""
    @echo "── Downloading Tailwind CSS standalone CLI ──"
    just tw-install
    @echo ""
    @echo "── Building Tailwind CSS ──"
    just tw-build
    @echo ""
    @echo "── Creating local.py settings override (if missing) ──"
    cp -n src/core/settings/local.py.tpl src/core/settings/local.py 2>/dev/null || true
    @echo ""
    @echo "✅  Setup complete. Run 'just runserver' to start developing."

# ── Development ───────────────────────────────────────────────────────────────

# Start the Django development server
runserver:
    uv run python manage.py runserver

# Open a Django shell
shell:
    uv run python manage.py shell

# Create a superuser interactively
superuser:
    uv run python manage.py createsuperuser

# Run Django migrations
migrate:
    uv run python manage.py migrate

# Create new Django migrations
makemigrations:
    uv run python manage.py makemigrations

# Fail if any migrations are missing
check-migrations:
    uv run python manage.py makemigrations --check --dry-run

# Run a manage.py command: just manage showmigrations
manage *args:
    uv run python manage.py {{ args }}

# ── Code quality ──────────────────────────────────────────────────────────────

# Run all quality gates: lint, types, migrations, tests. Run before every push.
ci:
    @echo "── ruff lint ──"
    uv run ruff check src/
    @echo "── ty type check ──"
    uv run ty check src/
    @echo "── migration check ──"
    uv run python manage.py makemigrations --check --dry-run
    @echo "── pytest ──"
    uv run pytest -v || test $? -eq 5
    @echo "✅  All checks passed."

# Run ruff linter and ty type checker
check:
    uv run ruff check src/
    uv run ty check src/

# Auto-fix lint issues and format code
fix:
    uv run ruff check --fix src/
    uv run ruff format src/

# Run ruff formatter only
format:
    uv run ruff format src/

# ── Testing ───────────────────────────────────────────────────────────────────

# Run the full test suite with pytest
test:
    uv run pytest -v

# Run specific tests: just test-one "test expression"
test-one filter:
    uv run pytest -v -k "{{ filter }}"

# Run e2e tests with Playwright
e2e:
    uv run pytest e2e/ -v

# ── Git hooks ─────────────────────────────────────────────────────────────────

# Install git hooks from .githooks/
install-hooks:
    git config core.hooksPath .githooks
    @echo "✅  Git hooks installed (using .githooks/ directory)."

# ── Agentic workflow ──────────────────────────────────────────────────────────
#
# Full start→done→PR lifecycle:
#
#   just work-new "Short title"                  # create + claim bd issue → prints id
#   just work-start my-branch [issue] ["title"]  # checkout main + pull + branch (+ claim)
#   just ci                                       # run all quality gates before pushing
#   just work-save "commit msg"                   # commit + push to current branch (existing PR, no bd)
#   just work-done "commit msg"                   # ci + commit + push (no bd, use before work-pr)
#   just work-pr "PR title" [issue]               # open PR then close bd issue (issue closed = PR open)
#
# bd rule: issue is closed when the PR is opened, not before and not on merge.
# work-save: no bd interaction — use for interim commits on an existing PR.
# work-done: no bd interaction — use for the final commit before opening a PR.
# work-pr:   closes the issue after the PR is open (pass the issue id here).

# Create and immediately claim a new bd issue; prints the issue id
work-new title:
    #!/usr/bin/env bash
    set -euo pipefail
    ISSUE_ID=$(bd q "{{ title }}")
    bd update "$ISSUE_ID" --claim
    echo "✅  Created and claimed $ISSUE_ID: {{ title }}"
    echo "    Next: just work-start <branch> $ISSUE_ID"

# Start work: checkout main, pull, create branch, optionally claim a bd issue.
# Usage:
#   just work-start my-branch           # branch only
#   just work-start my-branch bd-a1b2   # branch + claim existing issue
#   just work-start my-branch "" "New issue title"  # branch + create + claim new issue
work-start branch issue="" title="":
    #!/usr/bin/env bash
    set -euo pipefail
    if git show-ref --verify --quiet "refs/heads/{{ branch }}"; then
        echo "❌  Branch '{{ branch }}' already exists locally."
        echo "    Switch to it with: git checkout {{ branch }}"
        exit 1
    fi
    git checkout main
    git pull --ff-only origin main
    git checkout -b "{{ branch }}"
    if [[ -n "{{ title }}" ]]; then
        ISSUE_ID=$(bd q "{{ title }}")
        bd update "$ISSUE_ID" --claim
        echo "✅  Created and claimed $ISSUE_ID: {{ title }}"
    elif [[ -n "{{ issue }}" ]]; then
        bd update "{{ issue }}" --claim
        echo "✅  Claimed issue {{ issue }}"
    fi
    echo "✅  On branch '{{ branch }}', ready to work."

# Commit + push to the current branch without any issue or branch management.
# Use this when adding commits to an existing PR.
# Usage: just work-save "fix: tweak something"
work-save message:
    #!/usr/bin/env bash
    set -euo pipefail
    BRANCH=$(git branch --show-current)
    git add -A
    git commit -m "{{ message }}"
    # Rebase on remote branch first if it already exists (e.g. user edits via GitHub web)
    if git ls-remote --exit-code origin "$BRANCH" >/dev/null 2>&1; then
        git pull --rebase origin "$BRANCH"
    fi
    git push -u origin HEAD
    echo "✅  Pushed to $BRANCH."

# Run ci, commit, and push. No bd interaction — pass the issue to work-pr to close it.
# Usage:
#   just work-done "feat: my change"
work-done message:
    #!/usr/bin/env bash
    set -euo pipefail
    BRANCH=$(git branch --show-current)
    if [[ "$BRANCH" == "main" ]]; then
        echo "❌  Cannot run work-done on main. Create a feature branch first."
        exit 1
    fi
    just ci
    git add -A
    git commit -m "{{ message }}"
    # Rebase on remote branch first if it already exists
    if git ls-remote --exit-code origin "$BRANCH" >/dev/null 2>&1; then
        git pull --rebase origin "$BRANCH"
    fi
    git push -u origin HEAD
    echo "✅  Pushed. Now run: just work-pr \"PR title\" [bd-issue-id]"

# Open a PR for the current branch, then close the bd issue (if given).
# Issue is closed here — after the PR is open — per the bd rule.
# Usage:
#   just work-pr "PR title"
#   just work-pr "PR title" bd-a1b2
work-pr title issue="" body="":
    #!/usr/bin/env bash
    set -euo pipefail
    if gh pr view --json url --jq .url 2>/dev/null | grep -q 'http'; then
        echo "ℹ️  A PR already exists for this branch:"
        gh pr view --json url,title --jq '"  " + .title + "\n  " + .url'
    else
        gh pr create --title "{{ title }}" --body "{{ body }}" --base main
        echo "✅  PR opened."
    fi
    if [[ -n "{{ issue }}" ]]; then
        bd close "{{ issue }}"
        bd dolt push
        echo "✅  Closed issue {{ issue }} (PR is now open)."
    fi

# Close a bd issue standalone (without committing)
# Usage: just bd-close bd-a1b2
bd-close issue:
    bd close "{{ issue }}"
    bd dolt push
    @echo "✅  Closed issue {{ issue }}."

# ── Frontend – vendor JS ──────────────────────────────────────────────────────

# Download pinned Alpine.js and HTMX to src/static/js/
js-vendor:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{ JS_DIR }}"
    if [[ -f "{{ JS_DIR }}/alpine.min.js" && -f "{{ JS_DIR }}/htmx.min.js" ]]; then
        echo "✅  Vendor JS already present."
    else
        echo "── Downloading Alpine.js v{{ ALPINE_VERSION }} ──"
        curl -fSL "https://cdn.jsdelivr.net/npm/alpinejs@{{ ALPINE_VERSION }}/dist/cdn.min.js" \
            -o "{{ JS_DIR }}/alpine.min.js"
        echo "── Downloading HTMX v{{ HTMX_VERSION }} ──"
        curl -fSL "https://unpkg.com/htmx.org@{{ HTMX_VERSION }}/dist/htmx.min.js" \
            -o "{{ JS_DIR }}/htmx.min.js"
        echo "✅  Vendor JS downloaded."
    fi

# ── Frontend – Tailwind CSS ───────────────────────────────────────────────────

_tw-binary:
    #!/usr/bin/env bash
    set -euo pipefail
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    [[ "$OS" == "darwin" ]] && OS="macos"
    [[ "$ARCH" == "x86_64" ]] && ARCH="x64"
    [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
    echo "https://github.com/tailwindlabs/tailwindcss/releases/download/v{{ TW_VERSION }}/tailwindcss-${OS}-${ARCH}"

# Download the Tailwind CSS standalone CLI for this platform
tw-install:
    #!/usr/bin/env bash
    set -euo pipefail
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    [[ "$OS" == "darwin" ]] && OS="macos"
    [[ "$ARCH" == "x86_64" ]] && ARCH="x64"
    [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
    URL="https://github.com/tailwindlabs/tailwindcss/releases/download/v{{ TW_VERSION }}/tailwindcss-${OS}-${ARCH}"
    if [[ -x "{{ TAILWIND }}" ]] && "{{ TAILWIND }}" --help 2>/dev/null | grep -q "{{ TW_VERSION }}"; then
        echo "✅  Tailwind CSS v{{ TW_VERSION }} already installed."
    else
        echo "── Downloading Tailwind CSS v{{ TW_VERSION }} (${OS}-${ARCH}) ──"
        mkdir -p bin
        curl -fSL "$URL" -o "{{ TAILWIND }}"
        chmod +x "{{ TAILWIND }}"
        echo "✅  Tailwind CSS v{{ TW_VERSION }} installed to {{ TAILWIND }}"
    fi

# Build Tailwind CSS (one-off, minified)
tw-build:
    #!/usr/bin/env bash
    set -euo pipefail
    [[ -x "{{ TAILWIND }}" ]] || just tw-install
    "{{ TAILWIND }}" -i "{{ TW_INPUT }}" -o "{{ TW_OUTPUT }}" --content "{{ TW_CONTENT }}" --minify

# Watch and rebuild Tailwind CSS on changes
tw-watch:
    #!/usr/bin/env bash
    set -euo pipefail
    [[ -x "{{ TAILWIND }}" ]] || just tw-install
    "{{ TAILWIND }}" -i "{{ TW_INPUT }}" -o "{{ TW_OUTPUT }}" --content "{{ TW_CONTENT }}" --watch
