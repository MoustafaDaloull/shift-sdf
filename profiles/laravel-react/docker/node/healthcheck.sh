#!/bin/sh
# =============================================================================
# {{PROJECT_NAME}} — Vite dev server healthcheck
# -----------------------------------------------------------------------------
# This container has two legitimate running states, and a healthcheck that
# understands only one of them reports a false failure.
#
#   1. IDLE — the React application has not been scaffolded yet, so there is no
#      package.json and no dev server to probe. The container is intentionally
#      parked (see entrypoint.sh). This is CORRECT, not broken, so it must
#      report healthy — otherwise `docker compose up --wait` fails the whole
#      stack over a service that is behaving exactly as designed.
#
#   2. SERVING — package.json exists and Vite should be answering HTTP.
#      Here a non-responding port is a real failure and must be reported.
#
# Conflating the two is what makes a healthcheck untrustworthy: once people
# learn a red status is "normal", a genuine outage stops being noticed.
# =============================================================================

set -eu

APP_DIR="${APP_DIR:-/app}"
PORT="${VITE_PORT:-5173}"

# State 1 — nothing to serve yet.
if [ ! -f "${APP_DIR}/package.json" ]; then
    echo "idle: no package.json — React app not scaffolded yet (expected)"
    exit 0
fi

# State 2 — Vite must answer.
#
# `--spider` style HEAD is avoided: the Vite dev server does not always answer
# HEAD on `/`. A plain GET whose body is discarded is what a browser does and is
# therefore the honest check.
if curl -fsS --max-time 4 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
    exit 0
fi

echo "UNHEALTHY: Vite is not answering on port ${PORT}" >&2
exit 1
