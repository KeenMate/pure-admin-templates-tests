// Preset "full" Svelte SPA smoke.
//
// Runs against:
//   - test-09-spa-preset    (API recipe + --preset full)
//   - test-12-spa-tpl-preset (--template-path equivalent)
//
// Differs from sk-preset-full only in routing: SPA uses
// @keenmate/svelte-spa-router (hash-based), so navigation targets are
// `#/products` etc. Sidebar link assertions work unchanged — they match
// by label text, not href.

const { test, expect } = require('../_lib/test');
const { expectAppShell, expectChrome, expectSidebarLink } = require('../_lib/selectors');

const PRESET_PAGES = [
  { label: 'Dashboard', hash: '/' },
  { label: 'Products',  hash: '/products' },
  { label: 'Users',     hash: '/users' },
  { label: 'Settings',  hash: '/settings' },
];

test('every preset page has a sidebar link', async ({ page }) => {
  await expectAppShell(page);
  for (const p of PRESET_PAGES) {
    await expectSidebarLink(page, p.label);
  }
});

test('every preset page route renders content', async ({ page }) => {
  // SPA: one document, navigate by changing the hash. After hash change the
  // router swaps the visible component — wait for that by checking content.
  await page.goto('/');
  await expectChrome(page);

  for (const p of PRESET_PAGES) {
    await page.evaluate((h) => { window.location.hash = h; }, p.hash);
    // master-detail / form / dashboard all render at least one Card. The
    // chrome stays stable across hash changes; only main content swaps.
    await expect(
      page.locator('.pa-layout__main .pa-card').first(),
      `#${p.hash} should render a Card`
    ).toBeVisible();
  }
});
