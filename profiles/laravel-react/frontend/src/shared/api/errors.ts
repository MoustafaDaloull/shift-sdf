/*
 * The platform error envelope, as TypeScript.
 *
 * Source:         docs/03-development/error-contract-standard.md
 *                 ECS-003 (structure), ECS-004 (fields), ECS-005 (details).
 * Governing rule: RS-033 / CS-045 - types are derived from the approved
 *                 contract. Not one field here is invented, and a field the
 *                 contract does not define does not get added because a
 *                 response happened to carry it.
 *
 * ECS-004 marks code, type, message and trace_id mandatory and details
 * optional, and that is exactly how they are typed. The parser below still
 * treats every one of them as untrusted, because a type assertion describes
 * what the contract promises, not what arrived over the wire.
 *
 * ECS-011 is the rule that shapes how callers use this: no logic may branch on
 * the message text. Branch on `code`, or on `type`. The message is for display
 * and is explicitly allowed to be reworded without notice.
 */

/** ECS-001 - the five approved categories. No sixth exists. */
export type ApiErrorType =
  | 'VALIDATION'
  | 'BUSINESS_RULE'
  | 'AUTHORIZATION'
  | 'SYSTEM'
  | 'INTEGRATION'

/** ECS-005 - one entry per failing field when a request fails in several places. */
export interface ApiErrorDetail {
  field: string
  code: string
  message: string
}

/** ECS-003 / ECS-004. */
export interface ApiError {
  /** ERR-[MODULE]-[CATEGORY]-### (ECS-006). Stable across languages. */
  code: string
  type: ApiErrorType
  /** Display text in the user's language. Never branch on it (ECS-011). */
  message: string
  details?: ApiErrorDetail[]
  /** Ties the response to the server-side log entry. */
  trace_id: string
}

const ERROR_TYPES: readonly ApiErrorType[] = [
  'VALIDATION',
  'BUSINESS_RULE',
  'AUTHORIZATION',
  'SYSTEM',
  'INTEGRATION',
]

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

function readString(source: Record<string, unknown>, key: string): string {
  const value = source[key]

  return typeof value === 'string' ? value : ''
}

function parseDetails(value: unknown): ApiErrorDetail[] | undefined {
  if (!Array.isArray(value)) {
    return undefined
  }

  const details = value.filter(isRecord).map((entry) => ({
    field: readString(entry, 'field'),
    code: readString(entry, 'code'),
    message: readString(entry, 'message'),
  }))

  return details.length > 0 ? details : undefined
}

/**
 * Reads an ECS envelope out of a parsed response body, or returns null.
 *
 * Returning null rather than throwing is the whole point: an error path that
 * can itself fail is a screen that shows nothing when something goes wrong.
 * A caller that gets null falls back to classifying by HTTP status, which is
 * the pattern the contract's error tables are written against.
 */
export function parseApiError(body: unknown): ApiError | null {
  if (!isRecord(body) || !isRecord(body.error)) {
    return null
  }

  const error = body.error
  const code = readString(error, 'code')
  const rawType = readString(error, 'type')

  if (code === '' || !ERROR_TYPES.includes(rawType as ApiErrorType)) {
    return null
  }

  const parsed: ApiError = {
    code,
    type: rawType as ApiErrorType,
    message: readString(error, 'message'),
    trace_id: readString(error, 'trace_id'),
  }

  const details = parseDetails(error.details)

  return details ? { ...parsed, details } : parsed
}

/**
 * Field-keyed view of ECS-005 details, for forms that show a message under
 * each input. Later entries win, matching how the details array is ordered.
 */
export function fieldErrors(error: ApiError | null): Record<string, string> {
  const map: Record<string, string> = {}

  for (const detail of error?.details ?? []) {
    if (detail.field !== '') {
      map[detail.field] = detail.message
    }
  }

  return map
}
