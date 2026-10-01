#!/bin/sh
# =============================================================================
# {{PROJECT_NAME}} — PHP-FPM healthcheck
# -----------------------------------------------------------------------------
# Speaks FastCGI directly to the local FPM master and asserts that /ping answers
# `pong`.
#
# WHY not `curl http://localhost/ping`:
#   FPM speaks FastCGI, not HTTP — there is no HTTP listener in this container.
#   Routing the healthcheck through Nginx instead would couple two services:
#   an Nginx misconfiguration would mark PHP unhealthy and restart a perfectly
#   good container, and vice versa. Each container must report only its own
#   health.
#
# WHY not a PHP script:
#   `php -r` would test the CLI binary, not the FPM master and its worker pool —
#   which is the thing that actually serves traffic and the thing that can wedge.
# =============================================================================

set -eu

FPM_HOST="${PHP_FPM_HEALTH_HOST:-127.0.0.1}"
FPM_PORT="${PHP_FPM_PORT:-9000}"

# cgi-fcgi needs these CGI variables to form a valid FastCGI request. They map to
# the `ping.path` declared in the FPM pool config.
RESPONSE="$(
    SCRIPT_NAME=/ping \
    SCRIPT_FILENAME=/ping \
    REQUEST_METHOD=GET \
    cgi-fcgi -bind -connect "${FPM_HOST}:${FPM_PORT}" 2>/dev/null
)" || {
    echo "UNHEALTHY: cannot connect to php-fpm at ${FPM_HOST}:${FPM_PORT}" >&2
    exit 1
}

# The response includes CGI headers followed by the body, so match rather than
# compare exactly.
case "${RESPONSE}" in
    *pong*)
        exit 0
        ;;
    *)
        echo "UNHEALTHY: php-fpm did not answer 'pong'. Got: ${RESPONSE}" >&2
        exit 1
        ;;
esac
