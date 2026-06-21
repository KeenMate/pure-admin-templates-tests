// @ts-check
const { defineConfig } = require('@playwright/test');

/**
 * One Playwright project per generated test app.
 *
 * Each project pins its own baseURL (matching the per-app port test.ps1 uses:
 * 4200 + NN) and which spec file runs against it. Apps that share a matrix
 * row reuse the same spec — test-01 and test-05 both run sk-defaults.spec.js.
 *
 * Invoke from test.ps1 (or directly):
 *   npx playwright test --project=test-01-sk-defaults
 *   npx playwright test --project=test-01-sk-defaults --project=test-02-sk-full
 *
 * The runner does NOT start the dev server — test.ps1 owns that lifecycle and
 * only calls `playwright test` once the server is up.
 */
module.exports = defineConfig({
  testDir: './tests',
  // Sequential: each app is served by its own vite preview on its own port,
  // but test.ps1 starts one at a time. Parallelism is at the script level.
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: process.env.CI ? 'list' : [['list'], ['html', { open: 'never' }]],
  use: {
    browserName: 'chromium',
    headless: true,
    // navigationTimeout / actionTimeout kept default unless we hit flakes.
  },
  projects: [
    // ── SvelteKit ─────────────────────────────────────────────────────────
    { name: 'test-01-sk-defaults',     use: { baseURL: 'http://127.0.0.1:4201/' }, testMatch: 'sveltekit/sk-defaults.spec.js' },
    { name: 'test-02-sk-full',         use: { baseURL: 'http://127.0.0.1:4202/' }, testMatch: 'sveltekit/sk-full.spec.js' },
    { name: 'test-03-sk-preset-full',  use: { baseURL: 'http://127.0.0.1:4203/' }, testMatch: 'sveltekit/sk-preset-full.spec.js' },
    { name: 'test-04-sk-preset-poc',   use: { baseURL: 'http://127.0.0.1:4204/' }, testMatch: 'sveltekit/sk-preset-poc.spec.js' },
    { name: 'test-05-sk-tpl-defaults', use: { baseURL: 'http://127.0.0.1:4205/' }, testMatch: 'sveltekit/sk-defaults.spec.js' },
    { name: 'test-06-sk-tpl-full',     use: { baseURL: 'http://127.0.0.1:4206/' }, testMatch: 'sveltekit/sk-full.spec.js' },
    { name: 'test-07-sk-tpl-preset',   use: { baseURL: 'http://127.0.0.1:4207/' }, testMatch: 'sveltekit/sk-preset-full.spec.js' },

    // ── Svelte SPA ────────────────────────────────────────────────────────
    { name: 'test-08-spa-full',        use: { baseURL: 'http://127.0.0.1:4208/' }, testMatch: 'spa/spa-full.spec.js' },
    { name: 'test-09-spa-preset',      use: { baseURL: 'http://127.0.0.1:4209/' }, testMatch: 'spa/spa-preset-full.spec.js' },
    { name: 'test-10-spa-tpl-defaults', use: { baseURL: 'http://127.0.0.1:4210/' }, testMatch: 'spa/spa-defaults.spec.js' },
    { name: 'test-11-spa-tpl-full',    use: { baseURL: 'http://127.0.0.1:4211/' }, testMatch: 'spa/spa-full.spec.js' },
    { name: 'test-12-spa-tpl-preset',  use: { baseURL: 'http://127.0.0.1:4212/' }, testMatch: 'spa/spa-preset-full.spec.js' },

    // ── Phoenix LiveView (no-DB apps only — test-14 + test-15 + test-21) ──
    // Phoenix dev port is 4000 (config/dev.exs is compile-time); runs are
    // sequential so all phx projects share one baseURL.
    { name: 'test-14-phx-no-ecto',     use: { baseURL: 'http://127.0.0.1:4000/' }, testMatch: 'phoenix/phx-no-ecto.spec.js' },
    { name: 'test-15-phx-minimal',     use: { baseURL: 'http://127.0.0.1:4000/' }, testMatch: 'phoenix/phx-minimal.spec.js' },
    { name: 'test-21-phx-no-icons',    use: { baseURL: 'http://127.0.0.1:4000/' }, testMatch: 'phoenix/phx-no-icons.spec.js' },

    // ── --no-icons variants (SK + SPA) ───────────────────────────────────
    { name: 'test-19-sk-no-icons',     use: { baseURL: 'http://127.0.0.1:4219/' }, testMatch: 'sveltekit/sk-no-icons.spec.js' },
    { name: 'test-20-spa-no-icons',    use: { baseURL: 'http://127.0.0.1:4220/' }, testMatch: 'spa/spa-no-icons.spec.js' },
  ],
});
