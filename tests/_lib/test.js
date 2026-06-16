// Custom Playwright test fixture for Pure Admin apps.
//
// Extends the base `test` with automatic console/page error collection +
// post-test assertion. Specs don't need to manually wire collectors or call
// expectNoErrors at the end — the fixture does both.
//
// Usage:
//   const { test, expect } = require('../_lib/test');
//
//   test('something', async ({ page }) => {
//     await page.goto('/');
//     // ... assertions ...
//     // No manual error check needed — fixture asserts on test exit.
//   });
//
// If a specific test produces expected console noise (e.g. an upstream
// warning we can't fix), pass `consoleAllowList` via test.use:
//
//   test.use({ consoleAllowList: ['svelte_runes_warning'] });

const base = require('@playwright/test');

const test = base.test.extend({
  // Per-test allowlist for known-noisy console/page errors. Default empty.
  consoleAllowList: [[], { option: true }],

  // Wrap the page fixture so listeners attach BEFORE the test navigates,
  // and assertions run AFTER the test body completes.
  page: async ({ page, consoleAllowList }, use) => {
    const errors = [];
    const consoleErrors = [];

    page.on('pageerror', (err) => errors.push(err.message));
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    await use(page);

    const isClean = (msg) => !consoleAllowList.some((needle) => msg.includes(needle));
    const realErrors = errors.filter(isClean);
    const realConsoleErrors = consoleErrors.filter(isClean);

    base.expect(realErrors, `page errors:\n${realErrors.join('\n')}`).toHaveLength(0);
    base.expect(realConsoleErrors, `console errors:\n${realConsoleErrors.join('\n')}`).toHaveLength(0);
  },
});

module.exports = { test, expect: base.expect };
