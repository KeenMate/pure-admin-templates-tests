// Phoenix LiveView + --no-icons smoke (test-21).
//
// Validates that --no-icons produces a Phoenix app where the CLI-generated
// code contains no icon references:
//   - no FA CDN <link> in <head> (helper.ICON_CDN must be empty, not the
//     misleading "Using Heroicons" comment)
//   - no Heroicon spans (would only render if `--heroicons` had leaked through)
//   - sidebar_item icons are empty (no `<.sidebar_item icon="fa-...">` emitted
//     by the template helper)
//   - chrome + sidebar still render
//
// NOTE on `<i class="fa-...">` markup: keen_pure_admin's library components
// (flash, button, command_palette, etc.) embed FA classes internally — this
// is library-emitted markup outside the CLI's control. --no-icons governs
// what the CLI/template emits, not what the dependency renders at runtime.
// Visual rendering of those library icons depends on FA being loaded.
//
// Runs against:
//   - test-21-phx-no-icons (--no-ecto --no-icons --themes tokyo-night)

const { test } = require('../_lib/test');
const { expect } = require('@playwright/test');
const { expectAppShell, expectSidebarLink } = require('../_lib/selectors');

test('renders chrome + sidebar without CLI-emitted icon references', async ({ page }) => {
  await expectAppShell(page, { theme: 'tokyo-night' });
  await expectSidebarLink(page, 'Getting Started');
  await expectSidebarLink(page, 'Dashboard');
  await expectSidebarLink(page, 'Users');
  await expectSidebarLink(page, 'Settings');

  // No FA CDN — the CLI's primary opt-in mechanism for FA visuals.
  await expect(page.locator('link[href*="font-awesome"]')).toHaveCount(0);
  await expect(page.locator('link[href*="cdnjs"][href*="font"]')).toHaveCount(0);

  // No Heroicons — Phoenix renders <.icon name="hero-X" /> as
  // <span class="hero-X ..."> via the heroicons Tailwind plugin. Presence
  // would mean iconProvider leaked into 'heroicons'.
  await expect(page.locator('span[class*="hero-"]')).toHaveCount(0);

  // Sidebar items must have NO icon attribute — the strip-pass in create.js
  // removes empty `icon=""` left by the per-provider placeholder resolving
  // to ''. Anchor the assertion on the rendered .pa-sidebar__icon span,
  // which keen_pure_admin only emits when icon is non-empty.
  const sidebarIcons = page.locator('.pa-layout__sidebar .pa-sidebar__icon');
  await expect(sidebarIcons, 'sidebar items should render without icon spans').toHaveCount(0);
});
