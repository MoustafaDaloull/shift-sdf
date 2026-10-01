/*
 * Focus trap for a modal dialog - re-authored from the approved static
 * prototype (openModal / closeModal / the document-level Tab handler and the
 * shared Escape branch). The behaviour contract is the design system's
 * "focus trapping and restoration when a dialog closes".
 *
 * Governing rules: behavioural equivalence with the approved model; re-author
 * the behaviour, do not port the prototype's JS; function components / hooks
 * only; English code comments.
 *
 * The prototype's five behaviours, kept one for one:
 *   1. remember document.activeElement as the trigger before the dialog opens;
 *   2. set overflow:hidden on <body> while it is open;
 *   3. focus [data-modal-autofocus] first, else the .modal-close button;
 *   4. cycle Tab / Shift+Tab inside the container, and pull focus back in if it
 *      has escaped altogether;
 *   5. on close, restore body overflow and return focus to the trigger.
 *
 * What this hook deliberately does NOT do:
 *   · It pulls in no focus-trap library. The prototype writes its own, and the
 *     approved stack adds no dependency for this.
 *   · It does not widen the prototype's focusable selector. The source lists
 *     a[href], button, input, select and textarea and nothing else - no
 *     [tabindex], no [contenteditable], no <summary>. Widening it would change
 *     which element Tab lands on, which is a behaviour change, not a fix.
 *   · It does not save and restore the previous body overflow value. The
 *     prototype assigns the empty string on close, and a modal opened over an
 *     already-locked body is not a state the approved model has.
 *   · It does not stack. The prototype has one modal open at a time.
 */

import { useEffect, useRef } from 'react'
import type { RefObject } from 'react'

/*
 * The prototype's selector verbatim. Kept as a single string so a reviewer can
 * diff it against the source line rather than against a reformatted list.
 */
const FOCUSABLE_SELECTOR =
  'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled])'

/**
 * Traps keyboard focus inside the returned ref's element while `active` is true.
 *
 * @param active whether the dialog is currently open.
 * @param onEscape called when Escape is pressed while the dialog is open.
 * @returns a ref to attach to the element that contains the dialog.
 */
export function useFocusTrap<TElement extends HTMLElement>(
  active: boolean,
  onEscape: () => void,
): RefObject<TElement | null> {
  const containerRef = useRef<TElement | null>(null)
  // Held in a ref so that a new inline onEscape on every render does not tear
  // the trap down and rebuild it - which would re-run the initial focus.
  const onEscapeRef = useRef(onEscape)

  useEffect(() => {
    onEscapeRef.current = onEscape
  }, [onEscape])

  useEffect(() => {
    const container = containerRef.current
    if (!active || container === null) {
      return undefined
    }

    const activeElement = document.activeElement
    const trigger = activeElement instanceof HTMLElement ? activeElement : null

    document.body.style.overflow = 'hidden'

    const initialTarget =
      container.querySelector<HTMLElement>('[data-modal-autofocus]') ??
      container.querySelector<HTMLElement>('.modal-close')
    initialTarget?.focus()

    // Declared as a const arrow rather than a hoisted `function`: TypeScript
    // drops the non-null narrowing of `container` inside a hoisted
    // declaration, because such a function exists before the guard runs.
    const handleKeyDown = (event: KeyboardEvent): void => {
      if (event.key === 'Escape') {
        onEscapeRef.current()
        return
      }
      if (event.key !== 'Tab') {
        return
      }

      const focusables = container.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR)
      const first = focusables[0]
      const last = focusables[focusables.length - 1]
      if (first === undefined || last === undefined) {
        return
      }

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault()
        first.focus()
      } else if (!container.contains(document.activeElement)) {
        event.preventDefault()
        first.focus()
      }
    }

    document.addEventListener('keydown', handleKeyDown)

    return () => {
      document.removeEventListener('keydown', handleKeyDown)
      document.body.style.overflow = ''
      trigger?.focus()
    }
  }, [active])

  return containerRef
}
