#!/usr/bin/env bash
# =============================================================================
# GATE-I18N — rewrite the literal baseline from today's code
# -----------------------------------------------------------------------------
# Run after a slice moves primary-language texts into the locale catalogue: the
# per-file counts go DOWN and the ratchet is tightened to them. Review the diff
# of the baseline before committing — a count that went UP means a new literal,
# which the gate exists to stop, not to absorb.
#
#   bash scripts/i18n/refresh-baseline.sh
#
# Reads the same config as the gate (scripts/config/shift.env) and runs the
# same script inside the node container, so the baseline and the gate can
# never disagree about what counts.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CONFIG="$ROOT/scripts/config/shift.env"
[ -f "$CONFIG" ] || { echo "scripts/config/shift.env غير موجود" >&2; exit 2; }
# shellcheck source=../config/shift.env
. "$CONFIG"

if [ -z "${COMPOSE_PROJECT_NAME:-}" ] && [ -f .env ]; then
    COMPOSE_PROJECT_NAME="$(grep -E '^COMPOSE_PROJECT_NAME=' .env | tail -n1 | cut -d= -f2 | tr -d '\r')"
fi
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-$COMPOSE_PROJECT_BASE}"

DC="docker compose --project-directory . -f $COMPOSE_DIR/$COMPOSE_BASE_FILE -f $COMPOSE_DIR/$COMPOSE_DEV_FILE"
OUT="$I18N_BASELINE_FILE"

src="${FRONTEND_SRC#"$FRONTEND_DIR"/}"
cfg=$(printf '{"src":"%s","locales":"%s","primary":"%s","secondary":"%s","entries":"%s","excludeRegex":"%s","translateFn":"%s"}' \
    "$src" "$src/$I18N_LOCALES_SUBDIR" "$I18N_PRIMARY_LOCALE" "$I18N_SECONDARY_LOCALE" \
    "$I18N_CLIENT_ENTRIES" "$(printf '%s' "$I18N_EXCLUDE_REGEX" | sed 's/\\/\\\\/g; s/"/\\"/g')" "$I18N_TRANSLATE_FN")

mkdir -p "$(dirname "$OUT")"
{ printf 'globalThis.SHIFT_I18N = %s;\n' "$cfg"; cat scripts/i18n/i18n-check.cjs; } \
    | $DC exec -T "$NODE_SERVICE" sh -lc "cd $NODE_WORKDIR && node - --print-counts" > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
echo "كُتب $OUT — راجع الفرق قبل الالتزام: عدٌّ ارتفع يعني نصًّا حرفيًّا جديدًا لا أساسًا يُحدَّث"
