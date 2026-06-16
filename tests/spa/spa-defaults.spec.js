// Baseline Svelte SPA smoke: no preset, no panels, default features.
//
// Runs against:
//   - test-10-spa-tpl-defaults (--template-path)
//
// SPA matrix doesn't have an "api-defaults" sibling — when generated from the
// API the smallest path is test-08-spa-full (panels on). The local-path
// defaults case is the only no-panels-no-preset baseline we exercise.

const { test } = require('../_lib/test');
const { expectAppShell, expectSidebarLink, expectNoPanels } = require('../_lib/selectors');

test('renders chrome + dashboard, no panels', async ({ page }) => {
  await expectAppShell(page);
  await expectSidebarLink(page, 'Dashboard');
  await expectNoPanels(page);
});
