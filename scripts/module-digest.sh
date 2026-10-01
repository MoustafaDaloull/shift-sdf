#!/usr/bin/env bash
# =============================================================================
# Module digest - a line-precise index into an engineering package
# -----------------------------------------------------------------------------
# The problem this solves is measured, not assumed. Before writing a line of a
# slice, the framework requires reading data-model.md, api-contracts.md and
# test-scenarios.md for the target scope. A mature package runs to more than a
# megabyte, and the governance reading that precedes it is larger still. No
# context window holds that, so the files end up searched over and over
# instead of read once - the cost is paid on every slice, and a rule can still
# be missed.
#
# -- What this is, and what it deliberately is not --------------------------
# It is an INDEX: every identifier in the package with the file and line where
# it first appears and the heading it sits under. It restates no requirement,
# no field, no rule, no contract. That restraint is the design: a summary of an
# approved document becomes a second source that drifts from the first. The
# package stays the only authority; this only says where to look.
#
# The payoff is targeted reading. Instead of loading all of api-contracts.md
# to find one endpoint, the reader gets api-contracts.md:147 and reads sixty
# lines around it.
#
# -- Why there is no module map here ----------------------------------------
# The module code is derived from the package's own identifiers - the most
# frequent code across its documents wins. A hard-coded doc-dir to code map
# would be another copy of a mapping that already lives in modules.tsv, and
# copies drift.
#
# -- The status column is a measurement, and a weak one on purpose ----------
# [*] means the identifier appears somewhere under the backend tree - nothing
# more. It is not a claim of implementation and must not be read as one; the
# tracker remains the single source of execution state. It points at what has
# been touched, and its absence is the more informative half.
#
# -- Portability ------------------------------------------------------------
# Plain awk with no GNU-only regex. gawk on a development host supports \y,
# mawk on a CI runner does not, and a tool that behaves differently in the two
# places is the exact divergence the one-sequence rule exists to prevent.
# Identifier boundaries are checked by inspecting the adjacent characters.
#
# Usage:
#   bash scripts/module-digest.sh <module-doc-dir>
#   bash scripts/module-digest.sh <module-doc-dir> --ids API
#   bash scripts/module-digest.sh <module-doc-dir> --gaps
# =============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# shellcheck source=config/shift.env
. "$ROOT/scripts/config/shift.env" || exit 2

BACKEND="$BACKEND_DIR"
TSP="$SCENARIO_ID_PREFIX"
FILTER="ENT|API|US|$TSP"
GAPS_ONLY=0
MODULE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --ids)  FILTER="$2"; shift 2 ;;
        --gaps) GAPS_ONLY=1; shift ;;
        -h|--help) sed -n '/^# Usage:/,/^# ====/p' "$0" | sed 's/^# \{0,2\}//;$d'; exit 0 ;;
        *) MODULE="$1"; shift ;;
    esac
done

list_modules() {
    for d in "$MODULES_DOCS_DIR"/*/; do
        [ -d "$d" ] && printf '  %s\n' "$(basename "$d")"
    done
}

if [ -z "$MODULE" ]; then
    printf 'الاستعمال: bash scripts/module-digest.sh <module-doc-dir> [--ids API] [--gaps]\n\n' >&2
    printf 'الحزم المتاحة:\n' >&2
    list_modules >&2
    exit 2
fi

DOCS="$MODULES_DOCS_DIR/$MODULE"
if [ ! -d "$DOCS" ]; then
    printf 'لا توجد حزمة بهذا الاسم: %s\n\n' "$DOCS" >&2
    list_modules >&2
    exit 2
fi

# -- Module code, derived from the package itself ---------------------------
CODE=$(grep -rhoE "(ENT|API|$TSP|US|BR|FR)-[A-Z]{${MODULE_CODE_MIN},${MODULE_CODE_MAX}}-[0-9]{3}" "$DOCS" --include='*.md' 2>/dev/null \
       | sed -E 's/^[A-Z]+-([A-Z]+)-[0-9]+$/\1/' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')

if [ -z "$CODE" ]; then
    printf 'تعذّر اشتقاق كود الموديول من %s - لا معرّفات في حزمته.\n' "$DOCS" >&2
    exit 1
fi

LOWER=$(printf '%s' "$CODE" | tr '[:upper:]' '[:lower:]')

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
dim()  { printf '\033[2m%s\033[0m\n' "$1"; }

echo
bold "=== $MODULE · $CODE ==="

# -- Package inventory: the volume this index stands in for -----------------
TOTAL_LINES=0
TOTAL_BYTES=0
PKG=""
for f in data-model.md api-contracts.md user-stories.md "$TEST_SCENARIOS_FILE" traceability-matrix.md; do
    [ -f "$DOCS/$f" ] || continue
    L=$(wc -l < "$DOCS/$f")
    B=$(wc -c < "$DOCS/$f")
    TOTAL_LINES=$((TOTAL_LINES + L))
    TOTAL_BYTES=$((TOTAL_BYTES + B))
    PKG="$PKG  ${f%.md}:${L}L"
done
[ -n "$PKG" ] && dim "الحزمة:$PKG"
dim "الإجمالي: $TOTAL_LINES سطرًا · $((TOTAL_BYTES / 1024)) KB - وهذا الفهرس بديلٌ عن قراءتها كاملة"

# -- Identifiers that already appear anywhere under the backend tree --------
IN_CODE=$(grep -rhoE "(ENT|API|US|$TSP)-$CODE-[0-9]{3}" "$BACKEND" 2>/dev/null | sort -u)

# -- The index: one awk pass over the package -------------------------------
# The nearest preceding markdown heading is carried forward, so the index does
# not depend on how each package formats its sections - and they differ: one
# writes "### 2.1 API-XXX-001 - title", another "### API-XXX-001: title", a
# third only a table row. Anchoring on the identifier rather than on the
# heading shape is what lets one script serve all of them.
INDEX=$(find "$DOCS" -maxdepth 1 -name '*.md' -print0 2>/dev/null \
    | xargs -0 -r awk -v code="$CODE" -v filter="$FILTER" -v tsp="$TSP" -v tsfile="$TEST_SCENARIOS_FILE" '
        # The document that owns each identifier type. A package holds more
        # than the five contract files - an engineering analysis note among
        # them - and an entity discussed in an analysis note is not defined
        # there. Ranking the owning document first keeps the index pointing at
        # the approved contract rather than at the earliest mention of it.
        function owner(type) {
            if (type == "ENT") return "data-model.md"
            if (type == "API") return "api-contracts.md"
            if (type == tsp)   return tsfile
            if (type == "US")  return "user-stories.md"
            return ""
        }
        function scan(text, is_heading, is_table,   rest, id, before, after, where, type, base, score) {
            rest = text
            while (match(rest, pat)) {
                id = substr(rest, RSTART, RLENGTH)
                before = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : " "
                after  = substr(rest, RSTART + RLENGTH, 1)
                # Reject a partial hit inside a longer token: a preceding
                # letter or dash means this is the tail of another identifier,
                # a trailing digit means the number is longer than three.
                if (before !~ /[A-Za-z0-9-]/ && after !~ /[0-9]/) {
                    where = FILENAME "|" FNR "|" heading
                    type = substr(id, 1, index(id, "-") - 1)
                    base = FILENAME
                    sub(/^.*\//, "", base)
                    # A heading naming the identifier is its definition site -
                    # every package marks it that way, however differently they
                    # format headings. A summary table row or a cross-reference
                    # is only a mention, and pointing a reader at a mention
                    # wastes the very lookup this exists to save.
                    # Ranked: the owning document first, then a heading that
                    # names the identifier, then a prose line over a table row.
                    # The last rank matters where a package never puts the id
                    # in a heading and it then appears twice: once in the
                    # summary table and once at the definition. A summary row
                    # is an index, so sending a reader there costs the lookup
                    # this saves.
                    score = (base == owner(type) ? 4 : 0) + (is_heading ? 2 : 0) + (is_table ? 0 : 1)
                    # Strictly greater, so the earliest line wins a tie.
                    if (!(id in rank) || score > rank[id]) {
                        rank[id] = score
                        best[id] = where
                    }
                }
                rest = substr(rest, RSTART + RLENGTH)
            }
        }
        BEGIN { pat = "(" filter ")-" code "-[0-9][0-9][0-9]" }
        FNR == 1 { heading = "" }
        /^#+ +/ {
            heading = $0
            sub(/^#+ +/, "", heading)
            gsub(/`/, "", heading)
            scan(heading, 1, 0)
            next
        }
        { scan($0, 0, ($0 ~ /^[ 	]*\|/)) }
        END { for (id in best) printf "%s|%s\n", id, best[id] }
      ' | sort -t"|" -k1,1)

if [ -z "$INDEX" ]; then
    dim "لا معرّفات مطابقة للمرشِّح: $FILTER"
    exit 0
fi

# The traced flag is joined onto every row in a single awk pass. Testing each
# identifier with its own `grep` costs one process per identifier - about four
# hundred per module - and measured close to a minute per module on Windows,
# where process creation dominates everything else.
ANNOTATED=$(awk -F'|' 'NR == FNR { traced[$1] = 1; next }
                       { printf "%s|%s\n", (($1 in traced) ? "*" : "-"), $0 }' \
            <(printf '%s\n' "$IN_CODE") <(printf '%s\n' "$INDEX"))

for TYPE in ENT API US "$TSP"; do
    case "$FILTER" in *"$TYPE"*) ;; *) continue ;; esac
    ROWS=$(printf '%s\n' "$ANNOTATED" | grep -E "^.\|$TYPE-$CODE-" || true)
    [ -z "$ROWS" ] && continue

    DEFINED=$(printf '%s\n' "$ROWS" | wc -l)
    TRACED=$(printf '%s\n' "$ROWS" | grep -c '^\*|' || true)

    echo
    bold "$TYPE-$CODE-*   معرَّف: $DEFINED · له أثر في الكود: $TRACED"
    while IFS="|" read -r flag id file line heading; do
        if [ "$flag" = "*" ]; then
            [ "$GAPS_ONLY" -eq 1 ] && continue
            MARK="[*]"
        else
            MARK="   "
        fi
        # `${file##*/}` not `basename` - the latter is a process per row, and
        # a package with 150 scenarios pays it 150 times.
        printf '  %s %-16s %-24s %s\n' "$MARK" "$id" "${file##*/}:$line" "$heading"
    done <<< "$ROWS"
done

# -- Measured code facts for this module's prefix ---------------------------
echo
bold "المقيس في الكود (بادئة $LOWER)"

TABLES=$(grep -rhoE "Schema::create\('${LOWER}_[a-z0-9_]+'" "$BACKEND" --include='*.php' 2>/dev/null \
         | sed -E "s/Schema::create\('//;s/'\$//" | sort -u | tr '\n' ' ')
printf '  الجداول: %s\n' "${TABLES:-- لا جدول}"

# Routes are declared inside `Route::prefix(...)->group(...)`, so a verb line
# on its own carries a relative path only. Resolving the full path means
# walking nested groups, and a half-resolved path printed as if it were whole
# is worse than an honest summary - `php artisan route:list` already resolves
# them exactly, and is named here instead of imitated badly.
ROUTE_FILES=$(grep -rlE "Route::prefix\('v[0-9]+/${LOWER}" "$BACKEND/app" --include='*.php' 2>/dev/null | sort -u)
if [ -n "$ROUTE_FILES" ]; then
    for rf in $ROUTE_FILES; do
        N=$(grep -cE "Route::(get|post|put|patch|delete)\(" "$rf" 2>/dev/null || printf '0')
        printf '  المسارات: %s تصريحًا في %s\n' "$N" "$rf"
        grep -ohE "Route::prefix\('v[0-9]+/${LOWER}[^']*'" "$rf" 2>/dev/null \
            | sed -E "s/Route::prefix\('/    بادئة: /;s/'\$//" | sort -u
    done
    dim "    (المسار الكامل يُحلّه: php artisan route:list --path=v1/$LOWER)"
else
    printf '  المسارات: - لا ملف مسارات لهذه البادئة\n'
fi

SCEN=$(grep -rhoE "$SCENARIO_TAG +$TSP-$CODE-[0-9]{3}" "$BACKEND_TESTS_DIR" 2>/dev/null \
       | grep -oE "$TSP-$CODE-[0-9]{3}" | sort -u | wc -l)
printf '  سيناريوهات موسومة في الاختبارات: %s\n' "$SCEN"

echo
dim "المصدر الحاكم هو الحزمة نفسها - هذا فهرس مواضع لا خلاصة محتوى."
dim "وحالة التنفيذ تُقرأ من المتتبع التشغيلي وحده."
echo
