<?php

declare(strict_types=1);

namespace App\Shared\Support;

use Illuminate\Database\Query\Expression;

/**
 * Arabic search folding — a generic utility for any Arabic-first search.
 *
 * A search for «مدرسة» must find «مدرسه», «أحمد» must find «احمد», and a
 * diacritised name must be found by its bare spelling. The same folding is
 * applied to BOTH sides: `normalize()` to the typed term in PHP, and
 * `sqlColumn()` to the stored column inside the query, so the two agree
 * character for character.
 *
 * Folded: the harakat, tanween, shadda and sukun (U+064B–U+0652), the
 * superscript alef (U+0670) and the tatweel (U+0640) are removed; أ إ آ ٱ
 * become ا; ة becomes ه; ى becomes ي.
 *
 * No schema change: the fold runs at query time. A generated folded column is
 * the scalable follow-up if the tables grow past what a scan serves.
 *
 * MySQL only (`REGEXP_REPLACE`), which is the profile's database.
 */
final class ArabicText
{
    /** @var array<string, string> */
    private const FOLDS = [
        'أ' => 'ا',
        'إ' => 'ا',
        'آ' => 'ا',
        'ٱ' => 'ا',
        'ة' => 'ه',
        'ى' => 'ي',
    ];

    /** The marks removed — one regex class, built from code points. */
    private static function marksClass(): string
    {
        $marks = '';
        foreach ([...range(0x064B, 0x0652), 0x0670, 0x0640] as $codePoint) {
            $marks .= mb_chr($codePoint, 'UTF-8');
        }

        return '['.$marks.']';
    }

    public static function normalize(string $text): string
    {
        $bare = (string) preg_replace('/'.self::marksClass().'/u', '', $text);

        return strtr($bare, self::FOLDS);
    }

    /**
     * The SQL expression folding `$column` the way `normalize()` folds a term.
     * `$column` is a trusted identifier written by the caller, never input.
     */
    public static function sqlColumn(string $column): string
    {
        $expression = "REGEXP_REPLACE(COALESCE({$column}, ''), '".self::marksClass()."', '')";

        foreach (self::FOLDS as $from => $to) {
            $expression = "REPLACE({$expression}, '{$from}', '{$to}')";
        }

        return $expression;
    }

    /**
     * `sqlColumn()` as a query expression, for `->where(ArabicText::column('x'), 'like', …)`.
     *
     * @return Expression<literal-string>
     */
    public static function column(string $column): Expression
    {
        // The expression is built from this class's own constants and a column
        // name the caller writes in code — no input reaches it (the term goes
        // through a binding), so it is a literal string in all but type.
        /** @var literal-string $sql */
        $sql = self::sqlColumn($column);

        return new Expression($sql);
    }

    /** `%term%` with LIKE's own wildcards escaped, over the folded term. */
    public static function likePattern(string $term): string
    {
        return '%'.addcslashes(self::normalize($term), '\\%_').'%';
    }
}
