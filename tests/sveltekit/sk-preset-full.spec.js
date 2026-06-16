// Preset "full" SvelteKit smoke.
//
// Runs against:
//   - test-03-sk-preset-full (API recipe + --preset full)
//   - test-07-sk-tpl-preset  (--template-path equivalent)
//
// The "full" preset declares Dashboard + master-detail Products/Users +
// form Settings. Each gets its own assertion path so the failure points
// at the dimension that actually broke (sidebar wiring vs route render).

const { test, expect } = require('../_lib/test');
const { expectAppShell, expectChrome, expectSidebarLink } = require('../_lib/selectors');

const PRESET_PAGES = [
  { label: 'Dashboard', path: '/' },
  { label: 'Products',  path: '/products' },
  { label: 'Users',     path: '/users' },
  { label: 'Settings',  path: '/settings' },
];

test('every preset page has a sidebar link', async ({ page }) => {
  await expectAppShell(page);
  for (const p of PRESET_PAGES) {
    await expectSidebarLink(page, p.label);
  }
});

test('every preset page route renders content', async ({ page }) => {
  for (const p of PRESET_PAGES) {
    await page.goto(p.path);
    await expectChrome(page);
    // master-detail / form / dashboard all render at least one Card —
    // use that as a light "page rendered" signal that works across types.
    await expect(page.locator('.pa-card').first(), `${p.path} should render a Card`).toBeVisible();
  }
});
