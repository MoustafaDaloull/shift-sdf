#!/usr/bin/env bash
# =============================================================================
# AS-035 — تغطية السيناريوهات المعتمدة
# -----------------------------------------------------------------------------
# يربط `@scenario TS-*` في الاختبارات (`RS-041` · `CS-060`) بـ`test-scenarios.md`
# في حزمة الموديول، ويجيب آليًا عن السؤال: «هل نُفِّذ TS-XXX-001؟»
#
# صيغة المعرّف `<SCENARIO_ID_PREFIX>-<CODE>-NNN`، والمسارات من shift.env.
#
# ── لماذا bash لا php ────────────────────────────────────────────────────────
# الفحص يقرأ `docs/` و`tests/` معًا، وحاوية التطوير تربط مجلد الخلفية وحده —
# فـ`docs/` غير مرئي من داخلها. هذا هو سبب أن `arch-check.sh` و`secret-scan.sh`
# يعملان على المضيف، وهذا الفحص منهما.
#
# ── ما يُفرَض وما لا يُفرَض ─────────────────────────────────────────────────
# 1. **مُفرَض:** كل معرّف `@scenario` في الكود موجود فعلًا في ملف موديوله. معرّف
#    مُخترَع أو منسوب لموديول غير موديوله يُفشِل البناء. هذا يمنع أسوأ حالة:
#    اختبار يدّعي تنفيذ سيناريو لا وجود له.
#
# 2. **غير مُفرَض — يُعلَن ولا يُحتسب نجاحًا:** عتبة `AS-035` للأولوية
#    (`P1` = 100% وإلا فشل البناء). `RS-041` يضع تفعيلها «بعد أول حزمة موديول
#    كاملة»، وموديولات بلا وسم أولوية تجعل «100% من P1» تمرّ خضراء لأن المقسوم
#    عليه صفر — وهي تغطية وهمية يمنعها `AS-002`. فالحالة تُطبع `N/A` ولا
#    تُحتسب نجاحًا — المبدأ نفسه الذي يتّبعه `coverage-check.php` مع نطاق الواجهة.
#
# الاستخدام: bash scripts/scenario-check.sh
# =============================================================================

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

# shellcheck source=config/shift.env
. "scripts/config/shift.env" || exit 2

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'

DOCS_GLOB="$MODULES_DOCS_DIR/*/$TEST_SCENARIOS_FILE"
TESTS_DIR="$BACKEND_TESTS_DIR"
# Browser suites prove scenarios too — a gate pinned to the backend tests
# alone lets an E2E scenario sit in a frontend slice's declared scope and the
# slice close green with nothing proving it. Frontend tags go through the same
# defined-in-spec validation as backend ones.
FE_TESTS_DIR="$FRONTEND_TESTS_DIR"

TSP="$SCENARIO_ID_PREFIX"
# كود الموديول: [A-Z]{min,max} بصيغتَي ERE وBRE (sed).
CODE_ERE="[A-Z]{${MODULE_CODE_MIN},${MODULE_CODE_MAX}}"
CODE_BRE="[A-Z]\\{${MODULE_CODE_MIN},${MODULE_CODE_MAX}\\}"

failures=0

declare -A SPEC_FILE=()      # module_code ⟶ مسار ملف السيناريوهات
declare -A DEFINED=()        # "CODE|TS-CODE-###" ⟶ 1
declare -A DEFINED_COUNT=()  # module_code ⟶ عدد السيناريوهات المعرَّفة
declare -A P1_COUNT=()       # module_code ⟶ عدد سيناريوهات P1

# ── 1. بناء خريطة الموديولات من الترويسة لا من جدول مكتوب بأيدينا ────────────
# `module_code` في ترويسة كل ملف سيناريوهات، وقراءته منها تعني أن إضافة موديول
# جديد لا تحتاج تعديل هذا السكربت — وخريطة تُكتب يدويًا في موضع ثانٍ هي
# بالضبط ما يتباعد لاحقًا.
for spec in $DOCS_GLOB; do
    [ -f "$spec" ] || continue

    code="$(sed -n '1,25p' "$spec" | tr -d '\r' | sed -n 's/^module_code:[[:space:]]*"\{0,1\}\('"$CODE_BRE"'\)"\{0,1\}[[:space:]]*$/\1/p' | head -1)"

    if [ -z "$code" ]; then
        printf '  %sلا module_code في ترويسة%s %s\n' "$RED" "$OFF" "$spec"
        failures=$((failures + 1))
        continue
    fi

    SPEC_FILE["$code"]="$spec"

    # السيناريو **معرَّف** حيث يُنشأ لا حيث يُذكر. الصيغتان المقبولتان:
    #   · صف جدول يبدأ بالمعرّف        — أكثر الحزم
    #   · عنوان `### TS-XXX-001 — …`   — بعض الحزم
    #   والمعرّف في صفّ الجدول قد يُلفّ بعلامتَي كود (`| `TS-XXX-069` |`) —
    #   حزمٌ كاملة كُتبت هكذا فقرأتها البوابة «غير معرَّفة» كلَّها (lessons L-038).
    # واستثناء ما عداهما مقصود: أقسام التتبع تسرد معرّفات بالعشرات في سطر واحد
    # (`FLOW-XXX-003 | TS-XXX-001, 004, …`)، وعدّها تعريفًا يجعل الملف يُعرّف
    # سيناريوهات لم تُكتب.
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        DEFINED["$code|$id"]=1
    done < <(tr -d '\r' < "$spec" | sed -n \
        -e 's/^|[[:space:]]*`\{0,1\}\('"$TSP"'-'"$code"'-[0-9]\{1,\}\)`\{0,1\}[[:space:]]*|.*/\1/p' \
        -e 's/^#\{2,4\}[[:space:]]*\('"$TSP"'-'"$code"'-[0-9]\{1,\}\)[[:space:]].*/\1/p' \
        | sort -u)

    DEFINED_COUNT["$code"]=$(tr -d '\r' < "$spec" | sed -n \
        -e 's/^|[[:space:]]*`\{0,1\}\('"$TSP"'-'"$code"'-[0-9]\{1,\}\)`\{0,1\}[[:space:]]*|.*/\1/p' \
        -e 's/^#\{2,4\}[[:space:]]*\('"$TSP"'-'"$code"'-[0-9]\{1,\}\)[[:space:]].*/\1/p' \
        | sort -u | wc -l | tr -d ' ')

    P1_COUNT["$code"]=$(tr -d '\r' < "$spec" \
        | grep -cE "^\|[[:space:]]*\`?$TSP-$code-[0-9]+\`?[[:space:]]*\|.*\|[[:space:]]*P1[[:space:]]*\|?[[:space:]]*$" || true)
done

if [ "${#SPEC_FILE[@]}" -eq 0 ]; then
    printf '  %sلم يُعثر على أي ملف سيناريوهات%s (%s)\n' "$RED" "$OFF" "$DOCS_GLOB"
    exit 2
fi

# ── 2. جمع ما يدّعيه الكود ───────────────────────────────────────────────────
declare -A IMPLEMENTED=()    # "CODE|TS-CODE-###" ⟶ الملف:السطر
code_ids_total=0

if [ -d "$TESTS_DIR" ]; then
    while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        loc="${hit%%:@@:*}"
        id="${hit##*:@@:}"
        idcode="$(printf '%s' "$id" | sed 's/^'"$TSP"'-\('"$CODE_BRE"'\)-[0-9]\{1,\}$/\1/')"
        code_ids_total=$((code_ids_total + 1))

        if [ -z "${SPEC_FILE[$idcode]+x}" ]; then
            printf '  %s✗%s %s — بادئة موديول غير معروفة %s(%s)%s\n' \
                "$RED" "$OFF" "$id" "$DIM" "$loc" "$OFF"
            failures=$((failures + 1))
            continue
        fi

        if [ -z "${DEFINED[$idcode|$id]+x}" ]; then
            printf '  %s✗%s %s — غير معرَّف في %s %s(%s)%s\n' \
                "$RED" "$OFF" "$id" "${SPEC_FILE[$idcode]}" "$DIM" "$loc" "$OFF"
            failures=$((failures + 1))
            continue
        fi

        IMPLEMENTED["$idcode|$id"]="$loc"
    done < <(
        # One tag line may carry several ids separated by « · ». The pattern
        # below matches the whole run and awk emits one record per id.
        #
        # A version that matched a single id and anchored the sed at `$`
        # dropped every id after the first **silently**: the line still
        # counted, just as one. A coverage gate that under-reports is what
        # makes someone write a test that exists.
        TAG="${SCENARIO_TAG}[[:space:]]+${TSP}-${CODE_ERE}-[0-9]+([[:space:]]*·[[:space:]]*${TSP}-${CODE_ERE}-[0-9]+)*"
        {
            grep -rnoE "$TAG" "$TESTS_DIR" --include='*.php' 2>/dev/null
            # Frontend suites — *.ts and *.tsx, same tag grammar.
            [ -d "$FE_TESTS_DIR" ] && grep -rnoE "$TAG" "$FE_TESTS_DIR" --include='*.ts' --include='*.tsx' 2>/dev/null
        } | awk -F: -v tag="$SCENARIO_TAG" -v idre="${TSP}-${CODE_ERE}-[0-9]+" '{
                loc = $1 ":" $2
                rest = substr($0, index($0, tag))
                while (match(rest, idre)) {
                    print loc ":@@:" substr(rest, RSTART, RLENGTH)
                    rest = substr(rest, RSTART + RLENGTH)
                }
            }'
    )
fi

# ── 3. التقرير ───────────────────────────────────────────────────────────────
printf '%s\n' "────────────────────────────────────────────────────────────"
printf '  %-22s %8s %8s %10s\n' 'الموديول' 'معرَّف' 'مُنفَّذ' 'P1'
printf '%s\n' "────────────────────────────────────────────────────────────"

for code in $(printf '%s\n' "${!SPEC_FILE[@]}" | sort); do
    impl=0
    for key in "${!IMPLEMENTED[@]}"; do
        [ "${key%%|*}" = "$code" ] && impl=$((impl + 1))
    done

    # لا يُعرض إلا موديول له كود أو تنفيذ — سرد كل الحزم أصفارًا يُغرق
    # الإشارة الوحيدة المهمة.
    [ "$impl" -gt 0 ] || continue

    if [ "${P1_COUNT[$code]}" -gt 0 ]; then
        p1="${P1_COUNT[$code]}"
    else
        p1="N/A"
    fi

    printf '  %-22s %8s %8s %10s\n' "$code" "${DEFINED_COUNT[$code]}" "$impl" "$p1"
done

printf '%s\n' "────────────────────────────────────────────────────────────"

# العتبة المؤجَّلة تُعلَن في كل تشغيل. بوابة تصمت عن نصفها المعطَّل تُقرأ بعد شهر
# على أنها تفرض ما لا تفرض.
printf '  %s—%s  عتبة %sP1 = 100%%%s مُعلَنة وغير مفروضة بعد (AS-035)\n' \
    "$YELLOW" "$OFF" "$YELLOW" "$OFF"
printf '     %sالسبب: تُفعَّل بعد أول حزمة موديول كاملة (RS-041)، وموديول بلا وسم أولوية يمرّ بمقسومٍ عليه صفر.%s\n' \
    "$DIM" "$OFF"

# ── 4. `@covers` — المعرّف المصدري للقاعدة التي يُثبتها الاختبار ─────────────
# `@scenario` وحده لا يكفي: `@covers` هو ما يحمل السند حيث لا سيناريو مطابق.
# فمعرّف `@covers` مُخترَع يترك الاختبار **بلا سند أصلًا**.
#
# ولماذا يُفحَص **التعريف** لا الذِّكر: فحصٌ يبحث عن المعرّف في `docs/` كلها
# يُمرّر معرّفًا غير موجود كُتب خطأً في وثائق أخرى. **فحصٌ يقبل ما ذُكر يُصادق
# على الخطأ حين ينتشر.** الأصل أن يُسأل الملف الذي *يُعرِّف* المعرّف وحده.
#
# والعائلات التي لا يمكن حسم موضع تعريفها تُطبع «غير مفحوصة» ولا تُحتسب نجاحًا —
# المبدأ نفسه الذي اتّبعه `coverage-check.php` مع نطاق الواجهة.

covers_bad=0
covers_ok=0
# Explicit `=()`: a declared-but-empty associative array trips `set -u` on
# `${#arr[@]}` and aborts the gate mid-report.
declare -A UNCHECKED=()

while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    loc="${hit%%:@@:*}"
    id="${hit##*:@@:}"

    case "$id" in
        BR-*)
            # القواعد تُعرَّف بعنوان في `business-rules.md` لموديولها.
            if grep -rqE "^#{2,4}[[:space:]]*\`?${id}\`?([[:space:]]|—|$)" "$MODULES_DOCS_DIR"/*/business-rules.md 2>/dev/null; then
                covers_ok=$((covers_ok + 1))
            else
                printf '  %s✗%s %s — لا تعريف في أي `business-rules.md` %s(%s)%s\n' \
                    "$RED" "$OFF" "$id" "$DIM" "$loc" "$OFF"
                covers_bad=$((covers_bad + 1))
            fi
            ;;
        DEC-*)
            if grep -qE "^#{2,4}[[:space:]]*\`?${id}\`?([[:space:]]|—|$)" "$DECISIONS_FILE" 2>/dev/null; then
                covers_ok=$((covers_ok + 1))
            else
                printf '  %s✗%s %s — لا تعريف في سجل القرارات %s(%s)%s\n' \
                    "$RED" "$OFF" "$id" "$DIM" "$loc" "$OFF"
                covers_bad=$((covers_bad + 1))
            fi
            ;;
        SEC-*-*)
            # عائلةُ الأمن المُوَدْيَلة `SEC-<CODE>-###` ليست عائلةَ `SEC-###`
            # المنصّيّة رغم اشتراك البادئة: الأولى تُعرَّف **صفَّ جدولٍ** في حزمة
            # موديولها، والثانية **عنوانًا** في معايير STANDARDS_DIR. وغلوبٌ
            # `SEC-*` يبتلع الاثنتين ويسأل عنهما معاييرَ المنصة فيُعلن معرَّفًا
            # صادقًا بلا تعريف — **إخفاقٌ كاذبٌ يدفع إلى حذف وسمٍ صادقٍ لتخضرَّ
            # البوابة، وهو أسوأُ ما تفعله بوابة.**
            #
            # والقيدُ **الخليةُ الأولى** لا مجرّدُ الذِّكر: هذه المعرّفات نفسُها
            # تُذكَر في `test-scenarios.md` و`user-stories.md` وفي حزم موديولاتٍ
            # أخرى، وقبولُ الذِّكر يُصادق على الخطأ حين ينتشر. وموضعُ التعريف
            # يختلف بين الحزم، فالبحثُ في الحزمة كلِّها والتمييزُ بالخليّة الأولى.
            if grep -rqE "^\|[[:space:]]*\`?${id}\`?[[:space:]]*\|" "$MODULES_DOCS_DIR"/*/*.md 2>/dev/null; then
                covers_ok=$((covers_ok + 1))
            else
                printf '  %s✗%s %s — لا تعريف في حزمة أي موديول %s(%s)%s\n' \
                    "$RED" "$OFF" "$id" "$DIM" "$loc" "$OFF"
                covers_bad=$((covers_bad + 1))
            fi
            ;;
        CS-*|RS-*|DD-*|SEC-*|AS-*|ECS-*|EP-*|AUTH-*|AUTHZ-*)
            if grep -rqE "^#{2,4}[[:space:]]*\`?${id}\`?([[:space:]]|—|$)" "$STANDARDS_DIR"/*.md 2>/dev/null; then
                covers_ok=$((covers_ok + 1))
            else
                printf '  %s✗%s %s — لا تعريف في معايير `%s/` %s(%s)%s\n' \
                    "$RED" "$OFF" "$id" "$STANDARDS_DIR" "$DIM" "$loc" "$OFF"
                covers_bad=$((covers_bad + 1))
            fi
            ;;
        *)
            # `FR-*` و`ENT-*` و`HG-I-*` تُعرَّف صفوفَ جداول لا عناوين، وموضعها
            # يختلف بين الحزم — فحصها يحتاج قواعد اشتقاق لكل عائلة، وبناؤها
            # بالتخمين يُنتج إخفاقات كاذبة أسوأ من غياب الفحص.
            UNCHECKED["$id"]=1
            ;;
    esac
done < <(
    # سطر واحد لكل معرّف، والموضع محسوب من الحقلين الأولين لا مستنتَجًا من سياق
    # سابق — نسخةٌ تحمل الموضع عبر الأسطر تُكرّر بعض المعرّفات وتُبلغ عددًا أكبر
    # من الحقيقي. عددٌ خاطئ في بوابة أسوأ من رسالة ناقصة.
    grep -rnE "$COVERS_TAG" "$TESTS_DIR" --include='*.php' 2>/dev/null \
    | awk -F: -v tag="$COVERS_TAG" '{
        loc = $1 ":" $2
        idx = index($0, tag)
        if (idx == 0) next
        rest = substr($0, idx + length(tag))
        n = split(rest, parts, /·/)
        for (i = 1; i <= n; i++) {
            gsub(/[^A-Za-z0-9-]/, "", parts[i])
            if (parts[i] ~ /^[A-Z]/) print loc ":@@:" parts[i]
        }
      }'
)

if [ "${#UNCHECKED[@]}" -gt 0 ]; then
    printf '  %s—%s  %d معرّف `%s` %sغير مفحوص%s — عائلات تُعرَّف صفوفَ جداول (`FR-*` · `ENT-*` · `HG-I-*`)\n' \
        "$YELLOW" "$OFF" "${#UNCHECKED[@]}" "$COVERS_TAG" "$YELLOW" "$OFF"
fi

if [ "$covers_bad" -gt 0 ]; then
    printf '  %s✗ %d معرّف `%s` لا تعريف له%s\n' "$RED" "$covers_bad" "$COVERS_TAG" "$OFF"
    failures=$((failures + covers_bad))
else
    printf '  %s✓%s %d معرّف `%s` — كلها معرَّفة في مصادرها\n' "$GREEN" "$OFF" "$covers_ok" "$COVERS_TAG"
fi

if [ "$failures" -gt 0 ]; then
    printf '  %s✗ %d معرّف لا سند له%s\n' "$RED" "$failures" "$OFF"
    exit 1
fi

printf '  %s✓%s %d معرّف سيناريو — كلها مسنودة في حزم موديولاتها\n' \
    "$GREEN" "$OFF" "$code_ids_total"
exit 0
