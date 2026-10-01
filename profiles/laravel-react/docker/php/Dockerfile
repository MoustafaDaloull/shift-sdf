# syntax=docker/dockerfile:1.7
# =============================================================================
# {{PROJECT_NAME}} — PHP / Laravel image
# -----------------------------------------------------------------------------
# Multi-stage build with four targets:
#   base         -> shared runtime: PHP + extensions + non-root user (no app code)
#   development  -> base + Xdebug + Composer + dev tooling (code arrives via bind mount)
#   vendor       -> throwaway stage that resolves Composer dependencies for prod
#   production   -> base + baked app code + vendor + aggressive OPcache (immutable)
#
# WHY Alpine: image size is paid on every cold start of a managed container
# platform. Alpine keeps the runtime layer ~5x smaller than bookworm. The
# trade-off is musl libc instead of glibc; all extensions below are compiled
# against musl by install-php-extensions, which is the supported path.
#
# WHY a single Dockerfile for all environments: dev and prod share the exact same
# `base` layer, so an extension that exists in dev provably exists in prod. This
# removes the classic "works in dev, missing ext in prod" class of failure.
# =============================================================================

ARG PHP_VERSION=8.5.3
ARG ALPINE_VERSION=3.22
ARG COMPOSER_VERSION=2.9

# ---------------------------------------------------------------------------
# Composer binary, pinned and aliased as a named stage.
# ---------------------------------------------------------------------------
# WHY a stage instead of `COPY --from=composer:${COMPOSER_VERSION}` directly:
# BuildKit only expands variables in `--from` when the ARG is global, and
# re-declaring the ARG inside a later stage shadows it with an empty value —
# which fails with `invalid reference format`. Resolving the image once here,
# at global scope, sidesteps the whole problem and gives every downstream stage
# a stable name to copy from.
FROM composer:${COMPOSER_VERSION} AS composer-bin


# =============================================================================
# STAGE 1 — base
# Shared by every downstream target. Contains no application code on purpose.
# =============================================================================
FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION} AS base

# Build-time identity of the runtime user. Defaults to 1000 because that is the
# first non-root uid on WSL2/Ubuntu. Overriding these at build time makes files
# created inside the container (logs, cache, uploads) owned by the host user, so
# bind-mounted files stay editable from Windows/VS Code without chown dances.
ARG APP_USER=app
ARG APP_UID=1000
ARG APP_GID=1000

# PHP-FPM listens here. Nginx runs in a separate container and connects over the
# Compose network, so we bind TCP rather than a unix socket (a socket cannot
# cross a container boundary).
ARG PHP_FPM_PORT=9000

ENV APP_USER=${APP_USER} \
    PHP_FPM_PORT=${PHP_FPM_PORT} \
    # Composer must never run interactively inside an image build.
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_NO_INTERACTION=1 \
    # Keep Composer's cache on a predictable path so Compose/BuildKit can cache it.
    COMPOSER_HOME=/tmp/composer

# -----------------------------------------------------------------------------
# System packages
# -----------------------------------------------------------------------------
#   fcgi        -> provides cgi-fcgi, used by the FPM healthcheck to speak
#                  FastCGI directly. Without it we would have to healthcheck FPM
#                  through Nginx, which couples two services' health together.
#   mysql-client-> lets `docker compose exec php` run migrations/dumps and lets
#                  operators verify DB connectivity from the app's own network
#                  position (the app container, not the DB container).
#   git/unzip   -> required by Composer to fetch and extract packages.
#   tini        -> PID 1 init. PHP-FPM does not reap orphaned children well and
#                  ignores SIGTERM semantics we want; tini gives correct signal
#                  forwarding and zombie reaping for graceful shutdown.
#
# A project that processes video adds `ffmpeg` here (it ships `ffprobe` too);
# the queue, scheduler and test services build from this same image, so the
# worker that runs the job has it. Reproducibility comes from the pinned Alpine
# base like every other package in this block.
RUN apk add --no-cache \
        fcgi \
        git \
        mysql-client \
        tini \
        tzdata \
        unzip \
    && rm -rf /var/cache/apk/*

# -----------------------------------------------------------------------------
# PHP extensions
# -----------------------------------------------------------------------------
# install-php-extensions is copied from its own published image rather than
# curl-ed from the internet at build time. That keeps the build hermetic and
# pins the supply chain to an immutable image digest-able tag.
COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/

# Extension rationale:
#   pdo_mysql  -> MySQL 8.4 is the approved primary datastore.
#   redis      -> Redis is the approved cache/session/queue/rate-limit driver.
#   igbinary   -> compact serializer for Redis payloads; materially smaller
#                 cache entries than PHP's native serializer.
#   opcache    -> mandatory for acceptable PHP performance; tuned per-env below.
#   intl       -> Arabic-first platform: collation, locale-aware formatting,
#                 and calendar handling all depend on ICU.
#   gd + exif  -> image thumbnails and EXIF orientation.
#   zip        -> Composer archives + document/report export.
#   bcmath     -> money math. Financial values must never be computed in
#                 binary floats.
#   pcntl+posix-> required by Laravel queue workers for signal handling, so
#                 `docker stop` drains jobs instead of killing them.
#   sockets    -> needed by several queue/transport drivers.
#   soap/ldap are intentionally NOT installed: add them only when an approved
#   integration needs them.
RUN install-php-extensions \
        bcmath \
        exif \
        gd \
        igbinary \
        intl \
        opcache \
        pcntl \
        pdo_mysql \
        posix \
        redis \
        sockets \
        zip
# NOTE: install-php-extensions is deliberately left in place here because the
# `development` stage needs it for Xdebug. The `production` stage deletes it so
# the shipped image cannot compile or enable new extensions at runtime.

# -----------------------------------------------------------------------------
# Runtime user
# -----------------------------------------------------------------------------
# The stock php-fpm image runs the master process as root and workers as
# www-data. We replace that with a dedicated, predictable uid/gid so that
# bind-mounted files and a non-root platform policy both behave.
RUN set -eux; \
    # Alpine's base image ships a `ping` group at gid 999 and www-data at 82.
    # Create the app group/user only if the requested ids are free.
    if ! getent group "${APP_GID}" >/dev/null; then addgroup -g "${APP_GID}" "${APP_USER}"; fi; \
    if ! getent passwd "${APP_UID}" >/dev/null; then \
        adduser -u "${APP_UID}" -G "$(getent group "${APP_GID}" | cut -d: -f1)" -h /home/"${APP_USER}" -s /bin/sh -D "${APP_USER}"; \
    fi; \
    # vendor/ is created here on purpose, empty. In development it is a named
    # volume mounted at this exact path, and Docker seeds a new volume from
    # whatever the image holds there — including its ownership. With no such
    # directory in the image there is nothing to seed from, so Docker creates
    # the mountpoint as root:root and Composer, running as ${APP_USER}, cannot
    # write into it: "vendor/composer does not exist and could not be created".
    # Verified on a cold stack. Creating it here costs one empty directory and
    # makes the volume arrive owned by the user that must fill it.
    mkdir -p /var/www/html/vendor /home/"${APP_USER}" "${COMPOSER_HOME}"; \
    chown -R "${APP_UID}:${APP_GID}" /var/www/html /home/"${APP_USER}" "${COMPOSER_HOME}"

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
# Baseline php.ini + FPM pool. Environment-specific overlays (Xdebug, OPcache
# strictness) are layered by the development/production stages below, so the
# ordering prefix in the filename controls precedence.
COPY docker/php/conf.d/10-base.ini   /usr/local/etc/php/conf.d/10-base.ini
COPY docker/php/fpm/www.conf         /usr/local/etc/php-fpm.d/zz-app-www.conf

# Operational scripts. Copied with the exec bit set explicitly because the host
# may be Windows and cannot represent the POSIX executable permission.
COPY --chmod=0755 docker/php/entrypoint.sh   /usr/local/bin/app-entrypoint
COPY --chmod=0755 docker/php/healthcheck.sh  /usr/local/bin/app-healthcheck

WORKDIR /var/www/html

EXPOSE ${PHP_FPM_PORT}

# Speaks FastCGI to the local FPM master and asserts it answers /ping. This is
# inherited by every downstream stage; production tightens the interval.
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=5 \
    CMD ["app-healthcheck"]

# tini as PID 1 -> correct SIGTERM propagation -> graceful worker drain.
ENTRYPOINT ["/sbin/tini", "--", "app-entrypoint"]
CMD ["php-fpm", "--nodaemonize"]


# =============================================================================
# STAGE 2 — development
# Code is NOT copied in; it is bind-mounted by compose.dev.yaml so edits on the
# host are visible instantly without a rebuild.
# =============================================================================
FROM base AS development

# Composer is only present in the development image. Production installs its
# dependencies in the `vendor` stage and ships without Composer at all, which
# removes an arbitrary-code-execution tool from the production attack surface.
COPY --from=composer-bin /usr/bin/composer /usr/local/bin/composer

# Xdebug is a development-only concern: it imposes a large runtime penalty and
# opens a debugging channel, so it must never exist in the production image.
RUN install-php-extensions xdebug

# Overlay files sort after 10-base.ini, so these win where they overlap.
COPY docker/php/conf.d/20-development.ini /usr/local/etc/php/conf.d/20-development.ini
COPY docker/php/conf.d/30-xdebug.ini      /usr/local/etc/php/conf.d/30-xdebug.ini

ENV APP_ENV=local \
    PHP_ENVIRONMENT=development

USER ${APP_USER}


# =============================================================================
# STAGE 3 — vendor  (build-only, never shipped)
# Resolves Composer dependencies in isolation so that the production layer cache
# is invalidated only when composer.json/composer.lock change — not on every
# application source edit.
# =============================================================================
FROM base AS vendor

COPY --from=composer-bin /usr/bin/composer /usr/local/bin/composer

# NOTE: this stage requires backend/composer.json to exist. Until the Laravel
# application is scaffolded, build only the `development` target (which is what
# compose.dev.yaml does). See docker/README.md.
COPY backend/composer.json backend/composer.lock ./

# --no-dev            : PHPUnit/Pint/etc. must not exist in production.
# --no-scripts        : artisan scripts need the full source tree, which is not
#                       present yet in this stage; they run in the final stage.
# --classmap-authoritative : fastest autoloader; safe because the shipped code is
#                       immutable inside the image.
# This stage runs as root (base sets no USER), so the cache mount needs no
# uid/gid remapping. The cache survives rebuilds and makes dependency resolution
# near-instant on repeat builds.
RUN --mount=type=cache,target=/tmp/composer \
    composer install \
        --no-dev \
        --no-scripts \
        --no-progress \
        --prefer-dist \
        --classmap-authoritative

# The autoloader must be regenerated AFTER the application source is present.
#
# `--classmap-authoritative` means "the classmap is complete, never fall back
# to PSR-4". The install above ran with composer.json alone, so the classmap it
# wrote knew every vendor class and ZERO `App\` classes. The reference project
# measured the consequence on the first run of this image: the image loaded no
# module, provider or seeder; `migrate --seed` created 1 of 100+ tables, died
# on `Class "App\Shared\Http\ApiSurface" not found`, and still exited 0.
#
# Dumping here, in the stage that owns Composer, keeps Composer out of the
# shipped image. The install layer above stays cached (it depends only on the
# two manifests), so a code-only change re-runs this cheap step alone. The
# classmap paths are relative to /var/www/html, which is the same path in the
# production stage. The final `php -r` is a build-time proof that the shared
# kernel is reachable through the authoritative classmap.
COPY backend/ ./
RUN composer dump-autoload \
        --no-dev \
        --no-scripts \
        --classmap-authoritative \
    && php -r 'require "vendor/autoload.php"; exit(class_exists("App\\Shared\\Http\\ApiSurface") ? 0 : 1);'


# =============================================================================
# STAGE 4 — production
# Immutable, non-root, no Composer, no Xdebug, timestamp validation disabled.
# =============================================================================
FROM base AS production

ARG APP_USER
ARG APP_UID
ARG APP_GID

COPY docker/php/conf.d/20-production.ini /usr/local/etc/php/conf.d/20-production.ini

# Remove the extension installer: the production image must not be able to add
# extensions (or run its compiler toolchain) after it is built.
RUN rm -f /usr/local/bin/install-php-extensions

# Dependencies first (rarely change) then source (changes constantly) so that a
# code-only deploy reuses the vendor layer.
COPY --chown=${APP_UID}:${APP_GID} --from=vendor /var/www/html/vendor ./vendor
COPY --chown=${APP_UID}:${APP_GID} backend/ ./

# Writable paths must exist and be owned by the runtime user before we drop
# privileges. Everything else in the image stays read-only, which lets the
# container run with a read-only root filesystem in production.
#
# The paths are spelled out, not brace-expanded: RUN uses /bin/sh (BusyBox ash
# on Alpine), which has no brace expansion, so `{cache,sessions,...}` created
# ONE directory with that literal name and none of the four.
RUN set -eux; \
    mkdir -p storage/framework/cache storage/framework/sessions \
        storage/framework/testing storage/framework/views \
        storage/app/public storage/logs bootstrap/cache; \
    chown -R "${APP_UID}:${APP_GID}" storage bootstrap/cache; \
    chmod -R u+rwX storage bootstrap/cache

ENV APP_ENV=production \
    PHP_ENVIRONMENT=production

USER ${APP_USER}

# Fails the container if the FPM master stops accepting FastCGI requests.
HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=3 \
    CMD ["app-healthcheck"]
