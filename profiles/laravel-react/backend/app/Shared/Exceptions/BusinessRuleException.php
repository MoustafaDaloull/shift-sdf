<?php

declare(strict_types=1);

namespace App\Shared\Exceptions;

/**
 * انتهاك قاعدة عمل — `ECS-001` فئة `BUSINESS_RULE`.
 *
 * العملية سليمة الصيغة لكنها تخالف قاعدة معتمدة. غير قابل لإعادة المحاولة
 * حتى تتغير الظروف (`ECS-023`).
 *
 * ── ولهذه الفئة يُرمى «المورد غير موجود» ───────────────────────────────
 * `ECS-007` لا يُعرِّف كودًا عامًا لـ404، والاصطلاح المعتمد أن كل موديول
 * يملك كودَه الخاص بفئة `BIZ` وحالة `404`. والسبب: يُرجع `404` لا `403` كي
 * لا يُكشف وجود سجل خارج نطاق المستخدم — وهو `ECS-011` نفسه مطبَّقًا من
 * الجهة المقابلة.
 *
 * فالكود إذًا مملوك للموديول لا للطبقة المشتركة:
 * `new BusinessRuleException('ERR-XXX-BIZ-010', '...', httpStatus: 404)`.
 */
class BusinessRuleException extends DomainException
{
    /**
     * `ERR-SYS-BIZ-001` — تجاوز حدّ المعدّل (`ECS-007` · `API-025`).
     *
     * مسكوك في فئة **متوقَّعة** لا في `SYS`، كي يقرأ الطالب جملة الحكم نفسها
     * بدل رسالة `ECS-010` العامة، ويسجّل المُصيِّر تحذيرًا لا عطبَ نظام.
     * `BIZ` لأن `ECS-002` يُصنِّف تجاوزَ حدٍّ هناك. والحالة `429` من `API-025`
     * وتتجاوز افتراض `ECS-008`.
     */
    public static function rateLimitExceeded(): self
    {
        return new self('ERR-SYS-BIZ-001', 'تجاوزتَ حدَّ المحاولات', httpStatus: 429);
    }

    final public function category(): ErrorCategory
    {
        return ErrorCategory::BusinessRule;
    }
}
