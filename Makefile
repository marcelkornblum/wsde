.DEFAULT_GOAL := help
SHELL := /bin/bash

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

UV      := uv
PYTHON  := $(UV) run python
MANAGE  := $(PYTHON) manage.py

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

.PHONY: setup
setup: ## Full local setup: venv, hooks, vendor JS, Tailwind
	@echo "── Installing Python dependencies ──"
	$(UV) sync
	@echo ""
	@echo "── Installing git hooks ──"
	$(MAKE) install-hooks
	@echo ""
	@echo "── Downloading vendor JS ──"
	$(MAKE) js-vendor
	@echo ""
	@echo "── Downloading Tailwind CSS standalone CLI ──"
	$(MAKE) tw-install
	@echo ""
	@echo "── Building Tailwind CSS ──"
	$(MAKE) tw-build
	@echo ""
	@echo "── Creating local.py settings override (if missing) ──"
	@cp -n src/core/settings/local.py.tpl src/core/settings/local.py 2>/dev/null || true
	@echo ""
	@echo "✅  Setup complete. Run 'make runserver' to start developing."

# ---------------------------------------------------------------------------
# Development
# ---------------------------------------------------------------------------

.PHONY: runserver
runserver: ## Start the Django development server
	$(MANAGE) runserver

.PHONY: shell
shell: ## Open a Django shell
	$(MANAGE) shell

.PHONY: superuser
superuser: ## Create a superuser interactively
	$(MANAGE) createsuperuser

.PHONY: migrate
migrate: ## Run Django migrations
	$(MANAGE) migrate

.PHONY: makemigrations
makemigrations: ## Create new Django migrations
	$(MANAGE) makemigrations

.PHONY: check-migrations
check-migrations: ## Fail if any migrations are missing
	$(MANAGE) makemigrations --check --dry-run

.PHONY: manage
manage: ## Run a manage.py command: make manage c="showmigrations"
	$(if $(c),,$(error Usage: make manage c="<command>"))
	$(MANAGE) $(c)

# ---------------------------------------------------------------------------
# Code quality (runs on the host – no Django env needed)
# ---------------------------------------------------------------------------

.PHONY: check
check: ## Run ruff linter and ty type checker
	$(UV) run ruff check src/
	$(UV) run ty check src/

.PHONY: fix
fix: ## Auto-fix lint issues and format code
	$(UV) run ruff check --fix src/
	$(UV) run ruff format src/

.PHONY: format
format: ## Run ruff formatter only
	$(UV) run ruff format src/

# ---------------------------------------------------------------------------
# Testing
# ---------------------------------------------------------------------------

.PHONY: test
test: ## Run the full test suite with pytest
	$(UV) run pytest -v

.PHONY: test-one
test-one: ## Run specific tests. Usage: make test-one t="test expression"
	$(if $(t),,$(error Usage: make test-one t="test expression"))
	$(UV) run pytest -v -k "$(t)"

# ---------------------------------------------------------------------------
# Git hooks
# ---------------------------------------------------------------------------

.PHONY: install-hooks
install-hooks: ## Install git hooks from .githooks/
	git config core.hooksPath .githooks
	@echo "✅  Git hooks installed (using .githooks/ directory)."

.PHONY: app-yaml
app-yaml: ## Show the committed app.yaml location (it's already in the repo)
	@echo "app.yaml is committed at the repo root — edit it directly."
	@echo "Current contents:"
	@cat app.yaml

# ---------------------------------------------------------------------------
# Git workflow
# ---------------------------------------------------------------------------

.PHONY: git-start
git-start: ## Start a new piece of work. Usage: make git-start b="my-branch-name"
	$(if $(b),,$(error Usage: make git-start b="<branch-name>"))
	git checkout main
	git pull --ff-only origin main
	git checkout -b $(b)
	@echo "✅  On branch '$(b)', ready to work."

.PHONY: git-done
git-done: ## Stage all changes and commit. Usage: make git-done m="commit message"
	$(if $(m),,$(error Usage: make git-done m="<commit message>"))
	bd dolt push
	git add -A
	git commit -m "$(m)"
	git push -u origin HEAD
	@echo "✅  Pushed. Open a PR at: https://github.com/marcelkornblum/wsde/compare/$(shell git branch --show-current)"

.PHONY: git-pr
git-pr: ## Open a PR for the current branch. Usage: make git-pr t="PR title" [b="body text"]
	$(if $(t),,$(error Usage: make git-pr t="<title>" [b="<body>"]))
	gh pr create --title "$(t)" --body "$(or $(b), )" --base main
	@echo "✅  PR opened."

# ---------------------------------------------------------------------------
# Frontend – vendor JS (Alpine.js + HTMX, downloaded to src/static/js/)
# ---------------------------------------------------------------------------

ALPINE_VERSION := 3.14.8
HTMX_VERSION   := 2.0.4
JS_DIR         := src/static/js

.PHONY: js-vendor
js-vendor: ## Download pinned Alpine.js and HTMX to src/static/js/
	@mkdir -p $(JS_DIR)
	@if [ -f "$(JS_DIR)/alpine.min.js" ] && [ -f "$(JS_DIR)/htmx.min.js" ]; then \
		echo "✅  Vendor JS already present."; \
	else \
		echo "── Downloading Alpine.js v$(ALPINE_VERSION) ──"; \
		curl -fSL "https://cdn.jsdelivr.net/npm/alpinejs@$(ALPINE_VERSION)/dist/cdn.min.js" -o $(JS_DIR)/alpine.min.js; \
		echo "── Downloading HTMX v$(HTMX_VERSION) ──"; \
		curl -fSL "https://unpkg.com/htmx.org@$(HTMX_VERSION)/dist/htmx.min.js" -o $(JS_DIR)/htmx.min.js; \
		echo "✅  Vendor JS downloaded."; \
	fi

# ---------------------------------------------------------------------------
# Frontend – Tailwind CSS (standalone CLI)
# ---------------------------------------------------------------------------

TW_VERSION := 4.2.2
TAILWIND   := ./bin/tailwindcss
TW_INPUT   := src/styles/input.css
TW_OUTPUT  := src/static/css/output.css
TW_CONTENT := "src/**/templates/**/*.html"

# Detect the correct binary name for the current platform
TW_OS   := $(shell uname -s | tr '[:upper:]' '[:lower:]')
TW_ARCH := $(shell uname -m)
ifeq ($(TW_ARCH),x86_64)
  TW_ARCH := x64
else ifeq ($(TW_ARCH),aarch64)
  TW_ARCH := arm64
else ifeq ($(TW_ARCH),arm64)
  TW_ARCH := arm64
endif
ifeq ($(TW_OS),darwin)
  TW_OS := macos
endif
TW_URL := https://github.com/tailwindlabs/tailwindcss/releases/download/v$(TW_VERSION)/tailwindcss-$(TW_OS)-$(TW_ARCH)

.PHONY: tw-install
tw-install: ## Download the Tailwind CSS standalone CLI for this platform
	@if [ -x "$(TAILWIND)" ] && $(TAILWIND) --help 2>/dev/null | grep -q "$(TW_VERSION)"; then \
		echo "✅  Tailwind CSS v$(TW_VERSION) already installed."; \
	else \
		echo "── Downloading Tailwind CSS v$(TW_VERSION) ($(TW_OS)-$(TW_ARCH)) ──"; \
		mkdir -p bin; \
		curl -fSL "$(TW_URL)" -o $(TAILWIND); \
		chmod +x $(TAILWIND); \
		echo "✅  Tailwind CSS v$(TW_VERSION) installed to $(TAILWIND)"; \
	fi

.PHONY: tw-build
tw-build: ## Build Tailwind CSS (one-off, minified)
	@test -x "$(TAILWIND)" || $(MAKE) tw-install
	$(TAILWIND) -i $(TW_INPUT) -o $(TW_OUTPUT) --content $(TW_CONTENT) --minify

.PHONY: tw-watch
tw-watch: ## Watch and rebuild Tailwind CSS on changes
	@test -x "$(TAILWIND)" || $(MAKE) tw-install
	$(TAILWIND) -i $(TW_INPUT) -o $(TW_OUTPUT) --content $(TW_CONTENT) --watch
