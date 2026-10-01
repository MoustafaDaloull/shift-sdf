<?php

declare(strict_types=1);

namespace App\Shared\Exceptions;

use InvalidArgumentException;
use RuntimeException;

/**
 * جذر هرم أخطاء المنصة — `ECS-001`..`ECS-008`.
 *
 * كل خطأ مقصود يرث من هنا، فيحمل كودًا ثابتًا وفئةً ورسالةً للمستخدم. وما لا
 * يرث من هنا يُعامَل خطأَ نظام غير متوقع ويُخفى خلف رسالة عامة (`ECS-010`).
 *
 * ── لماذا يُتحقَّق من صيغة الكود عند الإنشاء ─────────────────────────────
 * `ECS-014` يجعل `error.code` هو العقد البرمجي الثابت الذي يعتمد عليه
 * المستهلك، بينما الرسالة قابلة للتغيير. فكودٌ مُخترَع أو مخالف للصيغة يكسر
 * العقد **بصمت** — يمرّ في التطوير ويظهر عند المستهلك. والتحقق هنا يجعل ذلك
 * فشلًا فوريًا لا مفاجأةً لاحقة، على المبدأ نفسه الذي وضع قيود التعدادات في
 * المخطط لا في التطبيق وحده.
 */
abstract class DomainException extends RuntimeException
{
    /** `ECS-006` — `ERR-[MODULE_CODE]-[CATEGORY_CODE]-###` */
    private const CODE_PATTERN = '/^ERR-[A-Z]{2,6}-(VAL|BIZ|AUZ|SYS|INT)-\d{3}$/';

    /** @var list<ErrorDetail> */
    private array $details;

    private ?int $httpStatusOverride;

    /**
     * @param  list<ErrorDetail>  $details
     */
    final public function __construct(
        private readonly string $errorCode,
        string $userMessage,
        array $details = [],
        ?int $httpStatus = null,
    ) {
        self::assertErrorCodeFormat($errorCode);
        $this->assertCategoryMatchesCode($errorCode);

        $this->details = $details;
        $this->httpStatusOverride = $httpStatus;

        parent::__construct($userMessage);
    }

    abstract public function category(): ErrorCategory;

    public function errorCode(): string
    {
        return $this->errorCode;
    }

    /**
     * @return list<ErrorDetail>
     */
    public function details(): array
    {
        return $this->details;
    }

    public function httpStatus(): int
    {
        return $this->httpStatusOverride ?? $this->category()->defaultHttpStatus();
    }

    /**
     * حقول إضافية تُكتب في السجل الداخلي ولا تُرسَل في الاستجابة — `ECS-021`.
     *
     * الفصل مقصود: ما يُشخّص العطب ليس ما يجوز أن يراه المستخدم، و`ECS-009`
     * يمنع أن يتسرّب الأول إلى الثاني. فمن أراد إرفاق سياق للتشخيص يزيده
     * هنا، لا في الرسالة.
     *
     * @return array<string, scalar|null>
     */
    public function logContext(): array
    {
        return [];
    }

    public static function assertErrorCodeFormat(string $code): void
    {
        if (preg_match(self::CODE_PATTERN, $code) !== 1) {
            throw new InvalidArgumentException(
                "كود خطأ مخالف لصيغة ECS-006: {$code}"
            );
        }
    }

    /**
     * الكود يحمل اختصار فئته، فلا يجوز أن يخالف الصنف الذي يُطلقه — وإلا صار
     * `type` في الاستجابة يقول شيئًا و`code` يقول غيره، ويبني المستهلك منطقه
     * على أحدهما فيقع في تناقض لا يظهر إلا عنده.
     */
    private function assertCategoryMatchesCode(string $code): void
    {
        $expected = $this->category()->abbreviation();
        $actual = explode('-', $code)[2] ?? '';

        if ($actual !== $expected) {
            throw new InvalidArgumentException(
                "كود الخطأ {$code} يحمل الفئة {$actual} بينما الاستثناء فئته {$expected}"
            );
        }
    }
}
