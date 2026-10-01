import { test as setup } from '@playwright/test'

/*
 * The routes are compiled before the clock starts, not during.
 *
 * -- What was measured ------------------------------------------------------
 * Vite's dev server transforms a lazily-loaded route the first time anyone
 * asks for it. Every stage in scripts/quality.sh is a separate Playwright
 * invocation with a freshly started server, so that cost is paid again in
 * every stage - and it lands inside the first navigating test, which has the
 * ordinary 30s budget like any other. That produced exactly one failure per
 * project, always on the first route each project reaches; re-measured alone,
 * the same test finished in 12s. Nothing was wrong with the code; the first
 * caller was paying a build cost.
 *
 * -- Why this is not the thing the framework forbids ------------------------
 * The framework forbids raising a timeout or a threshold so that a failing
 * check passes. This raises neither. Every measured test keeps its 30s budget
 * and every assertion is untouched - a genuinely broken route still fails the
 * test that checks it, which is proven by deliberate breach rather than
 * argued. What moves is WHEN compilation happens, not WHAT is checked.
 *
 * This file asserts nothing on purpose. It is a preparation step, and its own
 * generous timeout applies only to itself.
 *
 * -- Why per server ---------------------------------------------------------
 * Two dev servers serve two different bundles (5174 mocked, 5175 against the
 * real backend - see the webServer notes in playwright.config.ts), so each
 * needs its own first navigation. One route per server pays the app-shell
 * cost once; the per-route chunks that follow are small.
 */

// Absolute, not baseURL-relative: one warm-up project cannot carry two
// baseURLs, and these two ports are fixed by the webServer block in
// playwright.config.ts rather than being anyone's preference.
// TODO-GENERALIZE: the first route each surface reaches.
const ADMIN_ENTRY = 'http://127.0.0.1:5174/admin/login'
const CLIENT_ENTRY = 'http://127.0.0.1:5175/login'

// Generous, and deliberately only for the warm-up: a cold first compile on a
// loaded machine has been measured near 30s, and this step exists precisely so
// no measured test ever waits for it.
const WARMUP_TIMEOUT = 120_000

setup('warm the admin bundle', async ({ page }) => {
  setup.setTimeout(WARMUP_TIMEOUT)
  await page.goto(ADMIN_ENTRY, { waitUntil: 'load', timeout: WARMUP_TIMEOUT })
})

setup('warm the client bundle against the real backend', async ({ page }) => {
  setup.setTimeout(WARMUP_TIMEOUT)
  await page.goto(CLIENT_ENTRY, { waitUntil: 'load', timeout: WARMUP_TIMEOUT })
})
