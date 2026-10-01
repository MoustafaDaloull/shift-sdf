/*
 * Session expiry - handled once, for every request.
 * ---------------------------------------------------------------------------
 * The server ends sessions on its own: a password reset ends them all, a
 * password change ends every other one, an approved account deletion ends
 * them too. The next request then answers 401 ERR-SYS-AUZ-001. But the
 * screens read that 401 one by one - a hundred of them, each with its own
 * fetch - and most render it as a generic error, so the ended session stays
 * on screen as if it were alive.
 *
 * This is the one place that sees every response. When a request that
 * carried the stored session's own bearer token comes back 401 with the
 * session codes (ERR-SYS-AUZ-001 unauthenticated · ERR-SYS-AUZ-003 expired),
 * that stored session is cleared and the browser goes to the matching
 * sign-in page. Nothing else is touched:
 *   - a 401 with any other code (a wrong CURRENT password, say) is the
 *     screen's to handle;
 *   - a request carrying some other token (an old tab's, a temporary social
 *     token) says nothing about the stored session.
 *
 * Install once, before the first render: `installSessionExpiryHandler()` in
 * main.tsx.
 *
 * The storage keys are the two session stores' own; they are repeated here
 * rather than imported so this shared file does not depend on a module.
 * TODO-GENERALIZE: STORAGE_PREFIX and the two sign-in paths.
 */

const STORAGE_PREFIX = 'app'

const CLIENT_TOKEN_KEY = `${STORAGE_PREFIX}.client.token`
const CLIENT_USER_KEY = `${STORAGE_PREFIX}.client.user`
const ADMIN_TOKEN_KEY = `${STORAGE_PREFIX}.admin.token`
const ADMIN_USER_KEY = `${STORAGE_PREFIX}.admin.user`

const CLIENT_LOGIN_PATH = '/login'
const ADMIN_LOGIN_PATH = '/admin/login'

const SESSION_CODES: ReadonlySet<string> = new Set(['ERR-SYS-AUZ-001', 'ERR-SYS-AUZ-003'])

function read(storage: () => Storage, key: string): string | null {
  try {
    return storage().getItem(key)
  } catch {
    return null
  }
}

function remove(storage: () => Storage, keys: readonly string[]): void {
  try {
    for (const key of keys) storage().removeItem(key)
  } catch {
    /* Storage unavailable - nothing was stored there. */
  }
}

function bearerOf(input: RequestInfo | URL, init: RequestInit | undefined): string | null {
  const headers = new Headers(init?.headers ?? (input instanceof Request ? input.headers : undefined))
  const value = headers.get('Authorization')
  if (value === null || !value.startsWith('Bearer ')) return null
  return value.slice('Bearer '.length)
}

async function sessionCodeOf(response: Response): Promise<string | null> {
  try {
    const body: unknown = await response.clone().json()
    if (typeof body !== 'object' || body === null) return null
    const error = (body as { error?: { code?: unknown } }).error
    return typeof error?.code === 'string' ? error.code : null
  } catch {
    return null
  }
}

let installed = false

export function installSessionExpiryHandler(): void {
  if (installed || typeof window === 'undefined') return
  installed = true

  const original = window.fetch.bind(window)
  const local = () => window.localStorage
  const session = () => window.sessionStorage

  window.fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    const response = await original(input, init)
    if (response.status !== 401) return response

    const token = bearerOf(input, init)
    if (token === null) return response

    const code = await sessionCodeOf(response)
    if (code === null || !SESSION_CODES.has(code)) return response

    if (token === read(local, ADMIN_TOKEN_KEY) || token === read(session, ADMIN_TOKEN_KEY)) {
      // Both storages are cleared: a session store that migrated from
      // sessionStorage to localStorage leaves the old location behind.
      remove(local, [ADMIN_TOKEN_KEY, ADMIN_USER_KEY])
      remove(session, [ADMIN_TOKEN_KEY, ADMIN_USER_KEY])
      window.location.assign(ADMIN_LOGIN_PATH)
    } else if (token === read(local, CLIENT_TOKEN_KEY)) {
      remove(local, [CLIENT_TOKEN_KEY, CLIENT_USER_KEY])
      window.location.assign(CLIENT_LOGIN_PATH)
    }

    return response
  }
}
