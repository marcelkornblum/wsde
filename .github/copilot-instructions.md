# Worst Stag Do Ever – Copilot Instructions

> Full agent instructions in `AGENTS.md`. This file contains only what Copilot needs for coding decisions.

## Git Workflow (MANDATORY)

**Every piece of work must go through a feature branch + PR. Never push directly to `main`.**

Use the make targets — they encode the exact steps:

```bash
make git-start b="<branch-name>"   # checkout main + pull + create branch
# ... changes ...
make git-done m="<commit message>"  # stage + commit + push
make git-pr t="<PR title>"          # open PR via gh CLI
```

## Interaction Preferences (MANDATORY)

- **Confirm before acting** on anything non-trivial. Describe the plan first, wait for approval.
- **Ask when ambiguous.** If the request could mean two different things, ask rather than guess.
- **Report blockers immediately.** Don't silently work around a problem — surface it.
- **Prefer small focused PRs.** One concern per branch.

## Task Tracking (MANDATORY)

- Use **`bd` issues** for all task tracking. Run `bd ready` to find work, `bd update <id> --claim` to claim it.
- **Never** use the built-in TodoWrite/todo list tool — use `bd` instead.
- Create a `bd` issue for anything that needs follow-up before closing work.

## Project Overview

Django 6.x + Wagtail 7.x on Python 3.13, managed with uv. PostgreSQL via Cloud SQL. GAE Standard. Front end: Django templates + HTMX + Alpine.js + Tailwind CSS v4. **No django-cotton.**

## Architecture

- **`src/core/`** — Central config: settings, URLs, ASGI/WSGI, base views.
- Settings: `base.py` → `dev.py` → `production.py` → `local.py` (gitignored). Default is `core.settings.production`.
- Auth: django-allauth 65.x, Google + Apple Sign-In, admin approval gate before members area.

## Key Make Targets

| Target | Purpose |
|---|---|
| `make setup` | Full local setup (one-time) |
| `make runserver` | Start dev server |
| `make migrate` / `makemigrations` | Database migrations |
| `make check` | ruff + ty |
| `make fix` | Auto-fix + format |
| `make test` / `test-one t="…"` | pytest |
| `make tw-build` | Build Tailwind CSS |
| `make js-vendor` | Download Alpine.js + HTMX |
| `make git-start b="…"` | Start work: checkout main + pull + new branch |
| `make git-done m="…"` | Finish work: stage + commit + push |
| `make git-pr t="…"` | Open PR via gh CLI |

## Services Layer (MANDATORY)

Every app **must** have:

- **`services/data.py`** — Data-access layer. Only place that reads/writes models. Other apps import `data`, never models directly.
- **`services/logic.py`** — Business-logic layer. Views delegate mutations here. Never call mutating `data.py` functions from views directly.

## Models

Fields, `Meta`, `__str__`, simple computed properties only. No business logic.

## Views

HTTP concerns only: parse request, auth check, call services, return response.

## Testing (MANDATORY red/green TDD)

1. RED — Write failing test first. Confirm failure.
2. GREEN — Write minimal code to pass. Confirm green.
3. REFACTOR — Clean up. Re-run.

- Every `services/data.py` and `services/logic.py` function must have tests.
- Use factory-boy factories (`factories.py` per app).
- Use `pytest.mark.django_db` for database tests.
- Test files: `tests/test_data.py`, `tests/test_logic.py`, `tests/test_views.py`.

## E2E Tests (Playwright)

- Tests live in `e2e/`. Run with `make e2e`.
- All helpers in `e2e/helpers.py`. Never write local `go_to_*` helpers.
- Use `go(page, base_url, '/path/')`, never `page.goto(...)`.
- Use `require_or_skip(value, 'reason')`, never `if not x: return`.

### Alpine.js gotchas

- Use `x-show` not `x-if` (Playwright can find `x-show` elements; `x-if` removes them).
- Wait for Alpine to render before interacting: `expect(element).to_be_visible()`.
- In `@keydown` handlers, `this` is the input; store `this._root = this` in `init()`.
- Blur races with Enter/Escape: use `_skipBlur` flag. Cancel buttons: `@mousedown.prevent`.

## Feature Completeness Checklist

Every new model/feature must include:

- Django admin with `ModelAdmin`
- Services layer (CRUD in `data.py`, logic in `logic.py`)
- Tests (TDD)
- E2E tests for user-facing features
- factory-boy factory
- Sample data in `data_sample` management command

## Frontend

- Templates in `<app>/templates/`. Base template in `core/templates/`.
- Tailwind binary gitignored; auto-downloaded via `make tw-install` (version pinned in Makefile).
- Alpine.js + HTMX downloaded to `src/static/js/` via `make js-vendor` (never CDN in production).
- `BigAutoField` for all PKs.
