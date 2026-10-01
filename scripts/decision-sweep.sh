#!/usr/bin/env bash
# =============================================================================
# Decision sweep - every open decision in a module, in one batch
# -----------------------------------------------------------------------------
# The cost this attacks is measured: dozens of implementation decisions minted
# in a couple of days, one round per slice. Each round is a full stop - the
# agent halts, the owner reads, answers, and work resumes. Stops per module,
# not per project.
#
# They do not have to arrive one at a time. A module's open decisions are all
# sitting in its package before the first slice starts; only the habit of
# discovering them slice by slice makes them feel sequential. Sweeping the whole
# module up front turns N stops into one or two.
#
# -- Why the raw counts are useless and this is not -------------------------
# Grepping a package for OD-* gives dozens of hits per module. Nearly all are
# repeat references to the same handful of decisions, and most of those are
# already settled in the decision log. The unique, unsettled remainder is what
# an owner actually has to answer: a handful, against the dozens of raw hits.
#
# So every identifier is checked against the decision log, and the ones already
# recorded there are counted rather than listed. What is left is the batch.
#
# -- The settled flag is an indicator, not a verdict ------------------------
# It means the identifier appears somewhere in the decision log. It does not
# mean the decision covers this module, or that it is still current. Read the
# entry before relying on it - the decision log stays the authority, exactly as
# the package does for module-digest.sh.
#
# -- Asking well ------------------------------------------------------------
# A round is capped at eight questions and wants a recommendation with each.
# This tool finds them; it does not phrase them. Group the output, put the
# blocking ones first, and use the decision format of the framework.
#
# Usage:
#   bash scripts/decision-sweep.sh <module-doc-dir>
#   bash scripts/decision-sweep.sh <module-doc-dir> --all   include settled ones
# =============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# shellcheck source=config/shift.env
. "$ROOT/scripts/config/shift.env" || exit 2

DECISIONS="$DECISIONS_FILE"
SHOW_ALL=0
MODULE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --all) SHOW_ALL=1; shift ;;
        -h|--help) sed -n '/^# Usage:/,/^# ====/p' "$0" | sed 's/^# \{0,2\}//;$d'; exit 0 ;;
        *) MODULE="$1"; shift ;;
    esac
done

if [ -z "$MODULE" ]; then
    printf 'الاستعمال: bash scripts/decision-sweep.sh <module-doc-dir> [--all]\n\n' >&2
    for d in "$MODULES_DOCS_DIR"/*/; do [ -d "$d" ] && printf '  %s\n' "$(basename "$d")" >&2; done
    exit 2
fi

DOCS="$MODULES_DOCS_DIR/$MODULE"
if [ ! -d "$DOCS" ]; then
    printf 'لا توجد حزمة بهذا الاسم: %s\n' "$DOCS" >&2
    exit 2
fi

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
dim()  { printf '\033[2m%s\033[0m\n' "$1"; }
red()  { printf '\033[31m%s\033[0m\n' "$1"; }

echo
bold "=== قرارات مفتوحة · $MODULE ==="

# -- Everything already named in the decision log, in one read --------------
SETTLED=$(grep -ohE '(OD|CFL|ED|GD|DEC)-[A-Z0-9-]+' "$DECISIONS" 2>/dev/null | sort -u)

# -- One grep per identifier family over the package ------------------------
# Only the first occurrence of each identifier is kept, with its file and line,
# so a decision referenced forty times is one row. The trailing context is the
# line itself, trimmed - enough to recognise the decision without opening the
# file, not enough to stand in for reading it.
sweep() {
    local label="$1" pattern="$2"

    local hits
    hits=$(grep -rnoE "$pattern" "$DOCS" --include='*.md' 2>/dev/null \
           | awk -F: '!seen[$3]++ { printf "%s|%s|%s\n", $3, $1, $2 }' | sort -t'|' -k1,1)
    [ -z "$hits" ] && return 0

    local annotated
    annotated=$(awk -F'|' 'NR == FNR { known[$1] = 1; next }
                           { printf "%s|%s\n", (($1 in known) ? "s" : "-"), $0 }' \
                <(printf '%s\n' "$SETTLED") <(printf '%s\n' "$hits"))

    # A third state, and the first version was wrong without it. Open
    # decisions can be resolved IN PLACE: the decision log never names them
    # because it records their resolutions under a DEC-*/CR-* id, and their
    # own line in the package says so plainly. An identifier whose line names
    # a decision is resolved, and reporting it as open sends the owner
    # questions that were answered months ago.
    #
    # The context is read back from the file rather than carried through the
    # pipeline: decision lines are usually table rows, and those are full of
    # the pipe character used as the field separator here.
    local enriched=""
    while IFS='|' read -r flag id file line; do
        [ -z "$id" ] && continue
        local ctx
        ctx=$(sed -n "${line}p" "$file" 2>/dev/null | tr '|' ' ' | sed 's/^[[:space:]]*//' | cut -c1-88)
        if [ "$flag" = "-" ] && printf '%s' "$ctx" | grep -qE 'DEC-[A-Z]|CR-[0-9]'; then
            flag="r"
        fi
        enriched="$enriched$flag|$id|$file|$line|$ctx
"
    done <<< "$annotated"

    local total open_n resolved_n
    total=$(printf '%s' "$enriched" | grep -c . || true)
    open_n=$(printf '%s' "$enriched" | grep -c '^-|' || true)
    resolved_n=$(printf '%s' "$enriched" | grep -c '^r|' || true)

    echo
    if [ "$open_n" -gt 0 ]; then
        bold "$label — $total فريدًا · **$open_n يحتاج قرارًا** · $resolved_n محسوم في سطره · $((total - open_n - resolved_n)) في سجل القرارات"
    else
        bold "$label — $total فريدًا · لا شيء يحتاج قرارًا"
    fi

    while IFS='|' read -r flag id file line ctx; do
        [ -z "$id" ] && continue
        case "$flag" in
            s) [ "$SHOW_ALL" -eq 0 ] && continue; mark="  · " ;;
            r) [ "$SHOW_ALL" -eq 0 ] && continue; mark="  ~ " ;;
            *) mark="  ! " ;;
        esac
        printf '%s%-16s %-26s %s\n' "$mark" "$id" "${file##*/}:$line" "$ctx"
    done <<< "$enriched"
}

sweep "قرارات مفتوحة (OD)"        'OD-[A-Z]+-[0-9]{3}|OD-[0-9]{3}'
sweep "تعارضات (CFL)"             'CFL-[A-Z]+-[0-9]{2,3}|CFL-[0-9]{2}'
sweep "قرارات هندسية معلّقة (ED)" 'ED-[A-Z]+-P[0-9]{2}'
sweep "فجوات (GD)"                'GD-[0-9]{2}'

# -- Human gates the package itself points at -------------------------------
# A count, not a list: these are not decisions to answer, they are the gates
# this module will stop at during execution. Knowing which ones are coming is
# what lets them be raised in the same batch instead of one slice at a time.
echo
bold "بوابات القرار البشري التي تشير إليها الحزمة"
GATES=$(grep -rhoE 'HG-[IE]-[0-9]{2}' "$DOCS" --include='*.md' 2>/dev/null | sort | uniq -c | sort -rn)
if [ -n "$GATES" ]; then
    printf '%s\n' "$GATES" | sed 's/^ */  /'
else
    dim "  لا إشارة إلى بوابة"
fi

# -- Free-text markers, capped ----------------------------------------------
echo
bold "علامات نصّية (غير معرَّفة بمعرّف)"
for marker in 'قرار مالك المنتج' 'يُحسم' 'TBD'; do
    n=$(grep -rhoF "$marker" "$DOCS" --include='*.md' 2>/dev/null | wc -l)
    [ "$n" -gt 0 ] && printf '  %-22s %s موضعًا\n' "$marker" "$n"
done
dim "  (عدد لا قائمة — تُقرأ في سياقها، ولا تُحوَّل إلى سؤال بلا قراءة)"

echo
dim "«مذكور في سجل القرارات» مؤشّر لا حكم: قد يكون القرار لموديول آخر أو متجاوَزًا."
dim "اقرأ المدخل قبل الاعتماد عليه — سجل القرارات هو الحاكم."
dim "وصياغة الأسئلة على مالك المنتج: ثمانية كحدٍّ أقصى في الجولة، ومع كلٍّ توصية."
echo
