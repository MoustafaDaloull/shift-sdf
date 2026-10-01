/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// The dev server binds 0.0.0.0 because it runs inside a container and is
// reached from the host through a published port; 127.0.0.1 would only ever
// answer callers inside the container.
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    strictPort: true,
  },
  test: {
    // Component gate - Vitest with React Testing Library.
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.ts'],
    // Playwright owns tests/e2e, tests/visual, tests/a11y and
    // tests/integration; running them here would start a browser inside jsdom
    // and fail for reasons unrelated to the code.
    include: ['tests/unit/**/*.test.{ts,tsx}'],
    /*
     * The per-test timeout is a HANG DETECTOR, not a performance budget.
     *
     * Vitest's 5s default was fine at ~60 test files and became flaky at ~70:
     * two consecutive full-suite runs timed out on DIFFERENT tests while each
     * passed comfortably when run alone - a shell-mounting test takes ~3s on
     * its own, which leaves no headroom once several workers share the
     * container's CPUs. A suite that fails on a different test each run
     * teaches people to re-run it, and a gate nobody believes is worse than
     * no gate.
     *
     * Raised rather than "fixed" by shrinking the tests, because the slow ones
     * are slow for a real reason: they mount the whole application shell,
     * which is what they exist to exercise. If a test ever genuinely hangs,
     * 20s still catches it long before CI's own limit.
     */
    testTimeout: 20_000,
  },
})
