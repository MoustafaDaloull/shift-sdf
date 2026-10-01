/*
 * One file, sent straight to an object store, with progress.
 * ---------------------------------------------------------------------------
 * Governing rule: RS-030 / CS-044 - shared/api owns every request a screen
 * makes; no component opens a connection itself. This is the second transport
 * beside `client.ts`, and it is a separate file for the reason `requestUpload`
 * is a separate function there: it differs in the ways that matter.
 *
 * -- WHY THIS IS NOT `request()` --------------------------------------------
 *   · THE DESTINATION IS NOT THE PLATFORM'S API. The URL is an upload session
 *     address the API issued for one object. It is used exactly as given - no
 *     base URL is put in front of it.
 *   · NO BEARER TOKEN, EVER. The session address is itself the authorisation
 *     for that one upload; the user's token must not be sent to a third-party
 *     host, and there is no parameter here through which it could be.
 *   · NO ENVELOPE. The store answers in its own format, not `{success, data}`;
 *     nothing in the body is read. The outcome is the status alone, and what
 *     the upload BECAME is asked of the platform afterwards.
 *
 * -- WHY XMLHttpRequest AND NOT fetch ---------------------------------------
 * `fetch` cannot report upload progress, and faking it with a timer would draw
 * a bar that means nothing. A file of hundreds of megabytes on a phone
 * connection takes minutes, and a screen that accepts one needs a progress
 * indication for exactly that case. `upload.onprogress` is the one browser
 * API that reports real bytes sent.
 *
 * Like `request`, this never throws: every outcome is a member of a union.
 */

export type DirectUploadResult =
  /** The store accepted the whole file (2xx). */
  | { kind: 'success' }
  /** The caller aborted - it is unmounting and will not read this. */
  | { kind: 'aborted' }
  /** Refused, interrupted, offline, or blocked. `status` is null when no answer arrived. */
  | { kind: 'failure'; status: number | null }

export interface DirectUploadOptions {
  /** The verb the session expects. */
  method: 'PUT' | 'POST'
  /** Headers the issuer of the address asks for (e.g. `Content-Type`). */
  headers?: Record<string, string>
  /** Called with whole percentages, 0-100, as bytes leave the browser. */
  onProgress?: (percent: number) => void
  /** Aborts the transfer when the caller unmounts or cancels. */
  signal?: AbortSignal
}

export function sendFileDirect(
  url: string,
  file: Blob,
  options: DirectUploadOptions,
): Promise<DirectUploadResult> {
  const { method, headers = {}, onProgress, signal } = options

  return new Promise<DirectUploadResult>((resolve) => {
    if (signal?.aborted === true) {
      resolve({ kind: 'aborted' })
      return
    }

    const xhr = new XMLHttpRequest()
    const abort = () => {
      xhr.abort()
    }
    const settle = (result: DirectUploadResult) => {
      signal?.removeEventListener('abort', abort)
      resolve(result)
    }

    xhr.open(method, url)

    for (const [name, value] of Object.entries(headers)) {
      xhr.setRequestHeader(name, value)
    }

    xhr.upload.onprogress = (event) => {
      if (onProgress !== undefined && event.lengthComputable && event.total > 0) {
        onProgress(Math.min(100, Math.floor((event.loaded / event.total) * 100)))
      }
    }

    xhr.onload = () => {
      settle(xhr.status >= 200 && xhr.status < 300 ? { kind: 'success' } : { kind: 'failure', status: xhr.status })
    }
    xhr.onerror = () => {
      // Offline, a dropped connection, or a cross-origin refusal - the
      // browser does not say which, by design.
      settle({ kind: 'failure', status: null })
    }
    xhr.ontimeout = () => {
      settle({ kind: 'failure', status: null })
    }
    xhr.onabort = () => {
      settle({ kind: 'aborted' })
    }

    signal?.addEventListener('abort', abort, { once: true })

    xhr.send(file)
  })
}
