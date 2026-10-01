#!/bin/sh
# =============================================================================
# {{PROJECT_NAME}} — PHP container entrypoint
# -----------------------------------------------------------------------------
# Responsibilities (in order):
#   1. Provide safe defaults for every variable the FPM pool interpolates.
#   2. Prepare Laravel's writable directories, if the application exists yet.
#   3. Optionally install Composer dependencies in development.
#   4. exec the real command so it becomes PID 1's direct child and receives
#      signals correctly.
#
# Deliberately NOT done here:
#   - Waiting for MySQL/Redis. Compose `depends_on: condition: service_healthy`
#     already guarantees ordering; re-implementing it in shell would be slower
#     and would hide real dependency failures behind a retry loop.
#   - Running migrations. Schema changes are a deploy step with its own approval
#     gate, not a side effect of a container starting. Auto-migrating on boot
#     races when several replicas start at once.
# =============================================================================

# -e: abort on any unhandled error. -u: abort on an undefined variable, which
# turns a config typo into a loud failure instead of a silent empty value.
set -eu

log() { printf '[entrypoint] %s\n' "$*" >&2; }

# -----------------------------------------------------------------------------
# 1. FPM pool defaults
# -----------------------------------------------------------------------------
# www.conf references these with ${...}. PHP-FPM does NOT substitute a default
# when a variable is unset — it fails to start with a parse error. Exporting
# them here means the image boots correctly even with an empty environment,
# while still allowing compose or the platform to override any of them.
export APP_USER="${APP_USER:-app}"
export PHP_FPM_PM="${PHP_FPM_PM:-dynamic}"
export PHP_FPM_MAX_CHILDREN="${PHP_FPM_MAX_CHILDREN:-20}"
export PHP_FPM_START_SERVERS="${PHP_FPM_START_SERVERS:-4}"
export PHP_FPM_MIN_SPARE="${PHP_FPM_MIN_SPARE:-2}"
export PHP_FPM_MAX_SPARE="${PHP_FPM_MAX_SPARE:-6}"

# Referenced by 30-xdebug.ini. `off` keeps the extension loaded but inert, which
# is the correct default: near-zero overhead, and a developer can flip it to
# `debug` or `coverage` per session without rebuilding the image.
export XDEBUG_MODE="${XDEBUG_MODE:-off}"

# `static` ignores the spare-server settings; PHP-FPM warns loudly if they are
# set anyway. Blank them so the log stays clean and actionable.
if [ "${PHP_FPM_PM}" = "static" ]; then
    export PHP_FPM_START_SERVERS=""
    export PHP_FPM_MIN_SPARE=""
    export PHP_FPM_MAX_SPARE=""
fi

# -----------------------------------------------------------------------------
# 2. Application directories
# -----------------------------------------------------------------------------
# Everything below is conditional so the container starts cleanly before the
# Laravel application is scaffolded and does the right thing automatically
# once the app lands.
APP_ROOT="${APP_ROOT:-/var/www/html}"

if [ -f "${APP_ROOT}/artisan" ]; then
    log "Laravel application detected at ${APP_ROOT}"

    # Laravel writes to these at runtime. On a fresh bind mount they may not
    # exist. Creating them here avoids a 500 on the very first request.
    for dir in \
        storage/app/public \
        storage/framework/cache/data \
        storage/framework/sessions \
        storage/framework/testing \
        storage/framework/views \
        storage/logs \
        bootstrap/cache
    do
        mkdir -p "${APP_ROOT}/${dir}" 2>/dev/null || true
    done

    # Best-effort only. Under a bind mount the host owns the files and chmod may
    # legitimately fail; that is not a reason to refuse to start.
    chmod -R u+rwX "${APP_ROOT}/storage" "${APP_ROOT}/bootstrap/cache" 2>/dev/null || true
else
    log "No artisan found at ${APP_ROOT} — starting runtime only."
    log "This is expected until the Laravel application is scaffolded."
fi

# -----------------------------------------------------------------------------
# 3. Development convenience: dependency install
# -----------------------------------------------------------------------------
# Opt-in (COMPOSER_AUTO_INSTALL=true) and development-only. Never enable this in
# production: a container must not reach out to the network for code at boot —
# that makes the running artifact differ from the tested one.
#
# The emptiness test is on vendor/autoload.php, NOT on the vendor/ directory.
# This distinction is the whole of the check: vendor/ is a named volume mounted
# at that path, so Docker creates the directory before this script ever runs and
# `[ ! -d vendor ]` is false on a completely empty volume. The guard as first
# written could therefore never fire, and this block had never once executed —
# verified on a cold stack, where the scheduler died with
# "Failed opening required '/var/www/html/vendor/autoload.php'" while php
# reported healthy beside it. autoload.php is the artifact that actually decides
# whether the application can boot, so it is the right thing to test for.
if [ "${COMPOSER_AUTO_INSTALL:-false}" = "true" ] \
   && [ -f "${APP_ROOT}/composer.json" ] \
   && [ ! -f "${APP_ROOT}/vendor/autoload.php" ] \
   && command -v composer >/dev/null 2>&1
then
    log "vendor/autoload.php missing — running composer install (COMPOSER_AUTO_INSTALL=true)"
    composer install --no-interaction --no-progress --prefer-dist --working-dir="${APP_ROOT}"
fi

# -----------------------------------------------------------------------------
# 3a. Make sure Laravel has a .env to read
# -----------------------------------------------------------------------------
# Every real setting reaches this application through the container environment
# (see the environment blocks in compose.yaml), and Laravel's dotenv loader is
# immutable — a variable already exported by Compose is never overwritten by the
# file. So .env carries no configuration here. It only has to EXIST.
#
# It has to exist because phpdotenv reads it with @file_get_contents and lets
# safeLoad() swallow the failure — but PHPUnit installs an error handler that
# reports suppressed diagnostics anyway. On a clean checkout, where nothing
# creates backend/.env, every single test therefore came back as:
#
#     file_get_contents(/var/www/html/.env): Failed to open stream
#
# and PHPUnit still exited 0, so CI reported 19 warnings as a green gate.
#
# NOT copied from .env.example: that file is Laravel's untouched default and
# copying it would plant stale values in every fresh environment. An empty file
# with a note is the honest artifact — it says where configuration actually
# comes from.
#
# Production is excluded: there the image is immutable and the environment is
# injected by the platform, so a container writing into its own source tree at
# boot is exactly what must not happen.
if [ "${APP_ENV:-local}" != "production" ] \
   && [ -f "${APP_ROOT}/artisan" ] \
   && [ ! -f "${APP_ROOT}/.env" ]
then
    log ".env missing — creating an empty one (configuration comes from the container environment)"
    cat > "${APP_ROOT}/.env" <<'ENVEOF'
# Created automatically by docker/php/entrypoint.sh because Laravel expects this
# file to exist. It is deliberately empty.
#
# Configuration for this project comes from the container environment, declared
# in docker/compose/*.yaml and fed from the repository-root .env. Laravel's
# dotenv loader is immutable, so anything written here is IGNORED whenever the
# same variable is already set by Compose — which is the case for every setting
# that matters (APP_KEY, DB_*, REDIS_*, CACHE_STORE, QUEUE_CONNECTION).
#
# Put settings in the repository-root .env, not here.
ENVEOF
fi

# -----------------------------------------------------------------------------
# 3b. Guard artisan commands against a missing application
# -----------------------------------------------------------------------------
# The queue worker and scheduler run `php artisan ...`. Until the Laravel
# application is scaffolded there is no artisan file, so the command exits
# immediately — and with `restart: unless-stopped` Docker relaunches it forever.
# The result is a crash loop that floods `docker compose logs` and makes the
# whole stack read as broken in `compose ps`.
#
# Idling instead keeps the service slot alive and healthy-looking, and the
# worker starts doing real work the moment artisan appears (after a restart).
case "${*}" in
    *artisan*)
        if [ ! -f "${APP_ROOT}/artisan" ]; then
            log "======================================================================"
            log "Command needs artisan, which does not exist yet:"
            log "    $*"
            log ""
            log "Idling instead of crash-looping. Once the Laravel application is"
            log "scaffolded into backend/, restart this service:"
            log "    docker compose restart queue scheduler"
            log "======================================================================"
            # Interruptible by SIGTERM under tini, so `compose down` stays fast.
            exec tail -f /dev/null
        fi
        ;;
esac

# -----------------------------------------------------------------------------
# 4. Hand off
# -----------------------------------------------------------------------------
# `exec` replaces this shell with the target process. Without it, the shell
# would stay PID 1's child and swallow SIGTERM, so `docker stop` would wait the
# full 10s grace period and then SIGKILL — losing in-flight queue jobs.
log "Starting: $*"
exec "$@"
