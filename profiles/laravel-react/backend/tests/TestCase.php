<?php

declare(strict_types=1);

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\Cache;

abstract class TestCase extends BaseTestCase
{
    /**
     * Seeding is a property of the suite, not of whichever class sorts first.
     *
     * `RefreshDatabase` runs `migrate:fresh` ONCE per PHP process and passes
     * the FIRST class's `$seed` to it, so a first-alphabetical class without
     * the flag leaves the whole run unseeded (dozens of unrelated tests fell
     * in the reference project without a line changing in them). Declared
     * here, every class inherits it; the per-class declarations stay harmless.
     */
    protected bool $seed = true;

    /**
     * Every test starts on an empty cache.
     *
     * ── Why this is not already true ──────────────────────────────────────
     * `phpunit.xml` declares `CACHE_STORE=array`, which reads like isolation
     * and is not: PHPUnit's `<env>` does not overwrite a variable that
     * already exists in the environment, and `docker/compose/compose.test.yaml`
     * exports `CACHE_STORE: redis` for the runner. The overlay wins. So the
     * suite runs against a **real Redis instance that outlives both the test
     * and the run**, while the file everyone reads says otherwise.
     *
     * It goes unnoticed until the first test reads the cache back and fails
     * on a value another test had cached — or, the harder version, a value
     * cached by the *previous run*.
     *
     * `RefreshDatabase` rolls back the database and knows nothing about the
     * cache; this is the missing half of the same guarantee. Deliberately
     * not "fixed" by forcing the array store instead: testing on a different
     * engine than production has already cost once (SQLite has no triggers,
     * so append-only passed green while the constraint did not exist), and a
     * cache is worth exercising on the driver that ships.
     */
    protected function setUp(): void
    {
        parent::setUp();

        Cache::flush();
    }
}
