// "Full chrome" SvelteKit smoke: both panels enabled.
//
// Runs against:
//   - test-02-sk-full     (API recipe + --profile-panel --settings-panel)
//   - test-06-sk-tpl-full (--template-path equivalent)

const { test } = require('../_lib/test');
const { expectAppShell, expectPanelToggle } = require('../_lib/selectors');

test('renders chrome + both panels open on trigger click', async ({ page }) => {
  await expectAppShell(page);
  await expectPanelToggle(page, 'profile');
  await expectPanelToggle(page, 'settings');
});
