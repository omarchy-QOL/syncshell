export async function folderFixture(page, {folder = {}, model = {}, progress} = {}) {
    await page.route('**/rest/config', async route => {
        const config = await (await route.fetch()).json();
        config.folders = [{...config.folders[0], label: 'Folder under test',
            path: '/a/b', ...folder}];
        await route.fulfill({json: config});
    });
    await page.route('**/rest/db/status?*', async route => {
        const original = await (await route.fetch()).json();
        await route.fulfill({json: {...original, state: 'idle', errors: 0, pullErrors: 0,
            needTotalItems: 0, needBytes: 0, globalFiles: 109274, localFiles: 109274,
            globalDirectories: 12921, localDirectories: 12921,
            globalBytes: 7351042089, localBytes: 7351042089, ...model}});
    });
    let sentProgress = false;
    await page.route('**/rest/events?*', async route => {
        if (route.request().url().includes('limit=')) {
            await route.fulfill({json: [{id: 1, type: 'Starting', data: {}}]});
        } else if (progress && !sentProgress) {
            sentProgress = true;
            await route.fulfill({json: [{id: 2, type: 'FolderScanProgress',
                data: {folder: 'port-verification', ...progress}}]});
        } else {
            await page.waitForEvent('close').catch(() => {});
            await route.abort().catch(() => {});
        }
    });
}
