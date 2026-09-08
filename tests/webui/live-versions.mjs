import {chromium, expect} from '@playwright/test';
import {mkdtemp, writeFile, readFile, rm, access} from 'node:fs/promises';
import {join, basename} from 'node:path';
const root = '/home/iz/Work/syncshell-framework-ports';
const browser = await chromium.launch({headless: true, executablePath: '/usr/bin/chromium'});
const pages = [], results = [];
async function api(page, path, method = 'GET', body) {
    return page.evaluate(async ({path, method, body}) => {
        const name = 'CSRF-Token-' + window.metadata.deviceIDShort;
        const token = document.cookie.split(';').map(part => part.trim()).find(part => part.startsWith(name + '='));
        const response = await fetch('rest/' + path, {method, headers: {['X-' + name]: decodeURIComponent(token.slice(name.length + 1)), 'Content-Type': 'application/json'}, body: body === undefined ? undefined : JSON.stringify(body)});
        if (!response.ok) throw Error(await response.text());
        const text = await response.text(); return text ? JSON.parse(text) : null;
    }, {path, method, body});
}
try {
    for (const [index, name] of ['svelte', 'preact'].entries()) {
        await access(join(root, 'runtime', name, '.syncshell-port-fixture'));
        const page = await browser.newPage({viewport: {width: 1500, height: 954}, colorScheme: 'dark'});
        await page.goto(`http://127.0.0.1:${18401 + index}/`);
        await page.locator('.dashboard-folders .panel-heading').click();
        pages.push(page);
    }
    for (const [index, name] of ['svelte', 'preact'].entries()) {
        const page = pages[index], sender = pages[1-index];
        const names = ['svelte','preact'], failures = [];
        page.on('pageerror', error => failures.push(error.message));
        const original = await api(page, 'config/folders/port-verification');
        const source = await mkdtemp(join(root, 'runtime', names[1-index], 'files', 'port-version-'));
        const relative = basename(source) + '/version.txt';
        const destination = join(root, 'runtime', name, 'files', relative);
        try {
            await api(page, 'config/folders/port-verification', 'PATCH', {versioning: {...original.versioning, type:'simple', params:{keep:'5', cleanoutDays:'0'}}});
            await writeFile(join(source, 'version.txt'), 'original archived contents\n');
            await api(sender, 'db/scan?folder=port-verification', 'POST');
            await expect.poll(async () => readFile(destination, 'utf8').catch(() => ''), {timeout:15000}).toBe('original archived contents\n');
            await writeFile(join(source, 'version.txt'), 'replacement current contents\n');
            await api(sender, 'db/scan?folder=port-verification', 'POST');
            await expect.poll(async () => readFile(destination, 'utf8').catch(() => ''), {timeout:15000}).toBe('replacement current contents\n');
            await page.getByRole('button', {name:'Versions', exact:true}).click();
            const dialog = page.getByRole('dialog');
            const select = dialog.getByRole('combobox', {name: relative, exact:true});
            await expect(select).toBeVisible();
            await dialog.getByRole('searchbox', {name:'Filter by name'}).fill('does-not-match');
            await expect(select).toHaveCount(0);
            await dialog.getByRole('searchbox', {name:'Filter by name'}).fill('version.txt');
            const time = await select.locator('option').nth(1).getAttribute('value');
            await select.selectOption(time);
            await page.screenshot({path:join(root, name + '-versions-browser.png')});
            await dialog.getByRole('button', {name:'Restore (1)', exact:true}).click();
            await expect(dialog.getByRole('alert')).toContainText('restore 1 files');
            await expect.poll(() => readFile(destination, 'utf8')).toBe('replacement current contents\n');
            await dialog.getByRole('button', {name:'No', exact:true}).click();
            await dialog.getByRole('button', {name:'Restore (1)', exact:true}).click();
            const requestPromise = page.waitForRequest(request => request.method() === 'POST' && request.url().includes('/folder/versions'));
            await dialog.getByRole('button', {name:'Yes', exact:true}).click();
            const request = await requestPromise;
            expect(request.postDataJSON()).toEqual({[relative]: time});
            await expect(dialog).toHaveCount(0);
            await expect.poll(() => readFile(destination, 'utf8'), {timeout:10000}).toBe('original archived contents\n');
            expect(failures).toEqual([]);
            results.push({framework:name, result:'passed', checks:['real incoming change archived','name filtering','version selection','confirmation and cancel','exact REST path/time payload','archived contents restored']});
        } finally {
            await rm(source, {recursive:true, force:true});
            await rm(join(root, 'runtime', name, 'files', basename(source)), {recursive:true, force:true});
            for (const peer of pages) await api(peer, 'db/scan?folder=port-verification', 'POST');
            await api(page, 'config/folders/port-verification', 'PATCH', {versioning:original.versioning});
            await rm(join(root, 'runtime', name, 'files', '.stversions', basename(source)), {recursive:true, force:true});
        }
    }
    await writeFile(join(root,'versions-results.json'), JSON.stringify(results,null,2));
    console.log(JSON.stringify(results));
} finally { await browser.close(); }
