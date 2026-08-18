import { test, expect } from '@playwright/test';

function collectConsole(page) {
  const entries = [];
  page.on('console', message => {
    entries.push({ type: message.type(), text: message.text() });
  });
  page.on('pageerror', error => {
    entries.push({ type: 'pageerror', text: String(error) });
  });
  return entries;
}

test('project status dashboard loads', async ({ page }) => {
  const consoleEntries = collectConsole(page);
  await page.goto('/project-status/', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('body')).toContainText(/BGO|PROJECT|STATUS/i);
  await page.screenshot({ path: 'artifacts/screenshots/project-status.png', fullPage: true });
  expect(consoleEntries.filter(item => item.type === 'pageerror')).toEqual([]);
});

test('test launcher is reachable', async ({ page }) => {
  const consoleEntries = collectConsole(page);
  await page.goto('/test-launcher/', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('body')).toContainText(/BGO|TEST|PLAYER|DISPLAY/i);
  await page.screenshot({ path: 'artifacts/screenshots/test-launcher.png', fullPage: true });
  expect(consoleEntries.filter(item => item.type === 'pageerror')).toEqual([]);
});

test('Godot Web shell exposes diagnostics and creates a canvas', async ({ page }) => {
  const consoleEntries = collectConsole(page);
  await page.goto('/?role=display&game=TEST001', { waitUntil: 'domcontentloaded' });

  await expect.poll(async () => page.locator('canvas').count(), { timeout: 30_000 }).toBeGreaterThan(0);
  await expect.poll(
    async () => page.evaluate(() => typeof window.__bgoFlightRecorder === 'object'),
    { timeout: 15_000 },
  ).toBe(true);

  await page.screenshot({ path: 'artifacts/screenshots/godot-display.png', fullPage: true });

  const fatal = consoleEntries.filter(item => item.type === 'pageerror');
  expect(fatal).toEqual([]);
});

test('error viewer surface is reachable', async ({ page }) => {
  await page.goto('/error-viewer/', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('body')).toContainText(/error|diagnostic|BGO/i);
  await page.screenshot({ path: 'artifacts/screenshots/error-viewer.png', fullPage: true });
});
