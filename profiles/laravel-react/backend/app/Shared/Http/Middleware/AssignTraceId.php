<?php

declare(strict_types=1);

namespace App\Shared\Http\Middleware;

use App\Shared\Http\ApiSurface;
use App\Shared\Support\TraceContext;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * يُثبّت `X-Trace-Id` على كل استجابة من سطح API — `API-021`.
 *
 * الترويسة تُضاف على النجاح والخطأ معًا لأن قيمتها تظهر في الخطأ تحديدًا:
 * المستخدم يبلّغ بالمعرّف، ويُقرأ به السجل الداخلي الذي يحمل التفاصيل التي
 * منعها `ECS-009` من الاستجابة.
 *
 * ── لماذا وسيط عام لا وسيط مجموعة `api` ─────────────────────────────────
 * كان مُلحقًا بمجموعة `api`، ومجموعةُ المسار **لا تعمل إن لم يُطابَق مسار**.
 * فكان كل 404 على مسار غير معرَّف يخرج بجسمٍ يحمل `trace_id` وبترويسةٍ فارغة
 * — أي أن الترويسة كانت تغيب في الحالة التي وُضعت لأجلها بالضبط. ولم يكن
 * ليظهر في أي طلب ناجح.
 *
 * والوسيط العام يعمل قبل التوجيه، فيغطي فشل التوجيه وفشل ربط النموذج وفشل
 * الوسائط الأخرى. والشرط في `ApiSurface` كي لا تُحقن الترويسة في صفحات الويب.
 *
 * التسجيل في `bootstrap/app.php`: `$middleware->append(AssignTraceId::class);`
 */
final class AssignTraceId
{
    public function __construct(private readonly TraceContext $trace) {}

    public function handle(Request $request, Closure $next): Response
    {
        /** @var Response $response */
        $response = $next($request);

        if (ApiSurface::matches($request)) {
            $response->headers->set('X-Trace-Id', $this->trace->id());
        }

        return $response;
    }
}
