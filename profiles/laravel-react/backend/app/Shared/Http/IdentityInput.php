<?php

declare(strict_types=1);

namespace App\Shared\Http;

/**
 * `SEC-015`'s input half — refuse, do not sanitise.
 *
 * A field that cannot legitimately hold `<` or `>` — a person's name, a
 * phone, an email address, a code, an identifier — REFUSES input carrying
 * either, with the owning module's ordinary validation answer. Refusal, not
 * sanitising: stripping accepts and then silently changes what a person
 * typed, and encoding at input double-encodes under React's own escaping.
 * The protection against XSS stays where the decision puts it — encoding at
 * every output — and this rule is the second layer, not the first.
 *
 * Deliberately NOT applied to: free text (bio · reason · summary · notes ·
 * descriptions), which is stored verbatim and encoded at output; secrets
 * (passwords, OAuth/completion tokens), where any character is legitimate;
 * query filters, which store nothing; and fields whose own format rule
 * (E.164 `regex`, `digits:6`, `in:`) already cannot match either character.
 *
 * One constant rather than the literal in twenty places, so the day the
 * rule's reach changes it changes once.
 *
 * Usage in a FormRequest: `'full_name' => ['required', 'string', IdentityInput::NO_ANGLE_BRACKETS]`.
 */
final class IdentityInput
{
    public const NO_ANGLE_BRACKETS = 'not_regex:/[<>]/';
}
