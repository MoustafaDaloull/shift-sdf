#!/usr/bin/env bash
# =============================================================================
# protected-paths-check.sh — fail a PR when protected files change without
# the approving Change Request marker in the commit range.
# -----------------------------------------------------------------------------
# The protected set is read from `scripts/config/protected-paths.txt` (one glob
# per line; `*` matches one path segment). The CR marker pattern is
# CHANGE_REQUEST_PATTERN in shift.env. Local runs may pass an explicit base
# ref; CI supplies the pull request base SHA.
#
# Usage: bash scripts/protected-paths-check.sh [base-ref]
# Exit:  0 = clean or CR-backed · 1 = protected change without CR
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# shellcheck source=config/shift.env
. "$ROOT/scripts/config/shift.env" || exit 2

BASE_REF="${1:-${PROTECTED_BASE_REF:-origin/main}}"
if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
    echo "✗ protected paths: base ref غير موجود: $BASE_REF" >&2
    exit 1
fi

if [ ! -f "$PROTECTED_PATHS_FILE" ]; then
    echo "✗ protected paths: ملف الأنماط غير موجود: $PROTECTED_PATHS_FILE — لا حماية بلا قائمة مُعلَنة" >&2
    exit 1
fi

# glob ⟶ ERE: `.` literal, `*` one segment. The list is joined into one
# anchored alternation so a single grep decides membership.
protected=""
while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [ -n "$line" ] || continue
    re="$(printf '%s' "$line" | sed -e 's|[.]|\\.|g' -e 's|\*|[^/]*|g')"
    protected="${protected:+$protected|}$re"
done < <(tr -d '\r' < "$PROTECTED_PATHS_FILE")

if [ -z "$protected" ]; then
    echo "✗ protected paths: $PROTECTED_PATHS_FILE بلا نمط واحد — قائمة فارغة لا تحمي شيئًا" >&2
    exit 1
fi
protected="^($protected)$"

changed="$(git diff --name-only "$BASE_REF"...HEAD -- | grep -E "$protected" || true)"

if [ -z "$changed" ]; then
    echo "✓ protected paths: لا تعديل في الوثائق المحمية"
    exit 0
fi

range="${BASE_REF}..HEAD"
messages="$(git log --format='%B' "$range")"
if grep -Eq "$CHANGE_REQUEST_PATTERN" <<<"$messages"; then
    echo "✓ protected paths: تعديل محمي مرتبط بـChange Request؛ يلزم CODEOWNER review"
    printf '%s\n' "$changed" | sed 's/^/    /'
    exit 0
fi

echo "✗ تعديل وثائق محمية بلا Change Request في سجل الالتزامات:" >&2
printf '%s\n' "$changed" | sed 's/^/    /' >&2
exit 1
