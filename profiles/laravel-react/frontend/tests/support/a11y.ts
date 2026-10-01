import AxeBuilder from '@axe-core/playwright'
import { expect } from '@playwright/test'
import type { Page } from '@playwright/test'

/*
 * axe-core accessibility scan helpers for the `a11y` Playwright project.
 *
 * Every a11y spec asserts the same three things about a screen: the document
 * carries the approved language and direction, and axe reports zero
 * violations. Written once here so a spec is three lines, not thirty.
 *
 * DISABLED RULES ARE DISABLED LOUDLY. A rule disabled here is a defect the
 * approved prototype carries (a palette whose text contrast measures below
 * WCAG AA, say) which the visual-parity rule forbids fixing during the
 * HTML-to-React transfer. Each one is RAISED to the product owner in the
 * slice report, named in `DISABLED_RULES` with its reason, and removed the
 * day the owner decides. Every other axe rule runs.
 */

// TODO-GENERALIZE: empty unless the approved design carries a documented
// defect. Format: ['color-contrast'] with the reason in the slice report.
const DISABLED_RULES: readonly string[] = []

export async function expectNoViolations(page: Page): Promise<void> {
  const results = await new AxeBuilder({ page }).disableRules([...DISABLED_RULES]).analyze()
  expect(results.violations).toEqual([])
}

/** The document is Arabic and right-to-left, as the design system requires. */
export async function expectArabicRtlDocument(page: Page): Promise<void> {
  await expect(page.locator('html')).toHaveAttribute('lang', 'ar')
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl')
}

/** The three assertions every screen's a11y spec makes, in one call. */
export async function expectAccessibleScreen(page: Page): Promise<void> {
  await expectArabicRtlDocument(page)
  await expectNoViolations(page)
}
