#!/usr/bin/env bash
# =============================================================================
# Slice scaffolding - the repeatable half of a vertical slice
# -----------------------------------------------------------------------------
# Measured over the first slices of the reference project: every one of them
# produced the same file set - four to six FormRequests, one or two
# controllers, one to three services, a model, a migration, two or three test
# classes. The bodies are domain work and always will be. The shells are not:
# namespace, directory, `declare(strict_types=1)`, the module base class, the
# table prefix, the migration's location, the test namespace. Those are fixed
# by RS-012, RS-013, RS-014, CS-010 and the module layout, and getting one of
# them wrong is a red gate and a wasted cycle.
#
# -- What it will not do ----------------------------------------------------
# It writes no rule, no field, no validation, no route and no assertion. Those
# come from the approved package and nowhere else. What it emits is a correct
# shell with a TODO that names the identifier and the exact line of the
# contract to read - so the next step is a targeted read, not a search.
#
# -- Traceability is required, not optional ---------------------------------
# `--id` is mandatory and is checked against the module's code. A file with no
# source identifier is invented scope, so the generator refuses to produce one
# rather than leaving it to discipline. It also never overwrites an existing
# file.
#
# The module map is `scripts/config/modules.tsv`; <code> is the module's
# table prefix or its code in any case (`ord` · `ORD`).
#
# Usage:
#   bash scripts/scaffold-slice.sh <code> request    <Name>  --id API-ORD-013
#   bash scripts/scaffold-slice.sh <code> controller <Name>  --id API-ORD-013
#   bash scripts/scaffold-slice.sh <code> service    <Name>  --id US-ORD-012
#   bash scripts/scaffold-slice.sh <code> model      <Name>  --id ENT-ORD-009 --table ord_things
#   bash scripts/scaffold-slice.sh <code> migration  <table> --id ENT-ORD-009
#   bash scripts/scaffold-slice.sh <code> test       <Name>  --id TS-ORD-001
# =============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# shellcheck source=config/shift.env
. "$ROOT/scripts/config/shift.env" || exit 2

BACKEND="$BACKEND_DIR"

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }

usage() { sed -n '/^# Usage:/,/^# ====/p' "$0" | sed 's/^# \{0,2\}//;$d'; }

CODE=""; KIND=""; NAME=""; SRC_ID=""; TABLE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --id)    SRC_ID="$2"; shift 2 ;;
        --table) TABLE="$2";  shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *)
            if   [ -z "$CODE" ]; then CODE="$1"
            elif [ -z "$KIND" ]; then KIND="$1"
            elif [ -z "$NAME" ]; then NAME="$1"
            fi
            shift ;;
    esac
done

if [ -z "$CODE" ] || [ -z "$KIND" ] || [ -z "$NAME" ]; then
    usage >&2
    exit 2
fi

LOWER=$(printf '%s' "$CODE" | tr '[:upper:]' '[:lower:]')

# -- Module directory, read from the one map the repository already has -----
# modules.tsv is the authoritative code-to-directory map (RS-012); arch-check.sh
# fails the build on any directory missing from it. Reading it here means there
# is still exactly one map: a second copy would drift, and the drift would
# surface as a scaffold written into a directory the boundary gate rejects.
MODULE_DIR=""; DOC_DIR=""; TABLE_PREFIX=""; UPPER=""
if [ ! -f "$MODULES_TSV" ]; then
    red "خريطة الموديولات غير موجودة: $MODULES_TSV"
    exit 2
fi
while IFS=$'\t' read -r m_code m_docs m_dir m_prefix _rest; do
    case "$m_code" in ''|'#'*) continue ;; esac
    m_code_lower=$(printf '%s' "$m_code" | tr '[:upper:]' '[:lower:]')
    if [ "$m_code_lower" = "$LOWER" ] || [ "$m_prefix" = "$LOWER" ]; then
        MODULE_DIR="$m_dir"; DOC_DIR="$m_docs"; TABLE_PREFIX="$m_prefix"
        UPPER=$(printf '%s' "$m_code" | tr '[:lower:]' '[:upper:]')
        break
    fi
done < <(tr -d '\r' < "$MODULES_TSV")

if [ -z "$MODULE_DIR" ]; then
    red "كود موديول غير مسجَّل: $LOWER"
    dim "الخريطة المعتمدة في $MODULES_TSV"
    exit 2
fi

# -- The identifier must belong to this module ------------------------------
if [ -z "$SRC_ID" ]; then
    red "--id إلزامي — ملفٌ بلا معرّف مصدري نطاقٌ مُخترَع"
    exit 2
fi
case "$SRC_ID" in
    ENT-"$UPPER"-*|API-"$UPPER"-*|US-"$UPPER"-*|TS-"$UPPER"-*|BR-"$UPPER"-*|FR-"$UPPER"-*) ;;
    *)
        red "المعرّف $SRC_ID لا يخصّ الموديول $UPPER"
        dim "الصيغة: ENT|API|US|TS|BR|FR-$UPPER-###"
        exit 2 ;;
esac

# -- Where the contract for this identifier lives, for the TODO -------------
# The scaffold points at the line instead of at the file. Reading sixty lines
# of api-contracts.md beats searching 1400 of them, which is the same reason
# module-digest.sh exists.
#
# The file:line is matched by shape, not by column position: an untraced row
# has no `[*]` marker, so column numbers shift under it and a column-indexed
# read silently returns the identifier instead of the location.
ID_TYPE="${SRC_ID%%-*}"
DOC_HINT=""
if [ -n "$DOC_DIR" ] && [ -d "$MODULES_DOCS_DIR/$DOC_DIR" ]; then
    DOC_HINT=$(bash scripts/module-digest.sh "$DOC_DIR" --ids "$ID_TYPE" 2>/dev/null \
               | grep -F " $SRC_ID " | grep -oE '[a-z0-9-]+\.md:[0-9]+' | head -1)
fi
[ -z "$DOC_HINT" ] && DOC_HINT="راجع حزمة الموديول"

MOD_PATH="$BACKEND/app/Modules/$MODULE_DIR"
API_RESPONSE_FQCN="$SHARED_API_RESPONSE_CLASS"
API_RESPONSE_SHORT="${SHARED_API_RESPONSE_CLASS##*\\}"
CONTRACTS_NS="$SHARED_CONTRACTS_NS"

write_file() {
    local path="$1" body="$2"
    if [ -e "$path" ]; then
        red "الملف موجود — لا استبدال: $path"
        exit 1
    fi
    mkdir -p "$(dirname "$path")"
    printf '%s' "$body" > "$path"
    green "أُنشئ: $path"
}

case "$KIND" in

request)
    BASE="Illuminate\\Foundation\\Http\\FormRequest"
    BASE_SHORT="FormRequest"
    IMPORT="use Illuminate\\Foundation\\Http\\FormRequest;"
    if [ -f "$MOD_PATH/Http/Requests/${MODULE_DIR}FormRequest.php" ]; then
        # The module's own base carries its contracted error code; falling back
        # to the framework base would answer with the platform-generic code and
        # break DoD-SL-02 against the module's error contract.
        BASE_SHORT="${MODULE_DIR}FormRequest"
        IMPORT=""
    fi
    write_file "$MOD_PATH/Http/Requests/${NAME}Request.php" "<?php

declare(strict_types=1);

namespace App\\Modules\\$MODULE_DIR\\Http\\Requests;
${IMPORT:+
$IMPORT}

/**
 * \`$SRC_ID\` — TODO: the rule this request enforces, not what it does (CS-002).
 */
final class ${NAME}Request extends $BASE_SHORT
{
    /**
     * @return array<string, list<string>>
     */
    public function rules(): array
    {
        // TODO($SRC_ID): fields exactly as contracted — $DOC_HINT
        return [];
    }
}
"
    ;;

controller)
    write_file "$MOD_PATH/Http/Controllers/${NAME}Controller.php" "<?php

declare(strict_types=1);

namespace App\\Modules\\$MODULE_DIR\\Http\\Controllers;

use $API_RESPONSE_FQCN;
use Illuminate\\Http\\JsonResponse;

/**
 * \`$SRC_ID\` — TODO: the contracted surface, and the permission-matrix row it
 * implements if any (HG-I-02 applies before any authorisation rule is coded).
 */
final class ${NAME}Controller
{
    public function __invoke(): JsonResponse
    {
        // TODO($SRC_ID): request/response shape exactly as contracted — $DOC_HINT
        return $API_RESPONSE_SHORT::success([]);
    }
}
"
    ;;

service)
    write_file "$MOD_PATH/Application/Services/${NAME}Service.php" "<?php

declare(strict_types=1);

namespace App\\Modules\\$MODULE_DIR\\Application\\Services;

/**
 * \`$SRC_ID\` — TODO: the business rule this carries (CS-002 wants the why).
 *
 * Cross-module reads go through $CONTRACTS_NS only (RS-020 · RS-023).
 */
final class ${NAME}Service
{
    // TODO($SRC_ID): behaviour exactly as contracted — $DOC_HINT
}
"
    ;;

model)
    if [ -z "$TABLE" ]; then
        red "--table إلزامي للنموذج (بادئته تُفحص بـRS-013)"
        exit 2
    fi
    write_file "$MOD_PATH/Domain/Models/${NAME}.php" "<?php

declare(strict_types=1);

namespace App\\Modules\\$MODULE_DIR\\Domain\\Models;

use Illuminate\\Database\\Eloquent\\Model;

/**
 * $SRC_ID — TODO: one line on what this entity is for.
 *
 * TODO($SRC_ID): the @property block mirrors data-model.md — $DOC_HINT
 */
final class $NAME extends Model
{
    protected \$table = '$TABLE';

    /**
     * @var list<string>
     */
    protected \$fillable = [];
}
"
    ;;

migration)
    TABLE="$NAME"
    # RS-013 - the table prefix is the module code. Unprefixed reference tables
    # are the one documented exception (UNPREFIXED_TABLE_MODULES), and it is
    # declared here rather than silently tolerated.
    case "$TABLE" in
        "${TABLE_PREFIX}_"*) ;;
        *)
            case " ${UNPREFIXED_TABLE_MODULES:-} " in
                *" $TABLE_PREFIX "*) dim "جدول مرجعي بلا بادئة — الاستثناء الموثَّق لـ$UPPER" ;;
                *)
                    red "RS-013 — بادئة الجدول يجب أن تكون ${TABLE_PREFIX}_ : $TABLE"
                    exit 2 ;;
            esac ;;
    esac
    STAMP=$(date +%Y_%m_%d_%H%M%S)
    write_file "$MOD_PATH/Infrastructure/Migrations/${STAMP}_create_${TABLE}_table.php" "<?php

declare(strict_types=1);

use Illuminate\\Database\\Migrations\\Migration;
use Illuminate\\Database\\Schema\\Blueprint;
use Illuminate\\Support\\Facades\\Schema;

/**
 * $SRC_ID — TODO: what this table holds and which rule constrains it.
 *
 * TODO($SRC_ID): columns, constraints and enum checks per data-model.md
 * (DD-019 puts enum constraints in the schema, not only in the model)
 * — $DOC_HINT
 *
 * No cross-module FOREIGN KEY (RS-022): reference other modules' rows by a
 * logical id and read them through $CONTRACTS_NS.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('$TABLE', function (Blueprint \$table): void {
            \$table->id();
            \$table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('$TABLE');
    }
};
"
    ;;

test)
    write_file "$BACKEND/tests/Feature/Modules/$MODULE_DIR/${NAME}Test.php" "<?php

declare(strict_types=1);

namespace Tests\\Feature\\Modules\\$MODULE_DIR;

use Illuminate\\Foundation\\Testing\\RefreshDatabase;
use PHPUnit\\Framework\\Attributes\\Test;
use Tests\\TestCase;

/**
 * \`$SRC_ID\` — TODO: the scope this class covers.
 */
final class ${NAME}Test extends TestCase
{
    use RefreshDatabase;

    protected bool \$seed = true;

    /**
     * TODO($SRC_ID): assert the documented outcome — $DOC_HINT
     *
     * $COVERS_TAG $SRC_ID
     */
    #[Test]
    public function it_holds_the_contracted_behaviour(): void
    {
        \$this->markTestIncomplete('$SRC_ID — scaffolded, not yet written.');
    }
}
"
    ;;

*)
    red "نوع غير معروف: $KIND"
    usage >&2
    exit 2 ;;
esac

echo
dim "قبل الالتزام:"
dim "  · املأ كل TODO($SRC_ID) — الهيكل وحده لا يمرّ DoD (لا TODO صامتة)"
dim "  · سجّل ما يلزم في ${MODULE_DIR}ServiceProvider (المسارات · الربط)"
dim "  · $SCENARIO_TAG لا يُوضع إلا حيث ينفَّذ السيناريو كما كُتب"
dim "  · أعِد توليد العقد إن تغيّرت نقطة: php artisan scramble:export --path=$OPENAPI_FILE"
dim "  · bash scripts/quality.sh --with-tests"
echo
