#!/bin/sh
# =============================================================================
# {{PROJECT_NAME}} — Node/Vite container entrypoint
# -----------------------------------------------------------------------------
# This entrypoint must handle three distinct states without ever crash-looping:
#
#   A. No package.json          -> idle, print instructions, stay up.
#   B. package.json, no modules -> install dependencies, then run.
#   C. Ready                    -> run immediately.
#
# WHY idle instead of exit in state A: a container that exits is restarted
# forever by the restart policy, which floods the logs and makes `compose ps`
# read as broken. Idling keeps the service slot available so a developer can
# `docker compose exec node npm create vite@latest .` to scaffold the app in
# place, using the same Node version CI will use.
# =============================================================================

set -eu

log() { printf '[node-entrypoint] %s\n' "$*" >&2; }

APP_DIR="${APP_DIR:-/app}"
cd "${APP_DIR}"

# -----------------------------------------------------------------------------
# State A — application not scaffolded
# -----------------------------------------------------------------------------
if [ ! -f "${APP_DIR}/package.json" ]; then
    log "======================================================================"
    log "No package.json in ${APP_DIR}."
    log "The React application has not been scaffolded yet — this is expected."
    log ""
    log "The container will idle so the service stays available. To scaffold:"
    log "  docker compose exec node npm create vite@latest . -- --template react-ts"
    log "  docker compose restart node"
    log "======================================================================"

    # `tail -f /dev/null` blocks forever at ~0% CPU and, unlike `sleep infinity`,
    # is interruptible by SIGTERM under tini — so `docker compose down` is still
    # instant rather than waiting out the kill grace period.
    exec tail -f /dev/null
fi

# -----------------------------------------------------------------------------
# State B — dependencies missing
# -----------------------------------------------------------------------------
# node_modules is a named volume (see compose.dev.yaml), so it survives restarts
# and is empty only on first run or after an explicit volume prune.
if [ ! -d "${APP_DIR}/node_modules" ] || [ -z "$(ls -A "${APP_DIR}/node_modules" 2>/dev/null)" ]; then
    if [ -f "${APP_DIR}/package-lock.json" ]; then
        log "node_modules empty — running 'npm ci' from lockfile."
        npm ci --no-audit --no-fund
    else
        log "node_modules empty and no lockfile — running 'npm install'."
        log "Commit the generated package-lock.json so builds stay reproducible."
        npm install --no-audit --no-fund
    fi
fi

# -----------------------------------------------------------------------------
# State C — run
# -----------------------------------------------------------------------------
# Guard against a package.json that has no `dev` script (for example, right
# after scaffolding with a different template). Idling beats crash-looping.
if [ "${1:-}" = "npm" ] && [ "${2:-}" = "run" ] && [ "${3:-}" = "dev" ]; then
    if ! node -e "process.exit(require('${APP_DIR}/package.json').scripts?.dev ? 0 : 1)" 2>/dev/null; then
        log "package.json defines no 'dev' script — idling instead of crash-looping."
        log "Add a Vite 'dev' script, then: docker compose restart node"
        exec tail -f /dev/null
    fi
fi

log "Starting: $*"
exec "$@"
