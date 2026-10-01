#!/usr/bin/env bash
# =============================================================================
# فحوص البنية والحدود — تكملة Deptrac (AS-031)
# -----------------------------------------------------------------------------
# Deptrac يفحص رسم الاعتماديات بين الأصناف (RS-020 · RS-023 · RS-025). أما
# القواعد التالية فهي **قواعد ملفات ومحتوى** لا يراها محلّل أصناف:
#
#   RS-014  migration خارج مجلد الموديول
#   RS-016  مسار مُعرَّف في routes/api.php بدل مسارات الموديول
#   RS-012  مجلد موديول غير مسجَّل في modules.tsv
#   RS-013  بادئة جدول لا تطابق كود موديوله
#   RS-021  JOIN عابر لبادئتَي جدولين مختلفتين
#   RS-022  FOREIGN KEY عابر للموديولات
#   RS-020  استيراد مباشر من موديول آخر (الطريق الوحيد Shared/Contracts)
#   RS-017  مسار API بلا إصدار في الكود
#   API-005 مسار API بلا إصدار في الوثائق الهندسية
#   CS-010  ملف PHP بلا declare(strict_types=1)
#   CS-027  استدعاء env() خارج config/
#   CS-021  float في سياق مالي
#   DOC-VER انحراف إصدار الوثائق (أربعة أشقّة)
#   TRK-01  سلامة جداول المتتبع · TRK-02 مؤشّر المتتبع يتبع إعلانه
#   DoD-SL-08 لا علامة نائبة باقية في HEAD
#
# لماذا سكربت لا أداة جاهزة: هذه قواعد مشتقة من اصطلاح بادئة الجدول وبنية
# المجلدات المعتمدة في الإطار. لا أداة عامة تعرفها.
#
# خريطة الموديولات تُقرأ من `scripts/config/modules.tsv` — مجلد غير مسجَّل فيها
# يُرصد خرقًا لا صمتًا.
#
# الاستخدام:  bash scripts/arch-check.sh
# الخروج:     0 = نظيف · 1 = خرق
# =============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# shellcheck source=config/shift.env
. "$ROOT/scripts/config/shift.env" || exit 2

BACKEND="$BACKEND_DIR"
MODULES_PATH="$BACKEND/app/Modules"
FAILED=0
CHECKS=0

red()    { printf '\033[31m%s\033[0m\n' "$1"; }
green()  { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }
dim()    { printf '\033[2m%s\033[0m\n' "$1"; }

fail() {
    red "  ✗ $1"
    shift
    while [ $# -gt 0 ]; do printf '      %s\n' "$1"; shift; done
    FAILED=$((FAILED + 1))
}

pass() { green "  ✓ $1"; }
na()   { yellow "  —  $1 — N/A مُعلَنة"; }

check() { CHECKS=$((CHECKS + 1)); }

# ── خريطة الموديولات — من modules.tsv لا من هذا الملف (RS-012) ──────────────
# مجلد الموديول اسمه **كامل** لا مختصر (RS-012)، بينما بادئة الجدول (DMOD-002)
# وقطاع المسار (API-005) يستخدمان **كود** الموديول. اشتقاق البادئة بتحويل اسم
# المجلد إلى حروف صغيرة يصحّ فقط ما دام المجلد هو الكود نفسه — ولذلك الخريطة
# صريحة، وفي ملف إعداد واحد تقرؤه كل الأدوات.
#
# مجلد غير مسجَّل في الخريطة = خرق RS-012 لا صمت: لو رجعنا إلى الاشتقاق
# التلقائي عند عدم التطابق، لمرّ كل مجلد مُسمّى خطأً بلا رصد.
declare -A PREFIX_OF_DIR=()   # code_folder ⟶ table_prefix
declare -A DOCS_OF_DIR=()     # code_folder ⟶ docs_folder
declare -A CODE_OF_DIR=()     # code_folder ⟶ module_code
MODULE_ROWS=0
if [ ! -f "$MODULES_TSV" ]; then
    red "  ✗ خريطة الموديولات غير موجودة: $MODULES_TSV"
    exit 1
fi
while IFS=$'\t' read -r m_code m_docs m_dir m_prefix _rest; do
    case "$m_code" in ''|'#'*) continue ;; esac
    if [ -z "$m_docs" ] || [ -z "$m_dir" ] || [ -z "$m_prefix" ]; then
        red "  ✗ صفّ ناقص في $MODULES_TSV: «$m_code» — الأعمدة الأربعة إلزامية ومفصولة بـTAB"
        exit 1
    fi
    PREFIX_OF_DIR["$m_dir"]="$m_prefix"
    DOCS_OF_DIR["$m_dir"]="$m_docs"
    CODE_OF_DIR["$m_dir"]="$m_code"
    MODULE_ROWS=$((MODULE_ROWS + 1))
done < <(tr -d '\r' < "$MODULES_TSV")

module_code() { printf '%s' "${PREFIX_OF_DIR[$1]:-}"; }

# خط أساس من ملف: أسطر غير فارغة بلا تعليقات.
read_baseline() {
    [ -f "$1" ] || return 0
    tr -d '\r' < "$1" | sed -e 's/#.*$//' -e 's/[[:space:]]*$//' | grep -v '^$' || true
}

echo
echo "فحوص البنية والحدود — AS-031"
echo "────────────────────────────────────────────────────────────"

# ── RS-014 — migrations داخل الموديول ────────────────────────────────────────
# الاستثناء الوحيد: هجرات إطار العمل نفسه (jobs · cache · sessions) التي
# تُنشَأ ببادئة FRAMEWORK_MIGRATION_PREFIX ولا يملكها موديول.
check
STRAY=$(find "$BACKEND/database/migrations" -name "*.php" 2>/dev/null \
        | grep -v "$FRAMEWORK_MIGRATION_PREFIX" || true)
if [ -n "$STRAY" ]; then
    fail "RS-014 — migration خارج مجلد الموديول" $STRAY \
         "الهجرات تعيش في app/Modules/{Module}/Infrastructure/Migrations/"
else
    pass "RS-014 — كل الهجرات داخل موديولاتها"
fi

# ── RS-016 — لا تعريف مسار مركزي ─────────────────────────────────────────────
check
if [ -f "$BACKEND/routes/api.php" ]; then
    # `grep -c` exits 1 on zero matches, and `|| echo 0` used to append a
    # second zero. The value became a two-line "0" and "0", the `-gt` test
    # died with "integer expected", and the else branch swallowed it - so an
    # error was printed on every green run. A gate announcing success with an
    # error in its own log is what AS-002 forbids.
    ROUTES=$(grep -cE "^\s*Route::(get|post|put|patch|delete|resource|apiResource)" \
             "$BACKEND/routes/api.php" 2>/dev/null) || ROUTES=0
    if [ "$ROUTES" -gt 0 ]; then
        fail "RS-016 — $ROUTES مسارًا مُعرَّفًا في routes/api.php" \
             "المسارات تُعرَّف في app/Modules/{Module}/Http/routes.php"
    else
        pass "RS-016 — api.php ملف تجميع لا تعريف"
    fi
else
    pass "RS-016 — لا api.php مركزي"
fi

# ── RS-012 — اسم مجلد الموديول كامل ومسجَّل ─────────────────────────────────
# اسم المجلد = اسم مجلد التوثيق بصيغة PascalCase. مجلد خارج الخريطة إما مختصر
# وإما موديول غير مسجَّل — وكلاهما يُبطل اشتقاق البادئة في RS-021/022.
check
UNKNOWN_DIRS=""
for d in $(find "$MODULES_PATH" -mindepth 1 -maxdepth 1 -type d 2>/dev/null); do
    NAME=$(basename "$d")
    if [ -z "$(module_code "$NAME")" ]; then
        UNKNOWN_DIRS="$UNKNOWN_DIRS\n      $NAME"
    fi
done
if [ -n "$UNKNOWN_DIRS" ]; then
    fail "RS-012 — مجلد موديول غير مسجَّل في $MODULES_TSV أو مختصر"
    printf "$UNKNOWN_DIRS\n"
    printf '      الاسم = مجلد التوثيق بصيغة PascalCase — سجّله في %s\n' "$MODULES_TSV"
else
    pass "RS-012 — أسماء مجلدات الموديولات كاملة ومسجَّلة ($MODULE_ROWS في الخريطة)"
fi

# ── RS-013 / RS-021 / RS-022 — ملكية الجداول ────────────────────────────────
# الملكية تُشتَق ممّا يُنشئه الموديول فعلًا (`Schema::create`) لا من اسم مجلده.
# هذا يفحص ما تدّعيه القاعدة حقًا: FK أو JOIN إلى جدول لا يُنشئه هذا الموديول
# هو عبورٌ للحدود. الكود يأتي من الخريطة لا من اسم المجلد.
check
FK_BAD=""; JOIN_BAD=""; PREFIX_BAD=""
for d in $(find "$MODULES_PATH" -mindepth 1 -maxdepth 1 -type d 2>/dev/null); do
    MOD=$(basename "$d"); LOWER=$(module_code "$MOD")
    [ -z "$LOWER" ] && continue   # مجلد غير مسجَّل — ترصده RS-012 أعلاه
    OWNED=" $(grep -rhoE "Schema::create\('[a-z0-9_]+'" "$d" 2>/dev/null \
              | sed -E "s/Schema::create\('//;s/'$//" | tr '\n' ' ')"
    [ "$OWNED" = " " ] && continue

    # RS-013 — بادئة كل جدول يُنشئه الموديول تطابق كوده.
    # الاستثناء الموثَّق الوحيد: جداول مرجعية بلا بادئة لموديول مُدرَج في
    # UNPREFIXED_TABLE_MODULES. والمعيار أنها لا تحمل بادئة **موديول آخر**، لا
    # أنها بلا شرطة سفلية — `system_settings` مرجعيّ رغم احتوائه عليها.
    for t in $OWNED; do
        case "$t" in "${LOWER}_"*) continue ;; esac
        case " ${UNPREFIXED_TABLE_MODULES:-} " in
            *" $LOWER "*)
                HEAD_SEG="${t%%_*}"
                OTHER=""
                for m in $(find "$MODULES_PATH" -mindepth 1 -maxdepth 1 -type d 2>/dev/null); do
                    C=$(module_code "$(basename "$m")")
                    [ -n "$C" ] && [ "$C" = "$HEAD_SEG" ] && OTHER="$C"
                done
                [ -z "$OTHER" ] && continue ;;
        esac
        PREFIX_BAD="$PREFIX_BAD\n      $MOD/ ينشئ $t"
    done

    # RS-022 — FK إلى جدول لا يملكه الموديول
    # One grep per module instead of one per migration file. `-H` is required:
    # grep omits the filename when handed a single file, which would break the
    # split for a module holding one migration. `xargs -r` keeps grep off stdin
    # when a module has none.
    while IFS= read -r hit; do
        [ -z "$hit" ] && continue
        FK_FILE="${hit%%:*}"
        FK_T=$(printf '%s' "${hit#*:}" | sed -E "s/constrained\('//;s/'$//")
        case "$OWNED" in *" $FK_T "*) ;; *) FK_BAD="$FK_BAD\n      $FK_FILE → $FK_T" ;; esac
    done < <(find "$d" -path "*/Migrations/*.php" -print0 2>/dev/null \
             | xargs -0 -r grep -HoE "constrained\('[a-z0-9_]+'" 2>/dev/null)

    # RS-021 — JOIN إلى جدول لا يملكه الموديول
    for t_line in $(grep -rnoE "\->join\('[a-z0-9_]+'" "$d" --include=*.php 2>/dev/null); do
        T=$(echo "$t_line" | sed -E "s/.*->join\('//;s/'$//")
        case "$OWNED" in *" $T "*) ;; *) JOIN_BAD="$JOIN_BAD\n      $t_line" ;; esac
    done
done
if [ -n "$PREFIX_BAD$FK_BAD$JOIN_BAD" ]; then
    [ -n "$PREFIX_BAD" ] && { fail "RS-013 — بادئة جدول لا تطابق كود موديوله"; printf "$PREFIX_BAD\n"; }
    [ -n "$FK_BAD" ] && { fail "RS-022 — FOREIGN KEY إلى جدول خارج الموديول"; printf "$FK_BAD\n"
                          printf '      استخدم FK منطقيًا في طبقة التطبيق (DMOD-024)\n'; }
    [ -n "$JOIN_BAD" ] && { fail "RS-021 — JOIN عابر لحدود الموديول"; printf "$JOIN_BAD\n"
                            printf '      استخدم عقد قراءة من Shared/Contracts\n'; }
else
    pass "RS-013 · RS-021 · RS-022 — ملكية الجداول سليمة"
fi

# ── RS-020 / RS-023 — لا استيراد مباشر من موديول آخر ────────────────────────
# الطريق الوحيد بين الموديولات هو SHARED_CONTRACTS_NS. Deptrac هو الفارض الأول
# لهذه القاعدة برسم الأصناف؛ وهذا الفحص نسخةُ **الملفات** منها كي تبقى البوابة
# قائمة قبل تكوين Deptrac وبعده: سطرُ `use <MODULES_NAMESPACE>\<آخر>\…` داخل
# مجلد موديول غير مجلد <آخر> خرقٌ ولو مرّ محلّل الأصناف.
check
NS_RE="$(printf '%s' "$MODULES_NAMESPACE" | sed 's/\\/\\\\/g')"
XMOD=""
for d in $(find "$MODULES_PATH" -mindepth 1 -maxdepth 1 -type d 2>/dev/null); do
    MOD=$(basename "$d")
    hits=$(grep -rnE "^use ${NS_RE}\\\\[A-Za-z0-9_]+\\\\" "$d" --include=*.php 2>/dev/null \
           | grep -vE "^[^:]*:[0-9]+:use ${NS_RE}\\\\${MOD}\\\\" || true)
    [ -n "$hits" ] && XMOD="$XMOD
$(printf '%s\n' "$hits" | sed 's/^/      /')"
done
if [ -n "$XMOD" ]; then
    fail "RS-020 — استيراد مباشر من موديول آخر"
    printf '%s\n' "$XMOD" | grep -v '^$'
    printf '      الاستهلاك العابر عبر %s حصرًا (RS-020 · RS-023)\n' "$SHARED_CONTRACTS_NS"
else
    pass "RS-020 — لا استيراد مباشر عابر للموديولات"
fi

# ── RS-017 — إصدار المسار ───────────────────────────────────────────────────
check
UNVERSIONED=$(grep -rnE "['\"]/?api/(?!v[0-9])" "$MODULES_PATH" --include=*.php -P 2>/dev/null \
              | grep -v "api/v[0-9]" || true)
if [ -n "$UNVERSIONED" ]; then
    fail "RS-017 — مسار API بلا إصدار" "$UNVERSIONED"
else
    pass "RS-017 — كل المسارات مُصدَّرة"
fi

# ── API-005 — صيغة المسار في الوثائق الهندسية ───────────────────────────────
# هذه هي الثغرة التي يمرّ منها الانحراف: بوابة تفحص الكود وحده بينما وثائق
# العقود — التي يُبنى منها الكود — بلا حراسة. حزم كتبت مساراتها `/api/admin/...`
# بلا إصدار وبلا كود موديول، مخالفةً معيارًا MANDATORY، ولم يرصدها شيء حتى
# فحص يدوي.
#
# القاعدة المالكة: API-005 في api-design-standard.md
#   /api/v{N}/{module-code}/{resource-plural}
#
# لماذا تُستثنى وثائق Phase 0: هي مُجمَّدة ولا تُعدَّل إلا بـCR معتمد من مالك
# المنتج. بوابةٌ تفشل على ملفات لا تملك حق إصلاحها بوابةٌ ستُعطَّل — والتعطيل
# أسوأ من الاستثناء المُعلن.
check
# ── لماذا اللحاق الخلفي `(?<![A-Za-z0-9_])` ───────────────────────
# القاعدة تخصّ **مسار API مطلقًا** يبدأ بـ`/api/`. وبدون هذا القيد يلتقط النمطُ
# **مسارَ ملفٍّ** فيه المقطع نفسه — `shared/api/client.ts` — فيُعلَن خرقًا وهو
# اسمُ ملفٍ في الواجهة لا نقطةَ خدمة. فالمُصحَّحُ المصنّفُ لا الدليل.
#
# والقيدُ لا يُرخّي شيئًا: `/api/admin/...` مسارًا مطلقًا مسبوقًا بفراغٍ أو بعلامة
# اقتباس مرصودٌ كما كان — مُثبتًا بخرقٍ متعمَّد.
# One grep over the whole list instead of one per file. `-l` is enough: the
# gate reports the offending file, not the position of the match.
DOC_BAD=$(find "$MODULES_DOCS_DIR" -name "*.md" -not -path "*/screens/*" \
    -not -name "requirements.md"     -not -name "business-rules.md" \
    -not -name "user-flows.md"       -not -name "screen-inventory.md" \
    -not -name "permission-matrix.md" -not -name "module-readiness-review.md" \
    -print0 2>/dev/null \
    | xargs -0 -r grep -lP "(?<![A-Za-z0-9_])/api/(?!v[0-9]+/)[a-zA-Z0-9]" 2>/dev/null \
    | sort | sed 's/^/      /')
if [ -n "$DOC_BAD" ]; then
    fail "API-005 — مسار بلا إصدار في وثيقة هندسية"
    printf '%s\n' "$DOC_BAD"
    printf '      الصيغة المعتمدة: /api/v{N}/{module-code}/{resource-plural}\n'
else
    pass "API-005 — كل مسارات الوثائق الهندسية مطابقة"
fi

# ── CS-010 — declare(strict_types=1) ────────────────────────────────────────
check
# One awk call instead of head+grep per file: the cost of the loop was process
# creation, not checking (tens of seconds against under one). The semantics
# are preserved exactly: `FNR > 5` keeps the check inside the first five lines
# as `head -5` did, and the file universe comes from ARGV rather than from
# content, so an empty PHP file is still reported.
NO_STRICT=$(find "$BACKEND/app" "$BACKEND/tests" -name "*.php" -print0 2>/dev/null \
    | xargs -0 -r awk '
        BEGIN { for (i = 1; i < ARGC; i++) all[ARGV[i]] = 1 }
        FNR > 5                     { nextfile }
        /declare\(strict_types=1\)/ { ok[FILENAME] = 1; nextfile }
        END { for (f in all) if (!(f in ok)) print "      " f }
      ' | sort)
if [ -n "$NO_STRICT" ]; then
    fail "CS-010 — ملف PHP بلا declare(strict_types=1)"
    printf "$NO_STRICT\n"
else
    pass "CS-010 — الأنواع الصارمة في كل ملف"
fi

# ── CS-027 — env() خارج config/ ─────────────────────────────────────────────
# env() تعيد null عند تخزين الإعداد مؤقتًا في الإنتاج — العطب يظهر بعد النشر لا قبله.
check
ENV_CALLS=$(grep -rn "env(" "$BACKEND/app" --include=*.php 2>/dev/null | grep -v "//" || true)
if [ -n "$ENV_CALLS" ]; then
    fail "CS-027 — استدعاء env() خارج config/" "$ENV_CALLS" \
         "استخدم config() — env() تعيد null بعد config:cache"
else
    pass "CS-027 — لا env() خارج الإعداد"
fi

# ── CS-021 — float في سياق مالي ─────────────────────────────────────────────
check
FLOATS=$(grep -rniE "\(float\)|floatval|: *float" "$MODULES_PATH" --include=*.php 2>/dev/null \
         | grep -viE "${FLOAT_ALLOWLIST_REGEX:-^\$}" || true)
if [ -n "$FLOATS" ]; then
    fail "CS-021 — float في سياق قد يكون ماليًا" "$FLOATS" \
         "المبالغ DECIMAL — float يفقد الدقة"
else
    pass "CS-021 — لا float في سياق مالي"
fi

# ── DOC-VER — doc version drift ──────────────────────────────────────────────
# Strand (a): a doc's frontmatter version must equal the highest row of its own
# version-history table. This exact drift ships repeatedly when the changelog
# is bumped but not the frontmatter - the fix each time is the copy, never the
# mechanism. The baseline file (DOC_VERSION_BASELINE_FILE) is measured debt:
# it may only SHRINK - fixing a file removes its line; adding a line requires
# a product-owner decision. Any drift outside the baseline fails the gate.
# Row pattern is exactly the measurement's: "| X.Y | 20YY-..." (plain, no
# bold) - widening it re-baselines the debt and needs a decision too.
check
DOC_VER_BASELINE="$(read_baseline "$DOC_VERSION_BASELINE_FILE")"
DOC_VER_BASE_N=$(printf '%s\n' "$DOC_VER_BASELINE" | grep -c . || true)

DOC_DRIFT=$(find "$DOCS_DIR" -name "*.md" -print0 2>/dev/null | xargs -0 -r awk '
    function flush() {
        if (fm != "" && mx != "" && fm != mx)
            print prev " : frontmatter=" fm " changelog-max=" mx
    }
    function vgt(a, b,   x, y) {
        split(a, x, "."); split(b, y, ".")
        return (x[1]+0 > y[1]+0) || (x[1]+0 == y[1]+0 && x[2]+0 > y[2]+0)
    }
    FNR == 1 { flush(); fm = ""; mx = ""; prev = FILENAME }
    FNR <= 20 && /^(document_version|version): *"?[0-9]+\.[0-9]+"?/ {
        if (fm == "" && match($0, /[0-9]+\.[0-9]+/))
            fm = substr($0, RSTART, RLENGTH)
    }
    /^\| v?[0-9]+\.[0-9]+ \| 20[0-9][0-9]-/ {
        if (match($0, /[0-9]+\.[0-9]+/)) {
            v = substr($0, RSTART, RLENGTH)
            if (mx == "" || vgt(v, mx)) mx = v
        }
    }
    END { flush() }
' | sort)
# Normalize find's ./ and backslashes so baseline filtering is path-stable.
DOC_DRIFT=$(printf '%s\n' "$DOC_DRIFT" | sed 's|^\./||; s|\\|/|g' | grep -v '^$' || true)
NEW_DRIFT=$(printf '%s\n' "$DOC_DRIFT" | grep -v '^$' | grep -v -F -f <(printf '%s\n' "$DOC_VER_BASELINE" | grep -v '^$' | sed 's/$/ :/') || true)
if [ -n "$NEW_DRIFT" ]; then
    fail "DOC-VER(a) — انحراف إصدار وثيقة خارج خط الأساس المُعلن" \
         "$NEW_DRIFT" \
         "الترويسة والحقيقة في سجل الإصدارات يجب أن يتطابقا — أصلح الترويسة أو أضف صف السجل الناقص"
else
    pass "DOC-VER(a) — لا انحراف إصدار جديد (خط الأساس: $DOC_VER_BASE_N ملفًا — يتقلّص ولا يتوسع)"
fi

# Strand (b): live references must cite documents BY NAME, never by version.
# Governance files may mention versions only inside their own version-history
# rows (lines starting "| **vX.Y** |"). The lived instance: the baseline cited
# an instruction file at v2.3 while the file was at v2.4.
check
if [ -z "${GOVERNANCE_BASELINE_FILE:-}" ] || [ ! -f "$GOVERNANCE_BASELINE_FILE" ]; then
    na "DOC-VER(b) — لا ملف حوكمة جذري مُكوَّن أو موجود (GOVERNANCE_BASELINE_FILE)"
else
    # Adjacency window of 3 chars: a live citation reads "CLAUDE.md v2.3"; prose
    # that mentions this file's own version far downstream must not match.
    LIVE_CITE=$(grep -nE "${INSTRUCTION_FILE_REGEX}.{0,3}v[0-9]+\.[0-9]+" "$GOVERNANCE_BASELINE_FILE" 2>/dev/null \
        | grep -vE '^[0-9]+:\| \*\*v[0-9]' || true)
    if [ -n "$LIVE_CITE" ]; then
        fail "DOC-VER(b) — إحالة حيّة برقم إصدار في $GOVERNANCE_BASELINE_FILE" "$LIVE_CITE" \
             "الإحالة بالاسم لا بالرقم — رقم الإصدار داخل إحالة يتقادم بصمت"
    else
        pass "DOC-VER(b) — لا إحالة حيّة برقم إصدار إلى ملفات التعليمات"
    fi
fi

# Strand (c): the same drift as (a), for repository-root governance files.
# Strand (a) walks the docs tree only, so no root file ever reaches it - and
# that shadow is exactly where root drift hides.
#
# Kept SEPARATE from (a) rather than folded into it, for two reasons. Root
# files declare their version differently - "**الإصدار:** X.Y" in the
# instruction files, YAML frontmatter in the baseline - and governance files
# may write their changelog rows in bold. Widening (a)'s patterns to cover both
# would re-measure every file under the docs tree against a looser rule and
# silently re-baseline the pinned debt, which needs a product-owner decision.
#
# And this strand carries NO baseline: root drift must be zero, so any drift
# at all fails. A file with a version but no changelog table (an archived
# instruction file) is skipped, not failed - it was never revised, so there is
# nothing to disagree with.
check
ROOT_DRIFT=$(find . -maxdepth 1 -name "*.md" -print0 2>/dev/null | xargs -0 -r awk '
    function flush() {
        if (fm != "" && mx != "" && fm != mx)
            print prev " : header=" fm " changelog-max=" mx
    }
    function vgt(a, b,   x, y) {
        split(a, x, "."); split(b, y, ".")
        return (x[1]+0 > y[1]+0) || (x[1]+0 == y[1]+0 && x[2]+0 > y[2]+0)
    }
    FNR == 1 { flush(); fm = ""; mx = ""; prev = FILENAME }
    FNR <= 20 && /^(document_version|version): *"?[0-9]+\.[0-9]+"?/ {
        if (fm == "" && match($0, /[0-9]+\.[0-9]+/))
            fm = substr($0, RSTART, RLENGTH)
    }
    FNR <= 20 && /^\*\*(الإصدار|الاصدار):\*\* *[0-9]+\.[0-9]+/ {
        if (fm == "" && match($0, /[0-9]+\.[0-9]+/))
            fm = substr($0, RSTART, RLENGTH)
    }
    /^\| \*{0,2}v?[0-9]+\.[0-9]+\*{0,2} \| \*{0,2}20[0-9][0-9]-/ {
        if (match($0, /[0-9]+\.[0-9]+/)) {
            v = substr($0, RSTART, RLENGTH)
            if (mx == "" || vgt(v, mx)) mx = v
        }
    }
    END { flush() }
' | sed 's|^\./||' | sort)
if [ -n "$ROOT_DRIFT" ]; then
    fail "DOC-VER(c) — انحراف إصدار في ملف حوكمة جذري" "$ROOT_DRIFT" \
         "ترويسة ملف الجذر وأعلى صفٍّ في سجل إصداراته يجب أن يتطابقا — لا خط أساس لهذا الشقّ"
else
    pass "DOC-VER(c) — لا انحراف إصدار في ملفات الجذر (بلا خط أساس)"
fi

# Strand (d): bumping document_version obliges bumping last_updated. Statically
# visible as: the changelog row that CARRIES the frontmatter version has a
# date, and frontmatter last_updated must equal it — a version bumped "in
# place" leaves last_updated behind. Debt pinned in
# DOC_LAST_UPDATED_BASELINE_FILE, shrink-only like (a).
check
CFL58_BASELINE="$(read_baseline "$DOC_LAST_UPDATED_BASELINE_FILE")"
CFL58_BASE_N=$(printf '%s\n' "$CFL58_BASELINE" | grep -c . || true)

CFL58_DRIFT=$(find "$DOCS_DIR" -name "*.md" -print0 2>/dev/null | xargs -0 -r awk '
    function flush() {
        if (fm != "" && lu != "" && fmdate != "" && lu != fmdate)
            print prev " : last_updated=" lu " top-row-date=" fmdate
    }
    FNR == 1 { flush(); fm = ""; lu = ""; fmdate = ""; prev = FILENAME }
    FNR <= 20 && /^document_version: *"?v?[0-9]+\.[0-9]+"?/ {
        if (fm == "" && match($0, /[0-9]+\.[0-9]+/)) fm = substr($0, RSTART, RLENGTH)
    }
    FNR <= 20 && /^last_updated: *"?20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]"?/ {
        if (lu == "" && match($0, /20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) lu = substr($0, RSTART, RLENGTH)
    }
    /^\| \*{0,2}v?[0-9]+\.[0-9]+\*{0,2} \| \*{0,2}20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ {
        if (match($0, /[0-9]+\.[0-9]+/)) {
            v = substr($0, RSTART, RLENGTH)
            if (v == fm) {
                rest = substr($0, RSTART+RLENGTH)
                if (match(rest, /20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]/))
                    fmdate = substr(rest, RSTART, RLENGTH)
            }
        }
    }
    END { flush() }
' | sed 's|^\./||; s|\\|/|g' | sort)
NEW_CFL58=$(printf '%s\n' "$CFL58_DRIFT" | grep -v '^$' | grep -v -F -f <(printf '%s\n' "$CFL58_BASELINE" | grep -v '^$' | sed 's/$/ :/') || true)
if [ -n "$NEW_CFL58" ]; then
    fail "DOC-VER(d) — document_version تغيّر وlast_updated لم يلحق" \
         "$NEW_CFL58" \
         "من رفع إصدار الوثيقة يحدّث last_updated في الترويسة نفسها — التاريخان يجب أن يتطابقا"
else
    pass "DOC-VER(d) — لا انحراف last_updated جديد (خط الأساس: $CFL58_BASE_N ملفًا — يتقلّص ولا يتوسع)"
fi

# ── TRK-01 — tracker table integrity ─────────────────────────────────────────
# The tracker is the single operational-state source, and its state lives in
# Markdown tables; a row whose cell count disagrees with its header renders
# shifted and reads as the WRONG status. Malformed rows that already exist are
# pinned as shrink-only debt (TRACKER_MALFORMED_ROWS_BASELINE): the count may
# fall, never rise. The cell counter masks escaped pipes and code spans first
# (an unmasked `\|` in a code span once inflated the count to hundreds —
# measured, not feared).
check
TRACKER_MD="${TRACKER_FILE:-}"
TRACKER_BAD_BASELINE="${TRACKER_MALFORMED_ROWS_BASELINE:-0}"
if [ -z "$TRACKER_MD" ]; then
    na "TRK-01 — لا متتبع مُكوَّن (TRACKER_FILE فارغ)"
else
    TRACKER_BAD=$(awk '
        function cellcount(l,   m) {
            m = l
            gsub(/\\\|/, "", m)
            while (match(m, /`[^`]*`/))
                m = substr(m, 1, RSTART-1) substr(m, RSTART+RLENGTH)
            return gsub(/\|/, "|", m) - 1
        }
        function issep(l) { return l ~ /^[[:space:]]*\|[[:space:]:|-]+\|[[:space:]]*$/ }
        {
            line = $0
            if (issep(line) && prev ~ /^[[:space:]]*\|/ && !issep(prev)) {
                width = cellcount(prev); intable = 1
            } else if (intable && line ~ /^[[:space:]]*\|/ && !issep(line)) {
                if (cellcount(line) != width) bad++
            } else if (intable) { intable = 0 }
            prev = line
        }
        END { print bad+0 }
    ' "$TRACKER_MD" 2>/dev/null || echo 'ERR')
    if [ "$TRACKER_BAD" = "ERR" ] || [ ! -f "$TRACKER_MD" ]; then
        fail "TRK-01 — تعذّر فحص جداول المتتبع" "$TRACKER_MD" "الملف غائب أو الفاحص سقط — كلاهما لا يمرّ صامتًا"
    elif [ "$TRACKER_BAD" -gt "$TRACKER_BAD_BASELINE" ]; then
        fail "TRK-01 — صفوف جداول المتتبع المختلّة زادت: $TRACKER_BAD > $TRACKER_BAD_BASELINE" \
             "$TRACKER_MD" \
             "صف جديد بعدد خلايا مخالف لترويسة جدوله — أصلح الصف، ولا يُرفع خط الأساس بلا قرار"
    else
        pass "TRK-01 — جداول المتتبع: $TRACKER_BAD صفًّا مختلًّا ≤ خط الأساس $TRACKER_BAD_BASELINE (دَين يتناقص)"
    fi
fi

# ── TRK-02 — the tracker's pointer follows its own announcement ─────────────
# `last_verified_commit` must equal the last hash announced by the newest
# version row that announces one. Measured before this check: consecutive
# rows announced a lift while the field stayed on an older hash — the prose
# moves, the field does not, and `STALE — REVERIFY` is then judged on a number
# the document itself contradicts.
#
# What counts as an announcement: in a `| N.N | date |` row that names the
# pointer (`last_verified_commit` or «المؤشِّر»), a hash after «إلى» or «⟵»
# (optionally `main@`). A row may chain two lifts newest-first («من B إلى C …
# من A إلى B»), so the claim is the last target that no «من» in the same row
# leaves. Rows that name the pointer without a hash («لا يُرفع قبل الدمج»)
# announce nothing and are skipped; if no row announces anything the check is
# red, not silent. The copy under the title
# (`> **`Last Verified Commit`: `…`**`) must equal the field as well.
# Hashes compare as abbreviations: equal when the shorter (>= 7) prefixes the
# longer.
check
same_commit() {
    case "$1" in ''|*[!0-9a-f]*) return 1 ;; esac
    case "$2" in ''|*[!0-9a-f]*) return 1 ;; esac
    [ ${#1} -ge 7 ] && [ ${#2} -ge 7 ] || return 1
    case "$1" in "$2"*) return 0 ;; esac
    case "$2" in "$1"*) return 0 ;; esac
    return 1
}
if [ -z "$TRACKER_MD" ]; then
    na "TRK-02 — لا متتبع مُكوَّن (TRACKER_FILE فارغ)"
else
    TRACKER_POINTER=$(awk '
        function ishash(s) { return s ~ /^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*$/ }
        function strip(t) { sub(/^[^`]*`(main@)?/, "", t); sub(/`$/, "", t); return t }
        FNR <= 20 && /^last_verified_commit:/ && fm == "" {
            v = $0; sub(/^last_verified_commit:[[:space:]]*/, "", v); gsub(/["`[:space:]]/, "", v); fm = v
        }
        /^> \*\*`Last Verified Commit`: `/ && bq == "" {
            if (match($0, /: `[^`]*`/)) bq = substr($0, RSTART + 3, RLENGTH - 4)
        }
        /^\| \*{0,2}v?[0-9]+\.[0-9]+\*{0,2} \| \*{0,2}20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ {
            if ($0 !~ /last_verified_commit|Last Verified Commit|المؤشِّر|المؤشّر|المؤشر/) next
            # «من `X`» names a pointer being left; «إلى `Y`» / «⟵ `Y`» one being set.
            delete src; n = 0; rest = $0
            while (match(rest, /من[[:space:]]*`(main@)?[0-9a-f]+`/)) {
                src[strip(substr(rest, RSTART, RLENGTH))] = 1; rest = substr(rest, RSTART + RLENGTH)
            }
            rest = $0
            while (match(rest, /(إلى|⟵)[[:space:]]*`(main@)?[0-9a-f]+`/)) {
                tok = strip(substr(rest, RSTART, RLENGTH)); rest = substr(rest, RSTART + RLENGTH)
                if (ishash(tok)) dst[++n] = tok
            }
            # A row may chain two lifts newest-first («من B إلى C … من A إلى B»):
            # the claim is the last target that no other lift in the row leaves.
            ann = ""
            for (i = n; i >= 1 && ann == ""; i--) if (!(dst[i] in src)) ann = dst[i]
            if (ann == "" && n > 0) ann = dst[n]
            if (ann == "") next
            match($0, /[0-9]+\.[0-9]+/); split(substr($0, RSTART, RLENGTH), p, ".")
            if (row == "" || p[1] + 0 > maj || (p[1] + 0 == maj && p[2] + 0 > mnr)) {
                maj = p[1] + 0; mnr = p[2] + 0; row = maj "." mnr; claim = ann
            }
        }
        END { printf "%s\t%s\t%s\t%s\n", fm, bq, row, claim }
    ' "$TRACKER_MD" 2>/dev/null || echo 'ERR')
    IFS=$'\t' read -r PTR_FM PTR_BQ PTR_ROW PTR_CLAIM <<< "$TRACKER_POINTER"
    if [ "$TRACKER_POINTER" = "ERR" ] || [ ! -f "$TRACKER_MD" ]; then
        fail "TRK-02 — تعذّر فحص مؤشّر المتتبع" "$TRACKER_MD" "الملف غائب أو الفاحص سقط — كلاهما لا يمرّ صامتًا"
    elif [ -z "$PTR_CLAIM" ]; then
        fail "TRK-02 — لا صفّ إصدارٍ في المتتبع يُعلن بصمة last_verified_commit" "$TRACKER_MD" \
             "الفحص يقرأ «إلى \`<hash>\`» أو «⟵ \`<hash>\`» في صفٍّ يذكر المؤشِّر — غيابُه كلُّه لا يُقرأ نجاحًا"
    elif ! same_commit "$PTR_FM" "$PTR_CLAIM"; then
        fail "TRK-02 — last_verified_commit في الترويسة ($PTR_FM) يخالف ما يُعلنه صفّ الإصدار $PTR_ROW ($PTR_CLAIM)" \
             "$TRACKER_MD" \
             "من يُعلن رفعَ المؤشِّر في صفّ الإصدار يرفعه في حقل الترويسة نفسه في الالتزام نفسه"
    elif [ -n "$PTR_BQ" ] && ! same_commit "$PTR_BQ" "$PTR_FM"; then
        fail "TRK-02 — نسخةُ «Last Verified Commit» تحت العنوان ($PTR_BQ) تخالف حقل الترويسة ($PTR_FM)" \
             "$TRACKER_MD" \
             "الحقل والنسخة تحت العنوان يُرفعان معًا"
    else
        pass "TRK-02 — last_verified_commit ($PTR_FM) يطابق ما يُعلنه صفّ الإصدار $PTR_ROW"
    fi
fi

# ── DoD-SL-08 — no unreplaced placeholder may survive INTO HISTORY ────────
# The tracker stamps `Last Verified Commit` and every evidence row with the
# commit that measured them. That hash is created BY the commit carrying the
# tracker, so it cannot be written beforehand: the writing step leaves a
# literal placeholder behind and a second commit stamps it. That two-commit
# window is the intended pattern.
#
# So this check does NOT forbid the placeholder in the working tree — doing
# that would make the intended sequence impossible. It guards PERSISTENCE
# instead: whatever the window was, HEAD must already be stamped. Forget the
# second commit and the next gate run is red.
#
# What it deliberately does not catch: a placeholder sitting uncommitted in
# the working tree, which is a legitimate mid-flight state and indistinguishable
# from the failure that prompted this check (a gate run that died before its
# commit). That case is caught by this check the moment the work is committed
# without stamping — one commit later than ideal, and stated here rather than
# overclaimed.
check
COMMITTED_PLACEHOLDERS=$(git grep -l "$STAMP_PLACEHOLDER" HEAD -- "$DOCS_DIR/" 2>/dev/null | sed 's|^HEAD:||' | sort)
if [ -n "$COMMITTED_PLACEHOLDERS" ]; then
    fail "DoD-SL-08 — علامة نائبة غير مستبدَلة في HEAD" "$COMMITTED_PLACEHOLDERS" \
         "شغّل bash scripts/stamp-commit.sh والتزم الختم — نافذة الختم التزام واحد لا أكثر"
else
    pass "DoD-SL-08 — لا علامة نائبة باقية في HEAD"
fi

echo "────────────────────────────────────────────────────────────"
if [ "$FAILED" -gt 0 ]; then
    red "فشل $FAILED من $CHECKS فحصًا"
    exit 1
fi
green "اجتاز $CHECKS فحصًا"
echo
exit 0
