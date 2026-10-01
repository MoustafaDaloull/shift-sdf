<?php

declare(strict_types=1);

namespace App\Shared\OpenApi;

use App\Shared\Exceptions\AuthorizationException;
use App\Shared\Exceptions\BusinessRuleException;
use App\Shared\Exceptions\DomainException;
use App\Shared\Exceptions\ErrorCategory;
use App\Shared\Exceptions\IntegrationException;
use App\Shared\Exceptions\SystemException;
use App\Shared\Exceptions\ValidationException;
use Dedoc\Scramble\Extensions\ExceptionToResponseExtension;
use Dedoc\Scramble\Support\Generator\Response;
use Dedoc\Scramble\Support\Generator\Schema;
use Dedoc\Scramble\Support\Generator\Types as OpenApiTypes;
use Dedoc\Scramble\Support\Type\ObjectType;
use Dedoc\Scramble\Support\Type\Type;

/**
 * Teach the generator what a `DomainException` becomes on the wire.
 *
 * ── The gap this closes ──────────────────────────────────────────────────
 * Without it the generated contract carries no domain error at all: every
 * operation publishes 200/401/422 or a subset, and zero publish the AUZ or
 * BIZ statuses that `api-contracts.md` defines for them. The cause is
 * structural, not neglect — Scramble infers from code, the controllers
 * delegate to services, and the services are where `DomainException` is
 * raised. What DOES appear (401 from middleware, 422 from FormRequest) is
 * what happens INSIDE the controller.
 *
 * The consequence: a client built from the published contract reads that
 * these endpoints never answer 403, so it never writes that branch.
 *
 * ── Statuses come from ECS-008, not from this class ──────────────────────
 * `ErrorCategory::defaultHttpStatus()` is the single mapping and it is
 * already the one the renderer uses at runtime. Repeating the numbers here
 * would create a second table that drifts from the first — so the enum is
 * asked instead.
 *
 * ── The body shape is the one ECS actually emits ─────────────────────────
 * Taken from `ApiExceptionRenderer`: an `error` object with `code`,
 * `message`, and optional `details`. A schema invented here would document a
 * response the platform does not send, which is worse than documenting none.
 *
 * Registered in `config/scramble.php` under `extensions`.
 */
final class DomainExceptionToResponseExtension extends ExceptionToResponseExtension
{
    public function shouldHandle(Type $type): bool
    {
        return $type instanceof ObjectType && $type->isInstanceOf(DomainException::class);
    }

    public function toResponse(Type $type): ?Response
    {
        if (! $type instanceof ObjectType) {
            return null;
        }

        $category = $this->categoryOf($type);

        if ($category === null) {
            return null;
        }

        $error = (new OpenApiTypes\ObjectType)
            ->addProperty('code', (new OpenApiTypes\StringType)
                ->setDescription('كود الخطأ وفق `ECS-006` — مثال: `ERR-XXX-BIZ-002`.'))
            ->addProperty('message', (new OpenApiTypes\StringType)
                ->setDescription('رسالة موجَّهة للمستخدم.'))
            ->addProperty('details', (new OpenApiTypes\ObjectType)
                ->setDescription('تفصيل اختياري — حقول التحقق مثلًا.'))
            ->setRequired(['code', 'message']);

        $body = (new OpenApiTypes\ObjectType)
            ->addProperty('error', $error)
            ->setRequired(['error']);

        return Response::make($category->defaultHttpStatus())
            ->setDescription($category->value)
            ->setContent('application/json', Schema::fromType($body));
    }

    /**
     * Which category this exception class carries.
     *
     * Resolved from the class, not by instantiating it: the inferred type is a
     * name, there is no object, and several of these constructors require
     * arguments. The five subclasses each pin one category by construction —
     * that is the whole point of the hierarchy — so the mapping is a fact
     * about the class rather than a duplicate of one.
     *
     * A `DomainException` subclass outside these five returns null and is
     * skipped rather than guessed at, so a future category cannot be silently
     * published as the wrong status.
     */
    private function categoryOf(ObjectType $type): ?ErrorCategory
    {
        return match (true) {
            $type->isInstanceOf(ValidationException::class) => ErrorCategory::Validation,
            $type->isInstanceOf(BusinessRuleException::class) => ErrorCategory::BusinessRule,
            $type->isInstanceOf(AuthorizationException::class) => ErrorCategory::Authorization,
            $type->isInstanceOf(IntegrationException::class) => ErrorCategory::Integration,
            $type->isInstanceOf(SystemException::class) => ErrorCategory::System,
            default => null,
        };
    }
}
