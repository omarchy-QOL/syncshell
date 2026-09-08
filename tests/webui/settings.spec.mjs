import {test, expect} from '@playwright/test';
import {folderFixture} from './folder-fixture.mjs';

async function openSettings(page, advanced = false) {
    await page.getByRole('link', {name: /Actions/}).click();
    await page.getByRole('link', {name: advanced ? 'Advanced' : 'Settings', exact: true}).click();
    return page.getByRole('dialog').first();
}

test('settings preserve unsaved values across default editing and ignored-list changes', async ({page}, testInfo) => {
    let original, saved;
    await folderFixture(page);
    await page.route('**/rest/config', async route => {
        if (route.request().method() === 'PUT') {
            saved = route.request().postDataJSON();
            return route.fulfill({status: 200, body: ''});
        }
        original = await (await route.fetch()).json();
        const peer = original.devices[1].deviceID;
        original.remoteIgnoredDevices = [{deviceID: peer, name: 'Ignored example', time: '2026-09-01T12:00:00Z'}];
        original.devices[1].ignoredFolders = [{id: 'ignored-folder', label: 'Ignored folder', time: '2026-09-01T12:00:00Z'}];
        await route.fulfill({json: original});
    });
    await page.goto('/');
    await expect(page.locator('.dashboard-folders .panel-heading')).toBeVisible();
    const dialog = await openSettings(page);
    await dialog.getByLabel('Device Name', {exact: true}).fill('Unsaved device label');
    await dialog.getByRole('button', {name: 'Edit Folder Defaults', exact: true}).click();
    const defaults = page.getByRole('dialog', {name: 'Edit Folder Defaults', exact: true});
    await defaults.getByLabel('Folder Label', {exact: true}).fill('Future folder');
    await defaults.getByRole('link', {name: 'Ignore Patterns', exact: true}).click();
    await defaults.getByRole('textbox', {name: 'Ignore Patterns', exact: true}).fill('*.tmp\n\n# retained empty line');
    await defaults.getByRole('button', {name: /Save/, exact: false}).click();
    await expect(defaults).toHaveCount(0);
    expect(saved.defaults.folder.label).toBe('Future folder');
    expect(saved.defaults.ignores.lines).toEqual(['*.tmp', '', '# retained empty line']);
    await expect(dialog.getByLabel('Device Name', {exact: true})).toHaveValue('Unsaved device label');
    await dialog.getByRole('link', {name: 'Ignored Devices', exact: true}).click();
    await dialog.getByRole('button', {name: 'Unignore', exact: true}).click();
    await dialog.getByRole('link', {name: 'Ignored Folders', exact: true}).click();
    await dialog.getByRole('button', {name: 'Unignore', exact: true}).click();
    await page.screenshot({path: testInfo.outputPath('settings-ignored.png')});
    await dialog.getByRole('button', {name: 'Save', exact: true}).click();
    await expect(dialog).toHaveCount(0);
    expect(saved.remoteIgnoredDevices).toEqual([]);
    expect(saved.devices[1].ignoredFolders).toEqual([]);
    expect(saved.defaults.folder.label).toBe('Future folder');
    expect(saved.defaults.ignores.lines).toEqual(['*.tmp', '', '# retained empty line']);
    expect(saved.folders).toEqual(original.folders);
    expect(saved.devices.some(device => device.name === 'Unsaved device label')).toBe(true);
});

test('advanced changes stay in the draft until save or explicit discard', async ({page}, testInfo) => {
    let saved;
    await folderFixture(page);
    await page.route('**/rest/config', async route => {
        if (route.request().method() === 'PUT') { saved = route.request().postDataJSON(); return route.fulfill({status:200, body:''}); }
        await route.continue();
    });
    await page.goto('/');
    await expect(page.locator('.dashboard-folders .panel-heading')).toBeVisible();
    let dialog = await openSettings(page, true);
    await dialog.locator('summary').filter({hasText: /^Options$/}).click();
    const interval = dialog.locator('#config-options\\.reconnectionIntervalS');
    const initial = await interval.inputValue();
    await interval.fill('17');
    await dialog.getByRole('button', {name:'Close', exact:true}).click();
    expect(saved).toBeUndefined();
    await page.getByRole('dialog', {name:'Discard Changes', exact:true}).getByRole('button', {name:'Discard Changes', exact:true}).click();
    await expect(page.getByRole('dialog')).toHaveCount(0);
    dialog = await openSettings(page, true);
    await dialog.locator('summary').filter({hasText: /^Options$/}).click();
    await expect(interval).toHaveValue(initial);
    await interval.fill('17');
    await page.screenshot({path:testInfo.outputPath('advanced-options.png')});
    await dialog.getByRole('button', {name:'Save', exact:true}).click();
    await expect(dialog).toHaveCount(0);
    expect(saved.options.reconnectionIntervalS).toBe(17);
});

for (const [type, model, label, operation] of [
    ['sendonly', {needTotalItems: 2, needBytes: 100}, 'Override Changes', 'override'],
    ['receiveonly', {receiveOnlyTotalItems: 2}, 'Revert Local Changes', 'revert'],
]) test(`${label} requires confirmation and calls the original folder operation`, async ({page}) => {
    await folderFixture(page, {folder: {type}, model});
    let calls = 0;
    await page.route('**/rest/db/' + operation + '?*', async route => {
        expect(route.request().method()).toBe('POST');
        expect(new URL(route.request().url()).searchParams.get('folder')).toBe('port-verification');
        calls++; await route.fulfill({status:200, body:''});
    });
    await page.goto('/');
    await page.getByRole('button', {name:/Folder under test/}).click();
    await page.getByRole('button', {name:label, exact:true}).click();
    const dialog = page.getByRole('dialog', {name:label, exact:true});
    expect(calls).toBe(0);
    await dialog.getByRole('button', {name:'Cancel', exact:true}).click();
    expect(calls).toBe(0);
    await page.getByRole('button', {name:label, exact:true}).click();
    await dialog.getByRole('button', {name:operation === 'override' ? 'Override' : 'Revert', exact:true}).click();
    await expect(dialog).toHaveCount(0);
    expect(calls).toBe(1);
});
