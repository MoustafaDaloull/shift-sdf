<?php

declare(strict_types=1);

namespace App\Shared\Exceptions;

/**
 * عنصر واحد في `error.details` — `ECS-005`.
 *
 * يُستعمل حين يحمل الخطأ أكثر من نقطة فشل، وأشيعُها التحقق المجمَّع
 * (`ECS-015`): تُجمع أخطاء الحقول كلها في استجابة واحدة بدل إرجاع أولها
 * وترك المستخدم يكتشف البقية طلبًا بعد طلب.
 */
final readonly class ErrorDetail
{
    public function __construct(
        public string $code,
        public string $message,
        public ?string $field = null,
    ) {
        DomainException::assertErrorCodeFormat($code);
    }

    /**
     * `field` يُحذف من الحمولة حين لا ينطبق — الخطأ قد يكون على مستوى الطلب
     * كله لا على حقل بعينه، وإرسال `null` يوحي بحقلٍ اسمه فارغ.
     *
     * @return array<string, string>
     */
    public function toArray(): array
    {
        $payload = [
            'code' => $this->code,
            'message' => $this->message,
        ];

        if ($this->field !== null) {
            $payload = ['field' => $this->field] + $payload;
        }

        return $payload;
    }
}
