import {test, expect} from '@playwright/test';
import {folderFixture} from './folder-fixture.mjs';

test('needed files show event progress, prioritize a file and refresh when it finishes', async ({page}, testInfo) => {
    await folderFixture(page, {model:{needTotalItems:2, needBytes:2048}});
    const path = 'nested/file & review.txt';
    let pending, finished = false, reads = 0, priority;
    await page.route('**/rest/events?*', async route => {
        if (route.request().url().includes('limit=')) return route.fulfill({json:[{id:1,type:'Starting',data:{}}]});
        pending = route;
    });
    const need = () => ({progress:finished ? [] : [{name:path,size:1024,flags:0}], queued:finished ? [] : [{name:'queued.txt',size:500,flags:0}], rest:[]});
    await page.route('**/rest/db/need?*', async route => { reads++; await route.fulfill({json:need()}); });
    await page.route('**/rest/db/prio?*', async route => { priority = new URL(route.request().url()).searchParams.get('file'); await route.fulfill({json:need()}); });
    await page.goto('/');
    await page.getByRole('button',{name:/Folder under test/}).click();
    await page.getByRole('link',{name:/2.*2 KiB/}).click();
    await expect.poll(() => !!pending).toBe(true);
    const route = pending; pending = null;
    await route.fulfill({json:[{id:2,type:'DownloadProgress',data:{'port-verification':{[path]:{total:10,reused:1,copiedFromOrigin:1,copiedFromElsewhere:1,pulled:2,pulling:1,bytesTotal:2048,bytesDone:512}}}}]});
    const dialog = page.getByRole('dialog',{name:'Out of Sync Items',exact:true});
    const bar = dialog.getByRole('progressbar',{name:'Downloading',exact:true});
    await expect(bar).toHaveAttribute('aria-valuenow','512');
    await expect(bar).toContainText('512 B / 2 KiB');
    await dialog.getByRole('button',{name:'Move to top of queue'}).click();
    expect(priority).toBe('queued.txt');
    await page.screenshot({path:testInfo.outputPath('transfer-progress.png')});
    await expect.poll(() => !!pending).toBe(true);
    finished = true;
    await pending.fulfill({json:[{id:3,type:'DownloadProgress',data:{}}]}); pending = null;
    await expect(bar).toHaveCount(0);
    await expect(dialog.locator('tbody tr')).toHaveCount(0);
    expect(reads).toBe(2);
});

test('logs render literal text, update logging levels and cancel polling on close', async ({page}, testInfo) => {
    await folderFixture(page);
    let levels = {api:'INFO'}, writes = 0, reads = 0;
    await page.route('**/rest/system/loglevels', async route => {
        if (route.request().method() === 'POST') { levels = route.request().postDataJSON(); writes++; return route.fulfill({status:200,body:''}); }
        await route.fulfill({json:{levels,packages:{api:'REST API'}}});
    });
    await page.route('**/rest/system/log*', async route => {
        if (route.request().url().includes('loglevels')) return route.fallback();
        reads++; await route.fulfill({json:{messages:[{when:'2026-09-08T12:00:00.123Z',level:'INFO',message:'literal <script> & log entry'}]}});
    });
    await page.goto('/');
    await page.getByRole('link',{name:/Actions/}).click();
    await page.getByRole('link',{name:'Logs',exact:true}).click();
    const dialog=page.getByRole('dialog',{name:'Logs',exact:true});
    await expect(dialog.getByRole('textbox',{name:'Log',exact:true})).toHaveValue(/literal <script> & log entry/);
    await dialog.getByRole('link',{name:'Debugging Facilities',exact:true}).click();
    await dialog.getByRole('combobox',{name:'api',exact:true}).selectOption('WARN');
    await expect(dialog.getByRole('combobox',{name:'api',exact:true})).toHaveValue('WARN');
    expect(writes).toBe(1);
    await page.screenshot({path:testInfo.outputPath('logging-levels.png')});
    await dialog.getByRole('button',{name:/Close/}).click();
    const before = reads;
    await page.waitForTimeout(2200);
    expect(reads).toBe(before);
});

test('upgrade confirmation reports API failures without claiming a restart', async ({page}) => {
    await folderFixture(page);
    let writes=0;
    await page.route('**/rest/system/upgrade', async route => {
        if (route.request().method() === 'POST') { writes++; return route.fulfill({status:500,body:'test upgrade unavailable'}); }
        await route.fulfill({json:{newer:true,latest:'v2.1.4'}});
    });
    await page.goto('/');
    await page.getByRole('link',{name:/Actions/}).click();
    await page.getByRole('link',{name:'Upgrade v2.1.4',exact:true}).click();
    const dialog = page.getByRole('dialog',{name:'Upgrade',exact:true});
    await expect(dialog).toContainText('Are you sure you want to upgrade?');
    expect(writes).toBe(0);
    await dialog.getByRole('button',{name:'Upgrade',exact:true}).click();
    await expect(page.getByRole('dialog',{name:'Error',exact:true})).toContainText('test upgrade unavailable');
    expect(writes).toBe(1);
});
