import {chromium, expect} from '@playwright/test';
import {readFile, writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {resolve} from 'node:path';

const base = process.env.SYNCSHELL_WEBUI_URL;
const runtime = process.env.SYNCSHELL_TEST_RUNTIME;
const style = process.env.SYNCSHELL_TEST_STYLE;
const browser = await chromium.launch({headless: true,
    ...(process.env.SYNCSHELL_CHROMIUM ? {executablePath: process.env.SYNCSHELL_CHROMIUM} : {})});
try {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(base);
    await expect(page.locator('.dashboard-folders .panel-heading').first()).toBeVisible();
    await page.locator('.dashboard-folders .panel-heading').first().click();
    const scanButton = page.getByRole('button', {name: 'Rescan', exact: true}).first();
    await expect(scanButton).toBeEnabled({timeout: 15000});
    const [scan] = await Promise.all([
        page.waitForResponse(r => r.url().includes('/rest/db/scan') && r.request().method() === 'POST'),
        scanButton.click()
    ]);
    expect(scan.ok()).toBe(true);
    if (style === 'omarchy') {
        await expect.poll(() => page.locator('body').evaluate(el => getComputedStyle(el).backgroundColor))
            .toBe('rgb(18, 15, 24)');
        await page.evaluate(() => { window.themeAcceptance = 'retained'; });
        const palette = process.env.SYNCSHELL_TEST_PALETTE;
        await writeFile(palette, (await readFile(palette, 'utf8')).replace('#120f18', '#203040'));
        execFileSync('bash', [resolve('hosts/omarchy/scripts/syncthing-theme.sh'),
            'prepare', 'omarchy', runtime + '/gui'], {stdio: 'pipe'});
        await expect.poll(() => page.locator('body').evaluate(el => getComputedStyle(el).backgroundColor),
            {timeout: 10000}).toBe('rgb(32, 48, 64)');
        expect(await page.evaluate(() => window.themeAcceptance)).toBe('retained');
    } else {
        await page.getByRole('tab', {name: /Resolve sync conflicts/}).click();
        expect(await page.locator('button:enabled').filter({hasText: /^Autoresolve$/}).count()).toBe(0);
    }
    expect(errors).toEqual([]);
    console.log(`${style}: imported UI and real scan passed`);
} finally {
    await browser.close();
}
