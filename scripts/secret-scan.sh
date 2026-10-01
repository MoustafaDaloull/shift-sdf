#!/usr/bin/env bash
# =============================================================================
# كاشف الأسرار — AS-020
# -----------------------------------------------------------------------------
# لماذا هذا الفحص غير قابل للتجاوز:
#
# السر المدفوع يبقى في تاريخ Git **حتى بعد حذفه**. العلاج ليس تعديل الملف ولا
# إعادة كتابة التاريخ — العلاج تدوير المفتاح لدى مزوّده، وهو إجراء خارجي مكلف
# قد يمتد أثره إلى بوابة الدفع وحساب السحابة. منعه قبل الالتزام يكلّف ثانية.
#
# ولهذا السبب نفسه لا يكفي فحص **الحالة الراهنة**: سرٌّ أُضيف ثم حُذف يمرّ
# نظيفًا في `--all` بينما هو قائم في التاريخ ومكشوف لكل من يستنسخ المستودع.
# الوضع `--history` هو ما يُثبت نظافة التاريخ.
#
# الاستخدام:
#   bash scripts/secret-scan.sh            فحص الملفات المُدرَجة (pre-commit)
#   bash scripts/secret-scan.sh --all      فحص كل الملفات المتعقَّبة (CI)
#   bash scripts/secret-scan.sh --history  فحص كل إصدارات كل ملف في التاريخ
#
# لماذا `--history` ليس الوضع الافتراضي في كل تشغيل: كلفته تنمو مع عمر
# المستودع، وتشغيله في كل بناء يُبطئ الخط بلا مقابل — السر الجديد يمسكه
# `--all` قبل أن يصير تاريخًا. `--history` يُشغَّل عند إغلاق شريحة وعند
# التدقيق الدوري.
# =============================================================================

set -uo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=config/shift.env
. "$SCRIPT_ROOT/scripts/config/shift.env" || exit 2

MODE="${1:-staged}"
FAILED=0

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }

# ── أنماط الأسرار — مُعرَّفة مرة واحدة ويستعملها كل وضع ──────────────────────
# الأنماط تغطي الصيغ الشائعة لمفاتيح المزوّدين وقواعد البيانات والرموز، مع
# تجنّب الإيجابيات الكاذبة على القوالب والأمثلة.
PATTERN_LABELS=(
    "مفتاح خاص (PEM)"
    "مفتاح AWS"
    "مفتاح Google API"
    "حساب خدمة Google"
    "مفتاح بوابة دفع (sk_live / sk_test)"
    "رمز Slack"
    "رمز GitHub"
    "JWT مُضمَّن"
    "كلمة مرور بقيمة حقيقية"
)
PATTERN_REGEXES=(
    '\-\-\-\-\-BEGIN [A-Z ]*PRIVATE KEY\-\-\-\-\-'
    'AKIA[0-9A-Z]{16}'
    'AIza[0-9A-Za-z_\-]{35}'
    '"type"[[:space:]]*:[[:space:]]*"service_account"'
    'sk_(live|test)_[0-9A-Za-z]{16,}'
    'xox[baprs]-[0-9A-Za-z\-]{10,}'
    'gh[pousr]_[0-9A-Za-z]{36}'
    'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.'
    '(password|passwd|secret|api_?key|token)[[:space:]]*[=:][[:space:]]*["'"'"'][^"'"'"'{}$]{12,}["'"'"']'
)

# حساسية حالة الأحرف — لكل نمط على حدة (1 = بلا حساسية).
#
# ثمانية من الأنماط تصف **صيغًا مُعرَّفة الحالة**: مفتاح AWS أحرفه كبيرة
# بحكم صيغته، و`ghp_` و`xoxb-` و`eyJ` كذلك. فحصها بـ`-i` يُلغي خصوصية
# الصيغة ويحوّل أي كتلة base64 كبيرة إلى مصنع إنذارات كاذبة: أول تشغيل
# للوضع التاريخي رصد «مفتاح AWS» بحرف صغير واحد داخل صورة PNG مُرمَّزة في
# شعار — وهو ما لا يكون مفتاحًا أبدًا.
#
# النمط التاسع وحده يبقى بلا حساسية: `PASSWORD=` و`ApiKey:` و`Token =`
# كلها صيغ حقيقية يكتبها البشر بأي حالة.
PATTERN_ICASE=(0 0 0 0 0 0 0 0 1)

# أصول بصرية وخطوط — تُستثنى من فحص القيم في كل الأوضاع.
# سرٌّ مدفون داخل صورة أو خط ليس مسار تسريب معتبرًا، بينما محتواها
# المُرمَّز base64 يُنتج تطابقات عشوائية مع أي نمط طويل بلا استثناء.
ASSET_GLOBS=('*.svg' '*.png' '*.jpg' '*.jpeg' '*.gif' '*.ico' '*.webp'
             '*.woff' '*.woff2' '*.ttf' '*.eot' '*.otf' '*.pdf')

# الاستثناءات المُعدَّة (قوالب · وثائق) من SECRET_SCAN_EXCLUDE_GLOBS + الأصول أعلاه.
build_excludes() {
    EXCLUDES=()
    local g
    for g in ${SECRET_SCAN_EXCLUDE_GLOBS:-}; do EXCLUDES+=(":(exclude)$g"); done
    for g in "${ASSET_GLOBS[@]}"; do EXCLUDES+=(":(exclude)$g"); done
}

# ═════════════════════════════════════════════════════════════════════════════
# الوضع التاريخي — كل إصدار من كل ملف في كل مرجع
# ═════════════════════════════════════════════════════════════════════════════
if [ "$MODE" = "--history" ]; then
    REVS=$(git rev-list --all)
    if [ -z "$REVS" ]; then
        green "لا تاريخ للفحص"
        exit 0
    fi
    REV_COUNT=$(echo "$REVS" | wc -l | tr -d ' ')
    echo "فحص تاريخي — $REV_COUNT التزامًا"
    echo

    # ملف بيئة أُضيف يومًا ما، ولو حُذف بعدها
    EVER_ENV=$(git log --all --pretty=format: --name-only --diff-filter=A \
        -- '.env' '*/.env' '.env.local' '.env.prod' '.env.production' '.env.staging' \
        2>/dev/null | sort -u | grep -v '^$' || true)
    if [ -n "$EVER_ENV" ]; then
        red "✗ ملف بيئة كان مُتعقَّبًا في التاريخ:"
        echo "$EVER_ENV" | sed 's/^/    /'
        echo "    حذفه لاحقًا لا يزيله من التاريخ — العلاج تدوير كل مفتاح فيه (RS-003)"
        FAILED=1
    fi

    build_excludes

    for i in "${!PATTERN_REGEXES[@]}"; do
        if [ "${PATTERN_ICASE[$i]}" -eq 1 ]; then ICASE="-i"; else ICASE=""; fi
        hits=$(git grep -I -nH $ICASE -E "${PATTERN_REGEXES[$i]}" $REVS -- \
            "${EXCLUDES[@]}" \
            2>/dev/null | head -10 || true)
        if [ -n "$hits" ]; then
            red "✗ ${PATTERN_LABELS[$i]} — في التاريخ:"
            echo "$hits" | sed 's/^/    /'
            FAILED=1
        fi
    done

    echo
    if [ "$FAILED" -eq 1 ]; then
        red "فحص الأسرار التاريخي: فشل"
        echo
        echo "سرٌّ في التاريخ مكشوف لكل من يستنسخ المستودع، ولو لم يعد في الحالة"
        echo "الراهنة. العلاج تدوير المفتاح لدى مزوّده — لا حذف الملف."
        exit 1
    fi
    green "فحص الأسرار التاريخي: نظيف — $REV_COUNT التزامًا"
    exit 0
fi

# ═════════════════════════════════════════════════════════════════════════════
# الوضعان الراهنان — المُدرَج أو كل المتعقَّب
# ═════════════════════════════════════════════════════════════════════════════
if [ "$MODE" = "--all" ]; then
    FILES=$(git ls-files)
else
    FILES=$(git diff --cached --name-only --diff-filter=ACM)
fi

[ -z "$FILES" ] && { green "لا ملفات للفحص"; exit 0; }

# ── 1) منع إدراج .env ────────────────────────────────────────────────────────
# الاستثناء الوحيد: .env.example — قالب بأسماء المفاتيح وقيم وهمية.
ENV_FILES=$(echo "$FILES" | grep -E "(^|/)\.env$|(^|/)\.env\.(local|dev|prod|production|staging)$" || true)
if [ -n "$ENV_FILES" ]; then
    red "✗ محاولة إدراج ملف بيئة:"
    echo "$ENV_FILES" | sed 's/^/    /'
    echo "    ملفات .env مُستثناة في .gitignore — لا تُدرَج بأي حال (RS-003)"
    FAILED=1
fi

# ── 2) أنماط الأسرار ─────────────────────────────────────────────────────────
#
# يُستعمل `git grep` لا حلقة `grep` لكل ملف: الحلقة تُنتج «عدد الملفات × 9
# أنماط» عملية منفصلة، فيتجاوز فحصُ `--all` الدقيقتين على مستودع فيه آلاف
# الأصول — وهو زمن يقع على المسار الحرج لكل تشغيل CI ولكل التزام. `git grep`
# يقرأ الفهرس مرة ويوازي داخليًا.
build_excludes

scan() {
    local label="$1" pattern="$2" icase="$3"
    local icf="" hits
    [ "$icase" -eq 1 ] && icf="-i"

    if [ "$MODE" = "--all" ]; then
        hits=$(git grep -I -nH $icf -E "$pattern" -- "${EXCLUDES[@]}" 2>/dev/null | head -10 || true)
    else
        # وضع ما قبل الالتزام: الفهرس وحده، ومحصورًا بالملفات المُدرَجة.
        hits=$(git grep -I -nH --cached $icf -E "$pattern" -- $FILES "${EXCLUDES[@]}" 2>/dev/null | head -10 || true)
    fi

    if [ -n "$hits" ]; then
        red "✗ $label:"
        echo "$hits" | sed 's/^/    /'
        FAILED=1
    fi
}

for i in "${!PATTERN_REGEXES[@]}"; do
    scan "${PATTERN_LABELS[$i]}" "${PATTERN_REGEXES[$i]}" "${PATTERN_ICASE[$i]}"
done

echo
if [ "$FAILED" -eq 1 ]; then
    red "فحص الأسرار: فشل"
    echo
    echo "هذا الفحص لا يُتجاوَز. السر المدفوع يبقى في تاريخ Git بعد حذفه،"
    echo "وعلاجه تدوير المفتاح لدى مزوّده لا تعديل الملف."
    exit 1
fi
green "فحص الأسرار: نظيف"
exit 0
