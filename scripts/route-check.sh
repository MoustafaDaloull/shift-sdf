#!/usr/bin/env bash
# =============================================================================
# GATE-FE-05 + GATE-FE-06 — React routes backed by the approved route registries
# -----------------------------------------------------------------------------
# Binds every route written in `<FRONTEND_SRC>/**/<ROUTE_FILE_NAMES>` to a row
# in one of two approved registries (paths and sections in shift.env):
#
#   · Admin portal — ADMIN_ROUTE_MAP ADMIN_ROUTE_SECTION
#     (rows `<ROUTE_ROW_PREFIX>*` · namespace `<ADMIN_ROUTE_NAMESPACE>/*`)
#   · Client app   — CLIENT_ROUTE_MAP CLIENT_ROUTE_SECTION
#     (rows `<CLIENT_ROUTE_ROW_PREFIX>*` · every namespace except the admin one)
#
# Why a gate, not a convention: routes are COPIED verbatim from the registry,
# never derived. A convention breaks the first time someone writes a "clearer"
# path — and the break surfaces not in review but the day a deep link from an
# SMS fails.
#
# ── Three checks (identical for both registries) ─────────────────────────────
#   1. every route in code has a registry row      (no invented paths)
#   2. the path is absolute and copied verbatim    (no derivation, no nesting)
#   3. the route file lives in its owner's folder  (RS-030 + owner column)
#
# ── Registry self-checks (fail-fast, before any code is read) ────────────────
#   · a client row claiming the admin namespace is registry corruption
#   · a client row minted outside the client row prefix is corruption too
#   · the same path in both registries is a collision
#
# Rows whose status is not in ROUTE_ALLOWED_STATUSES and composite-ownership
# rows are out of scope by decision text; writing one of their paths in code
# is a violation, never a silent exception.
#
# Usage: bash scripts/route-check.sh
# Exit:  0 = clean or declared N/A · 1 = violation
# =============================================================================

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

# shellcheck source=config/shift.env
. "scripts/config/shift.env" || exit 2

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'

ADMIN_REGISTRY="${ADMIN_ROUTE_MAP:-}"
CLIENT_REGISTRY="${CLIENT_ROUTE_MAP:-}"
FRONTEND="$FRONTEND_SRC"
MODULES_SUB="$FRONTEND_MODULES_SUBDIR"
OWNER_COL="${ROUTE_OWNER_COLUMN:-5}"

_in_list() {
    local x
    for x in $2; do [ "$x" = "$1" ] && return 0; done
    return 1
}

failures=0

echo
echo "مسارات الواجهة — GATE-FE-05 (الإدارة) · GATE-FE-06 (العملاء)"
echo "────────────────────────────────────────────────────────────"

# سجلٌ مُكوَّن وغائب خطأٌ لا N/A؛ وسجلٌ غير مُكوَّن أصلًا يُعلَن N/A بوضوح.
if [ -z "$ADMIN_REGISTRY" ] && [ -z "$CLIENT_REGISTRY" ]; then
    if [ -d "$FRONTEND" ]; then
        printf '  %s✗%s لا سجل مسارات مُكوَّن (ADMIN_ROUTE_MAP · CLIENT_ROUTE_MAP) ويوجد %s — مسارات بلا سجل\n' "$RED" "$OFF" "$FRONTEND"
        exit 1
    fi
    printf '  %s—%s  %sN/A مُعلَنة%s — لا سجل مسارات مُكوَّن ولا واجهة في %s بعد\n' "$YELLOW" "$OFF" "$YELLOW" "$OFF" "$FRONTEND"
    echo "────────────────────────────────────────────────────────────"
    exit 0
fi
if [ -n "$ADMIN_REGISTRY" ] && [ ! -f "$ADMIN_REGISTRY" ]; then
    printf '  %s✗%s سجل مسارات الإدارة غير موجود: %s\n' "$RED" "$OFF" "$ADMIN_REGISTRY"; exit 1
fi
if [ -n "$CLIENT_REGISTRY" ] && [ ! -f "$CLIENT_REGISTRY" ]; then
    printf '  %s✗%s سجل مسارات العملاء غير موجود: %s\n' "$RED" "$OFF" "$CLIENT_REGISTRY"; exit 1
fi
[ -z "$ADMIN_REGISTRY" ]  && printf '  %s—%s  لا سجل إدارة مُكوَّن — GATE-FE-05 N/A مُعلَنة\n' "$YELLOW" "$OFF"
[ -z "$CLIENT_REGISTRY" ] && printf '  %s—%s  لا سجل عملاء مُكوَّن — GATE-FE-06 N/A مُعلَنة\n' "$YELLOW" "$OFF"

# ── 1. خريطة MOD-XX ⟵ مجلد الموديول ────────────────────────────────────────
# تُقرأ من ترويسة حزم MODULES_DOCS_DIR لا من جدول مكتوب هنا: خريطة يدوية في
# موضع ثانٍ هي ما يتباعد لاحقًا. و`RS-030` ينصّ أن مجلد الواجهة = مجلد التوثيق.
#
# مسحة واحدة لا حلقة تُشغّل `sed` و`grep` لكل حزمة: على Git Bash يكلّف إنشاء
# العملية أضعاف عمل الأداة نفسها، وحلقةٌ من بضعة عشر ملفًا جعلت البوابة
# تستغرق عشرات الثواني. وبوابة بطيئة تُتخطّى.
declare -A MOD_DIR=()
while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    f="${hit%%:*}"
    dir="${f#"$MODULES_DOCS_DIR"/}"; dir="${dir%%/*}"
    num="${hit##*MOD-}"
    [ -n "$dir" ] && MOD_DIR["MOD-$num"]="$dir"
done < <(grep -HoE '^module_id:[[:space:]]*"?MOD-[0-9]+' "$MODULES_DOCS_DIR"/*/data-model.md 2>/dev/null)

# ── 2. Registry loading ─────────────────────────────────────────────────────
# Both registries share one row grammar (| `RT-…` | `/path` | … | MOD-XX | … |
# STATUS |), so one parser reads them into merged maps and the code scan below
# needs no notion of which registry backed a path. Namespaces stay disjoint by
# construction — every admin path lives under the admin namespace, and the
# self-checks refuse a client row that could shadow it.
# Explicit `=()` matters: on this bash, expanding `${#arr[@]}` on a declared
# but never-assigned associative array trips `set -u` and silently aborted the
# loader while the gate still exited 0 — caught during the deliberate-break
# proof of GATE-FE-06.
declare -A ROUTE_MOD=()  # path ⟶ owning MOD-XX (or `system`)
declare -A ROUTE_RT=()   # path ⟶ registry row id
declare -A DEFERRED=()   # path ⟶ exclusion reason
declare -A ROUTE_SRC=()  # path ⟶ registry label (for collision reporting)

# load_registry <file> <label> <namespace: admin|client>
# Field splitting via array, trimming via parameter expansion — no subprocess
# per row (a per-row subprocess made the gate take tens of seconds on Git Bash).
load_registry() {
    local file="$1" label="$2" ns="$3"
    local rows=0 open_before=${#ROUTE_MOD[@]} def_before=${#DEFERRED[@]}
    local line rt path mod status n
    local -a F

    while IFS= read -r line; do
        IFS='|' read -ra F <<< "$line"
        n=${#F[@]}

        rt="${F[1]//[\` ]/}"
        path="${F[2]//[\` ]/}"
        mod="${F[$OWNER_COL]//[\` ]/}"
        # `n-1`, not `n-2`: `read -ra` drops the empty field after the trailing
        # separator (awk keeps it). One field of drift is enough to read the
        # "direct link" column as the status and wreck exclusion handling.
        status="${F[$((n - 1))]//[\` ]/}"

        [ -n "$path" ] || continue
        rows=$((rows + 1))

        if [ "$ns" = "client" ]; then
            # A client row inside the admin namespace or outside the client
            # row prefix is registry corruption — refuse the run.
            case "$path" in
                "$ADMIN_ROUTE_NAMESPACE"|"$ADMIN_ROUTE_NAMESPACE"/*)
                    printf '  %s✗%s صف عملاء «%s» يدّعي مسارًا إداريًا «%s» — فساد سجل\n' \
                        "$RED" "$OFF" "$rt" "$path"; exit 1 ;;
            esac
            case "$rt" in
                "$CLIENT_ROUTE_ROW_PREFIX"*) ;;
                *)  printf '  %s✗%s صف عملاء «%s» خارج فضاء %s* — فساد سجل\n' \
                        "$RED" "$OFF" "$rt" "$CLIENT_ROUTE_ROW_PREFIX"; exit 1 ;;
            esac
        fi

        if [ -n "${ROUTE_SRC[$path]+x}" ]; then
            printf '  %s✗%s المسار «%s» معرَّف في سجلَي %s و%s معًا — تصادم\n' \
                "$RED" "$OFF" "$path" "${ROUTE_SRC[$path]}" "$label"
            exit 1
        fi
        ROUTE_SRC["$path"]="$label"

        if ! _in_list "$status" "$ROUTE_ALLOWED_STATUSES"; then
            DEFERRED["$path"]="موسوم $status — DoD-SL-07 · HG-I-06"
            continue
        fi

        case "$mod" in
            *'/'*)  DEFERRED["$path"]="ملكية مشتركة ($mod) — لا مالك واحد يُشتق منه مجلد" ; continue ;;
            # `A→B`: A owns the spec, B is a consumption reference.
            *'→'*)  mod="${mod%%→*}" ;;
        esac

        _in_list "$mod" "$ROUTE_SYSTEM_OWNER_LABELS" && mod="system"

        ROUTE_MOD["$path"]="$mod"
        ROUTE_RT["$path"]="$rt"
    done < <(grep -E "^\| \`${ROUTE_ROW_PREFIX}" "$file")

    if [ "$rows" -eq 0 ]; then
        printf '  %s✗%s لم يُقرأ صفٌّ واحد من سجل %s — تغيّرت بنية الجدول؟\n' "$RED" "$OFF" "$label"
        exit 1
    fi

    printf '  %sسجل %s:%s %d صفًّا · %d مسارًا مفتوحًا · %d مستثنى\n' \
        "$DIM" "$label" "$OFF" "$rows" \
        "$(( ${#ROUTE_MOD[@]} - open_before ))" "$(( ${#DEFERRED[@]} - def_before ))"
}

[ -n "$ADMIN_REGISTRY" ]  && load_registry "$ADMIN_REGISTRY"  "الإدارة ($ADMIN_ROUTE_SECTION)" admin
[ -n "$CLIENT_REGISTRY" ] && load_registry "$CLIENT_REGISTRY" "العملاء ($CLIENT_ROUTE_SECTION)" client

# ── 3. جمع ما يدّعيه الكود ──────────────────────────────────────────────────
FIND_NAMES=()
for _n in $ROUTE_FILE_NAMES; do
    [ "${#FIND_NAMES[@]}" -gt 0 ] && FIND_NAMES+=(-o)
    FIND_NAMES+=(-name "$_n")
done
if [ "${#FIND_NAMES[@]}" -eq 0 ]; then
    printf '  %s✗%s ROUTE_FILE_NAMES فارغ في shift.env — لا اسم ملف تجمعه البوابة\n' "$RED" "$OFF"
    exit 1
fi
ROUTE_FILES=""
[ -d "$FRONTEND" ] && ROUTE_FILES=$(find "$FRONTEND" \( "${FIND_NAMES[@]}" \) 2>/dev/null || true)

# -- 3a. Check 0 -- a route file under a name the gate never collects --------
#
# البوابة تجمع ملفات المسارات بالاسم (ROUTE_FILE_NAMES). فملفٌ يعرّف مسارات
# باسم آخر — `ownerRoutes.tsx` مثلًا — لا يُجمع أصلًا، فلا يُفحص منه مسارٌ واحد
# ولا تُعلن البوابة نقصًا: تمرّ خضراء على مسارات لم تنظر إليها. وذلك أسوأ من
# الاحمرار، لأنه صمتٌ يُقرأ تغطيةً. وقع مرتين في موديول واحد.
#
# والعلامة دقيقة لا فضفاضة: الملف يحمل `RouteObject[]` **و** قيمة `path:`
# تبدأ بشرطة مائلة. فسجل التنقّل يحمل الثانية بلا الأولى فيمرّ، وملف الموجِّه
# وسجل المسارات المسجَّلة يحملان الأولى بلا الثانية فيمرّان.
orphans=0
if [ -d "$FRONTEND" ]; then
    while IFS= read -r cand; do
        [ -n "$cand" ] || continue
        _in_list "${cand##*/}" "$ROUTE_FILE_NAMES" && continue
        grep -q 'RouteObject\[\]' "$cand" 2>/dev/null || continue
        grep -qE "path: *['\"]/" "$cand" 2>/dev/null || continue
        printf '  %s\xe2\x9c\x97%s %s يعرّف مسارات باسم لا تجمعه البوابة — ملفُّ المسارات يُسمّى %s%s%s حصرًا\n' \
            "$RED" "$OFF" "$cand" "$DIM" "$(printf '%s' "$ROUTE_FILE_NAMES" | sed 's/ / أو /g')" "$OFF"
        orphans=$((orphans + 1))
    done < <(find "$FRONTEND" \( -name '*.tsx' -o -name '*.ts' \) 2>/dev/null || true)
fi

if [ "$orphans" -gt 0 ]; then
    printf '  %s\xe2\x9c\x97%s %d ملف مسارات خارج مدى الجمع — مساراتها غير مفحوصة\n' \
        "$RED" "$OFF" "$orphans"
    echo "────────────────────────────────────────────────────────────"
    exit 1
fi

if [ -z "$ROUTE_FILES" ]; then
    printf '  %s—%s  %sN/A مُعلَنة%s — لا ملف %s في %s بعد\n' \
        "$YELLOW" "$OFF" "$YELLOW" "$OFF" "$ROUTE_FILE_NAME" "$FRONTEND"
    printf '     %sالبوابة عاملة وتنتظر أول ملف؛ ولا تُحتسب نجاحًا حتى يوجد ما تفحصه.%s\n' \
        "$DIM" "$OFF"
    echo "────────────────────────────────────────────────────────────"
    exit 0
fi

checked=0

while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    file="${hit%%:*}"
    rest="${hit#*:}"
    lineno="${rest%%:*}"
    path="$(printf '%s' "${hit##*:@@:}")"
    loc="$file:$lineno"
    checked=$((checked + 1))

    # فحص ٢ — المسار مطلق. النسبي يجعل المقارنة بالسجل مستحيلة ويخالف
    # «يُنسخ حرفيًا»: تجزئةُ مسارٍ على أبٍ وابن تعيد الاشتقاق من الباب الخلفي.
    case "$path" in
        /*) ;;
        *)  printf '  %s✗%s «%s» مسار نسبي — يُكتب مطلقًا كما في السجل %s(%s)%s\n' \
                "$RED" "$OFF" "$path" "$DIM" "$loc" "$OFF"
            failures=$((failures + 1)); continue ;;
    esac

    # Check 1 — the path has a registry row
    if [ -n "${DEFERRED[$path]+x}" ]; then
        printf '  %s✗%s «%s» مستثنى بنصّ القرار: %s %s(%s)%s\n' \
            "$RED" "$OFF" "$path" "${DEFERRED[$path]}" "$DIM" "$loc" "$OFF"
        failures=$((failures + 1)); continue
    fi

    if [ -z "${ROUTE_MOD[$path]+x}" ]; then
        printf '  %s✗%s «%s» لا صفَّ له في سجل الإدارة (%s) ولا سجل العملاء (%s) %s(%s)%s\n' \
            "$RED" "$OFF" "$path" "$ADMIN_ROUTE_SECTION" "$CLIENT_ROUTE_SECTION" "$DIM" "$loc" "$OFF"
        failures=$((failures + 1)); continue
    fi

    # فحص ٣ — الملف داخل مجلد الموديول المالك
    owner="${ROUTE_MOD[$path]}"
    [ "$owner" = "system" ] && continue      # مسارات النظام تعيش في src/app/

    expected="${MOD_DIR[$owner]:-}"
    if [ -z "$expected" ]; then
        printf '  %s✗%s «%s» مالكه %s ولا حزمة له في %s/ %s(%s)%s\n' \
            "$RED" "$OFF" "$path" "$owner" "$MODULES_DOCS_DIR" "$DIM" "$loc" "$OFF"
        failures=$((failures + 1)); continue
    fi

    case "$file" in
        "$FRONTEND/$MODULES_SUB/$expected/"*) ;;
        *)  printf '  %s✗%s «%s» مالكه %s ⟵ %s/%s/%s/ %s(%s)%s\n' \
                "$RED" "$OFF" "$path" "$owner" "$FRONTEND" "$MODULES_SUB" "$expected" "$DIM" "$loc" "$OFF"
            failures=$((failures + 1)) ;;
    esac
done < <(
    # قيم `path:` و`path=` وحدها — لا كل سلسلة تبدأ بشرطة مائلة، وإلا رُصدت
    # عناوينُ استدعاءات API نصًّا وأُبلغ عنها خرقَ توجيه.
    #
    # `-H` ليس زخرفة: `grep -n` يحذف اسم الملف حين يُمرَّر ملف واحد، فيصير
    # الحقل الأول رقمَ السطر ويُقرأ مسارًا للملف. رُصد عند أول تشغيل — وكان
    # يُفشل المسارات الصحيحة، وهو أسوأ من عدم الرصد: بوابة تُنذر كذبًا تُعطَّل.
    grep -HnoE "path[:=][[:space:]]*[\"'][^\"']*[\"']" $ROUTE_FILES 2>/dev/null \
    | sed -E "s/path[:=][[:space:]]*[\"']([^\"']*)[\"']$/@@:\1/"
)

echo "────────────────────────────────────────────────────────────"

if [ "$failures" -gt 0 ]; then
    printf '  %s✗ %d مسارًا بلا سند%s\n' "$RED" "$failures" "$OFF"
    printf '     %sالمسار يُنسخ من سجله حرفيًا — سجل الإدارة (%s) · سجل العملاء (%s).%s\n' "$DIM" "$ADMIN_ROUTE_SECTION" "$CLIENT_ROUTE_SECTION" "$OFF"
    exit 1
fi

printf '  %s✓%s %d مسارًا — كلها مسنودة في السجل وفي مجلدات مالكيها\n' "$GREEN" "$OFF" "$checked"
exit 0
