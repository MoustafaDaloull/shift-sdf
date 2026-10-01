# =============================================================================
# {{PROJECT_NAME}} — Docker environment control
# -----------------------------------------------------------------------------
# WHY A MAKEFILE
# Every compose invocation in this project needs three things to be correct:
#   1. the base file plus exactly one environment overlay,
#   2. `--project-directory .` so relative paths resolve from the repository
#      root rather than from docker/compose/,
#   3. a project name that isolates the dev, test, and prod stacks from each
#      other.
# Typing that by hand invites the mistake where a test run reuses the
# development database. These targets make the correct invocation the easy one.
#
# Requires GNU Make. On Windows use Git Bash or WSL2, both of which ship it.
# The raw docker compose command for any target is printed by `make print-cmd`.
#
# `make` is NOT installed on every development machine. Every target that
# matters is a one-line delegation to a shell script, so the documented
# fallback is always `bash scripts/...`; a `make`-only path is a path that may
# never have run where the code is written.
# =============================================================================

# Fail a recipe if any command in a pipeline fails, not just the last one.
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

COMPOSE_DIR  := docker/compose
BASE_FILE    := $(COMPOSE_DIR)/compose.yaml
DEV_FILE     := $(COMPOSE_DIR)/compose.dev.yaml
TEST_FILE    := $(COMPOSE_DIR)/compose.test.yaml
PROD_FILE    := $(COMPOSE_DIR)/compose.prod.yaml

# `--project-directory .` is the load-bearing flag. Without it Compose treats
# docker/compose/ as the project directory, and every `context: .` would build
# from the wrong place while `.env` would be read from the wrong file.
DC       := docker compose --project-directory .
DC_DEV   := $(DC) -p $(or $(COMPOSE_PROJECT_NAME),app)      -f $(BASE_FILE) -f $(DEV_FILE)
DC_TEST  := $(DC) -p $(or $(COMPOSE_PROJECT_NAME),app)-test -f $(BASE_FILE) -f $(TEST_FILE)
DC_PROD  := $(DC) -p $(or $(COMPOSE_PROJECT_NAME),app)-prod -f $(BASE_FILE) -f $(PROD_FILE)

.DEFAULT_GOAL := help

# Every target is phony: none of them produces a file with that name, and
# without this a target would be skipped if a same-named file ever appeared.
.PHONY: help init up down restart build rebuild ps logs logs-php health \
        shell shell-root db redis-cli mailpit test test-coverage \
        config config-test config-prod validate prod-build prod-up prod-down \
        clean nuke print-cmd \
        db-init migrate seed db-reset \
        hooks fmt fmt-check stan arch routes fe-static secrets openapi quality ci

# -----------------------------------------------------------------------------
help: ## Show this help
	@echo "{{PROJECT_NAME}} — Docker environment"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ""

# -----------------------------------------------------------------------------
# SETUP
# -----------------------------------------------------------------------------
init: ## Create .env from the template (first-time setup)
	@if [ -f .env ]; then \
		echo "  .env already exists — not overwriting."; \
	else \
		cp .env.example .env; \
		echo "  Created .env from .env.example"; \
		echo ""; \
		echo "  >>> Edit .env and change these before 'make up': <<<"; \
		echo "      MYSQL_ROOT_PASSWORD"; \
		echo "      MYSQL_PASSWORD"; \
		echo "      REDIS_PASSWORD"; \
		echo ""; \
		echo "  Generate a strong value with: openssl rand -base64 24"; \
	fi

# -----------------------------------------------------------------------------
# DEVELOPMENT
# -----------------------------------------------------------------------------
up: ## Start the development stack (waits for health)
	$(DC_DEV) up -d --wait
	@echo ""
	@echo "  Laravel API   http://localhost:$${NGINX_PORT:-8080}"
	@echo "  Vite (React)  http://localhost:$${VITE_PORT:-5173}"
	@echo "  Mailpit       http://localhost:$${MAILPIT_UI_PORT:-8025}"
	@echo "  Health        http://localhost:$${NGINX_PORT:-8080}/healthz"
	@echo ""
	@echo "  First run on this machine? The database is empty until you run:"
	@echo "      make db-init      (without make: see docker/README.md §1 step 5)"
	@echo "  Skipping it leaves the OpenAPI gate RED on unmodified code."

down: ## Stop the development stack (volumes are preserved)
	$(DC_DEV) down

restart: ## Restart every service
	$(DC_DEV) restart

build: ## Build images (uses the layer cache)
	$(DC_DEV) build

rebuild: ## Rebuild images from scratch, ignoring the cache
	$(DC_DEV) build --no-cache --pull

ps: ## Show service status and health
	$(DC_DEV) ps

logs: ## Tail logs from every service
	$(DC_DEV) logs -f --tail=100

logs-php: ## Tail PHP logs only
	$(DC_DEV) logs -f --tail=100 php

health: ## Report the health state of every container
	@$(DC_DEV) ps --format 'table {{.Service}}\t{{.Status}}'

# -----------------------------------------------------------------------------
# SHELLS
# -----------------------------------------------------------------------------
shell: ## Shell into the PHP container as the app user
	$(DC_DEV) exec php sh

shell-root: ## Shell into the PHP container as root (for apk installs)
	$(DC_DEV) exec -u root php sh

db: ## Open a MySQL client inside the database container
	$(DC_DEV) exec mysql sh -c 'MYSQL_PWD="$$MYSQL_PASSWORD" mysql -u"$$MYSQL_USER" "$$MYSQL_DATABASE"'

redis-cli: ## Open a Redis client (authenticated)
	$(DC_DEV) exec redis sh -c 'REDISCLI_AUTH="$$REDIS_PASSWORD" redis-cli'

mailpit: ## Print the Mailpit UI URL
	@echo "http://localhost:$${MAILPIT_UI_PORT:-8025}"

# -----------------------------------------------------------------------------
# DATABASE (development stack)
# -----------------------------------------------------------------------------
# WHY THESE EXIST
# `make up` leaves a schema-less database behind. Any gate that reads the
# database while it generates — the OpenAPI contract gate, when a FormRequest's
# rules() reads its bounds from a settings table — then goes RED on unmodified
# code, and the failure names neither the database nor the seed. This is the
# warm-vs-cold class of defect: invisible on a machine whose database was
# seeded long ago, unavoidable on a fresh one.
db-init: ## First-time database setup — migrate then seed (run once after `make up`)
	$(DC_DEV) exec -T php sh -lc "cd /var/www/html && php artisan migrate --force && php artisan db:seed --force"
	@echo ""
	@echo "  Database ready. Financial values are NOT seeded on purpose —"
	@echo "  their absence is intended and tested; the product owner sets them."

migrate: ## Run pending migrations against the development database
	$(DC_DEV) exec -T php sh -lc "cd /var/www/html && php artisan migrate --force"

seed: ## Run the seeders against the development database
	$(DC_DEV) exec -T php sh -lc "cd /var/www/html && php artisan db:seed --force"

# Mirrors the CI step exactly. DESTRUCTIVE: drops every table in the developer's
# own database before rebuilding it, which is why it is not part of `up`.
db-reset: ## DESTROYS the dev database, then migrates and seeds it (what CI does)
	$(DC_DEV) exec -T php sh -lc "cd /var/www/html && php artisan migrate:fresh --seed --force"

# -----------------------------------------------------------------------------
# TESTING
# -----------------------------------------------------------------------------
# Delegates to scripts/quality.sh, which is the single source of truth for how a
# gate runs. This target used to spell out `$(DC_TEST) run --rm test` itself,
# and quality.sh spelled out something different — it ran the suite in the
# DEVELOPMENT container. Two definitions of "run the tests", and the one CI
# called was the wrong one: every run executed migrate:fresh against the
# developer's own database.
#
# The mechanics live in quality.sh now, including the `down -v` teardown, so the
# two paths cannot drift again.
test: ## Run the test suite in an isolated, ephemeral stack
	bash scripts/quality.sh tests

test-coverage: ## Run the test suite with code coverage
	$(DC_TEST) run --rm -e XDEBUG_MODE=coverage test php artisan test --coverage
	$(DC_TEST) down -v

# -----------------------------------------------------------------------------
# QUALITY GATES
# -----------------------------------------------------------------------------
# Every gate here is mandatory and fails the build. Advisory checks are
# forbidden: a check that only warns is ignored within a fortnight and leaves a
# false sense of coverage behind it.
#
# WHY THESE TARGETS ARE ONE-LINE DELEGATIONS
#
# The gate sequence lives in scripts/quality.sh, not here, and these targets
# only call it. Two reasons, both learned the hard way:
#
#   1. A sequence defined twice drifts. If the Makefile ordered the gates and
#      the CI workflow listed them again, the two would diverge on the first
#      change nobody mirrored — and a gate that behaves differently in CI than
#      locally is a gate nobody trusts.
#
#   2. `make` is not installed on every development machine. The shell script
#      runs anywhere Git Bash does.
#
# So: script is the source of truth, Makefile is a convenience alias, and the
# GitHub Actions workflow calls the same script.

# Both hooks, not just pre-commit. `post-commit` is what warns the moment a
# commit exists unpushed. A hook that ships in scripts/hooks/ and is never
# copied is a gate that does not exist.
hooks: ## Install the Git hooks (pre-commit + post-commit)
	@cp scripts/hooks/pre-commit  .git/hooks/pre-commit
	@cp scripts/hooks/post-commit .git/hooks/post-commit
	@chmod +x .git/hooks/pre-commit .git/hooks/post-commit
	@echo "installed: .git/hooks/pre-commit"
	@echo "installed: .git/hooks/post-commit"

fmt: ## Fix code style (Pint)
	$(DC_DEV) exec -T php sh -lc "cd /var/www/html && ./vendor/bin/pint"

fmt-check: ## Verify code style without changing files
	@bash scripts/quality.sh fmt

stan: ## Static analysis (PHPStan level 8 + Larastan)
	@bash scripts/quality.sh stan

arch: ## Architectural boundary gate (Deptrac + project rules)
	@bash scripts/quality.sh arch

routes: ## Frontend route registry gate
	@bash scripts/quality.sh routes

fe-static: ## Frontend static gate (ESLint + tsc --noEmit)
	@bash scripts/quality.sh fe-static

secrets: ## Scan the whole repository for secrets
	@bash scripts/quality.sh secrets

openapi: ## OpenAPI contract gate (regenerate and compare)
	@bash scripts/quality.sh openapi

quality: ## Run every static gate (no database needed)
	@bash scripts/quality.sh

ci: ## Full pipeline — what CI runs
	@bash scripts/quality.sh --with-tests

# -----------------------------------------------------------------------------
# VALIDATION
# -----------------------------------------------------------------------------
config: ## Render the merged development configuration
	$(DC_DEV) config

config-test: ## Render the merged testing configuration
	$(DC_TEST) config

config-prod: ## Render the merged production configuration
	$(DC_PROD) config

validate: ## Validate all three compose stacks
	@echo "==> development"; $(DC_DEV)  config --quiet && echo "    OK"
	@echo "==> testing";     $(DC_TEST) config --quiet && echo "    OK"
	@echo "==> production";  $(DC_PROD) config --quiet && echo "    OK"

print-cmd: ## Print the raw docker compose command for each stack
	@echo "dev : $(DC_DEV)"
	@echo "test: $(DC_TEST)"
	@echo "prod: $(DC_PROD)"

# -----------------------------------------------------------------------------
# PRODUCTION IMAGES (local build and smoke run only — no deploy target here)
# -----------------------------------------------------------------------------
# The Node bundle is built first as its own image, because the Nginx `web`
# target copies the compiled assets out of it via NODE_BUILD_IMAGE.
prod-build: ## Build production images locally
	docker build \
		--file docker/node/Dockerfile \
		--target build \
		--tag $${IMAGE_REGISTRY:-local}/node-build:$${IMAGE_TAG:-latest} \
		--build-arg VITE_API_BASE_URL=$${VITE_API_BASE_URL:-https://api.example.com} \
		.
	$(DC_PROD) build

prod-up: ## Start the production stack locally (smoke test)
	$(DC_PROD) up -d --wait

prod-down: ## Stop the production stack
	$(DC_PROD) down

# -----------------------------------------------------------------------------
# CLEANUP
# -----------------------------------------------------------------------------
clean: ## Stop the stack and remove its volumes (DESTROYS the local database)
	@echo "This deletes the development database, Redis data, and captured mail."
	@read -p "Type 'yes' to continue: " ok; [ "$$ok" = "yes" ] || { echo "Aborted."; exit 1; }
	$(DC_DEV) down -v

nuke: ## clean, plus remove built images
	@echo "This deletes all volumes AND all images built for this project."
	@read -p "Type 'yes' to continue: " ok; [ "$$ok" = "yes" ] || { echo "Aborted."; exit 1; }
	$(DC_DEV) down -v --rmi local
