// SvelteKit + --no-icons smoke (test-19).
//
// Validates that --no-icons produces an app with zero icon mentions:
//   - no FA CDN <link> in <head>
//   - no <i class="fa-..."> markup anywhere in the body
//   - chrome (navbar + sidebar) still renders normally
//
// Runs against:
//   - test-19-sk-no-icons (svelte-sveltekit, --template-path, --no-icons)

const { test } = require('../_lib/test');
const { expect } = require('@playwright/test');
const { expectAppShell, expectSidebarLink } = require('../_lib/selectors');

test('chrome renders + no icon markup anywhere', async ({ page }) => {
  await expectAppShell(page);
  await expectSidebarLink(page, 'Dashboard');

  // FA CDN link must NOT be in <head>.
  await expect(page.locator('link[href*="font-awesome"]')).toHaveCount(0);
  await expect(page.locator('link[href*="cdnjs"][href*="font"]')).toHaveCount(0);

  // No <i class="fa-..."> markup anywhere.
  await expect(page.locator('i[class*="fa-"]')).toHaveCount(0);

  // No Lucide SVG icons (Lucide renders as inline <svg class="lucide ...">).
  await expect(page.locator('svg.lucide')).toHaveCount(0);
});
