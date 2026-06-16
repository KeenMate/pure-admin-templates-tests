// "Full chrome" Svelte SPA smoke: both panels enabled.
//
// Runs against:
//   - test-08-spa-full     (API recipe + --profile-panel --settings-panel)
//   - test-11-spa-tpl-full (--template-path equivalent)
//
// Same matrix promise as sk-full — SPA renders the same @keenmate/svelte-pure-admin
// chrome, so the helper assertions are identical. Routing differs (hash-based)
// but the home page lives at /, no rerouting needed.

const { test } = require('../_lib/test');
const { expectAppShell, expectPanelToggle } = require('../_lib/selectors');

test('renders chrome + both panels open on trigger click', async ({ page }) => {
  await expectAppShell(page);
  await expectPanelToggle(page, 'profile');
  await expectPanelToggle(page, 'settings');
});
