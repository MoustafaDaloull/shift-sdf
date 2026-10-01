<?php

declare(strict_types=1);

namespace App\Shared\Exceptions;

/**
 * خطأ تحقق — `ECS-001` فئة `VALIDATION`.
 *
 * البيانات المُدخلة لا تستوفي قواعد التحقق. غير قابل لإعادة المحاولة بلا
 * تصحيح المدخلات (`ECS-023`).
 *
 * الصنف غير `final` عمدًا: للموديول أن يشتقّ منه اسمًا معبّرًا عن حالته
 * (`InvalidPhoneFormatException` مثلًا) فيقرأ موضع الرمي كما يقرأ الشرط.
 * لكن `category()` مقفلة — وإلا خالف الصنفُ فئتَه وانكسر `ECS-002`.
 */
class ValidationException extends DomainException
{
    final public function category(): ErrorCategory
    {
        return ErrorCategory::Validation;
    }

    /**
     * `ERR-SYS-VAL-001` — حقل إلزامي مفقود (`ECS-007`).
     *
     * @param  list<ErrorDetail>  $details
     */
    public static function missingRequiredField(
        string $message = 'يُرجى تعبئة جميع الحقول المطلوبة.',
        array $details = [],
    ): self {
        return new self('ERR-SYS-VAL-001', $message, $details);
    }

    /**
     * `ERR-SYS-VAL-002` — صيغة بيانات غير صالحة (`ECS-007`).
     *
     * @param  list<ErrorDetail>  $details
     */
    public static function invalidFormat(
        string $message = 'صيغة البيانات المُدخلة غير صحيحة.',
        array $details = [],
    ): self {
        return new self('ERR-SYS-VAL-002', $message, $details);
    }

    /**
     * `ERR-SYS-VAL-003` — قيمة خارج النطاق المسموح (`ECS-007`).
     *
     * @param  list<ErrorDetail>  $details
     */
    public static function outOfRange(
        string $message = 'القيمة المُدخلة خارج النطاق المسموح.',
        array $details = [],
    ): self {
        return new self('ERR-SYS-VAL-003', $message, $details);
    }
}
