#!/usr/bin/env bash
# =============================================================================
# Isolated worktree per agent - the fix for a lesson learned three times
# -----------------------------------------------------------------------------
# The same incident, three times over: two sessions working one tree. What it
# costs, measured rather than imagined:
#
#   · another session checked out a new branch mid-slice and a slice commit
#     landed on it (twice)
#   · the shared index carried one session's staged files into the other's
#     commit, discovered only after the branch was pushed. And a throwaway
#     probe migration from one session reddened the other's gate run, because
#     `php artisan migrate:status` reads one database for both.
#
# None of this is carelessness. `git add` then `git commit` is two steps over
# one shared index file, and nothing makes them atomic. The tree, the index,
# the branch checkout and the dev database are all single-writer resources that
# two sessions are asked to share.
#
# A worktree gives each agent its own checkout and its own index against the
# same repository and object store. Branches stay shared, history stays
# shared, and no session can see or stage another's files.
#
# -- Docker isolation --------------------------------------------------------
# The compose project name and every published port come from the tree's own
# .env, so `new` provisions one: the main tree's .env copied with a unique
# COMPOSE_PROJECT_NAME (<COMPOSE_PROJECT_BASE>-<name>) and a port slot. The
# tree then drives its own containers, volumes and database, and its gates may
# run CONCURRENTLY with other isolated trees. `drop` tears the tree's stacks
# down first.
#
# Two preconditions before relying on that concurrency:
#   1. a measured capacity check - two full stacks up + `docker stats`;
#   2. a deliberate-breach proof across two stacks: a probe migration in stack
#      A must NOT redden stack B's migrate:status, and two concurrent gate
#      runs must both come back green.
# Until both are on record - and always for a tree sharing a stack (no
# provisioned .env) - one agent runs the gates at a time.
#
# First boot of an isolated stack starts with EMPTY vendor/ and node_modules
# volumes - dependency install runs once per tree. That cost is paid once and
# is part of deciding whether a slice deserves its own tree.
#
# -- The dev database starts empty too, and several gates depend on it ------
# A fresh tree at a commit CI had passed green can run most gates green and
# several red, none of them about the code: the OpenAPI stage refuses to run
# against pending migrations by design, and the browser gates drive an
# application whose schema does not exist yet.
#
# So the tree is not ready when it is healthy - it is ready when it is
# migrated. After `up -d` reports every service healthy, run once per tree:
#
#   docker compose --project-directory . \
#     -f <COMPOSE_DIR>/<COMPOSE_BASE_FILE> -f <COMPOSE_DIR>/<COMPOSE_DEV_FILE> \
#     exec <PHP_SERVICE> php artisan migrate --seed
#
# --seed and not bare migrate: the integration gate registers an account
# against the real backend, and registration reads reference data that only
# the seeders write. No user is seeded on purpose.
#
# -- The commit rule that still applies inside a worktree -------------------
# Commit with an explicit pathspec - `git commit <paths> -m ...` - rather than
# `git add` followed by `git commit`. In a worktree the index is already
# private, so this is belt and braces; in the shared tree it is the difference
# between your commit and someone else's.
#
# Usage:
#   bash scripts/agent-worktree.sh new <name> [base-branch]   create and print the path
#   bash scripts/agent-worktree.sh list                       show every worktree
#   bash scripts/agent-worktree.sh drop <name>                remove one (refuses if dirty)
#
# Worktrees live beside the repository, never inside it - a checkout nested in
# the repo would be walked by every gate that greps the tree.
# =============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# shellcheck source=config/shift.env
. "$ROOT/scripts/config/shift.env" || exit 2

# The trees root is anchored to the MAIN worktree, never to whichever tree
# this script happens to run from. Deriving it from $ROOT put a tree created
# from inside another tree under "<tree>-agents/", giving it a private slot
# space that restarted at 1 - so nested trees were minted onto ports already
# published by outer ones. git tracks the main checkout for us: the common git
# dir is the main repository's .git from every worktree alike.
MAIN_ROOT="$(cd "$(dirname "$(git rev-parse --git-common-dir 2>/dev/null || echo "$ROOT/.git")")" && pwd)"
REPO_NAME="$(basename "$MAIN_ROOT")"
TREES_DIR="$(dirname "$MAIN_ROOT")/${REPO_NAME}${WORKTREE_DIR_SUFFIX}"

MAX_EXTRA="${MAX_EXTRA_WORKTREES:-3}"
BRANCH_PREFIX="${WORKTREE_BRANCH_PREFIX:-agent/}"
COMPOSE_BASE="$COMPOSE_DIR/$COMPOSE_BASE_FILE"
COMPOSE_DEV="$COMPOSE_DIR/$COMPOSE_DEV_FILE"
COMPOSE_TEST="$COMPOSE_DIR/$COMPOSE_TEST_FILE"

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }

usage() { sed -n '/^# Usage:/,/^# ====/p' "$0" | sed 's/^# \{0,2\}//;$d'; }

# Replace KEY=value in an env file, or append it when absent. sed with a "|"
# delimiter because the values carry "/" (URLs).
set_env() {
    local file="$1" key="$2" val="$3"
    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$file"
    else
        printf '%s=%s\n' "$key" "$val" >> "$file"
    fi
}

ACTION="${1:-}"
NAME="${2:-}"
BASE="${3:-}"

case "$ACTION" in

new)
    # الحدّ الأقصى لشجرات العمل الإضافية من الإعداد. الشجرة الرئيسة للتكامل
    # ولا تدخل في العد.
    ACTIVE_EXTRA=$(( $(git worktree list --porcelain | grep -c '^worktree ' || echo 1) - 1 ))
    if [ "$ACTIVE_EXTRA" -ge "$MAX_EXTRA" ]; then
        red "✗ بلغت شجرات العمل الحد الأقصى: $MAX_EXTRA شجرة إضافية (MAX_EXTRA_WORKTREES)"
        exit 2
    fi

    if [ -z "$NAME" ]; then
        red "اسم الشجرة مطلوب — يُستحسن أن يكون اسم الشريحة أو الموديول"
        usage >&2
        exit 2
    fi

    # The branch name mirrors the worktree name, so `git worktree list` and
    # `git branch` tell the same story. A tree whose branch is named after
    # something else is how a session loses track of where it is working.
    BRANCH="${BRANCH_PREFIX}${NAME}"
    DEST="$TREES_DIR/$NAME"

    if [ -e "$DEST" ]; then
        red "المسار موجود مسبقًا: $DEST"
        exit 1
    fi

    if [ -z "$BASE" ]; then
        BASE="$(git rev-parse --abbrev-ref HEAD)"
    fi

    # A worktree created from a dirty base still starts clean - it checks out
    # the commit, not the working tree - so the caller is told rather than
    # stopped, because uncommitted work in the main tree is normal here.
    if [ -n "$(git status --porcelain)" ]; then
        dim "تنبيه: الشجرة الرئيسة فيها تعديلات غير ملتزَمة — الشجرة الجديدة تبدأ من $BASE الملتزَم، لا منها."
    fi

    mkdir -p "$TREES_DIR"

    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        git worktree add "$DEST" "$BRANCH" || exit 1
    else
        git worktree add -b "$BRANCH" "$DEST" "$BASE" || exit 1
    fi

    # -- Provision the tree's own Docker stack ------------------------------
    # Copy the main .env and override the identity keys. .env is git-ignored,
    # so this never shows up in the tree's status. Without a main .env there
    # is nothing safe to copy - the tree would drive the MAIN stack, which is
    # the shared-index collision in Docker form - so the shared-stack rule is
    # announced out loud.
    STACK_MSG="  · حزمة Docker **مشتركة** (لا .env رئيسي يُنسخ) — لا تُشغَّل البوابات من شجرتين معًا"
    if [ -f "$ROOT/.env" ]; then
        # Compose project names must be lowercase; sanitise the tree name.
        PROJ="${COMPOSE_PROJECT_BASE}-$(printf '%s' "$NAME" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9-]/-/g')"

        # Lowest free port slot 1..WORKTREE_PORT_SLOTS, marked by PORT_SLOT in
        # every existing tree. The scan is recursive on purpose: a single-level
        # glob missed trees nested one directory deeper and handed out a slot
        # whose host ports were already published - a gate can bind to another
        # tree's Vite and grade its code. Collected first, then searched:
        # piping find into `grep -q` makes the loop depend on how xargs
        # happened to batch the files, and a grep that exits early can SIGPIPE
        # the producer.
        USED="$(find "$TREES_DIR" -name .env -type f -exec grep -h '^PORT_SLOT=' {} + 2>/dev/null | cut -d= -f2 | sort -u)"
        SLOT=1
        while [ "$SLOT" -le "$WORKTREE_PORT_SLOTS" ] && echo "$USED" | grep -qx "$SLOT"; do
            SLOT=$((SLOT + 1))
        done
        if [ "$SLOT" -gt "$WORKTREE_PORT_SLOTS" ]; then
            red "لا فتحة منافذ حرة (1..$WORKTREE_PORT_SLOTS) — أزل شجرة قبل إنشاء أخرى"
            exit 1
        fi
        OFFSET=$((SLOT * WORKTREE_PORT_STEP))

        cp "$ROOT/.env" "$DEST/.env"
        set_env "$DEST/.env" COMPOSE_PROJECT_NAME "$PROJ"
        set_env "$DEST/.env" PORT_SLOT "$SLOT"
        # HOST ports only (WORKTREE_PORT_VARS). Ports the app dials INSIDE the
        # compose network stay fixed in every tree (WORKTREE_FIXED_VARS) —
        # shifting them once pointed the app at a port where nothing listens,
        # and every path behind it answered 500.
        for kv in $WORKTREE_PORT_VARS; do
            set_env "$DEST/.env" "${kv%%:*}" "$(( ${kv#*:} + OFFSET ))"
        done
        for kv in $WORKTREE_FIXED_VARS; do
            set_env "$DEST/.env" "${kv%%=*}" "${kv#*=}"
        done
        # The SPA and the backend must point at THIS tree's web entry, not the main one.
        for key in $WORKTREE_URL_VARS; do
            set_env "$DEST/.env" "$key" "http://localhost:$((WORKTREE_URL_PORT_BASE + OFFSET))"
        done

        STACK_MSG="  · حزمة معزولة: $PROJ (منافذ +$OFFSET · المدخل على $((WORKTREE_URL_PORT_BASE + OFFSET))) — أول إقلاع يثبّت الاعتماديات كاملة
  · وقاعدة التطوير تبدأ **فارغة**، وعدة بوابات تعتمد عليها. بعد الإقلاع مرة واحدة:
      docker compose --project-directory . -f $COMPOSE_BASE -f $COMPOSE_DEV exec $PHP_SERVICE php artisan migrate --seed"
    fi

    echo
    green "الشجرة جاهزة: $DEST"
    dim "  الفرع: $BRANCH   (من $BASE)"
    echo
    dim "شغّل الوكيل من هناك:"
    dim "  cd \"$DEST\""
    echo
    dim "وتذكّر:"
    dim "  · الالتزام بمسار صريح: git commit <paths> -m ...  (لا git add -A)"
    dim "$STACK_MSG"
    dim "  · التوازي عند البوابات مشروط بالشرطين القبليين (السعة · الخرق المتعمَّد)"
    dim "  · عند الانتهاء: bash scripts/agent-worktree.sh drop $NAME"
    ;;

list)
    git worktree list
    ;;

drop)
    if [ -z "$NAME" ]; then
        red "اسم الشجرة مطلوب"
        exit 2
    fi
    DEST="$TREES_DIR/$NAME"
    if [ ! -d "$DEST" ]; then
        red "لا توجد شجرة بهذا الاسم: $DEST"
        exit 1
    fi

    # Never `--force`. An uncommitted change in an agent's tree is work, and a
    # cleanup command that discards work is a worse failure than the mess it
    # tidies - which is also why deletion is a human decision gate (HG-I-08).
    if [ -n "$(git -C "$DEST" status --porcelain)" ]; then
        red "الشجرة فيها تعديلات غير ملتزَمة — لن تُحذف:"
        git -C "$DEST" status --short | sed 's/^/      /'
        dim "التزمها أو انقلها، ثم أعد المحاولة."
        exit 1
    fi

    # -- Tear down the tree's stacks before removing it ---------------------
    # A stack that outlives its tree is the orphaned-containers failure with
    # no tree left to stop it from. Guarded against the main project name so a
    # tree that was never provisioned cannot take the main stack down with it.
    # `down` without -v on purpose: the volumes hold data, and deleting data
    # is a human decision - they are listed instead.
    #
    # `--remove-orphans` is not decoration. The test stage runs PHPUnit through
    # `compose run`, and a run container is not a service: a plain `down` takes
    # the database and cache away and leaves the test runner alive, still
    # holding the network it was told to release — measured after stopping a
    # gate run: the run container survived `down` and the network removal then
    # failed with "Resource is still in use".
    if [ -f "$DEST/.env" ]; then
        TREE_PROJ="$(grep -E '^COMPOSE_PROJECT_NAME=' "$DEST/.env" | tail -n1 | cut -d= -f2 | tr -d '\r')"
        MAIN_PROJ="$(grep -Es '^COMPOSE_PROJECT_NAME=' "$ROOT/.env" 2>/dev/null | tail -n1 | cut -d= -f2 | tr -d '\r')"
        if [ -n "$TREE_PROJ" ] && [ "$TREE_PROJ" != "${MAIN_PROJ:-$COMPOSE_PROJECT_BASE}" ]; then
            docker compose --project-directory "$DEST" \
                -f "$DEST/$COMPOSE_BASE" -f "$DEST/$COMPOSE_DEV" \
                down --remove-orphans >/dev/null 2>&1 || true
            docker compose --project-directory "$DEST" -p "${TREE_PROJ}-test" \
                -f "$DEST/$COMPOSE_BASE" -f "$DEST/$COMPOSE_TEST" \
                down --remove-orphans >/dev/null 2>&1 || true
            dim "أُسقطت حزمتا الشجرة ($TREE_PROJ · $TREE_PROJ-test). الحجوم باقية — لعرضها:"
            dim "  docker volume ls -q --filter name=${TREE_PROJ}_"
        fi
        # The .env was provisioned by `new`, is git-ignored, and would block
        # `git worktree remove` as an untracked leftover on some git versions.
        rm -f "$DEST/.env"
    fi

    git worktree remove "$DEST" || exit 1
    green "أُزيلت الشجرة: $DEST"
    dim "الفرع ${BRANCH_PREFIX}${NAME} باقٍ — احذفه بنفسك إن لم تعد تحتاجه."
    ;;

*)
    usage >&2
    exit 2 ;;
esac
