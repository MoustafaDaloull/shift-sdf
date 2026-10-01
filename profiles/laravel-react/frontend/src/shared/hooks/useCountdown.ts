/*
 * Countdown to an absolute target time.
 *
 * Re-authored from the approved static prototype's `[data-countdown]`
 * behaviour (the rendered result must match the approved model; the
 * prototype's JS is re-authored, never ported line for line; no network here -
 * this is arithmetic over the clock).
 *
 * What the prototype does, exactly, so the differences below are visible:
 *   var total = ((d*24 + h)*60 + m)*60 + (s||0);      // seconds
 *   setInterval(function(){ if(t.left>0){ t.left--; renderTimer(t); } }, 1000);
 *   d = floor(left/86400); h = floor(left%86400/3600);
 *   m = floor(left%3600/60); s = floor(left%60);
 * It never goes below zero: at zero the guard stops the decrement and the
 * element keeps showing 00 in every unit. There is no callback, no class swap,
 * no text change and no navigation when it reaches zero - nothing at all
 * happens. This hook reproduces that ending precisely: `ended` turns true, the
 * four numbers sit at zero, and no other behaviour is implied.
 *
 * Deliberate difference: the prototype counts down a *duration* held in a
 * local variable and decrements it, which drifts against the wall clock and
 * resets on reload. This hook takes a *target time* and derives the remainder
 * from a ticking `now`, which is what a real screen needs. The visible output
 * is identical - the same four floored numbers - because it is the same
 * arithmetic applied to the same remaining seconds.
 *
 * Shape of the state, and why: the only state is `now`, and the remainder is
 * derived from it during render. Storing the remainder instead would mean
 * writing state from an effect whenever `target` changed, which
 * react-hooks/set-state-in-effect refuses - and rightly, since deriving is both
 * simpler and correct on the very first render after a target changes.
 *
 * The interval stops itself once the target is reached: `ended` is in the
 * dependency list, so the run that observes the end tears the timer down.
 *
 * What this deliberately does not do:
 *  - It does not pad. The prototype pads at render time, so padding belongs
 *    to the Countdown component, not here.
 *  - It does not fire a callback, emit an event, or expose an "onEnd" hook.
 *    The model has no such behaviour and inventing one is forbidden.
 *  - It does not clamp days to any maximum, nor drop empty leading units.
 *    Which units get displayed is the caller's choice.
 */

import { useEffect, useState } from 'react'

export interface CountdownParts {
  days: number
  hours: number
  minutes: number
  seconds: number
  ended: boolean
}

const SECONDS_PER_DAY = 86400
const SECONDS_PER_HOUR = 3600
const SECONDS_PER_MINUTE = 60

/** Whole seconds left until `target`, floored at zero as the prototype is. */
function secondsUntil(target: number, from: number): number {
  const left = Math.floor((target - from) / 1000)
  return left > 0 ? left : 0
}

/** The same four floored quantities the prototype computes from `left`. */
function split(left: number): Omit<CountdownParts, 'ended'> {
  return {
    days: Math.floor(left / SECONDS_PER_DAY),
    hours: Math.floor((left % SECONDS_PER_DAY) / SECONDS_PER_HOUR),
    minutes: Math.floor((left % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE),
    seconds: Math.floor(left % SECONDS_PER_MINUTE),
  }
}

/**
 * Counts down to `target`. Returns the remaining days, hours, minutes and
 * seconds, and whether the target has been reached.
 *
 * @param target absolute target time - a Date or epoch milliseconds.
 */
export function useCountdown(target: Date | number): CountdownParts {
  const targetMs = target instanceof Date ? target.getTime() : target

  const [now, setNow] = useState(() => Date.now())

  const left = secondsUntil(targetMs, now)
  const ended = left === 0

  useEffect(() => {
    if (ended) return

    // The prototype ticks every 1000ms; so does this. Reading the clock inside
    // the callback rather than during render keeps render pure.
    const id = window.setInterval(() => {
      setNow(Date.now())
    }, 1000)

    return () => {
      window.clearInterval(id)
    }
  }, [ended])

  return { ...split(left), ended }
}
