# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd prime` for full workflow context.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work atomically
bd close <id>         # Complete work
bd dolt push          # Push beads data to remote
```

## Git Workflow (MANDATORY)

**Every piece of work must go through a feature branch + PR. Never push directly to `main`.**

Use the `just` recipes — they encode the exact steps:

```bash
just work-start <branch-name>       # checkout main + pull + create branch
# ... changes ...
just work-done "<commit message>"   # stage + commit + push
just work-pr "<PR title>"           # open PR via gh CLI
```

**Rules:**

- Always `git pull --ff-only origin main` before creating a branch
- Branch names should be descriptive (e.g. `wsde-3ln.5-hooks`, `fix-cd-proxy-socket`)
- Open a PR after pushing — work is not complete until a PR exists
- Never amend or force-push to branches that already have a PR open

---

## Interaction Preferences (MANDATORY)

- **Confirm before acting** on anything non-trivial. Describe the plan first, wait for approval.
- **Ask when ambiguous.** If the request could mean two different things, ask rather than guess.
- **Report blockers immediately.** Don’t silently work around a problem — surface it.
- **Prefer small focused PRs.** One concern per branch.

---

## Non-Interactive Shell Commands

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**

```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**

- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->

## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use **`bd` issues** for all task tracking. Run `bd ready` to find work, `bd update <id> --claim` to claim it.
- **Never** use the built-in TodoWrite/todo list tool — use `bd` instead.
- Create a `bd` issue for anything that needs follow-up before closing work.

### Full lifecycle for non-trivial requests

```bash
# 1. Before starting — create an issue and branch in one step
just work-start my-branch "" "Short title of work"  # creates issue, claims it, makes branch
# — or claim an existing issue —
just work-start my-branch bd-a1b2                   # branch + claim existing issue
# — or create the issue first, then branch —
just work-new "Short title of work"                 # create + claim → prints id
just work-start my-branch bd-a1b2                   # branch + claim

# 2. Do the work...

# 3. Commit, close the issue, push
just work-done "feat: my change" bd-a1b2  # closes issue + commits + pushes

# 4. Open the PR
just work-pr "PR title"
```

**Rules:**

- Any request that takes more than a single file edit gets a `bd` issue.
- Claim the issue before doing any work (`--claim` is idempotent if already claimed by you).
- Close the issue when the PR is open, not when it's merged.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE via PR** - This is MANDATORY:
   ```bash
   git pull --rebase origin main   # ensure branch is from latest main
   bd dolt push
   just work-done "<commit msg>" [bd-id]  # closes issue + commits + pushes
   just work-pr "<PR title>"
   # or manually: git push -u origin <branch>
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed (PR open)
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**

- Work is NOT complete until `git push` succeeds and a PR is open
- NEVER push directly to `main` — always use a feature branch + PR
- Always `git pull --ff-only` (or `--rebase`) from main before creating a branch
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push and open the PR
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->

---

## Project Overview

**Worst Stag Do Ever** — a members-only event site with a promotional public face, built on Django + Wagtail + GAE Standard.

- **Stack**: Python 3.13, Django 6.x, Wagtail 7.x, django-allauth 65.x
- **Frontend**: Django templates + HTMX + Alpine.js + Tailwind CSS v4. **No django-cotton.**
- **Auth**: Google + Apple Sign-In (django-allauth), admin approval gate before members area access
- **Infra**: Google App Engine Standard, Cloud SQL (PostgreSQL), GCS static/media
- **Domain**: wsde.rcel.biz
- **Dependency management**: uv (not pip)

---

## Architecture Conventions

Source code lives under `src/`. Add `src/` to `PYTHONPATH` (already configured in `pyproject.toml`).

### Settings hierarchy

```
core/settings/base.py       ← shared, imported by all others
core/settings/dev.py        ← local development (default for manage.py)
core/settings/production.py ← GAE / Cloud SQL (default for wsgi.py + asgi.py)
core/settings/local.py      ← gitignored, extends dev, personal overrides
```

### Services Layer (MANDATORY for every app)

Each app **must** have a `services/` directory:

- **`services/data.py`** — Data-access layer. The public API for reading/writing the app's models. Other apps import this, **never models directly**. Large apps may split into a `services/data/` package with focused submodules; `data/__init__.py` re-exports via `__all__`.
- **`services/logic.py`** — Business-logic layer. Views delegate here. Logic calls `data.py` for persistence.

**Critical mutation rule:**

- Views **may** call `data.py` for **reads**.
- Views **must never** call `data.py` for **mutations**. All mutations go through `logic.py`.
- This ensures business rules (approval gate, payment tracking, workflow transitions) are always enforced.

### Models

Minimise logic. Fields, `Meta`, `__str__`, simple computed properties only. No business logic.

### Views

HTTP concerns only: request parsing, auth checks, call services layer, return response. No business logic.

---

## Testing (MANDATORY red/green TDD)

1. **RED** — Write failing test first. Run tests, confirm failure.
2. **GREEN** — Write minimal code to pass. Run tests, confirm green.
3. **REFACTOR** — Clean up. Re-run tests.

Rules:

- Never write production code without a failing test.
- Run tests after every RED and GREEN step.
- After all tests pass, run `just check` and `just fix`.
- Never leave failing tests.

### Unit tests

- Every function in `services/data.py` and `services/logic.py` must have tests.
- Test happy paths and edge cases.
- Use factory-boy factories (each app's `factories.py`).
- Use `pytest.mark.django_db` for database tests.
- Test files: `tests/test_data.py`, `tests/test_logic.py`, `tests/test_views.py`.
- Shared per-app fixtures in `tests/conftest.py`. Cross-app fixtures in `src/conftest.py`.

### E2E tests (Playwright)

- Every significant front-end feature must have Playwright e2e tests in `e2e/`.
- Use `just e2e` (headless).
- All navigation helpers live in `e2e/helpers.py` — never write local `go_to_*` helpers in test files.

#### `e2e/helpers.py` canonical helpers

```python
go(page, base_url, path)           # replaces page.goto + wait_for_load_state
settle(page)                       # wait for networkidle after click/submit
wait_for_htmx(page)                # signals HTMX was the trigger, waits for networkidle
wait_for_htmx_target(page, sel)    # wait for HTMX to inject content into specific element
wait_for_alpine(page, ms=300)      # short wait for Alpine reactive DOM updates
wait_for_animation(page, ms=200)   # wait for CSS transitions to complete
require_or_skip(value, reason)     # replaces `if not x: return`, reports as skipped
pk_from_href(href)                 # extract integer PK from a URL path string
```

Canonical test pattern:

```python
from helpers import go, require_or_skip

class TestMyFeature:
    def test_something(self, authenticated_page: Page, base_url: str) -> None:
        go(authenticated_page, base_url, '/members/')
        require_or_skip(authenticated_page.locator('.member-card').count(), 'no members')
        # ... interact and assert
```

Never use `page.goto(f'{base_url}/path/')` — always `go(page, base_url, '/path/')`.
Never use `if not x: return` — always `require_or_skip(x, 'reason')`.

#### E2E gotchas (Alpine.js + Playwright)

- **CDN scripts won't work in headless e2e** — serve Alpine.js and HTMX from local static files (`just js-vendor`), never CDN URLs.
- **`x-show` not `x-if`** — `x-if` removes elements from DOM; Playwright cannot find them before Alpine initialises. `x-show` keeps elements in DOM (hidden via `display:none`). Pair with `x-cloak` to prevent flash.
- **Wait for Alpine to render** — after a click that triggers Alpine state change, add `expect(element).to_be_visible()` before pressing keys.
- **`this` in event handlers vs `init()`** — inside `@keydown` on an input, `this` is the input, not the component root. Store `this._root = this` in `init()` and use `_root` for DOM traversal.
- **Blur races with keyboard/cancel** — `x-show` triggers blur (element stays in DOM). Enter/Escape + `@blur='save()'` causes double-fire. Use a `_skipBlur` flag in keyboard handlers. For cancel buttons use `@mousedown.prevent` instead of `@click`.
- **Locator specificity with `x-show`** — both display and edit elements are always in DOM. Scope locators to visible elements.

---

## Feature Completeness Checklist

Every new model or feature must include:

- Django admin with full `ModelAdmin` configuration
- Complete services layer (CRUD in `data.py`, logic in `logic.py`)
- Comprehensive tests via red/green TDD
- E2E tests for user-facing features
- factory-boy factory with sensible defaults
- Sample data wired into `data_sample` management command

---

## Frontend Conventions

Stack: Django/Wagtail templates + HTMX + Alpine.js + Tailwind CSS v4. **No django-cotton.**

- Templates live inside each app at `<app>/templates/`. Base template in `core/templates/`.
- URL patterns in `core/urls.py` — include new app URL confs from there.
- Tailwind version pinned in `justfile` (`TW_VERSION`). Binary gitignored, auto-downloaded via `just tw-install`.
- Alpine.js and HTMX pinned in `justfile` (`ALPINE_VERSION`, `HTMX_VERSION`). Downloaded to `src/static/js/` via `just js-vendor`.
- `BigAutoField` for all primary keys (set in `base.py`).
- Use `uv` for dependencies (not pip).

---

## Key `just` Recipes

| Recipe                                           | Purpose                                                          |
| ------------------------------------------------ | ---------------------------------------------------------------- |
| `just setup`                                     | Full local setup (one-time)                                      |
| `just runserver`                                 | Start Django dev server                                          |
| `just migrate` / `makemigrations`                | Database migrations                                              |
| `just check`                                     | ruff + ty quality gates                                          |
| `just fix`                                       | Auto-fix and format                                              |
| `just test` / `test-one "…"`                     | pytest                                                           |
| `just install-hooks`                             | Wire `.githooks/` pre-commit hook                                |
| `just js-vendor`                                 | Download pinned Alpine.js + HTMX                                 |
| `just tw-install` / `tw-build` / `tw-watch`      | Tailwind CSS v4 standalone CLI                                   |
| `just work-start <branch> [issue] ["title"]`     | Start work: checkout main + pull + branch (+ create/claim issue) |
| `just work-done "msg" [issue]`                   | Finish work: close issue + commit + push                         |
| `just work-pr "title"`                           | Open PR via gh CLI                                               |
| `just work-new "title"`                          | Create and claim a new bd issue                                  |
| `just bd-close <issue>`                          | Close a bd issue standalone                                      |
