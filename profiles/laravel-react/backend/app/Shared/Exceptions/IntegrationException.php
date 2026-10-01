<?php

declare(strict_types=1);

namespace App\Shared\Exceptions;

/**
 * خطأ تكامل خارجي — `ECS-001` فئة `INTEGRATION`.
 *
 * الفئة الوحيدة القابلة لإعادة المحاولة بلا تحفّظ (`ECS-023`).
 *
 * ── لماذا سياق المزوّد منفصل عن الرسالة ──────────────────────────────────
 * `ECS-019` يمنع تسريب اسم المزوّد واستجابته الخام إلى المستخدم، بينما
 * `ECS-020` يوجب تسجيلهما كاملَين داخليًا. فالحقلان متناقضا الوجهة، ولو
 * وُضعا في الرسالة لتغلّب أحد الواجبين على الآخر حتمًا. ففُصلا: الرسالة
 * للمستخدم، و`logContext()` للسجل — ولا طريق بينهما.
 */
class IntegrationException extends DomainException
{
    private ?string $provider = null;

    private ?string $providerResponse = null;

    final public function category(): ErrorCategory
    {
        return ErrorCategory::Integration;
    }

    /**
     * `ERR-SYS-INT-001` — فشل تكامل خارجي عام (`ECS-007`).
     */
    public static function providerFailed(
        string $message = 'تعذّر إتمام العملية حاليًا. يُرجى المحاولة لاحقًا.',
    ): self {
        return new self('ERR-SYS-INT-001', $message);
    }

    /**
     * يُرفق سياق المزوّد للسجل الداخلي وحده — `ECS-020`.
     */
    public function withProviderContext(string $provider, ?string $rawResponse = null): static
    {
        $this->provider = $provider;
        $this->providerResponse = $rawResponse;

        return $this;
    }

    /**
     * @return array<string, string|null>
     */
    public function logContext(): array
    {
        if ($this->provider === null) {
            return [];
        }

        return [
            'provider' => $this->provider,
            'integration_response' => $this->providerResponse,
        ];
    }
}
