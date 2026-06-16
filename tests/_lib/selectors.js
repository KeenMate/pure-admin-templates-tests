// Shared assertions for Pure Admin apps (SK + SPA, anything using
// @keenmate/svelte-pure-admin chrome).
//
// Keep each helper focused — composites should make spec code one or two
// lines per intent. If a helper grows conditionals, split it.

const { expect } = require('@playwright/test');

// ── Chrome ────────────────────────────────────────────────────────────────

/**
 * Assert just navbar + sidebar render. Use this on inner pages where the
 * theme assertion would be redundant (already verified on /).
 */
async function expectChrome(page) {
  await expect(page.locator('.pa-navbar')).toBeVisible();
  await expect(page.locator('.pa-layout__sidebar')).toBeVisible();
}

/**
 * Assert the theme CSS link points at the expected slug. Matches both shapes:
 *   - API template ships a static <link rel="stylesheet" href="/themes/...">
 *   - Bundled CLI fallback injects <link id="pa-theme-css"> via inline script
 * Matching by href pattern works against both.
 */
async function expectTheme(page, slug) {
  const href = `/themes/${slug}/css/${slug}.css`;
  await expect(page.locator(`link[rel="stylesheet"][href$="${href}"]`)).toHaveCount(1);
}

/**
 * Composite: navigate to / and assert chrome + theme. The common opener for
 * every smoke spec — replaces 3 lines (goto + chrome + theme) with one.
 */
async function expectAppShell(page, { theme = 'corporate', path = '/' } = {}) {
  await page.goto(path);
  await expectChrome(page);
  await expectTheme(page, theme);
}

// ── Sidebar ───────────────────────────────────────────────────────────────

/**
 * Assert a sidebar link with the given label is present in the rendered
 * sidebar. Checks "attached" (in DOM), not "visible" — items inside a
 * collapsed submenu (e.g. Users/Settings under "Management") are reachable
 * by expanding the parent, so they count as a present sidebar link.
 *
 * Matches by `.pa-sidebar__label` inner text, exact-match by anchored regex
 * so "Users" doesn't accidentally hit "User Management".
 */
async function expectSidebarLink(page, label) {
  const loc = page
    .locator('.pa-layout__sidebar .pa-sidebar__label')
    .filter({ hasText: new RegExp(`^${label}$`) });
  await expect(loc, `sidebar should contain a link labeled "${label}"`).toHaveCount(1);
}

// ── Panels ────────────────────────────────────────────────────────────────

/**
 * Profile button is always in the header when --profile-panel is enabled.
 * Settings gear is rendered by the SettingsPanel component itself, not in
 * the header — selectors are different per panel.
 */
const PANEL = {
  profile:  { trigger: '.pa-header__profile-btn',        panel: '.pa-profile-panel',  openClass: /pa-profile-panel--open/  },
  settings: { trigger: '.pa-settings-panel__toggle',     panel: '.pa-settings-panel', openClass: /pa-settings-panel--open/ },
};

/**
 * Assert a panel exists in the DOM but starts closed, then click its trigger
 * and verify it gets the `--open` modifier. Closes via Escape so we don't
 * race a panel that overlays its own trigger.
 *
 * Pass one of PANEL entries (PANEL.profile / PANEL.settings) or an object
 * shaped { trigger, panel, openClass }.
 */
async function expectPanelToggle(page, kindOrDef) {
  const def = typeof kindOrDef === 'string' ? PANEL[kindOrDef] : kindOrDef;
  const panel = page.locator(def.panel);
  await expect(panel, `${def.panel} should be in the DOM`).toBeAttached();
  await expect(panel, `${def.panel} should start closed`).not.toHaveClass(def.openClass);

  const trigger = page.locator(def.trigger);
  await expect(trigger, `${def.trigger} should be visible`).toBeVisible();
  await trigger.click();
  await expect(panel, `${def.panel} should be open after click`).toHaveClass(def.openClass);

  // Close via Escape — clicking the trigger again is unreliable because the
  // open panel often overlays it.
  await page.keyboard.press('Escape');
}

/**
 * Assert neither the profile button nor the settings gear is in the DOM.
 * Used by specs that explicitly request no panels (sk-defaults).
 */
async function expectNoPanels(page) {
  expect(await page.locator(PANEL.profile.trigger).count(),
    'profile button should be absent without --profile-panel').toBe(0);
  expect(await page.locator(PANEL.settings.trigger).count(),
    'settings gear should be absent without --settings-panel').toBe(0);
}

module.exports = {
  expectChrome,
  expectTheme,
  expectAppShell,
  expectSidebarLink,
  expectPanelToggle,
  expectNoPanels,
  PANEL,
};
