<?php

declare(strict_types=1);

namespace App\Shared\Http;

use Illuminate\Http\JsonResponse;

/**
 * مغلّف الاستجابة الموحّد للمنصة.
 *
 * CS-016: لا يُبنى المغلّف يدويًا في أي متحكم — يمر عبر هذا الصنف حصرًا.
 * السبب: مغلّف مبني يدويًا في عشرين موديولًا ينحرف حتمًا، فيضطر عميل الواجهة
 * إلى معالجة أشكال متعددة لنفس المعنى.
 *
 * @see docs/03-development/api-design-standard.md
 * @see docs/03-development/error-contract-standard.md
 */
final class ApiResponse
{
    /**
     * استجابة ناجحة.
     *
     * `array-key` لا `string`: `API-009` يجعل `data` **مصفوفةً** للقوائم
     * وكائنًا للمورد المفرد، فقصْرُ المفتاح على `string` كان يمنع أول نقطة
     * قائمة من المرور بالمغلّف الذي يوجب `CS-016` المرور به.
     *
     * @param  array<array-key, mixed>|object|null  $data
     */
    public static function success(
        mixed $data = null,
        ?string $message = null,
        int $status = 200,
    ): JsonResponse {
        // الفرع صريح لا `if` يزيد مفتاحًا على مصفوفة مبنيّة: Scramble يقرأ هذه
        // الدالة ليشتقّ شكل الاستجابة، والبناءُ التراكمي يُدمج عنده في شكل
        // واحد يُعلن `message` **حاضرًا وإلزاميًا ونوعه `null`** — أي عقدًا
        // منشورًا يصف حقلًا لا يخرج أبدًا. والفرعان يُنتجان `anyOf` يصف
        // الحالتين كما هما.
        return response()->json(
            $message === null
                ? ['success' => true, 'data' => $data]
                : ['success' => true, 'data' => $data, 'message' => $message],
            $status,
        );
    }

    /**
     * استجابةٌ بكتلة `meta` ليست ترقيمًا (التقارير · البحث · قوائم `{total}` غير المرقَّمة).
     *
     * ── لماذا هنا لا في المتحكم ─────────────────────────────────────────
     * `CS-016` يوجب أن يُبنى المغلّف في هذا الصنف حصرًا، و`ApiResponse::success`
     * لا تحمل مفتاحًا شقيقًا لـ`data`. فالخيار كان بين بناء المغلّف يدويًا في
     * المتحكم — وهو ما يمنعه المعيار نصًّا — وبين دالة تصف الشكل هنا.
     *
     * ── Not for pagination ──────────────────────────────────────────────
     * Every paginated list answers `API-015`'s `pagination` block through
     * `paginated`/`paginatedWith` below. A `meta` that is a page block is a
     * regression, not a second accepted shape.
     *
     * @param  array<array-key, mixed>  $data
     * @param  array<string, mixed>  $meta
     */
    public static function successWithMeta(array $data, array $meta): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $data,
            'meta' => $meta,
        ]);
    }

    /**
     * A paginated list in the `API-015` shape: `pagination` is a sibling of
     * `data`. Services build the block inline: Scramble does not infer it
     * through a shared static helper (measured).
     *
     * @param  array<array-key, mixed>  $data
     * @param  array<string, int>  $pagination  page · page_size · total_items · total_pages
     */
    public static function paginated(array $data, array $pagination): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $data,
            'pagination' => $pagination,
        ]);
    }

    /**
     * `paginated` plus top-level siblings that describe the whole list,
     * never inside the page block.
     *
     * @param  array<array-key, mixed>  $data
     * @param  array<string, int>  $pagination  page · page_size · total_items · total_pages
     * @param  array<string, mixed>  $extra
     */
    public static function paginatedWith(array $data, array $pagination, array $extra): JsonResponse
    {
        return response()->json([...['success' => true, 'data' => $data, 'pagination' => $pagination], ...$extra]);
    }

    /**
     * استجابة خطأ — بنية `ECS-003` كاملة.
     *
     * CS-018: الرسالة موجّهة للمستخدم — لا تكشف بنية داخلية ولا استعلامًا.
     *
     * ── لا يُستدعى هذا من متحكم ─────────────────────────────────────────
     * الطريق الوحيد إلى استجابة خطأ هو **رمي** `DomainException`، ويتولّى
     * `ApiExceptionRenderer` تطبيعه ثم يستدعي هذه الدالة. وهي عامة لأن
     * `CS-016` يوجب أن يُبنى المغلّف هنا حصرًا — لا ليُبنى الخطأ من موضعين.
     *
     * `type` و`trace_id` **إلزاميان** بـ`ECS-004` — نسخة سابقة من هذه الدالة
     * أصدرت `code` و`message` وحدهما ولم يظهر النقص لأنها لم تُستدعَ قط.
     *
     * @param  list<array<string, string>>  $details
     */
    public static function error(
        string $code,
        string $type,
        string $message,
        string $traceId,
        int $status,
        array $details = [],
    ): JsonResponse {
        $error = [
            'code' => $code,
            'type' => $type,
            'message' => $message,
            'details' => $details,
            'trace_id' => $traceId,
        ];

        // `details` اختياري (`ECS-004`) — يُبنى في موضعه من بنية `ECS-003`
        // ثم يُنزع فارغًا، فيبقى ترتيب المفاتيح مطابقًا للبنية المنشورة.
        if ($details === []) {
            unset($error['details']);
        }

        return response()->json(['success' => false, 'error' => $error], $status);
    }

    /**
     * استجابة ناجحة تحمل كتلة `warnings` إلى جانب `data` و`message`.
     *
     * دالّةٌ ثالثة لا مفتاحٌ يُضاف في المتحكم، للعلّة نفسِها التي أنشأت
     * `successWithMeta`. وتُحذف فارغةً على سابقة `success`: العقدُ يرسم
     * الكتلةَ **حين يوجد تحذير**، ونشرُ `"warnings": []` في كل استجابةٍ
     * ناجحة يصف حقلًا لا معنى له في أكثر حالاته.
     *
     * @param  array<array-key, mixed>|object|null  $data
     * @param  list<string>  $warnings
     */
    public static function successWithWarnings(
        mixed $data,
        string $message,
        array $warnings,
        int $status = 200,
    ): JsonResponse {
        return response()->json(
            $warnings === []
                ? ['success' => true, 'data' => $data, 'message' => $message]
                : ['success' => true, 'data' => $data, 'message' => $message, 'warnings' => $warnings],
            $status,
        );
    }

    /**
     * استجابة ناجحة بلا محتوى — للعمليات التي لا تُعيد كيانًا.
     */
    public static function noContent(): JsonResponse
    {
        return response()->json(['success' => true, 'data' => null], 204);
    }
}
