<?php

declare(strict_types=1);

namespace App\Modules\_Example;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

/**
 * _Example — the shape of a module service provider. No business code.
 *
 * Replace `_Example`/`Example` with the module's full PascalCase name and
 * `exm` with its three-letter code; register it in bootstrap/providers.php in
 * its wave's position; add its layer and ruleset row to deptrac.yaml.
 */
final class ExampleServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // Bind every cross-module contract this module PUBLISHES
        // (app/Shared/Contracts/<ModuleName>/*Interface) to its implementation
        // in Application/. The consumer injects the interface and never learns
        // the class name. Example:
        //
        //   $this->app->singleton(SomethingReaderInterface::class, SomethingReader::class);
    }

    public function boot(): void
    {
        // RS-014 · RS-015 — migrations live inside the module, never in
        // database/migrations.
        $this->loadMigrationsFrom(__DIR__.'/Infrastructure/Migrations');

        $this->registerRateLimiter();

        $routes = __DIR__.'/Http/routes.php';

        if (file_exists($routes)) {
            // Prefix and middleware group belong here, not in the routes
            // file: `loadRoutesFrom` registers outside any group, and
            // without them the routes would miss the `api` middleware and
            // with it the `X-Trace-Id` that API-021 requires.
            Route::middleware('api')
                ->prefix('api')
                ->group(fn () => $this->loadRoutesFrom($routes));
        }

        // Listeners for integration events this module CATCHES are registered
        // here as well, the day the first one exists:
        //
        //   Event::listen(SomethingHappened::class, ReactToSomething::class);
    }

    /**
     * `SEC-014` · `API-025` — every endpoint of a module is rate limited, and
     * the figure comes from the module's api-contracts.md, never from here.
     *
     * Keyed by USER for authenticated endpoints, not by IP: an IP key lets one
     * administrator on a shared office connection consume the whole allowance
     * for their colleagues. Unauthenticated endpoints fall back to the IP.
     */
    private function registerRateLimiter(): void
    {
        RateLimiter::for('exm-read', static function (Request $request): Limit {
            $key = (string) ($request->user()?->getAuthIdentifier() ?? ($request->ip() ?? 'unknown'));

            // TODO-GENERALIZE: the number is the contract's, cited beside it.
            return Limit::perMinute(30)->by($key);
        });
    }
}
