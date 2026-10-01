<?php

declare(strict_types=1);

use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| _Example routes — the shape, with no endpoint registered
|--------------------------------------------------------------------------
|
| The `/api` prefix and the `api` middleware group are added in
| `ExampleServiceProvider`, so paths start at `v1/<code>/...` and the full
| form matches API-005: `/api/v1/<code>/<resource>`.
|
| Every route below is COPIED from a row of the module's api-contracts.md and
| carries that row's id (API-<CODE>-###) in a comment, with the test scenarios
| it serves. A route with no backing row is invented scope.
|
| Routes that need an order (a literal segment such as `export` before a
| `{id}` parameter) are declared in that order and the reason is written
| beside them — the parser answers 422 on `export` otherwise.
|
*/
Route::prefix('v1/exm')
    ->middleware(['auth:sanctum', 'throttle:exm-read'])
    ->group(static function (): void {
        // API-EXM-001 — TS-EXM-001..003
        // Route::get('things', [ThingController::class, 'index'])->name('exm.things.index');

        // API-EXM-002 — TS-EXM-004..006
        // Route::get('things/{id}', [ThingController::class, 'show'])->name('exm.things.show');
    });
