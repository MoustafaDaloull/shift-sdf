/*
 * Header scroll shadow - is the page scrolled past the threshold?
 *
 * Re-authored from the approved static prototype:
 *
 *     var header = document.getElementById("siteHeader");
 *     function onScroll(){ if(header) header.classList.toggle("scrolled", window.scrollY > 8); }
 *     window.addEventListener("scroll", onScroll, {passive:true});
 *     onScroll();
 *
 * Governing rule: behaviour transferred as-is, threshold and listener options
 * included - re-authored, not a copy of the prototype's JS.
 *
 * Three details of the source are load-bearing and are kept:
 *   · the threshold is `> 8`, not `> 0` - a one-pixel scroll must not flash
 *     the border and shadow that `.site-header.scrolled` turns on;
 *   · the listener is `{passive:true}` - it never calls preventDefault, and
 *     saying so lets the browser keep scrolling off the main thread;
 *   · `onScroll()` runs once on mount, because a page restored mid-scroll
 *     (a reload, a back navigation) must start in the right state instead of
 *     waiting for the user to move.
 *
 * What this deliberately does not do: no throttle, no rAF batching. The
 * source has none, the handler is one comparison and a setState that React
 * drops when the value is unchanged, and adding scheduling would make the
 * class lag the scroll by a frame - visible against a sticky header.
 */

import { useEffect, useState } from 'react'

/** Pixels of scroll before the header takes its border and shadow. */
const SCROLL_SHADOW_THRESHOLD = 8

export function useScrollShadow(threshold: number = SCROLL_SHADOW_THRESHOLD): boolean {
  const [scrolled, setScrolled] = useState(false)

  useEffect(() => {
    const onScroll = () => {
      setScrolled(window.scrollY > threshold)
    }

    window.addEventListener('scroll', onScroll, { passive: true })
    onScroll()

    return () => {
      window.removeEventListener('scroll', onScroll)
    }
  }, [threshold])

  return scrolled
}
