/*
 * Shared HTTP client.
 *
 * Source:         docs/03-development/api-design-standard.md (versioned /api/v1
 *                 paths, API-005) and error-contract-standard.md ECS-003.
 * Governing rule: RS-030 (shared/api owns the HTTP client, the response
 *                 envelope and error handling in one place), CS-044 (no
 *                 component calls fetch), RS-003 (no secret rides in a VITE_*
 *                 variable - only the base URL does).
 *
 * Two load-bearing decisions:
 *
 *   1. This never throws. Every outcome is a discriminated union on `kind`, so
 *      a screen handles them with an exhaustive switch and the compiler tells
 *      it when a case is missing. A rejected promise is a state a screen
 *      forgets to render; a union member is one it cannot.
 *
 *   2. Classification is by HTTP status first. The ECS envelope is parsed and
 *      handed over when present, but nothing depends on it being well formed -
 *      a malformed error body must not break the error path itself.
 *
 * WHAT THIS DELIBERATELY DOES NOT DO
 * ---------------------------------------------------------------------------
 * No caching, no retries, no request deduplication, no polling. A query layer
 * (TanStack Query, say) arrives with the first screen that needs it, wrapping
 * this module rather than replacing it. An unused runtime dependency is one
 * the dependency audit flags and nothing exercises.
 *
 * No mock, no fixture, no seeded response. The client calls the endpoint it is
 * given; a screen whose endpoint does not exist yet renders its error state -
 * that is the honest signal.
 *
 * No token handling. The `token` argument is passed in by whoever holds the
 * session. Session EXPIRY is handled once, for every request, by
 * sessionExpiry.ts.
 *
 * PROJECT-WIDE REFUSALS
 * ---------------------------------------------------------------------------
 * A project may have one error code that no screen can do anything useful
 * with (a consent wall, a forced password change, a suspended account). The
 * right place to react is here - the one place that still holds the error
 * CODE (ECS-011 forbids branching on the message) - with a full navigation
 * to the screen where the only ways forward live. Add such a hook beside
 * `classify` below, keyed on `error.code`, and make sure that screen's own
 * calls are exempt so no loop is possible.
 */

import { parseApiError } from './errors'
import type { ApiError } from './errors'

const API_BASE: string = import.meta.env.VITE_API_BASE_URL ?? ''

export type ApiResult<T> =
  /** 2xx with a body that parsed. */
  | { kind: 'success'; data: T }
  /** 401 - no session, or an expired one. */
  | { kind: 'unauthenticated'; error: ApiError | null }
  /** 403 - authenticated, not permitted. */
  | { kind: 'forbidden'; error: ApiError | null }
  /** 404 - the resource is absent, or hidden from this caller. */
  | { kind: 'notfound'; error: ApiError | null }
  /** 422 - ECS VALIDATION; `error.details` carries the per-field messages. */
  | { kind: 'invalid'; error: ApiError | null }
  /** 409 - ECS BUSINESS_RULE. Branch on `error.code`, never on the message. */
  | { kind: 'conflict'; error: ApiError | null }
  /** 429 - rate limited. */
  | { kind: 'throttled'; error: ApiError | null }
  /** Network failure, 5xx, an unmapped status, or a body that would not parse. */
  | { kind: 'failure'; error: ApiError | null }

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'
  /** Serialised as JSON. Omit for GET. */
  body?: unknown
  /** Bearer token, when the endpoint requires a session. */
  token?: string
  /** Cancels the request when the caller unmounts. */
  signal?: AbortSignal
  /**
   * Returns the WHOLE parsed body instead of `body.data`.
   *
   * Only `requestList` sets it, and only because a list's page block sits
   * beside the rows rather than inside them. It is on the options object and
   * not a separate transport so that the base URL, the headers, the status
   * classification and the never-throws contract stay written once.
   */
  rawEnvelope?: boolean
}

function buildHeaders(token: string | undefined, hasBody: boolean): HeadersInit {
  const headers: Record<string, string> = { Accept: 'application/json' }

  if (hasBody) {
    headers['Content-Type'] = 'application/json'
  }

  if (token !== undefined && token !== '') {
    headers.Authorization = `Bearer ${token}`
  }

  return headers
}

/*
 * ECS-008 maps categories onto status codes; this is the inverse, and only the
 * statuses the standard actually assigns. Anything else is `failure` - a status
 * with no approved handling is not something to guess at on screen.
 */
function classify(status: number, error: ApiError | null): ApiResult<never> {
  switch (status) {
    case 401:
      return { kind: 'unauthenticated', error }
    case 403:
      return { kind: 'forbidden', error }
    case 404:
      return { kind: 'notfound', error }
    case 409:
      return { kind: 'conflict', error }
    case 422:
      return { kind: 'invalid', error }
    case 429:
      return { kind: 'throttled', error }
    default:
      return { kind: 'failure', error }
  }
}

/**
 * Performs one request against a versioned platform endpoint.
 *
 * `path` is the full versioned path from the module's api-contracts.md, copied
 * literally - `/api/v1/<code>/<resource>`, not a fragment this function
 * assembles. API-005 makes the path part of the contract, and building it here
 * from parts would put a second, silent definition of it in the frontend.
 *
 * `T` is the type of the `data` field, derived from the same contract
 * (RS-033). It is asserted, not validated: the contract is the agreement, and
 * a runtime schema check here would be a second source of truth for a shape
 * the backend already owns and the OpenAPI gate already compares.
 */
export async function request<T>(path: string, options: RequestOptions = {}): Promise<ApiResult<T>> {
  const { method = 'GET', body, token, signal, rawEnvelope = false } = options
  const hasBody = body !== undefined

  let response: Response

  try {
    response = await fetch(`${API_BASE}${path}`, {
      method,
      headers: buildHeaders(token, hasBody),
      ...(hasBody ? { body: JSON.stringify(body) } : {}),
      ...(signal ? { signal } : {}),
    })
  } catch {
    // Offline, DNS failure, CORS rejection, or an aborted request. The caller
    // that aborted is unmounting and will not read this.
    return { kind: 'failure', error: null }
  }

  // 204 carries no body by definition, so there is nothing to parse.
  if (response.status === 204) {
    return { kind: 'success', data: undefined as T }
  }

  let payload: unknown

  try {
    payload = await response.json()
  } catch {
    // A 2xx that promised JSON and did not deliver is as broken as a 5xx.
    return { kind: 'failure', error: null }
  }

  if (!response.ok) {
    const error = parseApiError(payload)

    return classify(response.status, error) as ApiResult<T>
  }

  if (rawEnvelope) {
    return { kind: 'success', data: payload as T }
  }

  const envelope = payload as { data?: T }

  return { kind: 'success', data: envelope.data as T }
}

/**
 * Pagination block, as returned by every list endpoint.
 *
 * Source: api-design-standard.md API-015. The names are the contract's.
 */
export interface Pagination {
  page: number
  page_size: number
  total_items: number
  total_pages: number
}

/*
 * MULTIPART, AND WHY IT IS A SECOND FUNCTION RATHER THAN A FLAG
 * ---------------------------------------------------------------------------
 * Upload endpoints take `multipart/form-data`. That differs from `request` in
 * exactly one way that matters and one that does not:
 *
 *   · The Content-Type header must NOT be set. The browser writes it itself,
 *     including the boundary token it generates - and a hand-written
 *     `multipart/form-data` without that boundary produces a body the server
 *     cannot split, which surfaces as "file is required" rather than as a
 *     header problem. Adding a `multipart: true` flag to `request` would put
 *     that trap one boolean away from every JSON caller.
 *   · Everything else - the base URL, the envelope, the status classification,
 *     the never-throws contract - is identical, so it is shared, not copied.
 *
 * Progress reporting is deliberately absent: `fetch` cannot report upload
 * progress, and faking it with a timer would draw a bar that means nothing.
 * For real progress on a large file see directUpload.ts (XMLHttpRequest).
 */
export async function requestUpload<T>(
  path: string,
  form: FormData,
  options: { token?: string; signal?: AbortSignal; rawEnvelope?: boolean } = {},
): Promise<ApiResult<T>> {
  const { token, signal, rawEnvelope = false } = options

  const headers: Record<string, string> = { Accept: 'application/json' }

  if (token !== undefined && token !== '') {
    headers.Authorization = `Bearer ${token}`
  }

  let response: Response

  try {
    response = await fetch(`${API_BASE}${path}`, {
      method: 'POST',
      headers,
      body: form,
      ...(signal ? { signal } : {}),
    })
  } catch {
    return { kind: 'failure', error: null }
  }

  if (response.status === 204) {
    return { kind: 'success', data: undefined as T }
  }

  let payload: unknown

  try {
    payload = await response.json()
  } catch {
    return { kind: 'failure', error: null }
  }

  if (!response.ok) {
    const error = parseApiError(payload)

    return classify(response.status, error) as ApiResult<T>
  }

  // `rawEnvelope` for the same reason `request` has it: a block that sits
  // BESIDE `data` rather than inside it (`pagination`, `warnings`) cannot be
  // reached by returning `data` alone.
  return {
    kind: 'success',
    data: (rawEnvelope ? payload : (payload as { data?: T }).data) as T,
  }
}

/**
 * A LIST endpoint, whose envelope carries `pagination` beside `data` (API-015).
 *
 * `request` returns `envelope.data` and nothing else, which is right for every
 * single-resource read and wrong for a paginated one: the page block sits NEXT
 * TO the rows, not inside them. So `request<{data, pagination}>` hands back the
 * row ARRAY typed as the whole envelope, the screen reads `page.total_pages`
 * off an array, and gets `undefined` - with nothing red anywhere, because the
 * type assertion `request` admits to in its own header is what hides it.
 *
 * A list therefore gets its own function, returning both halves explicitly.
 * A missing or malformed `pagination` degrades to a single page covering the
 * rows in hand rather than throwing: the rows are what the screen renders, and
 * the page block is only a claim about what else exists.
 */
export async function requestList<T>(
  path: string,
  options: RequestOptions = {},
): Promise<ApiResult<{ rows: T[]; page: Pagination }>> {
  const result = await request<unknown>(path, { ...options, rawEnvelope: true })

  if (result.kind !== 'success') {
    return result as ApiResult<{ rows: T[]; page: Pagination }>
  }

  const envelope = result.data as { data?: unknown; pagination?: unknown }
  const rows = Array.isArray(envelope.data) ? (envelope.data as T[]) : []

  return { kind: 'success', data: { rows, page: readPage(envelope.pagination, rows.length) } }
}

/** A total reader for API-015's page block. Anything absent falls back. */
function readPage(block: unknown, rowCount: number): Pagination {
  const source = (block ?? {}) as Record<string, unknown>
  const num = (key: string, fallback: number): number => {
    const value = source[key]
    return typeof value === 'number' && Number.isFinite(value) ? value : fallback
  }

  return {
    page: num('page', 1),
    page_size: num('page_size', rowCount),
    total_items: num('total_items', rowCount),
    total_pages: num('total_pages', 1),
  }
}
