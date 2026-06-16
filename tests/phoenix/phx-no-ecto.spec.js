// Phoenix LiveView smoke: no-ecto template (test-14).
// Pure Admin chrome is the same as SK/SPA (HEEx components emit the same
// .pa-* classes), so the shared _lib helpers work unchanged.
//
// Runs against:
//   - test-14-phx-no-ecto  (--themes tokyo-night --no-ecto --heroicons)

const { test } = require('../_lib/test');
const { expectAppShell, expectSidebarLink } = require('../_lib/selectors');

test('renders chrome + theme + sidebar links', async ({ page }) => {
  await expectAppShell(page, { theme: 'tokyo-night' });
  await expectSidebarLink(page, 'Getting Started');
  await expectSidebarLink(page, 'Dashboard');
  await expectSidebarLink(page, 'Users');
  await expectSidebarLink(page, 'Settings');
});

test('LiveView routes render content', async ({ page }) => {
  for (const path of ['/getting-started', '/users', '/settings']) {
    await page.goto(path);
    // Phoenix LiveView injects the body content directly under .pa-layout__main
    const main = page.locator('.pa-layout__main');
    await main.waitFor({ state: 'visible' });
  }
});
