<?php

declare(strict_types=1);

namespace App\Shared\Exceptions;

use App\Shared\Http\ApiResponse;
use App\Shared\Support\TraceContext;
use Illuminate\Auth\Access\AuthorizationException as LaravelAuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException as LaravelValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\MethodNotAllowedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException;
use Throwable;

/**
 * يحوّل أي استثناء إلى استجابة `ECS-003` — النقطة الوحيدة التي تُبنى فيها
 * حمولة الخطأ في المنصة.
 *
 * ── لماذا واحدة لا واحدة لكل موديول ─────────────────────────────────────
 * `ECS-003` و`ECS-009` و`ECS-010` قيود على **كل** استجابة خطأ. وقيدٌ يُعاد
 * تنفيذه في عشرين موضعًا يُنفَّذ في تسعة عشر ويُنسى في واحد — ولا يظهر
 * النسيان في المُهمِل بل عند المستهلك، بعد النشر. فالتحويل هنا وحده،
 * والموديول لا يملك إلا أن يرمي استثناءً.
 *
 * ── ما يعبر كما هو وما يُبدَّل ──────────────────────────────────────────
 * `DomainException` تعبر بكودها وفئتها وحالتها. وكل ما عداها يُطبَّع إلى
 * أقرب كود معتمد في `ECS-007` — لا يُخترع كود، ولا يُترك استثناء بلا شكل.
 *
 * ── التسجيل في `bootstrap/app.php` ──────────────────────────────────────
 *   $exceptions->shouldRenderJsonWhen(ApiSurface::matches(...));
 *   $exceptions->render(function (Throwable $e, Request $request) {
 *       if (! ApiSurface::matches($request)) { return null; }
 *       return app(ApiExceptionRenderer::class)->render($request, $e);
 *   });
 *
 * @see docs/03-development/error-contract-standard.md
 */
final class ApiExceptionRenderer
{
    public function __construct(private readonly TraceContext $trace) {}

    public function render(Request $request, Throwable $e): JsonResponse
    {
        $domain = $this->normalise($e);

        $this->record($request, $domain, $e);

        return $this->respond($domain);
    }

    /**
     * يُرجع كل استثناء إلى الهرم المعتمد.
     */
    private function normalise(Throwable $e): DomainException
    {
        return match (true) {
            $e instanceof DomainException => $e,
            $e instanceof LaravelValidationException => $this->fromLaravelValidation($e),
            $e instanceof AuthenticationException => AuthorizationException::unauthenticated(),
            $e instanceof LaravelAuthorizationException => AuthorizationException::forbidden(),
            $e instanceof HttpExceptionInterface => $this->fromHttpException($e),
            default => SystemException::unexpected($e->getMessage()),
        };
    }

    /**
     * أخطاء التحقق مجمَّعة — `ECS-015` — وكلٌّ مربوط بحقله — `ECS-016`.
     *
     * الحالة `400` لا `422`: `ECS-008` يُلزم بها لفئة `VALIDATION`، وافتراض
     * الإطار مخالف. المعيار هو المرجع، والانحراف عنه يجعل عميل الواجهة
     * يفرّق بين مصدرَي تحقق لا فرق بينهما في العقد.
     */
    private function fromLaravelValidation(LaravelValidationException $e): ValidationException
    {
        $details = [];

        foreach ($e->errors() as $field => $messages) {
            foreach ($messages as $message) {
                $details[] = new ErrorDetail(
                    code: 'ERR-SYS-VAL-002',
                    message: $message,
                    field: $field,
                );
            }
        }

        return ValidationException::invalidFormat(
            'يُرجى تصحيح البيانات المُدخلة.',
            $details,
        );
    }

    /**
     * استثناءات الإطار التي لا نقطةَ عقدٍ لها — مسار غير موجود · فعل غير
     * مسموح · تجاوز حدّ الطلبات.
     *
     * `ERR-SYS-VAL-004` لطلبٍ إلى مسارٍ غير موجود أو بطريقة HTTP غير مدعومة —
     * خطأُ طالبٍ لا خطأُ نظام، فيُصنَّف `VALIDATION` (يُسجَّل تحذيرًا بلا أثر
     * مكدّس، ورسالتُه تصل العميل) **مع الإبقاء على حالة HTTP الحقيقية**
     * `404`/`405`.
     *
     * وتجاوزُ الحدّ: محدِّدٌ بلا ردٍّ خاص يرمي `ThrottleRequestsException` — وهي
     * `TooManyRequestsHttpException` — فتُجاب `ERR-SYS-BIZ-001` بحالة `429`
     * ورسالةٍ صريحة وتسجيلِ تحذير، لا `ERR-SYS-SYS-001` برسالةٍ عامة وخطورةِ
     * نظام. وما سوى الثلاثة يبقى على `ERR-SYS-SYS-001` بحالته الحقيقية.
     *
     * وهذا لا يمسّ الأخطاء المتعاقد عليها: «المورد غير موجود» يرميه الموديول
     * بكوده `BIZ` الخاص، فلا يمرّ من هنا أصلًا.
     */
    private function fromHttpException(HttpExceptionInterface $e): DomainException
    {
        if ($e instanceof NotFoundHttpException || $e instanceof MethodNotAllowedHttpException) {
            return new ValidationException(
                'ERR-SYS-VAL-004',
                'المسار غير موجود أو طريقة الطلب غير مدعومة.',
                [],
                $e->getStatusCode(),
            );
        }

        // The framework's own 429 (Retry-After headers are not carried: the
        // envelope is built by ApiResponse alone).
        if ($e instanceof TooManyRequestsHttpException) {
            return BusinessRuleException::rateLimitExceeded();
        }

        return new SystemException(
            'ERR-SYS-SYS-001',
            $e->getMessage(),
            [],
            $e->getStatusCode(),
        );
    }

    /**
     * البناء يمرّ بـ`ApiResponse` لا بـ`response()->json()` مباشرة — `CS-016`.
     * موضع واحد يبني المغلّف، وموضع واحد (هذا) يقرر ما يدخله.
     */
    private function respond(DomainException $domain): JsonResponse
    {
        $category = $domain->category();

        return ApiResponse::error(
            code: $domain->errorCode(),
            type: $category->value,
            // `ECS-010`: رسالة أخطاء النظام تُستبدل دائمًا، لأنها مُشتقّة من
            // استثناء داخلي فتحمل ما يمنعه `ECS-009`. الأصل ذهب إلى السجل.
            message: $category->exposesItsMessage()
                ? $domain->getMessage()
                : SystemException::GENERIC_MESSAGE,
            traceId: $this->trace->id(),
            status: $domain->httpStatus(),
            details: array_map(
                static fn (ErrorDetail $detail): array => $detail->toArray(),
                $domain->details(),
            ),
        );
    }

    /**
     * السجل الداخلي — `ECS-021`.
     *
     * هنا يذهب ما مُنع من الاستجابة: نص الاستثناء الأصلي وأثر المكدّس وسياق
     * المزوّد. والرابط بين الاثنين هو `trace_id` وحده.
     */
    private function record(Request $request, DomainException $domain, Throwable $original): void
    {
        $category = $domain->category();
        $isSevere = in_array($category, [ErrorCategory::System, ErrorCategory::Integration], true);

        $context = [
            'trace_id' => $this->trace->id(),
            'error_code' => $domain->errorCode(),
            'error_type' => $category->value,
            'module' => $this->moduleOf($domain->errorCode()),
            'endpoint' => $request->getMethod().' '.$request->path(),
            'actor_id' => $this->actorId(),
            'request_summary' => $this->summarise($request),
            'severity' => $isSevere ? 'ERROR' : 'WARNING',
        ];

        // `stack_trace` إلزامي لأخطاء النظام وحدها (`ECS-021`) — ولها تحديدًا
        // لأن رسالتها لا تصل المستخدم، فلو لم يُسجَّل الأثر لضاع العطب كله.
        if ($category === ErrorCategory::System) {
            $context['exception'] = $original::class.': '.$original->getMessage();
            $context['stack_trace'] = $original->getTraceAsString();
        }

        $context += $domain->logContext();

        $isSevere
            ? Log::error($domain->getMessage(), $context)
            : Log::warning($domain->getMessage(), $context);
    }

    /**
     * كود الموديول من كود الخطأ — `ERR-XXX-VAL-001` ⟵ `XXX`.
     */
    private function moduleOf(string $errorCode): string
    {
        return explode('-', $errorCode)[1] ?? 'SYS';
    }

    /**
     * `actor_id` «إلزامي عند التوفر» (`ECS-021`).
     *
     * `hasUser()` تقرأ ما استقرّ في الحارس ولا تستدعي المزوّد، فلا يحاول
     * المُصيِّر مصادقةَ من فشل طلبه — ومُصيِّرٌ يرمي أثناء تصييره خطأً يُنتج
     * `500` فارغة بلا `trace_id`، وهي أسوأ ما ينتهي إليه هذا المسار.
     */
    private function actorId(): int|string|null
    {
        try {
            return Auth::hasUser() ? Auth::id() : null;
        } catch (Throwable) {
            return null;
        }
    }

    /**
     * ملخص الطلب «بدون بيانات حساسة» (`ECS-021`).
     *
     * تُسجَّل **أسماء** الحقول لا قيمها. والبديل — قائمة منع لأسماء حساسة —
     * يفشل مفتوحًا: أول حقل لم يخطر على بال كاتب القائمة يُسجَّل بقيمته.
     * وأسماء الحقول وحدها تكفي لإعادة بناء شكل الطلب عند التشخيص.
     *
     * @return array<string, mixed>
     */
    private function summarise(Request $request): array
    {
        return [
            'input_keys' => array_keys($request->all()),
            'ip' => $request->ip(),
        ];
    }
}
