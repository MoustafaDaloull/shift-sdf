#!/usr/bin/env bash
# =============================================================================
# QG-SYNC — شجرات عمل ضمن الحد · ولا التزام غير مدفوع · وتشغيلة واحدة
# -----------------------------------------------------------------------------
# يفحص ثلاثة أمور:
#   1) لا تزيد شجرات العمل الإضافية على MAX_EXTRA_WORKTREES وكلها خارج المستودع
#   2) لا التزام محلي غير مدفوع — الالتزام والدفع حركة واحدة
#   3) تشغيلة بوابات واحدة في الشجرة (قفل mkdir)
#
# لماذا بوابة وليست قاعدة مكتوبة: ما لا يُفحَص لا يُعتمد عليه. والسابقتان
# اللتان أنتجتا هذه البوابة مقيستان: بوابات أُعلنت عاملة ولم تكن مفعَّلة،
# وشجرات تراكمت حتى صارت اثنتي عشرة، نصفها داخل المستودع نفسه حيث تمشي عليها
# كل بوابة تمسح الشجرة.
#
# الاستخدام: bash scripts/sync-check.sh
# =============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# shellcheck source=config/shift.env
. "$ROOT/scripts/config/shift.env" || exit 2

FAILED=0
red()    { printf '\033[31m%s\033[0m\n' "$1"; }
green()  { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }
dim()    { printf '\033[2m%s\033[0m\n' "$1"; }

MAX_EXTRA="${MAX_EXTRA_WORKTREES:-3}"

echo
echo "المزامنة وشجرات العمل — QG-SYNC"
echo "────────────────────────────────────────────────────────────"

# ── 1) شجرات العمل ──────────────────────────────────────────────────────────
# `git worktree list` تطبع الأصلية أولًا ثم كل شجرة مضافة. الحدّ من الإعداد،
# وكلها **خارج** المستودع: شجرةٌ متداخلة تمشي عليها كل بوابة تمسح الشجرة.
# العدد لا يُتجاوَز بمجلد جديد، والمسار يُفحص فوقه.
#
# ولماذا يُقارَن المسار بما تطبعه git لا بـ`$ROOT`: على Git Bash يكون `$ROOT`
# بصيغة `/d/...` بينما تطبع git الشجرات بصيغة `D:/...`، فلا يتطابق النمطان
# أبدًا وتمرّ الشجرة المتداخلة خضراء — وهو ما وقع فعلًا في أول خرق متعمَّد
# على هذه البوابة. فالمرجع السطر الأول من مخرج git نفسه.
WT_LIST="$(git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')"
MAIN_WT="$(printf '%s\n' "$WT_LIST" | head -n 1)"
WT_TOTAL=$(printf '%s\n' "$WT_LIST" | grep -c . || echo 1)

EXTRA_TOTAL=$((WT_TOTAL - 1))
[ "$EXTRA_TOTAL" -lt 0 ] && EXTRA_TOTAL=0
INVALID_TOTAL=0
while IFS= read -r wt; do
    [ -z "$wt" ] && continue
    case "$wt" in
        "$MAIN_WT"/*) INVALID_TOTAL=$((INVALID_TOTAL + 1)) ;;
    esac
done <<EOF
$(printf '%s\n' "$WT_LIST" | tail -n +2)
EOF

if [ "$EXTRA_TOTAL" -gt "$MAX_EXTRA" ] || [ "$INVALID_TOTAL" -gt 0 ]; then
    red "  ✗ QG-SYNC(1) — شجرات عمل غير صالحة (الإضافية=$EXTRA_TOTAL/$MAX_EXTRA · داخل المستودع=$INVALID_TOTAL)"
    printf '%s\n' "$WT_LIST" | tail -n +2 | while IFS= read -r wt; do
        [ -n "$wt" ] && dim "      $wt"
    done
    dim "      الإزالة: bash scripts/agent-worktree.sh drop <الاسم>  ·  أو: git worktree remove <المسار>"
    FAILED=1
else
    green "  ✓ QG-SYNC(1) — شجرات العمل ضمن الحد وخارج المستودع (الإضافية=$EXTRA_TOTAL/$MAX_EXTRA)"
fi

# ── 2) لا التزام غير مدفوع ──────────────────────────────────────────────────
# في CI لا معنى للفحص: الخط يفحص مرجعًا **مدفوعًا أصلًا** ويسحبه في حالة
# detached HEAD بلا upstream. فتُعلَن N/A ولا تُسكت — القاعدة نفسها التي
# تتبعها بوابة المسارات عند غياب ملف مسارات.
if [ "${CI:-}" = "true" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
    yellow "  —  QG-SYNC(2) N/A مُعلَنة — CI يفحص مرجعًا مدفوعًا بحكم تشغيله"
else
    BRANCH="$(git branch --show-current 2>/dev/null || true)"

    if [ -z "$BRANCH" ]; then
        red "  ✗ QG-SYNC(2) — HEAD منفصل · لا فرع يُدفع إليه"
        dim "      git checkout <branch>"
        FAILED=1
    elif ! UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
        red "  ✗ QG-SYNC(2) — الفرع '$BRANCH' بلا upstream · لم يُدفع قط"
        dim "      git push -u origin $BRANCH"
        FAILED=1
    else
        # `ahead` دقيق بلا fetch: الدفع نفسه يُحدِّث مرجع التتبّع محليًا. أما
        # `behind` فيعكس آخر fetch لا حالة origin الآن، ولذلك يُذكر خبرًا ولا
        # يُفشِل — بوابةٌ تتطلّب شبكة بوابةٌ تسقط بانقطاعها لا بعيب في الكود.
        AHEAD="$(git rev-list --count "$UPSTREAM"..HEAD 2>/dev/null || echo 0)"
        BEHIND="$(git rev-list --count HEAD.."$UPSTREAM" 2>/dev/null || echo 0)"

        if [ "$AHEAD" -gt 0 ]; then
            red "  ✗ QG-SYNC(2) — $AHEAD التزام غير مدفوع على '$BRANCH'"
            git log --oneline "$UPSTREAM"..HEAD | head -10 | while read -r line; do
                dim "      $line"
            done
            dim "      الدفع: git push origin $BRANCH"
            FAILED=1
        else
            green "  ✓ QG-SYNC(2) — '$BRANCH' مطابق لـ$UPSTREAM"
        fi

        if [ "$BEHIND" -gt 0 ]; then
            yellow "  —  $BEHIND التزام على $UPSTREAM غير موجود محليًا (بحسب آخر fetch)"
            dim "      git pull --ff-only"
        fi
    fi
fi

# ── 3) تشغيلة بوابات واحدة — الجلسة لا الشجرة ────────────────────────────────
# الفحص (1) يعدّ **الشجرات** بينما الضرر يأتي من **الجلسات**. أربع جلسات في
# الشجرة الواحدة تمرّ من (1) كلها، وقد مزّقت قاعدة الاختبار ثلاث مرات، وأسقطت
# تشغيلةً كاملة بخادمَي Vite يتيمين — لأن الحزمة المعزولة لكل شجرة لا تعزل
# جلستين تتقاسمان شجرة.
#
# ولماذا `mkdir` لا `flock`: `flock` غير موجود على Git Bash. بوابةٌ تُعلن نفسها
# متخطّاة هناك لا تحمي الجهاز الذي يحتاجها أكثر من غيره. و`mkdir` ذرّيّ في
# POSIX وعلى Windows معًا: ينجح لواحد ويفشل لكل من سواه.
#
# والقفل يُنظّف نفسه: يُخزَّن PID صاحبه، فإن كان ميتًا (تشغيلة قُتلت بـCtrl+C)
# يُنتزع القفل ويُعلَن ذلك. قفلٌ لا يُنتزع يحجب المستودع إلى الأبد بعد أول
# مقاطعة، وهو علاج أسوأ من الداء.
LOCK_DIR="$ROOT/.git/quality-run.lock"

# ── ومَن صاحب القفل: التشغيلة لا المرحلة ────────────────────────────────────
# هذا السكربت مرحلةٌ ابنة تنتهي في ثانيتها الأولى. فلو كان صاحب القفل `$$` —
# أي عملية هذا الملف — لانتزعه `trap ... EXIT` بانتهاء المرحلة، وعاش القفل
# ثانيةً واحدة من تشغيلةٍ تمتدّ ساعة. وهذا ما كان يحدث فعلًا: ثلاث تشغيلات
# متزامنة في شجرة واحدة، وكلٌّ منها تُعلن «✓ تشغيلة واحدة».
#
# فالمالك الآن `QUALITY_RUN_PID` الذي يُصدِّره `quality.sh` — عمر القفل عمر
# التشغيلة، والإطلاق هناك مشروطٌ بالملكية. وحين يُشغَّل هذا الملف وحده (بلا
# `quality.sh`) يبقى السلوك القديم: `$$` صاحبًا، والقفل يُطلَق عند الخروج.
LOCK_PID="${QUALITY_RUN_PID:-$$}"

lock_claim() {
    printf '%s\n' "$LOCK_PID" > "$LOCK_DIR/pid"
    printf 'بدأت %s · %s\n' "$(date '+%H:%M:%S')" "${HOSTNAME:-local}" > "$LOCK_DIR/info"

    # الإطلاق لصاحب القفل وحده. تحت `quality.sh` يتولّاه هو عند خروجه.
    if [ -z "${QUALITY_RUN_PID:-}" ]; then
        trap 'rm -rf "$LOCK_DIR"' EXIT
    fi
}

if mkdir "$LOCK_DIR" 2>/dev/null; then
    lock_claim
    green "  ✓ تشغيلة واحدة — لا تشغيلة أخرى في هذه الشجرة"
else
    OWNER_PID="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [ -z "$OWNER_PID" ] || ! kill -0 "$OWNER_PID" 2>/dev/null; then
        yellow "  —  قفل متروك بلا مالك حي (PID ${OWNER_PID:-مفقود}) — يُنتزع"
        rm -rf "$LOCK_DIR"
        mkdir "$LOCK_DIR" 2>/dev/null && lock_claim
        green "  ✓ تشغيلة واحدة — لا تشغيلة أخرى في هذه الشجرة"
    else
        red "  ✗ تشغيلة بوابات أخرى تعمل الآن في هذه الشجرة"
        dim "      $(cat "$LOCK_DIR/info" 2>/dev/null || echo "PID $OWNER_PID")"
        dim "      تشغيلتان متزامنتان تتقاسمان قاعدة الاختبار ومنفذ Vite —"
        dim "      وقد مُزّقت القاعدة بهذا بالضبط. انتظر أو أوقفها."
        dim "      لانتزاع قفل متروك يدويًّا: rm -rf .git/quality-run.lock"
        FAILED=1
    fi
fi

echo "────────────────────────────────────────────────────────────"
exit "$FAILED"
