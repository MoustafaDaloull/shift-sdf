<?php

declare(strict_types=1);

namespace App\Shared\Exceptions;

/**
 * الفئات الخمس المعتمدة لتصنيف الأخطاء — `ECS-001`.
 *
 * `ECS-002`: لا يُصنَّف خطأ في أكثر من فئة. عند التداخل يُختار الأقرب لجذر
 * السبب — بطاقة منتهية `VALIDATION`، وعطل بوابة الدفع `INTEGRATION`، وتجاوز
 * حدّ معتمد `BUSINESS_RULE`.
 */
enum ErrorCategory: string
{
    case Validation = 'VALIDATION';
    case BusinessRule = 'BUSINESS_RULE';
    case Authorization = 'AUTHORIZATION';
    case System = 'SYSTEM';
    case Integration = 'INTEGRATION';

    /**
     * اختصار الفئة داخل كود الخطأ — `ECS-006`.
     */
    public function abbreviation(): string
    {
        return match ($this) {
            self::Validation => 'VAL',
            self::BusinessRule => 'BIZ',
            self::Authorization => 'AUZ',
            self::System => 'SYS',
            self::Integration => 'INT',
        };
    }

    /**
     * كود HTTP الافتراضي — `ECS-008`.
     *
     * ثلاث فئات يمنحها المعيار خيارين (`BUSINESS_RULE` · `AUTHORIZATION` ·
     * `INTEGRATION`)، فيُختار هنا الافتراضُ الأعمّ ويُترك التخصيص للاستثناء
     * نفسه. والسبب أن الفرق بينهما دلالي لا تقني: `401` تقول «لم تُثبت هويتك»
     * و`403` تقول «هويتك ثابتة ولا تكفي» — واختيار أحدهما عن الآخر قرارُ
     * موضعٍ لا قرارُ فئة.
     */
    public function defaultHttpStatus(): int
    {
        return match ($this) {
            self::Validation => 400,
            self::BusinessRule => 422,
            self::Authorization => 403,
            self::System => 500,
            self::Integration => 502,
        };
    }

    /**
     * هل يجوز لهذه الفئة أن تُظهر رسالتها للمستخدم كما هي؟
     *
     * `ECS-010` يوجب رسالة عامة لأخطاء النظام مهما كان الأصل، لأن رسالتها
     * تُشتقّ عادةً من استثناء داخلي — وهو بالضبط ما يمنعه `ECS-009`.
     */
    public function exposesItsMessage(): bool
    {
        return $this !== self::System;
    }
}
