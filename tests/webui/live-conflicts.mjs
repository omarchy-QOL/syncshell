import {chromium, expect} from '@playwright/test';
import {mkdtemp, writeFile, rename, rm, access} from 'node:fs/promises';
import {join} from 'node:path';
const root = '/home/iz/Work/syncshell-framework-ports';
const browser = await chromium.launch({headless: true, executablePath: '/usr/bin/chromium'});
const results = [];
try {
    for (const [index, name] of ['svelte', 'preact'].entries()) {
        await access(join(root, 'runtime', name, '.syncshell-port-fixture'));
        const folder = await mkdtemp(join(root, 'runtime', name, 'files', 'port-conflicts-'));
        const current = 'notes & <review>.txt';
        const first = 'notes & <review>.sync-conflict-20260908-120000-ABCDEFG.txt';
        const second = 'notes & <review>.sync-conflict-20260908-120100-HIJKLMN.txt';
        for (const file of [current, first, second]) await writeFile(join(folder, file), 'disposable conflict review\n');
        const page = await browser.newPage({viewport: {width: 1908, height: 954}, colorScheme: 'dark'});
        const failures = [], calls = [];
        page.on('pageerror', error => failures.push(error.message));
        page.on('request', request => {
            if (request.url().includes('/rest/db/')) calls.push({method: request.method(), url: request.url()});
        });
        try {
            await page.goto(`http://127.0.0.1:${18401 + index}/`);
            await page.getByRole('tab', {name: 'Resolve sync conflicts'}).click();
            const panel = page.locator('.conflict-review');
            const recheck = panel.getByRole('button', {name: 'Recheck all files', exact: true});
            await expect(recheck).toBeEnabled();
            await recheck.click();
            const row = panel.locator('.review-row').filter({hasText: current});
            await expect(row).toHaveCount(1);
            await expect(row.locator('select option')).toHaveCount(2);
            await expect(row.locator('.review-current')).toContainText(current);
            await row.locator('select').selectOption({label: '2/2 · ' + first});
            await expect(row.locator('.review-copies .review-file')).toHaveText(first);
            await rm(join(folder, current));
            await row.getByRole('button', {name: 'Recheck files in folder', exact: true}).click();
            await expect(row.locator('.review-current')).toContainText('Missing current file');
            await expect(row.getByRole('button', {name: 'Autoresolve'})).toBeDisabled();
            await expect(row.locator('.review-current')).toContainText('To keep a conflict file, rename it to:');
            await page.screenshot({path: join(root, name + '-conflicts-browser.png')});
            await rename(join(folder, first), join(folder, current));
            await rm(join(folder, second));
            await row.getByRole('button', {name: 'Recheck files in folder', exact: true}).click();
            await expect(row).toHaveCount(0);
            await expect(panel.locator('[role="alert"]')).toHaveCount(0);
            expect(failures).toEqual([]);
            const scans = calls.filter(call => call.method === 'POST' && call.url.includes('/db/scan'));
            expect(scans).toHaveLength(3);
            const sub = new URL(scans[1].url);
            expect(sub.searchParams.get('folder')).toBe('port-verification');
            expect(sub.searchParams.get('sub')).toBe(folder.split('/').at(-1));
            results.push({framework: name, result: 'passed', checks: ['indexed multiple copies', 'literal filenames', 'selection', 'missing current persists', 'directory-scoped scan', 'manual rename removes group', 'no runtime exceptions']});
        } finally {
            await rm(folder, {recursive: true, force: true});
            await page.evaluate(async () => {
                const name = 'CSRF-Token-' + window.metadata.deviceIDShort;
                const token = document.cookie.split(';').map(part => part.trim()).find(part => part.startsWith(name + '='));
                await fetch('rest/db/scan?folder=port-verification', {method: 'POST', headers: {['X-' + name]: decodeURIComponent(token.slice(name.length + 1))}});
            });
            await page.close();
        }
    }
    await writeFile(join(root, 'conflicts-results.json'), JSON.stringify(results, null, 2));
    console.log(JSON.stringify(results));
} finally { await browser.close(); }
