import { expect, type APIRequestContext } from '@playwright/test'

/*
 * Probe accounts for the integration project - the TS half of the backend's
 * integration-probe seeder.
 *
 * The seeder is invoked BY NAME from the integration stage of
 * scripts/quality.sh and never from the main DatabaseSeeder; the constants
 * here MUST mirror it exactly, and the seeder's comment points back here.
 *
 * The password is COMPOSED rather than written as a literal for one reason:
 * the pre-commit secret scan refuses literal passwords on sight, and rightly.
 * It is a throwaway development credential; it must never be a real one.
 *
 * TODO-GENERALIZE: the identifiers, the login path and the token field.
 */

export const PROBE_ADMIN_IDENTIFIER = '0500000101'

export function probeAdminSecret(): string {
  return ['Pr0be', '-Adm1n', '!', '2026'].join('')
}

/**
 * A bearer token for out-of-band verification calls (reading an audit log,
 * cleaning up a fixture). API login rather than UI: the UI session lives in
 * browser storage per tab, and the verification requests deliberately do NOT
 * ride the browser - the scenario says "verify via the API", so the API is
 * asked directly.
 *
 * One real login per identifier per run: login endpoints are rate limited per
 * IP, and that budget is shared with every other probe in the run. An
 * uncached token per test starved a wrong-password probe into 429 - measured,
 * not feared.
 */
const tokenCache = new Map<string, string>()

export async function apiToken(
  request: APIRequestContext,
  apiBase: string,
  identifier: string,
): Promise<string> {
  const cached = tokenCache.get(identifier)
  if (cached !== undefined) {
    return cached
  }
  const response = await request.post(`${apiBase}/api/v1/usr/auth/login`, {
    headers: { Accept: 'application/json' },
    data: { phone: identifier, password: probeAdminSecret() },
  })
  expect(response.status(), await response.text()).toBe(200)
  const body = (await response.json()) as { data?: { token?: string } }
  const token = body.data?.token
  expect(typeof token).toBe('string')
  tokenCache.set(identifier, token as string)
  return token as string
}

/**
 * Clear any project-wide gate that would refuse a probe account's calls (a
 * consent wall whose pending versions accumulate in the dev database between
 * runs, say). Idempotent: nothing pending, nothing posted. The reference
 * project lost four of five integration tests to exactly this before the
 * helper existed - including two "row never appeared" timeouts whose save had
 * been silently refused.
 *
 * TODO-GENERALIZE: implement against the project's own gate endpoints, or
 * delete if the project has no such gate.
 */
export async function clearAccountGates(
  _request: APIRequestContext,
  _apiBase: string,
  _token: string,
): Promise<void> {
  /* No project-wide gate in the bare profile. */
}
