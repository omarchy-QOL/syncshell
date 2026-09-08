import {test, expect} from '@playwright/test';
import {folderFixture} from './folder-fixture.mjs';

test('rechecks show activity until completion and clear it after errors', async ({page}, info) => {
    await folderFixture(page);
    const copy = 'note.sync-conflict-20260908-120000-ABCDEFG.txt';
    await page.route('**/rest/db/browse?*', route => route.fulfill({json: [
        {name: 'notes', type: 'FILE_INFO_TYPE_DIRECTORY', children: [
            {name: copy, type: 'FILE_INFO_TYPE_FILE'},
        ]},
    ]}));
    await page.route('**/rest/db/file?*', route => {
        const file = {type: 'FILE_INFO_TYPE_FILE', size: 16, modified: '2026-09-08T12:00:00Z'};
        return route.fulfill({json: {global: file, local: file}});
    });
    let finish, request;
    await page.route('**/rest/db/scan*', async route => {
        request = new URL(route.request().url());
        const fail = await new Promise(resolve => { finish = resolve; });
        await route.fulfill({status: fail ? 500 : 200, body: fail ? 'scan failed' : ''});
    });
    await page.goto('/');
    await page.getByRole('tab', {name: 'Resolve sync conflicts'}).click();
    const all = page.getByRole('button', {name: 'Recheck all files', exact: true});
    const row = page.getByRole('button', {name: 'Recheck files in folder', exact: true});
    await expect(row).toBeEnabled();
    await page.screenshot({path: info.outputPath('recheck-idle.png')});
    for (const [button, fail] of [[all, false], [row, true]]) {
        finish = null;
        await button.click();
        await expect.poll(() => typeof finish).toBe('function');
        await expect(button).toHaveAttribute('aria-busy', 'true');
        await expect(button.locator('.text-warning .fa-spin')).toBeVisible();
        await expect(button).toBeDisabled();
        if (fail) {
            expect(request.searchParams.get('folder')).toBe('port-verification');
            expect(request.searchParams.get('sub')).toBe('notes');
            await expect(all).toHaveAttribute('aria-busy', 'false');
        } else expect([...request.searchParams]).toEqual([]);
        await page.screenshot({path: info.outputPath(fail ? 'recheck-folder-active.png' : 'recheck-all-active.png')});
        finish(fail);
        await expect(button).toHaveAttribute('aria-busy', 'false');
        await expect(button.locator('.fa-spin')).toHaveCount(0);
        await expect(button).toBeEnabled();
    }
    await expect(page.getByRole('alert')).toBeVisible();
    await page.screenshot({path: info.outputPath('recheck-error-cleared.png')});
});
