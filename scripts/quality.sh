#!/usr/bin/env bash
# =============================================================================
# بوابات الجودة — التنفيذ الفعلي (AS-030)
# -----------------------------------------------------------------------------
# هذا السكربت هو **مصدر الحقيقة الوحيد** لتسلسل الفحوص. أهداف Makefile تفوّض
# إليه، وخط CI يستدعيه، والمطوّر يشغّله محليًا — فلا يوجد تسلسلان يتباعدان.
# بوابة تسلك في CI غير ما تسلكه محليًا بوابة لا يثق بها أحد.
#
# سبب إضافي عملي: `make` ليس مُثبَّتًا على كل جهاز تطوير. الاعتماد على make
# وحده يعني بوابات لا تعمل حيث يُكتب الكود.
#
# الترتيب مقصود (AS-030): الأرخص أولًا. لا معنى لتشغيل مجموعة اختبارات كاملة
# على كود يخالف التنسيق.
#
# الإعداد كلّه في `scripts/config/shift.env` — أسماء المجلدات والخدمات والحزم
# والبوابات المُوقفة. ما في هذا الملف قواعد، وما هناك قيم.
#
# الاستخدام:
#   bash scripts/quality.sh              كل الفحوص الساكنة
#   bash scripts/quality.sh --with-tests كل شيء بما فيه الاختبارات
#   bash scripts/quality.sh fmt|stan|arch|secrets   فحص واحد
#   bash scripts/quality.sh sync           المزامنة وشجرات العمل وحدها
#   bash scripts/quality.sh i18n           ترجمة الواجهة وحدها (GATE-I18N — للمشروع ثنائي اللغة)
#
#   بوابة مُوقفة بقرار (SUSPENDED_GATES في shift.env) تُعلَن في كل تشغيلة ولا
#   تحجب. لإعادة المُوقفات كلِّها في تشغيلةٍ واحدة:
#       bash scripts/quality.sh --with-tests --include-suspended
#   أو QG_INCLUDE_SUSPENDED=1 في البيئة. ولتشغيل واحدةٍ منها وحدها يكفي اسمها:
#       bash scripts/quality.sh fe-unit|fe-e2e|fe-a11y|integration|tests|coverage
#   وبوابة يدويّة (MANUAL_ONLY_GATES) لا تعود بأي عَلَم — بأمرها المفرد وحده.
#
#   CI planning — only automatically enabled stages are listed:
#       bash scripts/quality.sh --list-shards      JSON job names (`core` today)
#       bash scripts/quality.sh --shard=<name>     one job's enabled stages
#
# ⚠ لا تُمرِّر مخرَج هذا السكربت عبر أنبوب (`| tail` · `| tee`): رمز الخروج
#   يصير رمز الأمر الأخير، فتُقرأ بوابة حمراء خضراء.
# =============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

CONFIG="$ROOT/scripts/config/shift.env"
if [ ! -f "$CONFIG" ]; then
    printf '\033[31m%s\033[0m\n' "scripts/config/shift.env غير موجود — لا بوابة بلا إعداد مُعلَن"
    exit 2
fi
# shellcheck source=config/shift.env
. "$CONFIG"

# Per-tree stack isolation. The compose CLI reads .env from the project
# directory on its own, but THIS shell does not - and the test-stack name
# below is built from the shell variable. Unfixed, every worktree would run
# its tests as "<base>-test" and two trees would collide on one database: the
# very collision the isolation exists to end. A value set in the shell
# environment still wins over the file.
if [ -z "${COMPOSE_PROJECT_NAME:-}" ] && [ -f .env ]; then
    COMPOSE_PROJECT_NAME="$(grep -E '^COMPOSE_PROJECT_NAME=' .env | tail -n1 | cut -d= -f2 | tr -d '\r')"
fi

DC="docker compose --project-directory . -f $COMPOSE_DIR/$COMPOSE_BASE_FILE -f $COMPOSE_DIR/$COMPOSE_DEV_FILE"
PHP_EXEC="$DC exec -T $PHP_SERVICE sh -lc"
NODE_EXEC="$DC exec -T $NODE_SERVICE sh -lc"

# الفحوص الساكنة تقرأ الكود فقط، فتُنفَّذ داخل حاوية التطوير القائمة — أرخص من
# رفع حزمة ثانية. أما الاختبارات فتكتب: `RefreshDatabase` يُجري migrate:fresh،
# ومن يفعل ذلك في حاوية التطوير يُفرغ قاعدة المطوّر في كل تشغيل. لذلك لها حزمتها
# المعزولة — قاعدة في tmpfs · شبكة داخلية · اسم مشروع مستقل فلا يتشارك حجمًا ولا
# شبكة مع التطوير (COMPOSE_TEST_FILE).
DC_TEST="docker compose --project-directory . -p ${COMPOSE_PROJECT_NAME:-$COMPOSE_PROJECT_BASE}-test -f $COMPOSE_DIR/$COMPOSE_BASE_FILE -f $COMPOSE_DIR/$COMPOSE_TEST_FILE"

FAILED=0
STAGE=""

# ── البوابات المُوقفة بقرار — من الإعداد لا من هذا الملف ──────────────────────
# الافتراضي في الإطار: كل بوابة مفعَّلة. الإيقاف قرارٌ مُعلَنٌ قابلٌ للعكس يُكتب
# في `SUSPENDED_GATES` (تعود بعَلَم) أو `MANUAL_ONLY_GATES` (بأمرها المفرد وحده)،
# ويحمل مرجعه في `SUSPENSION_DECISION`.
#
# ولا شيء يُحذف ولا يُعطَّل بالإيقاف: الدوالُّ في موضعها، والأوامرُ المفردة تعمل،
# والتكوينُ والعتباتُ وخطوطُ الأساس كما هي — فالعودةُ سطرٌ واحد في الإعداد.
# وهذا هو الفرقُ الذي تحرسه المبادئ غير القابلة للتفاوض بين **مُوقفةٍ بقرار**
# و**متخطّاةٍ صمتًا**: الأولى تُعلن نفسَها في كل تشغيلة، والثانية تكذب.
INCLUDE_SUSPENDED="${QG_INCLUDE_SUSPENDED:-0}"
SUSPENDED_COUNT=0

KNOWN_STAGES="sync fmt stan arch scenario routes fe-static i18n fe-unit fe-e2e fe-visual fe-a11y secrets audit openapi integration tests coverage"

_in_list() {
    local x
    for x in $2; do [ "$x" = "$1" ] && return 0; done
    return 1
}

# إعدادٌ لا يُفهم لا يمرّ صامتًا: معرّفُ بوابةٍ مكتوبٌ خطأً في قائمة الإيقاف كان
# سيُوقف لا شيء ويُقرأ إيقافًا. و`sync` لا تُوقَف بحال — هي التي تأخذ قفل
# التشغيلة الواحدة، وبوابةٌ بلا قفل هي ما مزّق قاعدة الاختبار.
for _g in $SUSPENDED_GATES $MANUAL_ONLY_GATES; do
    if ! _in_list "$_g" "$KNOWN_STAGES"; then
        printf '\033[31m%s\033[0m\n' "shift.env: «$_g» ليست مرحلة معروفة — المراحل: $KNOWN_STAGES"
        exit 2
    fi
    if [ "$_g" = "sync" ]; then
        printf '\033[31m%s\033[0m\n' "shift.env: QG-SYNC لا تُوقَف — هي صاحبة قفل التشغيلة الواحدة"
        exit 2
    fi
done

# ── CI shards ─────────────────────────────────────────────────────────────────
# `--list-shards` changes no state and runs no gate. It walks the automatic
# sequence and records `core` for every active gate. Suspended gates are
# omitted unless a human explicitly passes `--include-suspended` locally, so
# CI can never reactivate a suspended gate by implication. `--shard=<name>`
# executes only that job's stages. QG_JOIN keeps a stage in the job of the
# stage whose output it reads.
QG_MODE="run"      # run | list
QG_SHARD=""        # empty = not sharded: every stage runs as it always has
QG_SHARDS=()       # list mode: the jobs, in sequence order
PARALLEL_COUNT=0   # stages this job left to a parallel job
EXECUTED_COUNT=0   # stages this job actually ran
declare -A QG_JOIN=([stage_coverage]=stage_tests)

# ── قفل التشغيلة الواحدة — من يحمله ومتى يُطلَق ──────────────────────────────
# القفل يُؤخذ في `sync-check.sh` (`QG-SYNC`)، لكنه لو أُطلق هناك أيضًا لعاش
# ثانيةً واحدة: السكربت مرحلةٌ ابنة تنتهي في ثانيتها الأولى، و`trap ... EXIT`
# فيه ينتزع القفل بانتهائها — فلا يحرس شيئًا من تشغيلةٍ تمتدّ ساعة. ورُصد ذلك
# بالقياس لا بالقراءة: ثلاث تشغيلات متزامنة في شجرة واحدة، وكلٌّ منها أعلنت
# «✓ تشغيلة واحدة» — حارسٌ مُعلَنٌ عاملًا وهو أعمى عمّا وُجد له.
#
# فصاحب القفل هو **هذه** العملية، وتمتدّ حياته بامتداد التشغيلة. والإطلاق
# مشروطٌ بالملكية — تشغيلةٌ تسقط لأن غيرها يحمل القفل لا تنتزعه وهي تخرج.
export QUALITY_RUN_PID="$$"
release_run_lock() {
    local d="$ROOT/.git/quality-run.lock"
    if [ -f "$d/pid" ] && [ "$(cat "$d/pid" 2>/dev/null)" = "$$" ]; then
        rm -rf "$d"
    fi
}
trap release_run_lock EXIT

# ── لماذا تُحفظ مخرجات البوابات كاملةً ───────────────────────────────────────
# تمييز سقوطٍ بمهلة تحت حمل متزامن من سقوطٍ بتأكيد حقيقي لا يكون إلا بقراءة
# **نصّ** الخطأ. والمراحل التي تُمرِّر مخرجاتها إلى `tail` مباشرةً تُضيّع النصّ
# بانتهائها؛ ولا يبقى على القرص شيء لأن Playwright يمسح `test-results/` بين
# مشروع وآخر. فقاعدةٌ تعتمد على نصٍّ **تمحوه الأداة** قاعدةٌ لا تُطبَّق.
#
# المخرَج كامل في `$GATE_LOGS_DIR/<name>.log` (مُتجاهَل في Git)، و`tail` للعرض
# وحده لا للحفظ.
GATE_LOGS="$GATE_LOGS_DIR"
# المسار نفسه كما تراه حاوية node (FRONTEND_DIR مربوط على NODE_WORKDIR).
GATE_LOGS_IN_NODE="${GATE_LOGS_DIR#"$FRONTEND_DIR"/}"

node_logged() {
    local name="$1" cmd="$2" lines="${3:-16}" rc
    mkdir -p "$GATE_LOGS"
    $NODE_EXEC "$cmd" > "$GATE_LOGS/$name.log" 2>&1
    rc=$?
    tail -n "$lines" "$GATE_LOGS/$name.log"
    [ "$rc" -ne 0 ] && yellow "  المخرَج الكامل: $GATE_LOGS/$name.log"
    return "$rc"
}

php_logged() {
    local name="$1" cmd="$2" lines="${3:-12}" rc
    mkdir -p "$GATE_LOGS"
    $PHP_EXEC "$cmd" > "$GATE_LOGS/$name.log" 2>&1
    rc=$?
    tail -n "$lines" "$GATE_LOGS/$name.log"
    [ "$rc" -ne 0 ] && yellow "  المخرَج الكامل: $GATE_LOGS/$name.log"
    return "$rc"
}

red()    { printf '\033[31m%s\033[0m\n' "$1"; }
green()  { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }
head2()  { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
# سطرٌ ثانويّ خافت — نظيرُ `dim` في sync-check.sh وفي خطّاف pre-commit. غيابُه
# هنا يومًا طبع «dim: command not found» في كل تشغيلة، ولم يُرصد في الاختبار
# لأن صَدَفة الاختبار عرّفت الدالة بنفسها فوفّرت ما كان ناقصًا وأخفت النقص.
dim()    { printf '\033[2m%s\033[0m\n' "$1"; }

require_php_container() {
    if ! $DC ps "$PHP_SERVICE" --status running >/dev/null 2>&1; then
        red "حاوية $PHP_SERVICE متوقفة — شغّل: docker compose ... up -d"
        exit 2
    fi
}

# The frontend gates need the node service for the same reason the PHP gates
# need theirs: the toolchain lives in the image, not on the host. And they need
# something to check - a repository with no frontend yet must say so out loud.
# A gate that silently passes on an absent target is the failure mode where
# four gates were believed to exist and none did.
require_node_container() {
    if [ ! -f "$FRONTEND_DIR/package.json" ]; then
        yellow "  —  N/A مُعلَنة — لا تطبيق في $FRONTEND_DIR/ بعد"
        return 1
    fi
    if ! $DC ps "$NODE_SERVICE" --status running >/dev/null 2>&1; then
        red "حاوية $NODE_SERVICE متوقفة — شغّل: docker compose ... up -d $NODE_SERVICE"
        exit 2
    fi
    return 0
}

# ── بوابة مُوقفة بقرار — تُعلَن ولا تُسكت ───────────────────────────────────
# «`N/A` تُعلَن ولا تُسكت». وحذفُ سطر الاستدعاء كان أبسط، لكنه يُنتج تشغيلةً
# يقرؤها القارئ فيظنّ البوابة عاملةً وهي ليست كذلك. فالسطر يبقى مرئيًّا، ويحمل
# مرجع قراره كي يُعرف مَن أوقفها ومتى ولماذا، ولا يُحتسب في FAILED.
declare_disabled() {
    local label="$1" decision="$2" note="$3"
    head2 "$label"
    yellow "  ⏸  مُوقفة بقرار $decision — لا تحجب ولا تدخل DoD-SL-04"
    dim    "      $note"
    SUSPENDED_COUNT=$((SUSPENDED_COUNT + 1))
}

# بوابةٌ مُوقفةٌ بقرارٍ **قابلٍ للعكس بعَلَم** — تعمل حين يُطلب، وتُعلن حين لا
# يُطلب. تُقرأ كـ`run_stage` تمامًا، والفرقُ وسيطٌ ثانٍ يحمل طريقةَ إعادتها،
# كي لا يضطرّ قارئُ المخرَج إلى فتح هذا الملف ليعرف كيف يُشغّل ما رآه مُوقفًا.
run_or_suspended() {
    local label="$1" decision="$2" note="$3"; shift 3
    local key="${QG_JOIN[$1]:-$1}"
    if [ "$QG_MODE" = "list" ]; then
        # Suspended gates stay suspended in CI too. List only stages that this
        # automatic sequence is actually authorised to run.
        [ "$INCLUDE_SUSPENDED" = "1" ] && _shard_record "$key"
        return 0
    fi
    if [ "$INCLUDE_SUSPENDED" = "1" ]; then
        if _in_shard "$key"; then
            if [ "$1" = "stage_fe_visual" ]; then
                _exec_stage_visual "$label" "$@"
            else
                _exec_stage "$label" "$@"
            fi
        else
            declare_parallel "$label" "$key"
        fi
    else
        declare_disabled "$label" "$decision" "$note"
    fi
}

# An active gate. Every active gate belongs to the one `core` job.
#
# Except QG-SYNC, which runs in EVERY shard. It is not a check of the code: it
# is where the one-run-per-worktree lock is taken (`sync-check.sh`). A shard
# that skipped it would run without the lock, and two runs in one worktree is
# exactly what shredded the test database three times. In CI it costs seconds
# and prints N/A for the unpushed-commit check; locally it keeps the guarantee.
#
# It is NOT counted toward EXECUTED_COUNT, or a mistyped shard name would run
# this one stage, count one, and pass the empty-shard guard it exists to trip.
run_stage() {
    local label="$1"; shift
    if [ "$QG_MODE" = "list" ]; then
        _shard_record core
        return 0
    fi
    if ! _in_shard core; then
        if [ "$1" = "stage_sync" ]; then
            _exec_stage "$label" "$@"
            EXECUTED_COUNT=$((EXECUTED_COUNT - 1))
            return 0
        fi
        declare_parallel "$label" core
        return 0
    fi
    _exec_stage "$label" "$@"
}

_exec_stage() {
    local label="$1"; shift
    head2 "$label"
    EXECUTED_COUNT=$((EXECUTED_COUNT + 1))
    if "$@"; then
        green "  ✓ $label"
    else
        red "  ✗ $label"
        FAILED=$((FAILED + 1))
    fi
}

# ── Shard helpers ─────────────────────────────────────────────────────────────
_in_shard() { [ -z "$QG_SHARD" ] || [ "$QG_SHARD" = "$1" ]; }

_shard_record() {
    local x
    for x in ${QG_SHARDS[@]+"${QG_SHARDS[@]}"}; do
        [ "$x" = "$1" ] && return 0
    done
    QG_SHARDS+=("$1")
}

# A stage this job does not run, because another CI job does. Printed, never
# silent — and not counted as suspended, because it IS running, elsewhere.
declare_parallel() {
    local label="$1" shard="$2"
    head2 "$label"
    dim "  ⇉ تعمل في مهمة CI موازية ($shard) — تحكم بها المهمة الجامعة «بوابات الجودة»"
    PARALLEL_COUNT=$((PARALLEL_COUNT + 1))
}

# `run_stage` لبوابة المطابقة البصرية: PASS لا يُطبع إلا بـPlaywright أخضر
# **و**الحزمة محفوظة (visual.log والصور)؛ وإلا FAIL بسببه — اختلاف لقطة أو فشل
# تأكيد، أو تعذّر حفظ الحزمة — ويُعدّ في FAILED كأي بوابة.
run_stage_visual() {
    local label="$1"; shift
    if [ "$QG_MODE" = "list" ]; then
        _shard_record core
        return 0
    fi
    if ! _in_shard core; then
        declare_parallel "$label" core
        return 0
    fi
    _exec_stage_visual "$label" "$@"
}

# The executor behind run_stage_visual — no list/shard logic, so it can also be
# reached from run_or_suspended when the visual gate is suspended and re-enabled.
_exec_stage_visual() {
    local label="$1"; shift
    head2 "$label"
    EXECUTED_COUNT=$((EXECUTED_COUNT + 1))
    local rc=0
    "$@" || rc=$?
    if [ "$rc" -eq 0 ] && [ "$VISUAL_ARTIFACTS_OK" = "1" ]; then
        green "  ✓ $label — PASS"
        dim   "      الحزمة: $GATE_LOGS/visual.log · $GATE_LOGS/visual-artifacts/"
        return 0
    fi
    red "  ✗ $label — FAIL — VISUAL CHECK FAILED"
    [ "$rc" -ne 0 ] && dim "      السبب: اختلاف لقطة أو فشل تأكيد — التفصيل في $GATE_LOGS/visual.log"
    [ "$VISUAL_ARTIFACTS_OK" != "1" ] && dim "      السبب: تعذّر حفظ الحزمة — ${VISUAL_ARTIFACTS_WHY:-غير مكتملة} (لا PASS بلا حزمة)"
    dim "      الصور expected/actual/diff: $GATE_LOGS/visual-artifacts/ — للمراجعة البشرية؛ المرجع الحاكم الشاشات المعتمدة"
    dim "      خطوط الأساس لا تُحدَّث تلقائيًّا — بمقارنة وتقرير اختلافات وموافقة مالك المنتج"
    FAILED=$((FAILED + 1))
    return 1
}

# ── الموجِّه الواحد لكل بوابة في التسلسل ─────────────────────────────────────
# gate <id> <label> <stage-fn>
# يقرأ حالة البوابة من الإعداد: يدويّة ⟵ تُعلَن ولا تعود بعَلَم · مُوقفة ⟵
# تُعلَن وتعود بـ--include-suspended · وإلا تعمل. الأوامر المفردة لا تمرّ من هنا:
# من كتب اسم البوابة أرادها، مُوقفةً كانت أو لا.
gate() {
    local id="$1" label="$2" fn="$3"
    if _in_list "$id" "$MANUAL_ONLY_GATES"; then
        [ "$QG_MODE" = "list" ] && return 0
        declare_disabled "$label" "$SUSPENSION_DECISION" "يدويًّا فقط: bash scripts/quality.sh $id — لا تعود بـ--include-suspended"
        return 0
    fi
    if _in_list "$id" "$SUSPENDED_GATES"; then
        run_or_suspended "$label" "$SUSPENSION_DECISION" "للتشغيل: bash scripts/quality.sh $id · أو التسلسل كاملًا: --include-suspended" "$fn"
        return 0
    fi
    if [ "$fn" = "stage_fe_visual" ]; then
        run_stage_visual "$label" "$fn"
    else
        run_stage "$label" "$fn"
    fi
}

# ── الفحوص ───────────────────────────────────────────────────────────────────

# ── QG-SYNC — شجرات العمل ولا التزام غير مدفوع ─────────────────────────────
# أولًا في الترتيب عن قصد، ولسببين: هي الأرخص على الإطلاق (Git محلي، بلا حاوية
# ولا شبكة) فيقتضيها `AS-030`؛ وهي تفحص **حالة المستودع** لا الكود — فسقوطها
# يعني أن التشغيلة ستقيس شيئًا غير الذي تظنّه، وأرخص أن تعرف ذلك في الثانية
# الأولى لا بعد ستين دقيقة.
stage_sync() {
    bash scripts/sync-check.sh
}

stage_fmt() {
    require_php_container
    $PHP_EXEC "cd $PHP_WORKDIR && ./vendor/bin/pint --test" 2>&1 | tail -6
    return "${PIPESTATUS[0]}"
}

# المستوى يحكمه phpstan.neon لا هذا السطر — PHPSTAN_LEVEL في الإعداد للعرض،
# وتمريره هنا كان سيسمح لقيمةٍ في ملف إعداد أن تُخفِّض التحليل بصمت.
stage_stan() {
    require_php_container
    $PHP_EXEC "cd $PHP_WORKDIR && ./vendor/bin/phpstan analyse --no-progress --memory-limit=$PHPSTAN_MEMORY_LIMIT" 2>&1 | tail -12
    return "${PIPESTATUS[0]}"
}

# AS-031 — البوابة المحورية. جزآن لا يُغني أحدهما عن الآخر:
#   Deptrac        رسم الاعتماديات بين الأصناف (RS-020 · RS-023 · RS-025)
#   arch-check.sh  قواعد الملفات والمحتوى (RS-014/016/021/022 · CS-010/021/027)
stage_arch() {
    require_php_container
    local rc=0
    $PHP_EXEC "cd $PHP_WORKDIR && ./vendor/bin/deptrac analyse --config-file=$DEPTRAC_CONFIG --no-progress" 2>&1 | tail -12
    rc="${PIPESTATUS[0]}"
    bash scripts/arch-check.sh || rc=1
    return "$rc"
}

# AS-035 — تغطية السيناريوهات. تعمل على المضيف لأنها تقرأ `docs/` و`tests/`
# معًا، و`docs/` غير مربوط في أي حاوية.
#
# موضعها هنا — لا مع الاختبارات — مقصود: هي لا تحتاج تشغيلًا، تحتاج ملفات. ووضعها
# في الكتلة الدائمة يجعلها تحرس الاتجاه الآخر أيضًا: التزامٌ توثيقي يحذف سيناريو
# يشير إليه اختبار قائم يُفشِل البناء، ولو لم يُشغَّل اختبار واحد.
stage_scenario() {
    bash scripts/scenario-check.sh
}

stage_secrets() {
    bash scripts/secret-scan.sh --all
}

# GATE-FE-05 + GATE-FE-06 — every React route is backed by an approved registry
# row: admin and client.
#
# على المضيف كنظيرَيها `arch-check` و`scenario-check`: تقرأ `docs/` و`frontend/`
# معًا، و`docs/` غير مربوط في أي حاوية.
#
# تُطبع `N/A` مُعلَنة ما دام `frontend/src` بلا ملف مسارات — لا تمرّ صامتة.
stage_routes() {
    bash scripts/route-check.sh
}

# ── GATE-FE-01 — static analysis ─────────────────────────────────────────────
# Two tools, because they answer different questions: `tsc --noEmit` proves the
# types hold, ESLint proves the rules the types cannot express. `--max-warnings=0`
# is AS-002 applied to the linter - a warning is a failure, not a note.
# `package.json` must define the `typecheck` script.
stage_fe_static() {
    require_node_container || return 0
    local rc=0
    $NODE_EXEC "cd $NODE_WORKDIR && npm run typecheck" 2>&1 | tail -12
    rc="${PIPESTATUS[0]}"
    $NODE_EXEC "cd $NODE_WORKDIR && npx eslint . --max-warnings=0" 2>&1 | tail -12 || rc=1
    return "$rc"
}

# ── GATE-I18N — the client app's translations (bilingual projects) ───────────
# Three checks in one Node script (scripts/i18n/i18n-check.cjs), inside the
# node container like GATE-FE-01 because the TypeScript compiler lives there:
#   (a) key parity — <locales>/<primary>/*.json and <locales>/<secondary>/*.json
#       hold the same keys, every message parses as ICU, each key uses the
#       same {placeholders} in both languages, and no primary-language message
#       formats a number or a date through ICU;
#   (b) literal ratchet — no client-reachable file may hold MORE primary-
#       language string literals / JSX text than scripts/i18n/literals.baseline.json
#       allows, and a file absent from it may hold none. Slices that move texts
#       into the catalogue lower the counts (bash scripts/i18n/refresh-baseline.sh);
#   (c) one sentence = one key — a sentence may not be assembled from several
#       t() calls around a link, an emphasis or a value (no baseline: zero).
#
# The script, its config and its baseline travel on stdin — prepended as two
# assignments — because only the frontend is mounted in the container. Nothing
# is copied into it, and the gate reads exactly the files in the working tree.
#
# Applicability (I18N_GATE in shift.env): `auto` runs the gate when the locales
# directory exists and declares it N/A — out loud, never silently — when it
# does not; `on` makes a missing directory red; `off` keeps it out of the
# sequence (still runnable by name). A missing baseline is red, never a pass.
stage_i18n() {
    local locales="$FRONTEND_SRC/$I18N_LOCALES_SUBDIR"
    if [ "$I18N_GATE" = "off" ]; then
        yellow "  N/A — GATE-I18N خارج التسلسل بالإعداد (I18N_GATE=off)"
        return 0
    fi
    if [ ! -d "$locales" ]; then
        if [ "$I18N_GATE" = "on" ]; then
            red "  مجلد الترجمة غائب: $locales — والبوابة مطلوبة (I18N_GATE=on)"
            return 1
        fi
        yellow "  N/A — لا مجلد ترجمة ($locales): مشروع بلغة واحدة. للفرض: I18N_GATE=on"
        return 0
    fi
    require_node_container || return 0
    local baseline="$I18N_BASELINE_FILE"
    if [ ! -f "$baseline" ]; then
        red "  الأساس غائب: $baseline — أنشئه: bash scripts/i18n/refresh-baseline.sh"
        return 1
    fi
    mkdir -p "$GATE_LOGS"
    local rc=0
    {
        printf 'globalThis.SHIFT_I18N = %s;\n' "$(_i18n_config_json)"
        printf 'globalThis.SHIFT_I18N_BASELINE = '; cat "$baseline"; printf ';\n'
        cat scripts/i18n/i18n-check.cjs
    } | $NODE_EXEC "cd $NODE_WORKDIR && node -" > "$GATE_LOGS/i18n.log" 2>&1 || rc=$?
    tail -n 24 "$GATE_LOGS/i18n.log"
    [ "$rc" -ne 0 ] && yellow "  المخرَج الكامل: $GATE_LOGS/i18n.log"
    return "$rc"
}

# The gate's configuration as one JSON object (values from shift.env). Paths
# are relative to the frontend root as mounted in the container.
_i18n_config_json() {
    local src="${FRONTEND_SRC#"$FRONTEND_DIR"/}"
    printf '{"src":"%s","locales":"%s","primary":"%s","secondary":"%s","entries":"%s","excludeRegex":"%s","translateFn":"%s"}' \
        "$src" "$src/$I18N_LOCALES_SUBDIR" "$I18N_PRIMARY_LOCALE" "$I18N_SECONDARY_LOCALE" \
        "$I18N_CLIENT_ENTRIES" "$(printf '%s' "$I18N_EXCLUDE_REGEX" | sed 's/\\/\\\\/g; s/"/\\"/g')" "$I18N_TRANSLATE_FN"
}

# ── GATE-FE-02 — component tests ─────────────────────────────────────────────
# Vitest is Vite's own runner, so there is no second build configuration to
# drift from the first. `package.json` must define the `test` script.
stage_fe_unit() {
    require_node_container || return 0
    $NODE_EXEC "cd $NODE_WORKDIR && npm test" 2>&1 | tail -14
    return "${PIPESTATUS[0]}"
}

# ── GATE-FE-03 — full flows ───────────────────────────────────────────────────
# Chromium only, and the distribution's rather than Playwright's when the image
# is Alpine: the bundled one is glibc-built and will not start there.
# playwright.config.ts names the binary explicitly. Project name: `e2e`.
stage_fe_e2e() {
    require_node_container || return 0
    node_logged e2e "cd $NODE_WORKDIR && npx playwright test --project=e2e"
}

# ── GATE-FE-04 — visual parity ───────────────────────────────────────────────
# Per-pixel threshold 0 and a tiny maxDiffPixelRatio, and baselines are
# generated inside this container - never on the host. Font rendering differs
# between Windows and Linux, so a host-made baseline can never match CI.
#
# `--update-snapshots` is deliberately absent: a gate that regenerates its own
# reference on failure approves every change it was built to catch.
#
# Playwright project name: `visual`. The gate is the only automatic enforcement
# of visual equivalence; if it is ever suspended, that rule becomes an approved
# rule that nothing checks — record that price with the decision.
VISUAL_ARTIFACTS_OK=0
VISUAL_ARTIFACTS_WHY=""
stage_fe_visual() {
    require_node_container || return 0

    # A failure here is nearly always explained by its FIRST lines - "A snapshot
    # doesn't exist", or the pixel ratio - and a short tail cuts exactly those,
    # leaving only "Expected:/Received:" paths. That truncation once sent a whole
    # cycle hunting a rendering difference when the real cause was a baseline
    # that had never been committed (git commit -- <pathspec> adds no untracked
    # file). A gate that hides why it fell costs more than the run it saves.
    # The whole output is kept on disk (see node_logged); the number here
    # governs what is DISPLAYED, and nothing is lost either way.
    local rc
    node_logged visual "cd $NODE_WORKDIR && npx playwright test --project=visual" 60
    rc=$?
    # الصور expected/actual/diff تكتبها Playwright في test-results/ ثم تمسحها أي
    # تشغيلة تالية. تُنسخ فورًا إلى gate-logs/visual-artifacts (مُتجاهَل في Git)
    # لتبقى للمراجعة محليًّا. وحفظُ الحزمة جزء من الحكم: إن تعذّر النسخ أو غاب
    # visual.log أو غابت الوجهة، يُسجَّل السبب ولا يُعلَن PASS (run_stage_visual).
    VISUAL_ARTIFACTS_OK=0; VISUAL_ARTIFACTS_WHY=""
    if ! $NODE_EXEC "cd $NODE_WORKDIR && rm -rf $GATE_LOGS_IN_NODE/visual-artifacts && mkdir -p $GATE_LOGS_IN_NODE/visual-artifacts && if [ -d test-results ]; then cp -R test-results/. $GATE_LOGS_IN_NODE/visual-artifacts/; fi" >/dev/null 2>&1; then
        VISUAL_ARTIFACTS_WHY="تعذّر نسخ test-results إلى $GATE_LOGS_IN_NODE/visual-artifacts داخل حاوية $NODE_SERVICE"
    elif [ ! -s "$GATE_LOGS/visual.log" ]; then
        VISUAL_ARTIFACTS_WHY="$GATE_LOGS/visual.log غائب أو فارغ"
    elif [ ! -d "$GATE_LOGS/visual-artifacts" ]; then
        VISUAL_ARTIFACTS_WHY="$GATE_LOGS/visual-artifacts غير موجود على المضيف"
    else
        VISUAL_ARTIFACTS_OK=1
    fi
    return "$rc"
}

# ── QG-A11Y — accessibility ───────────────────────────────────────────────────
# axe-core via Playwright on rendered screens (project `a11y`): the design
# system's accessibility section and RTL are commitments the static gates
# cannot see. Declares N/A while no a11y spec exists - absence is said out
# loud, exactly as stage_routes does for a missing router, never passed silently.
stage_fe_a11y() {
    require_node_container || return 0
    if ! ls "$FRONTEND_TESTS_DIR"/a11y/*.spec.ts >/dev/null 2>&1; then
        yellow "  —  N/A مُعلَنة — لا اختبار إتاحة في $FRONTEND_TESTS_DIR/a11y بعد"
        return 0
    fi
    node_logged a11y "cd $NODE_WORKDIR && npx playwright test --project=a11y"
}

# QG-INTEG — الواجهة والخلفية تُجيب إحداهما الأخرى، بلا وسيط.
#
# ── لماذا بوابة إضافية للواجهة ──────────────────────────────────────────────
# بوابات الواجهة الأخرى تقيس الواجهة وحدها: مشروع `e2e` يُقلع Vite فقط ويعترض
# الشبكة. فما من نداءٍ واحد يبلغ الخلفية في الطابور كلّه، ومجموعةٌ تُجيب
# اعتماديتها بنفسها لا ترى صنف «الخلفية تردّ بخطأ نظام والبوابات كلها خضراء».
#
# ── وتُثبَت بخرق متعمَّد قبل الاعتماد عليها ──────────────────────────────────
# `INTEGRATION_API_BASE_URL=http://127.0.0.1:9` يجب أن يُسقط المجموعة كلها.
# فالمجموعة تقيس الخلفية لا نفسها — والإثبات يسبق الاعتماد ولا يتبعه.
#
# ── وهي ليست محكمة الانعزال، ويُقال صراحةً ─────────────────────────────────
# تعمل على حزمة التطوير وقاعدتها، فتترك أثرًا لكل تشغيل وتمسح مخزن الكاش قبله.
# هذا ثمنُ قياس الشيء الحقيقي، وهو مقبول ما دامت البيئة محلية. ولا يُبنى عليه
# ادّعاء نظافة: من أراد تشغيلًا نظيفًا فليُعِد بناء القاعدة قبله.
stage_integration() {
    require_node_container || return 0
    if ! ls "$FRONTEND_TESTS_DIR"/integration/*.spec.ts >/dev/null 2>&1; then
        yellow "  —  N/A مُعلَنة — لا اختبار تكامل في $FRONTEND_TESTS_DIR/integration بعد"
        return 0
    fi
    # ── تصفير عدّاد المحاولات قبل التشغيل، وهو شرط تكرارٍ لا تليينُ حارس ──
    # حارس المعدّل على مسارات المصادقة يعمل صوابًا: التشغيل الثاني للمجموعة
    # يُجاب بـ429. وبوابةٌ تسقط في إعادتها بوابةٌ لا تُشغَّل. فالعدّاد يُصفَّر
    # **بين** التشغيلات ويبقى مُنفَّذًا **داخل** كل تشغيل.
    #
    # والأداة فظّة بقدر ما يلزم: `cache:clear` يمسح المخزن كلّه بما فيه القراءات
    # المرجعية — وهي تُبنى ثانيةً عند أول قراءة، فالأثر زمنٌ لا صحّة.
    $DC exec -T "$PHP_SERVICE" sh -lc "cd $PHP_WORKDIR && php artisan cache:clear" >/dev/null 2>&1 || true

    # حسابات الفحص التي تحتاجها مجموعة التكامل تُبذر هنا حصرًا، بالاسم، ولا
    # تدخل البذّار المركزي: قرارُ «لا مستخدمَ مبذورًا» قائمٌ للمنتَج، وهذه عُدّةُ
    # بوابةٍ من صنف تصفير العدّاد أعلاه. والاستدعاءُ متكرِّرُ التشغيل بأمان.
    # NOTE the escaping: the seeder class carries SINGLE backslashes and sits
    # inside single quotes for the container shell, so artisan receives them as
    # written. Doubled ones make Composer include the same file under two
    # class-name keys — a fatal "Cannot redeclare class", observed, not a
    # hypothesis.
    if [ -n "$INTEGRATION_SEEDER" ]; then
        $DC exec -T "$PHP_SERVICE" sh -lc "cd $PHP_WORKDIR && php artisan db:seed --class='$INTEGRATION_SEEDER'" >/dev/null 2>&1 \
            || { red "  ✗ بذر حسابات الفحص فشل ($INTEGRATION_SEEDER) — السيناريوهات التي تحتاج دخولًا ستسقط"; return 1; }
    fi

    node_logged integration "cd $NODE_WORKDIR && npx playwright test --project=integration"
}

# API-030 / DoD-SL-09 — عقد OpenAPI مُولَّد من الكود ومتزامن معه.
#
# ── لماذا بوابة لا خطوة توليد ───────────────────────────────────────────────
# «الملف اليدوي ينحرف عن التنفيذ بصمت فيصير توثيقًا يكذب، وهو أسوأ من غيابه».
# وملفٌ مُولَّد مرة ثم مُلتزَم يعود إلى الحالة نفسها عند أول تغيير في متحكم:
# منشورٌ يصف نقطةً لم تعد كذلك. فالتوليد وحده لا يكفي — **المقارنة** هي البوابة.
#
# ولذلك يُولَّد إلى مسار مؤقت ويُقارَن بالملتزَم: اختلافٌ = الملف بائت ⟵ فشل،
# لا تحديث صامت. من غيّر العقد يُعيد التوليد ويلتزم الناتج في تغييره نفسه.
#
# والتحذيرات تُعامَل فشلًا (`AS-002`): تحذير المولِّد يعني شكلًا لم يستطع
# اشتقاقه — أي حقلًا في العقد المنشور بلا سند في الكود.
stage_openapi() {
    require_php_container

    local committed="$BACKEND_DIR/$OPENAPI_FILE"
    local generated="$OPENAPI_GENERATED_PATH"

    if [ ! -f "$committed" ]; then
        red "  $committed غير موجود — وهو المرجع الذي تُقارَن به إعادة التوليد"
        return 1
    fi

    # -- Pending migrations: the real cause behind most of this gate's reds --
    # The generator reads the DEVELOPMENT SCHEMA to infer model field types, so
    # any slice that adds a table reddens this stage until its migration has
    # run. The resulting warning is rendered below as "a published field with
    # no support in code" - the wrong diagnosis of a cause that has nothing to
    # do with code. A gate that lies about why it fell costs a full round on
    # every repair cycle.
    #
    # The migration is deliberately not run from here: a check reads and does
    # not write - exactly as the coverage stage does - and running a migration
    # against an environment holding data is a human decision gate (HG-I-03)
    # that no check script may cross silently, behind its owner's back.
    #
    # The remediation line below builds its command from $DC, never from a
    # literal container name: an agent in an isolated worktree who followed a
    # literal name would migrate someone else's development database while its
    # own stayed empty — and a fresh tree hits this message on its very first
    # run, because an isolated stack starts with an EMPTY dev database.
    pending="$($PHP_EXEC "cd $PHP_WORKDIR && php artisan migrate:status --pending" 2>&1)"
    if ! printf '%s' "$pending" | grep -qi 'No pending migrations'; then
        printf '%s\n' "$pending" | tail -12
        red "  هجرات معلّقة — مخطط قاعدة التطوير متأخر عن الكود"
        red "  المولِّد سيشتقّ الأنواع من مخطط ناقص ويُنتج تحذيرًا مُضلِّلًا"
        yellow "  طبّقها أولًا ثم أعِد التشغيل:"
        yellow "    $DC exec $PHP_SERVICE php artisan migrate --seed"
        return 1
    fi

    local out
    out="$($PHP_EXEC "cd $PHP_WORKDIR && php artisan scramble:export --path=$generated -v" 2>&1)"

    if [ $? -ne 0 ]; then
        printf '%s\n' "$out"
        red "  فشل توليد عقد OpenAPI"
        return 1
    fi

    if printf '%s' "$out" | grep -qi 'warning'; then
        printf '%s\n' "$out"
        red "  توليد OpenAPI أنتج تحذيرات — تُعامَل فشلًا (AS-002)"
        red "  التحذير يعني شكلًا لم يُشتقّ من الكود، أي حقلًا منشورًا بلا سند"
        if printf '%s' "$out" | grep -qE 'VR00[12]'; then
            yellow "  نمط VR001/VR002 غالبًا قاعدة بيانات مُهجَّرة ولم تُبذر: المولِّد يستدعي"
            yellow "  rules() أثناء التوليد، وبعض FormRequest تقرأ حدودها من جداول الإعداد"
            yellow "  وقت التشغيل (CS-004) فيرمي الاستدعاء إن كانت فارغة."
            yellow "  إن كانت هذه أول تهيئة على هذا الجهاز، ابذر القاعدة أولًا:"
            yellow "    $DC exec $PHP_SERVICE php artisan db:seed --force"
        fi
        return 1
    fi

    if ! diff -q "$committed" "$BACKEND_DIR/$generated" >/dev/null 2>&1; then
        red "  عقد OpenAPI الملتزَم لا يطابق المُولَّد من الكود (API-030 · DoD-SL-09)"
        diff "$committed" "$BACKEND_DIR/$generated" | head -30
        yellow "  أعِد التوليد والتزم الناتج:"
        yellow "    $DC exec $PHP_SERVICE php artisan scramble:export --path=$OPENAPI_FILE"
        rm -f "$BACKEND_DIR/$generated"
        return 1
    fi

    rm -f "$BACKEND_DIR/$generated"
    green "  عقد OpenAPI متزامن مع الكود"
    return 0
}

# AS-036 — تدقيق الاعتماديات. ثغرة Critical أو High تُفشِل البناء.
#
# هذه الخطوة تعيش هنا لا في ملف CI وحده: خطوةٌ في CI خارج هذا الملف تعني أن
# المطوّر يُشغّل `quality.sh` فيراها خضراء بينما فحصٌ إلزامي لم يُشغَّل عنده
# أصلًا، ولا يكتشفه إلا بعد الدفع — وهو عطب «تسلسلان يتباعدان» في موضع آخر.
stage_audit() {
    require_php_container
    # `--locked` ليس تفصيلًا: بدونه يدقّق composer شجرة `vendor` **المثبَّتة**
    # لا ما يُعلنه `composer.lock`. و`vendor` هنا حجم Docker دائم — أي أنه قد
    # يتقادم عن القفل ويبقى نظيفًا بينما القفل يُعلن حزمة مثغورة، فتمرّ البوابة
    # خضراء على اعتمادية ستُثبَّت مثغورةً في أول بيئة نظيفة. مُثبَت بالقياس:
    # إصدار مثغور في القفل مرّ بلا ملاحظة، وكشفه `--locked` فورًا.
    local rc=0
    php_logged audit "cd $PHP_WORKDIR && composer audit --locked --abandoned=ignore" || rc=1

    # The other half `AS-036` names: `npm audit` on the frontend lock. The node
    # image installs with `npm ci --no-audit`, so a High in the frontend lock
    # could land on `main` with every gate green unless it is audited here.
    #
    # `--package-lock-only` is `--locked`'s twin: it audits what the committed
    # lock DECLARES, not the `node_modules` volume that may have drifted from it.
    # `--audit-level` is AS-036's threshold.
    #
    # Both halves always run, so one red does not hide the other; the stage is
    # red if either is. And `npm audit` asks the registry: with no network it
    # fails, and a failure here is red — an audit that could not run is not a
    # clean audit.
    if require_node_container; then
        node_logged audit-npm "cd $NODE_WORKDIR && npm audit --package-lock-only --audit-level=$NPM_AUDIT_LEVEL" || rc=1
    fi

    return "$rc"
}

# الاختبارات تعمل في الحزمة المعزولة حصرًا. مرحلةٌ تنفّذ `php artisan test` داخل
# حاوية التطوير تعمل على قاعدة المطوّر لا قاعدة الاختبار — أُثبت بالقياس: بعد
# تشغيل كامل كانت قاعدة الاختبار بصفر جدول وقاعدة المطوّر مُفرَغة — أي أن كل
# تشغيل اختبارات كان يُجري `migrate:fresh` على قاعدة المطوّر ويمحو بياناتها.
#
# الأسطر الواقية في `phpunit.xml` لا تحمي: عنصر `<env>` لا يتجاوز متغيّر بيئة
# **موجودًا مسبقًا**، وCompose يصدّر DB_DATABASE وCACHE_STORE وSESSION_DRIVER
# وQUEUE_CONNECTION إلى الحاوية قبل أن يبدأ PHPUnit. فالحماية معلنة ومعطَّلة.
#
# والعلاج ليس `force="true"` — ذلك يُصلح العَرَض (اسم القاعدة) ويُبقي الاختبارات
# تعمل داخل حزمة التطوير: بنفس Redis، وبنفس الشبكة المنفذة إلى الخارج، وبقاعدة
# على قرص دائم. العلاج هو الحزمة التي صُمِّمت لهذا أصلًا.
stage_tests() {
    local rc=0

    # خطوة التحضير: هي وحدها التي لها منفذ إلى الشبكة. حزمة الاختبار داخلية،
    # فلا يمكن تثبيت الاعتماديات من داخلها — التفصيل في ملف Compose الاختباري.
    #
    # `--build` ليس احتياطًا: `docker compose run` يستعمل الصورة الموجودة كما
    # هي ولا يلاحظ أن Dockerfile أو نقطة الدخول تغيّرا، فيعمل بصورة قديمة
    # **صامتًا**. وهذا يُنتج أسوأ صنف من الاختلاف — محليًا يمرّ بصورة بائتة،
    # وCI يبني من الصفر فيكشف ما لم يُرَ.
    if ! $DC_TEST run --rm --build "$TEST_DEPS_SERVICE" 2>&1 | tail -4; then
        red "  تعذّر تحضير اعتماديات الاختبار"
        $DC_TEST down >/dev/null 2>&1 || true
        return 1
    fi

    # عند النجاح يكفي الذيل. وعند الفشل **لا يُبتر**: البتر إلى 12 سطرًا يُخفي
    # رسالة الاستثناء نفسها ويُبقي أثر المكدس فقط، فيصير السجل يقول «سقط
    # اختبار» دون أن يقول لماذا. بوابة تُخفي سبب سقوطها تُطيل كل دورة إصلاح.
    # AS-034 — التغطية تُنتَج من **نفس** التشغيل لا من ثانٍ. تشغيل المجموعة مرتين
    # (مرة للنتيجة ومرة للتغطية) يضاعف الزمن ويفتح احتمال أن يختلف التشغيلان،
    # فتصير التغطية وصفًا لمجموعة غير التي مرّت. `XDEBUG_MODE=coverage` يُمرَّر
    # للتشغيل وحده — الوضع الافتراضي `develop` يبقى كما هو للتطوير اليومي.
    #
    # الملف يُكتب إلى storage/app/ لأن مجلد الخلفية مربوط في حزمة الاختبار،
    # فيبقى بعد زوال الحاوية ليقرأه stage_coverage.
    local out
    out="$($DC_TEST run --rm --build -e XDEBUG_MODE=coverage "$TEST_SERVICE" sh -lc \
        "cd $PHP_WORKDIR && php artisan test --coverage-clover $COVERAGE_REPORT_PATH" 2>&1)"
    rc=$?

    # AS-002 — لا فحص استشاري. مجموعة تمرّ «بتحذيرات» ليست مجموعة خضراء، ولا
    # إعداد في PHPUnit يمنع ذلك هنا: `failOnWarning` لا يغيّر شيئًا لأن PHPUnit
    # نفسه يرى المجموعة `OK` — التحذيرات تُظهرها طبقة Collision التي يمرّ بها
    # `artisan test`. فالسدّ هنا لا هناك.
    #
    # `skipped` و`incomplete` غير مشمولين: لهما استعمال مشروع ومقصود، بخلاف
    # تحذير أو اختبار مشبوه.
    if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qiE 'Tests:.*(warning|risky)'; then
        rc=1
        printf '%s\n' "$out"
        red "  المجموعة مرّت بتحذيرات — تُعامَل فشلًا (AS-002)"
        $DC_TEST down >/dev/null 2>&1 || true
        return "$rc"
    fi

    if [ "$rc" -eq 0 ]; then
        printf '%s\n' "$out" | tail -8
    else
        printf '%s\n' "$out"
    fi

    # `down` بلا `-v` عن قصد: البيانات في tmpfs وتزول مع الحاوية أصلًا، والحجم
    # الوحيد الباقي هو ذاكرة الاعتماديات. حذفه يعني إعادة تثبيت كامل في كل
    # تشغيل — كلفةٌ بلا عزل إضافي.
    $DC_TEST down >/dev/null 2>&1 || true
    return "$rc"
}

# AS-034 — عتبات التغطية. مرحلة مستقلة عن الاختبارات في `AS-030`، لكنها تقرأ
# ناتج تشغيلها لا تُعيده — انظر التعليق في stage_tests.
#
# تُنفَّذ في حاوية التطوير لأنها **قراءة فقط**: تفتح ملف XML وتحسب. ولا يجوز أن
# تحتاج حزمة الاختبار مرة ثانية لمجرد تحليل ملف موجود على القرص. العتبات تُمرَّر
# من الإعداد عبر البيئة لأن `scripts/` غير مربوط داخل الحاوية.
stage_coverage() {
    require_php_container
    local report="$BACKEND_DIR/$COVERAGE_REPORT_PATH"

    if [ ! -f "$report" ]; then
        red "  تقرير التغطية غير موجود — شغّل الاختبارات أولًا (--with-tests)"
        return 1
    fi

    $PHP_EXEC "COVERAGE_GENERAL_MIN='$COVERAGE_GENERAL_MIN' COVERAGE_SERVICES_MIN='$COVERAGE_SERVICES_MIN' COVERAGE_FINANCIAL_MIN='$COVERAGE_FINANCIAL_MIN' COVERAGE_FINANCIAL_MODULES='$COVERAGE_FINANCIAL_MODULES' COVERAGE_FRONTEND_MIN='$COVERAGE_FRONTEND_MIN' php -- $PHP_WORKDIR/$COVERAGE_REPORT_PATH" < scripts/coverage-check.php
    return "${PIPESTATUS[0]}"
}

# ── التوجيه ──────────────────────────────────────────────────────────────────

# عَلَمُ إعادةِ المُوقفات يُنتزع من الوسائط قبل التوجيه، فيصحّ في أي موضع:
# `--with-tests --include-suspended` و`--include-suspended --with-tests` سواء.
# ولو تُرك في `$@` لسقط على الفرع `*)` وطبع «استخدام:» — عَلَمٌ يُبطل الأمرَ
# الذي أُضيف إليه.
_args=()
for _a in "$@"; do
    case "$_a" in
        --include-suspended|--all-gates) INCLUDE_SUSPENDED=1 ;;
        --list-shards) QG_MODE="list" ;;
        --shard=*) QG_SHARD="${_a#--shard=}" ;;
        *) _args+=("$_a") ;;
    esac
done
set -- ${_args[@]+"${_args[@]}"}

# CI planning works on `--with-tests` but deliberately leaves INCLUDE_SUSPENDED
# off. This is an explicit suspension, not a silent drop: the core job prints
# every disabled gate in its summary.
if [ "$QG_MODE" = "list" ] || [ -n "$QG_SHARD" ]; then
    if [ "$QG_MODE" = "list" ] && [ -n "$QG_SHARD" ]; then
        echo "استخدام: --list-shards و--shard=<name> لا يجتمعان" >&2
        exit 2
    fi
    # CI sharding must not silently reactivate a suspended gate. Manual
    # --include-suspended remains available only when explicitly passed.
    set -- --with-tests
fi

# List mode prints JSON and nothing else: CI reads stdout as a job matrix, so
# the banner and the summary go to /dev/null and the list goes to fd 3.
if [ "$QG_MODE" = "list" ]; then
    exec 3>&1 1>/dev/null
fi

case "${1:-all}" in
    sync)    run_stage "المزامنة وشجرات العمل (QG-SYNC)" stage_sync ;;
    fmt)     run_stage "التنسيق (Pint)" stage_fmt ;;
    stan)    run_stage "التحليل الساكن (PHPStan $PHPSTAN_LEVEL)" stage_stan ;;
    arch)    run_stage "الحدود المعمارية (AS-031)" stage_arch ;;
    scenario) run_stage "تغطية السيناريوهات (AS-035)" stage_scenario ;;
    routes)  run_stage "مسارات الواجهة (GATE-FE-05/06)" stage_routes ;;
    fe-static) run_stage "الفحص الساكن للواجهة (GATE-FE-01)" stage_fe_static ;;
    i18n)      run_stage "ترجمة الواجهة (GATE-I18N)" stage_i18n ;;
    fe-unit)   run_stage "اختبار المكوّنات (GATE-FE-02)" stage_fe_unit ;;
    fe-e2e)    run_stage "تدفقات الواجهة (GATE-FE-03)" stage_fe_e2e ;;
    fe-visual) run_stage_visual "المطابقة البصرية (GATE-FE-04)" stage_fe_visual ;;
    fe-a11y)   run_stage "فحص الإتاحة (QG-A11Y)" stage_fe_a11y ;;
    secrets) run_stage "كاشف الأسرار" stage_secrets ;;
    audit)   run_stage "تدقيق الاعتماديات (AS-036)" stage_audit ;;
    openapi) run_stage "عقد OpenAPI (API-030)" stage_openapi ;;
    integration) run_stage "التكامل مع الخلفية الحقيقية (QG-INTEG)" stage_integration ;;
    tests)   run_stage "الاختبارات (PHPUnit)" stage_tests ;;
    coverage) run_stage "عتبات التغطية (AS-034)" stage_coverage ;;

    all|--with-tests)
        echo "════════════════════════════════════════════════════════════"
        echo "  بوابات الجودة — $PROJECT_NAME"
        echo "════════════════════════════════════════════════════════════"

        gate sync      "المزامنة وشجرات العمل (QG-SYNC)"       stage_sync
        gate fmt       "التنسيق (Pint)"                        stage_fmt
        gate stan      "التحليل الساكن (PHPStan $PHPSTAN_LEVEL)" stage_stan
        gate arch      "الحدود المعمارية (AS-031)"             stage_arch
        gate scenario  "تغطية السيناريوهات (AS-035)"           stage_scenario
        gate routes    "مسارات الواجهة (GATE-FE-05/06)"        stage_routes
        gate fe-static "الفحص الساكن للواجهة (GATE-FE-01)"     stage_fe_static
        gate i18n      "ترجمة الواجهة (GATE-I18N)"             stage_i18n
        gate fe-unit   "اختبار المكوّنات (GATE-FE-02)"         stage_fe_unit
        gate secrets   "كاشف الأسرار"                          stage_secrets
        gate audit     "تدقيق الاعتماديات (AS-036)"            stage_audit
        gate openapi   "عقد OpenAPI (API-030)"                 stage_openapi

        if [ "${1:-all}" = "--with-tests" ]; then
            gate fe-e2e      "تدفقات الواجهة (GATE-FE-03)"              stage_fe_e2e
            gate fe-visual   "المطابقة البصرية (GATE-FE-04)"             stage_fe_visual
            gate fe-a11y     "فحص الإتاحة (QG-A11Y)"                     stage_fe_a11y
            gate integration "التكامل مع الخلفية الحقيقية (QG-INTEG)"    stage_integration
            gate tests       "الاختبارات (PHPUnit)"                      stage_tests
            gate coverage    "عتبات التغطية (AS-034)"                    stage_coverage
        fi

        if [ "$QG_MODE" = "list" ]; then
            _json="["
            for _s in ${QG_SHARDS[@]+"${QG_SHARDS[@]}"}; do
                _json="$_json\"$_s\","
            done
            printf '%s]\n' "${_json%,}" >&3
            exit 0
        fi

        echo
        echo "════════════════════════════════════════════════════════════"
        # A shard that matched nothing ran nothing, and «nothing failed» would
        # read as green. A mistyped job name, or a job whose stage was renamed,
        # must fail loudly instead — the gate-that-passes-on-an-absent-target.
        if [ -n "$QG_SHARD" ] && [ "$EXECUTED_COUNT" -eq 0 ]; then
            red "  المهمة «$QG_SHARD» لا تطابق أي مرحلة — لم يُشغَّل شيء"
            dim "      المهام الصحيحة: bash scripts/quality.sh --list-shards"
            echo "════════════════════════════════════════════════════════════"
            exit 2
        fi
        [ -n "$QG_SHARD" ] && dim "  المهمة: $QG_SHARD — نفّذت $EXECUTED_COUNT مرحلة"
        if [ "$FAILED" -gt 0 ]; then
            red "  فشلت $FAILED بوابة"
            [ "$SUSPENDED_COUNT" -gt 0 ] && yellow "  ⏸  و$SUSPENDED_COUNT بوابةٍ مُوقفةٌ بقرار — لم تُشغَّل"
            [ "$PARALLEL_COUNT" -gt 0 ] && dim "  ⇉ و$PARALLEL_COUNT بوابةٍ في مهامّ CI موازية"
            echo "════════════════════════════════════════════════════════════"
            exit 1
        fi
        green "  كل البوابات المُفعَّلة خضراء"
        if [ "$PARALLEL_COUNT" -gt 0 ]; then
            dim "  ⇉ و$PARALLEL_COUNT بوابةٍ في مهامّ CI موازية — لا تشملها الخضرةُ أعلاه، وتحكم بها المهمة الجامعة «بوابات الجودة»"
        fi
        # الخضرةُ تُقيَّد بما شُغِّل. «كل البوابات خضراء» على تشغيلةٍ أُوقف
        # بعضُها جملةٌ صادقةُ اللفظ كاذبةُ الأثر، وهي بعينها ما تمنعه المبادئ.
        if [ "$SUSPENDED_COUNT" -gt 0 ]; then
            yellow "  ⏸  و$SUSPENDED_COUNT بوابةٍ مُوقفةٌ بقرار — لم تُشغَّل ولا تشملها الخضرةُ أعلاه"
            dim    "      لإعادتها: bash scripts/quality.sh --with-tests --include-suspended${MANUAL_ONLY_GATES:+  (لا تشمل اليدويّة: $MANUAL_ONLY_GATES — بأمرها المفرد وحده)}"
        fi
        echo "════════════════════════════════════════════════════════════"
        ;;

    *)
        echo "استخدام: bash scripts/quality.sh [all|--with-tests|$(printf '%s' "$KNOWN_STAGES" | tr ' ' '|')]"
        echo "         ويُضاف --include-suspended لإعادة البوابات المُوقفة (SUSPENDED_GATES) إلى التسلسل — لا اليدويّة (MANUAL_ONLY_GATES)"
        echo "         وفي CI: --list-shards · --shard=<name> — المفعّل فقط"
        exit 2
        ;;
esac

exit "$([ "$FAILED" -gt 0 ] && echo 1 || echo 0)"
