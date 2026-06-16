// Phoenix LiveView smoke: minimal template (test-15).
// Same shape as no-ecto but with --no-mailer --no-dashboard. Theme is nato.

const { test } = require('../_lib/test');
const { expectAppShell, expectSidebarLink } = require('../_lib/selectors');

test('renders chrome + theme + sidebar links', async ({ page }) => {
  await expectAppShell(page, { theme: 'nato' });
  await expectSidebarLink(page, 'Getting Started');
  await expectSidebarLink(page, 'Dashboard');
  await expectSidebarLink(page, 'Users');
  await expectSidebarLink(page, 'Settings');
});

test('LiveView routes render content', async ({ page }) => {
  for (const path of ['/getting-started', '/users', '/settings']) {
    await page.goto(path);
    const main = page.locator('.pa-layout__main');
    await main.waitFor({ state: 'visible' });
  }
});
