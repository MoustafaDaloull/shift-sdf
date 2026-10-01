#!/bin/bash
# =============================================================================
# {{PROJECT_NAME}} — MySQL first-boot initialisation
# -----------------------------------------------------------------------------
# The official MySQL entrypoint executes everything in /docker-entrypoint-initdb.d
# exactly ONCE — on the very first boot, while the data directory is empty. It
# does not re-run on restart, and it does not run at all against an existing
# volume.
#
# CONSEQUENCE: editing this file has no effect on an already-initialised
# database. To pick up changes you must destroy the volume:
#     docker compose down -v && docker compose up -d mysql
#
# WHY a .sh and not a .sql file:
#   Database and user names come from environment variables so they can differ
#   per environment. A static .sql file cannot interpolate them, and hardcoding
#   them would put an environment-specific value (and, worse, a password) into
#   version control — which is forbidden.
#
# THIS FILE MUST BE COMMITTED WITH THE EXECUTE BIT (mode 100755):
#     git update-index --chmod=+x docker/mysql/initdb/01-init-databases.sh
#   Without it the MySQL entrypoint SOURCES the script instead of executing
#   it, inherits `set -euo pipefail`, and aborts the whole boot on its own
#   next unset variable. See docker/mysql/Dockerfile.
# =============================================================================

set -euo pipefail

# The parent entrypoint exports these; `:-` guards keep the script debuggable if
# it is ever run by hand.
APP_DB="${MYSQL_DATABASE:-app}"
APP_USER="${MYSQL_USER:-app}"

# Laravel's test suite runs against a physically separate database so that
# `php artisan test` (which truncates and re-migrates aggressively) can never
# destroy development data. The name is derived from the app database so the two
# always stay in step.
TEST_DB="${MYSQL_TEST_DATABASE:-${APP_DB}_test}"

echo "[mysql-init] Creating test database '${TEST_DB}' and granting to '${APP_USER}'."

# --------------------------------------------------------------------------
# Why the password is passed via MYSQL_PWD rather than -p"$PASSWORD":
#   A password on the command line is visible in `ps` output to any process in
#   the container for the duration of the call. MYSQL_PWD is scoped to this one
#   invocation's environment.
# --------------------------------------------------------------------------
MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql \
    --protocol=socket \
    --user=root \
    --database=mysql <<-SQL
	-- utf8mb4 + unicode_ci for the same Arabic-correctness reasons documented in
	-- docker/mysql/conf.d/server.cnf. Set explicitly here because CREATE DATABASE
	-- inherits the server default, and we do not want this to silently change if
	-- the server config is ever edited.
	CREATE DATABASE IF NOT EXISTS \`${TEST_DB}\`
	    CHARACTER SET utf8mb4
	    COLLATE utf8mb4_unicode_ci;

	-- The application user gets full rights on the test database only. It is
	-- deliberately NOT granted anything global: a SQL-injection foothold in the
	-- app must not be able to read other schemas or create users.
	GRANT ALL PRIVILEGES ON \`${TEST_DB}\`.* TO '${APP_USER}'@'%';

	-- Laravel's RefreshDatabase trait and some migrations create temporary
	-- tables and routines; without these the test suite fails on setup rather
	-- than on a real assertion.
	GRANT CREATE TEMPORARY TABLES ON \`${APP_DB}\`.* TO '${APP_USER}'@'%';

	FLUSH PRIVILEGES;
SQL

echo "[mysql-init] Done. Databases available: ${APP_DB}, ${TEST_DB}"
