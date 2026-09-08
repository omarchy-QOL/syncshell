import {test, expect} from '@playwright/test';
import {folderFixture} from './folder-fixture.mjs';

test('version filters, bulk selection and recoverable errors preserve REST values', async ({page}, testInfo) => {
    await page.emulateMedia({colorScheme: 'dark'});
    await folderFixture(page, {folder: {versioning: {type: 'simple', params: {keep: '5', cleanoutDays: '0'}, cleanupIntervalS: 3600}}});
    const path = 'nested/name & <literal>.txt', requests = [];
    const versions = [
        {versionTime: '2026-08-10T14:15:16+02:00', modTime: '2026-08-09T12:00:00Z', size: 40},
        {versionTime: '2026-08-09T14:15:16+02:00', modTime: '2026-08-08T12:00:00Z', size: 25},
    ];
    await page.route('**/rest/folder/versions?*', async route => {
        if (route.request().method() === 'GET') return route.fulfill({json: {[path]: versions}});
        requests.push(route.request().postDataJSON());
        await route.fulfill({json: requests.length === 1 ? {[path]: 'permission denied'} : {}});
    });
    await page.goto('/');
    await page.getByRole('button', {name: /Folder under test/}).click();
    await page.getByRole('button', {name: 'Versions', exact: true}).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog.getByRole('combobox', {name: path})).toBeVisible();
    expect(await dialog.evaluate(element => getComputedStyle(element).color))
        .toBe(await page.locator('body').evaluate(element => getComputedStyle(element).color));
    await dialog.getByLabel('Filter by date · From').fill('2026-08-10T00:00');
    await expect(dialog.getByRole('combobox', {name: path}).locator('option')).toHaveCount(2);
    await dialog.getByLabel('Filter by date · From').fill('');
    await dialog.getByRole('button', {name: 'Select oldest version', exact: true}).first().click();
    await expect(dialog.getByRole('combobox', {name: path})).toHaveValue(versions[1].versionTime);
    await dialog.getByRole('button', {name: 'Restore (1)', exact: true}).click();
    expect(requests).toHaveLength(0);
    await dialog.getByRole('button', {name: 'Yes', exact: true}).click();
    await expect(dialog).toContainText('permission denied');
    expect(requests).toEqual([{[path]: versions[1].versionTime}]);
    await page.screenshot({path: testInfo.outputPath('version-error-dark.png')});
    await dialog.getByRole('button', {name: 'Restore (1)', exact: true}).click();
    await dialog.getByRole('button', {name: 'Yes', exact: true}).click();
    await expect(dialog).toHaveCount(0);
    expect(requests).toEqual([{[path]: versions[1].versionTime}, {[path]: versions[1].versionTime}]);
});
