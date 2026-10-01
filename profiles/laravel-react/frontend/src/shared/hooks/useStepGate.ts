/*
 * useStepGate - the step-by-step validation gate every multi-step form uses.
 * ---------------------------------------------------------------------------
 * Governing rule (CS-051, the multi-step form standard) -
 *   (a) «السابق»/«رجوع» never renders on the first step. The hook exposes
 *       `isFirst`; the screen does not draw the back control while it is true.
 *   (b) «التالي» is never silently disabled. `next()` validates ONLY the current
 *       step; on failure it stays, publishes the per-field messages and focuses
 *       the first invalid field. Only a valid step advances.
 *   (c) `submitGuard()` validates every step before the final submit. When a
 *       step fails it moves to the FIRST failing step, shows its messages and
 *       returns false - the caller does not call the server.
 *   (d) `back()` / `goTo()` to an earlier step never validate.
 *   (e) The server stays the authority: a 422 is still mapped by the screen
 *       with `setErrors(...)` and `goTo(step)`.
 *
 * The hook is pure state; it renders nothing and knows no markup. The screen
 * keeps its own field-error display (a FormField `error` prop, `.error-text`,
 * `aria-invalid` ...) and reads `errors[field]` into it. The wizard markup
 * component stays state-free on purpose: the gate lives here, the markup
 * there, and the screen composes both.
 *
 * `validateStep(index)` returns `{ field: message }` for the given step; an
 * empty object means the step is valid. The field keys are the screen's own
 * (usually the API field names, so a 422 lands on the same key).
 *
 * Focus lookup: after the failing step is on screen, the first key of the
 * failing step's result is resolved to an element by, in order,
 *   1. `document.getElementById(fieldElementId(field))` - by default the key
 *      itself; screens whose control ids differ from their keys (e.g. `c-name`
 *      for `name`) pass a mapper,
 *   2. `[name="<mapped id>"]`, then `[name="<field>"]` - the first match, so
 *      a radio group mapped to its shared `name` focuses its first radio.
 * If neither exists nothing is focused; the messages still render. Order the
 * keys in `validateStep` the way the fields are laid out on screen, because
 * "first invalid field" is the first key.
 */

import { useCallback, useEffect, useRef, useState } from 'react'

export type StepErrors = Record<string, string>

/*
 * The two plain messages for a rule whose screen spec defines no sentence of
 * its own. A spec's own message always wins over these.
 */
export const MSG_STEP_FIELD_REQUIRED = 'هذا الحقل مطلوب'
export const MSG_STEP_FIELD_INVALID = 'القيمة غير صالحة'

export interface StepGateOptions {
  /** Number of steps in the wizard. */
  stepCount: number
  /** Field -> message for the given step; empty object = step is valid. */
  validateStep: (index: number) => StepErrors
  /** Maps a field key to its control's element id. Default: the key itself. */
  fieldElementId?: (field: string) => string
  /** Zero-based step shown on arrival. Default 0. */
  initialStep?: number
}

export interface StepGate {
  step: number
  errors: StepErrors
  isFirst: boolean
  isLast: boolean
  /** Validate the current step; advance only when it is valid. */
  next: () => boolean
  /** One step back, never validating. */
  back: () => void
  /** Jump to a step without validating (server-error mapping, review edits). */
  goTo: (index: number) => void
  /** Validate every step; on failure show the first failing step. */
  submitGuard: () => boolean
  setErrors: (errors: StepErrors) => void
  /** Remove one field's message - call it from the field's onChange. */
  clearError: (field: string) => void
  /** Focus the first of these fields once the current render lands. */
  focusField: (field: string) => void
}

function escapeAttr(value: string): string {
  return typeof CSS !== 'undefined' && typeof CSS.escape === 'function'
    ? CSS.escape(value)
    : value.replace(/"/g, '\\"')
}

function findFieldElement(field: string, elementId: string): HTMLElement | null {
  const byId = document.getElementById(elementId)
  if (byId !== null) return byId
  for (const name of elementId === field ? [field] : [elementId, field]) {
    const byName = document.querySelector<HTMLElement>(`[name="${escapeAttr(name)}"]`)
    if (byName !== null) return byName
  }
  return null
}

export function useStepGate({
  stepCount,
  validateStep,
  fieldElementId,
  initialStep = 0,
}: StepGateOptions): StepGate {
  const last = Math.max(0, stepCount - 1)
  const [step, setStep] = useState(() => Math.max(0, Math.min(initialStep, last)))
  const [errors, setErrorsState] = useState<StepErrors>({})
  /* A fresh object per request, so a repeated failure on the same field
     re-focuses it; the ref keeps an unrelated re-render from focusing again. */
  const [pendingFocus, setPendingFocus] = useState<{ field: string } | null>(null)
  const handledFocus = useRef<{ field: string } | null>(null)

  useEffect(() => {
    if (pendingFocus === null || handledFocus.current === pendingFocus) return
    handledFocus.current = pendingFocus
    const { field } = pendingFocus
    findFieldElement(field, fieldElementId ? fieldElementId(field) : field)?.focus()
  }, [pendingFocus, fieldElementId])

  const focusField = useCallback((field: string) => {
    setPendingFocus({ field })
  }, [])

  const fail = useCallback(
    (index: number, found: StepErrors) => {
      setStep(index)
      setErrorsState(found)
      const first = Object.keys(found)[0]
      if (first !== undefined) focusField(first)
    },
    [focusField],
  )

  const next = useCallback((): boolean => {
    const found = validateStep(step)
    if (Object.keys(found).length > 0) {
      fail(step, found)
      return false
    }
    setErrorsState({})
    setStep((current) => Math.min(last, current + 1))
    return true
  }, [validateStep, step, fail, last])

  const back = useCallback(() => {
    setStep((current) => Math.max(0, current - 1))
  }, [])

  const goTo = useCallback(
    (index: number) => {
      setStep(Math.max(0, Math.min(index, last)))
    },
    [last],
  )

  const submitGuard = useCallback((): boolean => {
    for (let index = 0; index < stepCount; index += 1) {
      const found = validateStep(index)
      if (Object.keys(found).length > 0) {
        fail(index, found)
        return false
      }
    }
    return true
  }, [stepCount, validateStep, fail])

  const setErrors = useCallback((next: StepErrors) => {
    setErrorsState(next)
  }, [])

  const clearError = useCallback((field: string) => {
    setErrorsState((current) => {
      if (!(field in current)) return current
      const rest = { ...current }
      delete rest[field]
      return rest
    })
  }, [])

  return {
    step,
    errors,
    isFirst: step === 0,
    isLast: step === last,
    next,
    back,
    goTo,
    submitGuard,
    setErrors,
    clearError,
    focusField,
  }
}
