<?php

declare(strict_types=1);

namespace App\Shared\Http;

use Illuminate\Http\Request;

/**
 * «هل هذا الطلب موجَّه إلى سطح API؟» — تعريف واحد لثلاثة مواضع.
 *
 * الشرط نفسه يحكم ثلاثة قرارات لا يجوز أن تفترق:
 *
 *   1. هل تُصيَّر الأخطاء JSON؟            (`shouldRenderJsonWhen`)
 *   2. هل يمرّ الخطأ بعقد `ECS-003`؟        (`ApiExceptionRenderer`)
 *   3. هل تحمل الاستجابة `X-Trace-Id`؟     (`AssignTraceId`)
 *
 * ولو كُتب الشرط ثلاث مرات لافترق عند أول تعديل، والنتيجة أسوأ صنف من العطب:
 * استجابة خطأ **بشكل العقد وبلا `trace_id`** — أي معرّف في الجسم لا يقابله
 * شيء في الترويسة يُبلّغ به المستخدم.
 */
final class ApiSurface
{
    public static function matches(Request $request): bool
    {
        return $request->is('api/*') || $request->expectsJson();
    }
}
