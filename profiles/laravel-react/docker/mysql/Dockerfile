# syntax=docker/dockerfile:1.7
# =============================================================================
# {{PROJECT_NAME}} — MySQL 8.4 LTS image
# -----------------------------------------------------------------------------
# WHY THIS IMAGE EXISTS AT ALL
#
# The obvious approach is to bind-mount docker/mysql/conf.d into the stock
# mysql image and skip a custom build entirely. That approach is broken on a
# Windows development host, and the failure is silent.
#
# MySQL refuses to read an option file that is group- or world-writable, as a
# defence against another user tampering with the server's configuration. It
# does not fail, warn loudly, or exit — it logs one line and starts on its
# built-in defaults:
#
#     [Warning] World-writable config file '/etc/mysql/conf.d/server.cnf'
#     is ignored.
#
# Every file bind-mounted from a Windows drive through Docker Desktop is
# presented inside the container as 0777, so on such a host the mounted
# configuration is ALWAYS discarded.
#
# The consequence is specific and serious for an Arabic-first platform: without
# the config, databases are created with MySQL's default utf8mb4_0900_ai_ci,
# an accent-insensitive collation under which Arabic strings differing only by
# a hamza or a diacritic compare as EQUAL. A UNIQUE index on person names would
# then reject legitimately distinct records — and the root cause would be a
# single warning buried in the startup log.
#
# Baking the file in with an explicit mode removes host filesystem semantics
# from the equation. The build needs no network beyond pulling the base image.
#
# REJECTED ALTERNATIVES
#   - Compose `configs:` with `mode: 0444` — outside Swarm, Compose V2 ignores
#     `mode` and falls back to a bind mount. Verified: the warning persisted.
#   - Passing every setting as a `command:` flag — works, but moves ~40 tuned
#     settings and their rationale out of a reviewable file and into a YAML
#     list, and silently drops the `[client]` and `[mysql]` sections.
# =============================================================================

ARG MYSQL_VERSION=8.4.7

FROM mysql:${MYSQL_VERSION}

# 0444 = read-only for owner, group, and other.
#
# The mode is the entire point of this layer. MySQL's check is specifically for
# the group-write and other-write bits; anything writable by a non-owner causes
# the file to be discarded. Ownership is left as root, which the server (running
# as the mysql user) can still read.
COPY --chmod=0444 docker/mysql/conf.d/server.cnf /etc/mysql/conf.d/server.cnf

# Directory the `slow_query_log_file` setting writes into. It must exist and be
# owned by the mysql user before the server drops privileges, or the server
# fails to start with a permissions error on the log file.
RUN mkdir -p /var/log/mysql && chown mysql:mysql /var/log/mysql

# Initialisation scripts are deliberately NOT copied in. They stay a bind mount
# so they can be edited without rebuilding, and MySQL applies no permission
# check to /docker-entrypoint-initdb.d.
#
# BUT THE EXECUTE BIT ON THEM IS LOAD-BEARING. MySQL checks no permissions
# here — its entrypoint, however, branches on exactly one:
#
#     *.sh) if [ -x "$f" ]; then "$f"; else . "$f"; fi
#
# A script without the bit is SOURCED into the entrypoint's own shell, so
# `set -euo pipefail` at the top of 01-init-databases.sh became the entrypoint's
# flags too, and the next unset variable it touched aborted the whole boot:
#
#     docker-entrypoint.sh: line 342: MYSQL_ONETIME_PASSWORD: unbound variable
#
# The container then never reaches healthy and every dependent service fails
# with it. Observed in the reference project's first two CI runs and invisible
# on Windows, where Docker Desktop presents every bind-mounted file as 0777 —
# the same host quirk that forced server.cnf into the image above, arriving
# this time from the opposite direction: there it made a file too permissive
# to be accepted, here it made one executable enough to hide the defect.
#
# Any new script added to docker/mysql/initdb/ must be committed with mode
# 100755 (`git update-index --chmod=+x`). Git tracks that bit; Windows does not
# represent it, so it will not be set for you.
