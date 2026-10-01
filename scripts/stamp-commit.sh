#!/usr/bin/env bash
# =============================================================================
# stamp-commit.sh — replace the commit placeholder with the real commit
# -----------------------------------------------------------------------------
# WHY A PLACEHOLDER EXISTS AT ALL
#
# The tracker records, for `Last Verified Commit` and for every evidence row,
# the commit the measurement was taken on. That hash cannot be known while the
# tracker is being written — it is created by the commit that includes the
# tracker itself. So the writing step leaves the placeholder (STAMP_PLACEHOLDER
# in shift.env, `__COMMIT__` by default) behind deliberately and the
# substitution happens afterwards.
#
# That "afterwards" is a step somebody has to remember. A gate run that dies
# before its commit leaves placeholders in the tracker: a stamp that is not
# stale but ABSENT, while still occupying the field where a reader expects a
# hash. `DoD-SL-08` in scripts/arch-check.sh makes that state fail the gate;
# this script is the other half — the way to fix it.
#
# USAGE
#   bash scripts/stamp-commit.sh              # stamp with HEAD
#   bash scripts/stamp-commit.sh <ref>        # stamp with a specific commit
#   bash scripts/stamp-commit.sh --check      # report only, change nothing
#
# The stamped files are left MODIFIED, not committed: what they now claim is
# that HEAD measured them, and turning that claim into a commit is a decision
# for whoever ran the gates — not for this script.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=config/shift.env
. "$ROOT/scripts/config/shift.env"

PLACEHOLDER="$STAMP_PLACEHOLDER"
MODE="${1:-}"

files() { grep -rl "$PLACEHOLDER" "$DOCS_DIR/" 2>/dev/null | sort || true; }

FOUND="$(files)"

if [ -z "$FOUND" ]; then
    echo "لا علامة نائبة — لا شيء يُختَم."
    exit 0
fi

if [ "$MODE" = "--check" ]; then
    echo "علامات نائبة قائمة في:"
    printf '  %s\n' $FOUND
    exit 1
fi

REF="${MODE:-HEAD}"
SHA="$(git rev-parse --short "$REF")"

# Refuse to stamp with a commit that does not contain the files being stamped.
# Stamping a document with a commit made BEFORE it was written is the exact
# false claim this whole mechanism exists to prevent.
for f in $FOUND; do
    if ! git ls-tree -r --name-only "$REF" -- "$f" | grep -q .; then
        echo "توقّف: $f غير موجود في $SHA — الختم به ادّعاءُ قياسٍ لم يقع." >&2
        exit 1
    fi
done

for f in $FOUND; do
    count=$(grep -c "$PLACEHOLDER" "$f")
    perl -pi -e "s/\Q$PLACEHOLDER\E/$SHA/g" "$f"
    echo "  $f — $count موضعًا ⟵ $SHA"
done

echo "خُتمت بـ $SHA. الملفات معدَّلة وغير ملتزمة عمدًا."
