// Preset "poc" SvelteKit smoke.
//
// Runs against:
//   - test-04-sk-preset-poc
//
// The "poc" preset is minimal — dashboard only by default.

const { test } = require('../_lib/test');
const { expectAppShell, expectSidebarLink } = require('../_lib/selectors');

test('chrome + dashboard render', async ({ page }) => {
  await expectAppShell(page);
  await expectSidebarLink(page, 'Dashboard');
});
