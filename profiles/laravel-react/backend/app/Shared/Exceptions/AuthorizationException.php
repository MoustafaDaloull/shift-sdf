<?php

declare(strict_types=1);

namespace App\Shared\Exceptions;

/**
 * خطأ صلاحية — `ECS-001` فئة `AUTHORIZATION`.
 *
 * ── قيد `ECS-011` مبنيّ في الرسائل الافتراضية ────────────────────────────
 * رسالة رفض الوصول لا تكشف وجود المورد من عدمه (تفاديًا لتعداد الموارد)،
 * ولا تسمّي الصلاحية المطلوبة. ولذلك جاءت الرسائل الافتراضية هنا عامةً
 * بنصّها الوارد في `ECS-013` — لا لأنها الأسهل، بل لأن الأدقّ منها يسرّب.
 *
 * ومن يحتاج إخفاءً أقوى (مورد خارج نطاق المستخدم) لا يرمي هذا الصنف أصلًا:
 * يرمي `BusinessRuleException` بحالة `404` وفق الاصطلاح المعتمد.
 */
class AuthorizationException extends DomainException
{
    final public function category(): ErrorCategory
    {
        return ErrorCategory::Authorization;
    }

    /**
     * `ERR-SYS-AUZ-001` — غير مصادق (`ECS-007`).
     *
     * `401` لا `403`: `ECS-008` يفصل بينهما بأن الأولى «لم تُثبت هويتك»
     * والثانية «هويتك ثابتة ولا تكفي».
     */
    public static function unauthenticated(
        string $message = 'يُرجى تسجيل الدخول للمتابعة.',
    ): self {
        return new self('ERR-SYS-AUZ-001', $message, httpStatus: 401);
    }

    /**
     * `ERR-SYS-AUZ-002` — غير مصرح (`ECS-007`).
     */
    public static function forbidden(
        string $message = 'ليس لديك صلاحية لتنفيذ هذا الإجراء.',
    ): self {
        return new self('ERR-SYS-AUZ-002', $message);
    }

    /**
     * `ERR-SYS-AUZ-003` — جلسة منتهية (`ECS-007`).
     */
    public static function sessionExpired(
        string $message = 'انتهت الجلسة. يُرجى تسجيل الدخول من جديد.',
    ): self {
        return new self('ERR-SYS-AUZ-003', $message, httpStatus: 401);
    }
}
