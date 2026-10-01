import { defineConfig, devices } from '@playwright/test'

/*
 * Browser gates: flows (e2e) · visual parity · accessibility (a11y) ·
 * integration against the real backend.
 *
 * -- One browser, by decision ----------------------------------------------
 * Chromium only. Cross-browser coverage is not a documented requirement for
 * an internal admin surface, and downloading three browser bundles per run
 * would undo a measured result: 200-400MB of browser download per run puts a
 * ~2.5-minute CI run back over four minutes.
 *
 * -- The browser is the distribution's, not Playwright's --------------------
 * The node image is Alpine, and Playwright's bundled Chromium is built against
 * glibc - it will not run there. Rather than carry a second base image for one
 * gate, the gate uses Alpine's own chromium package and points Playwright at
 * it. The consequence is stated rather than discovered: the rendering engine is
 * whatever that package ships, so baselines must be generated in this image.
 * Rebuilding the image on a newer Alpine can shift rendering and require
 * baselines to be regenerated - a visible, reviewable diff, not a silent one.
 * The image also installs `ttf-dejavu`: without it every Arabic glyph is a
 * box, and the visual gate compares baselines of an unreadable page while
 * reporting success.
 *
 * -- The threshold is a number ---------------------------------------------
 * The decision asked for "almost zero" and Playwright needs figures. See the
 * `expect.toHaveScreenshot` block: three numbers, each proven by a deliberate
 * breach, not reasoned about.
 */

const CHROMIUM_PATH = process.env.PLAYWRIGHT_CHROMIUM_PATH ?? '/usr/bin/chromium'

export default defineConfig({
  // A dedicated port: the container already serves the dev server on 5173, and
  // a gate that fights the developer's own server for a port fails for reasons
  // that have nothing to do with the code under test.
  webServer: [
    {
      command: 'npm run dev -- --port 5174 --strictPort',
      url: 'http://127.0.0.1:5174',
      reuseExistingServer: false,
      timeout: 120_000,
    },
    {
      // A SECOND server, and the difference is one variable.
      //
      // The other projects intercept the network, and they have to: the dev
      // bundle injects VITE_API_BASE_URL=http://localhost:8080, and inside the
      // node container `localhost` is the node container - so an
      // un-intercepted call resolves to nothing. That is why no mocked test
      // reaches the backend, and why "real API" was unmeasured until this
      // server existed.
      //
      // From this container the backend answers on its compose service name.
      // This server serves the same app against that name, so the integration
      // project can let the calls through instead of answering them itself.
      command: 'npm run dev -- --port 5175 --strictPort',
      url: 'http://127.0.0.1:5175',
      env: { VITE_API_BASE_URL: process.env.INTEGRATION_API_BASE_URL ?? 'http://nginx' },
      reuseExistingServer: false,
      timeout: 120_000,
    },
  ],

  use: {
    baseURL: 'http://127.0.0.1:5174',
    launchOptions: { executablePath: CHROMIUM_PATH },
  },

  // A flaky pass is not a pass. No retries: a test that only succeeds on the
  // second attempt is reporting something real.
  retries: 0,
  forbidOnly: true,

  // One worker, pinned rather than inferred.
  //
  // Left unset, Playwright derives it from the host: `ceil(cores / 2)`, which
  // is 4 on one machine and something else on the next. A gate whose
  // parallelism changes with the hardware is not the same gate in two places.
  //
  // And 4 was not merely non-deterministic, it was wrong. Measured on a clean
  // tree, same commit, three runs:
  //
  //     default (4)      visual 14/18   a11y 33/37    1.4 min
  //     --workers=1      visual 18/18   a11y 37/37    2.0 min
  //
  // The four failures were the SAME four every time - the first test of each
  // of the four spec files, i.e. one per worker, at the moment all four take
  // their first navigation together. Not load between runs, and not a cold
  // Vite cache (a warm re-run failed identically). Structure.
  //
  // The cost is 36 seconds and the individual tests get FASTER - about 5s each
  // instead of about 10.5s - because four Chromiums taking full-page shots on
  // eight cores spend more on contending than parallelism returns.
  //
  // This weakens nothing. Every test still runs and every comparison still
  // happens at threshold 0 and maxDiffPixels 100. What changes is how many run
  // at once, not what is checked - unlike raising a timeout or a threshold,
  // which the framework forbids and what this exists to avoid needing.
  workers: 1,
  reporter: [['list']],

  expect: {
    toHaveScreenshot: {
      // Three numbers, and each one closed a blind spot found by breach.
      //
      // `maxDiffPixelRatio` is the decision: at most 0.1% of pixels may
      // differ. `threshold` is what decides whether a pixel counts as differing
      // at all, and its default of 0.2 is permissive enough that a changed
      // colour token passed straight through - proven, not assumed: the gate
      // was breached by moving a brand colour token one shade and reported
      // success. The ratio was never reached because almost no pixel was ever
      // counted. Zero means the comparison is exact per pixel.
      //
      // -- AND THEN THE RATIO TURNED OUT TO BE THE SECOND BLIND SPOT ---------
      //
      // 0.1% of a 1280x800 full-page shot is 1024 pixels, and that is a much
      // larger budget than it sounds for an Arabic interface: glyphs are thin
      // strokes, and rewriting an ENTIRE <h1> moved 587 pixels - a whole
      // heading changed, comfortably under budget, gate green. Measured by a
      // deliberate breach run with the ratio at zero.
      //
      // So an ABSOLUTE cap is added beside the ratio. Playwright fails the
      // comparison when EITHER bound is exceeded, so the smaller one governs -
      // verified by breach, because that combination rule is exactly the kind
      // of assumption that produced the two blind spots above.
      //
      // 100 is chosen against what the two knobs each have to do: with
      // threshold 0 and deterministic in-container rendering there is no
      // antialiasing noise to absorb at all, so the cap only needs to sit far
      // below the smallest change worth catching. The smallest real one
      // measured was 587.
      threshold: 0,
      maxDiffPixelRatio: 0.001,
      maxDiffPixels: 100,
    },
  },

  projects: [
    {
      // A preparation project, not a checking one. It asserts nothing; it
      // pays Vite's first-compile cost for each dev server so no measured test
      // pays it inside its own 30s budget. Every other project declares it as
      // a dependency, so Playwright runs it first whatever `--project=` the
      // gate script passes.
      name: 'warmup',
      testDir: './tests',
      testMatch: /warmup\.setup\.ts/,
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'e2e',
      dependencies: ['warmup'],
      testDir: './tests/e2e',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'visual',
      dependencies: ['warmup'],
      testDir: './tests/visual',
      // Pinned viewport: a baseline photographed at one size and compared at
      // another differs everywhere, and the gate would be reporting the window
      // rather than the design.
      use: { ...devices['Desktop Chrome'], viewport: { width: 1280, height: 800 } },
    },
    {
      // The gate that measures what the other three cannot: the frontend and
      // the backend answering each other, with nothing standing in between.
      //
      // It exists because a live probe found a registration endpoint returning
      // a system error while every gate was green - the dev database was
      // missing a seeded table and no test in the queue ever called a real
      // endpoint. A suite that mocks its dependency cannot see that class of
      // failure at all.
      //
      // Scope is deliberately narrow: whatever crosses the whole chain
      // (browser, Vite, nginx, PHP, MySQL, and back) without needing secrets
      // the suite cannot hold.
      name: 'integration',
      dependencies: ['warmup'],
      testDir: './tests/integration',
      // The backend's address travels as project metadata, not as an env read
      // inside the spec: `tsc --noEmit` covers tests/ and has no node types, so
      // `process` there is a static-gate error. The config is outside that
      // check and is the right place for environment anyway.
      metadata: { apiBase: process.env.INTEGRATION_API_BASE_URL ?? 'http://nginx' },
      use: { ...devices['Desktop Chrome'], baseURL: 'http://127.0.0.1:5175' },
    },
    {
      // axe-core accessibility scans over the built screens, RTL document
      // included. Separate project so the a11y suite can be run (and gated) on
      // its own without re-running flows or visual comparisons.
      name: 'a11y',
      dependencies: ['warmup'],
      testDir: './tests/a11y',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
})
