// Svelte SPA + --no-icons smoke (test-20).
//
// Same as sk-no-icons but for the hash-routed SPA template.
//
// Runs against:
//   - test-20-spa-no-icons (svelte-spa, --template-path, --no-icons)

const { test } = require('../_lib/test');
const { expect } = require('@playwright/test');
const { expectAppShell, expectSidebarLink } = require('../_lib/selectors');

test('chrome renders + no icon markup anywhere', async ({ page }) => {
  await expectAppShell(page);
  await expectSidebarLink(page, 'Dashboard');

  await expect(page.locator('link[href*="font-awesome"]')).toHaveCount(0);
  await expect(page.locator('link[href*="cdnjs"][href*="font"]')).toHaveCount(0);
  await expect(page.locator('i[class*="fa-"]')).toHaveCount(0);
  await expect(page.locator('svg.lucide')).toHaveCount(0);
});
