// Baseline SvelteKit smoke: no preset, no panels, default features.
//
// Runs against:
//   - test-01-sk-defaults     (API recipe)
//   - test-05-sk-tpl-defaults (--template-path; should be equivalent)

const { test } = require('../_lib/test');
const { expectAppShell, expectSidebarLink, expectNoPanels } = require('../_lib/selectors');

test('renders chrome + dashboard, no panels', async ({ page }) => {
  await expectAppShell(page);
  await expectSidebarLink(page, 'Dashboard');
  await expectNoPanels(page);
});
