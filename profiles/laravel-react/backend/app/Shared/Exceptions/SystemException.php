<?php

declare(strict_types=1);

namespace App\Shared\Exceptions;

/**
 * خطأ نظام — `ECS-001` فئة `SYSTEM`.
 *
 * ── الرسالة هنا لا تصل المستخدم ──────────────────────────────────────────
 * `ECS-010` يوجب رسالة عامة لهذه الفئة مهما كان الأصل، لأن رسالتها تُشتقّ
 * عادةً من استثناء داخلي فتحمل اسم جدول أو مسار ملف أو أثر مكدّس — وهو
 * بالضبط ما يمنعه `ECS-009`. فالمُصيِّر يستبدلها بـ`GENERIC_MESSAGE`
 * ويُبقي الأصل في السجل الداخلي مقرونًا بـ`trace_id`.
 *
 * ولهذا يُكتب النص التشخيصي هنا بحريّة: هو مادة السجل لا مادة الاستجابة.
 */
class SystemException extends DomainException
{
    /** النص الوارد في `ECS-010` — الرسالة الوحيدة التي يراها المستخدم من هذه الفئة. */
    public const GENERIC_MESSAGE = 'حدث خطأ غير متوقع. يُرجى المحاولة لاحقًا.';

    final public function category(): ErrorCategory
    {
        return ErrorCategory::System;
    }

    /**
     * `ERR-SYS-SYS-001` — خطأ داخلي غير متوقع (`ECS-007`).
     */
    public static function unexpected(string $diagnostic = self::GENERIC_MESSAGE): self
    {
        return new self('ERR-SYS-SYS-001', $diagnostic);
    }

    /**
     * `ERR-SYS-SYS-002` — الخدمة غير متاحة مؤقتًا (`ECS-007`).
     */
    public static function serviceUnavailable(string $diagnostic = self::GENERIC_MESSAGE): self
    {
        return new self('ERR-SYS-SYS-002', $diagnostic, httpStatus: 503);
    }
}
