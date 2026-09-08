import {chromium, expect} from '@playwright/test';
import {access, mkdtemp, writeFile, readFile, rm} from 'node:fs/promises';
import {join} from 'node:path';
const root = '/home/iz/Work/syncshell-framework-ports';
const browser = await chromium.launch({headless:true, executablePath:'/usr/bin/chromium'});
async function api(page, path, method = 'GET', body) {
    return page.evaluate(async ({path, method, body}) => {
        const name = 'CSRF-Token-' + window.metadata.deviceIDShort;
        const token = document.cookie.split(';').map(part => part.trim()).find(part => part.startsWith(name + '='));
        const response = await fetch('rest/' + path, {method, headers:{['X-' + name]: decodeURIComponent(token.slice(name.length + 1)), 'Content-Type':'application/json'}, body:body === undefined ? undefined : JSON.stringify(body)});
        if (!response.ok) throw Error(await response.text());
        const text = await response.text(); return text ? JSON.parse(text) : null;
    }, {path, method, body});
}
const results = [];
try {
    for (const [index, framework] of ['svelte','preact'].entries()) {
        const runtime = join(root,'runtime',framework);
        await access(join(runtime,'.syncshell-port-fixture'));
        const page = await browser.newPage({viewport:{width:1500,height:954},colorScheme:'dark'});
        const failures = []; page.on('pageerror', error => failures.push(error.message));
        await page.goto(`http://127.0.0.1:${18401 + index}/`);
        await expect(page.locator('.dashboard-folders .panel-heading')).toBeVisible();
        const original = await api(page,'config');
        const testFolder = await mkdtemp(join(runtime,'settings-removal-'));
        try {
            await page.getByRole('link',{name:/Actions/}).click();
            await page.getByRole('link',{name:'Settings',exact:true}).click();
            const settings = page.getByRole('dialog',{name:'Settings',exact:true});
            await settings.getByLabel('Device Name',{exact:true}).fill(framework + ' settings test');
            await settings.getByRole('button',{name:'Edit Device Defaults',exact:true}).click();
            const defaults = page.getByRole('dialog',{name:'Edit Device Defaults',exact:true});
            await defaults.getByLabel('Device Name',{exact:true}).fill('Future test peer');
            await defaults.getByRole('button',{name:/Save/}).click();
            await expect(defaults).toHaveCount(0);
            expect((await api(page,'config/defaults/device')).name).toBe('Future test peer');
            await settings.getByRole('button',{name:'Save',exact:true}).click();
            await expect(settings).toHaveCount(0);
            const saved = await api(page,'config');
            expect(saved.defaults.device.name).toBe('Future test peer');
            expect(saved.devices.some(device => device.name === framework + ' settings test')).toBe(true);
            expect(saved.folders).toEqual(original.folders);
            await writeFile(join(testFolder,'keep.txt'),'removing configuration must keep this file\n');
            const template = await api(page,'config/defaults/folder');
            const myID = (await api(page,'system/status')).myID;
            await api(page,'config/folders','POST',{...template,id:'settings-removal',label:'Disposable removal folder',path:testFolder,devices:[{deviceID:myID}]});
            const heading = page.getByRole('button',{name:/Disposable removal folder/});
            await heading.click();
            const panel = page.locator('.dashboard-folders .panel').filter({has:heading});
            await panel.getByRole('button',{name:/Edit/,exact:false}).click();
            const editor = page.getByRole('dialog',{name:'Edit Folder',exact:true});
            await editor.getByRole('button',{name:'Remove',exact:true}).click();
            const confirmation = page.getByRole('dialog',{name:'Remove Folder',exact:true});
            await expect(confirmation).toContainText('No files will be deleted');
            await confirmation.getByRole('button',{name:'Cancel',exact:true}).click();
            expect((await api(page,'config/folders')).some(folder => folder.id === 'settings-removal')).toBe(true);
            await editor.getByRole('button',{name:'Remove',exact:true}).click();
            await confirmation.getByRole('button',{name:'Yes',exact:true}).click();
            await expect(editor).toHaveCount(0);
            expect((await api(page,'config/folders')).some(folder => folder.id === 'settings-removal')).toBe(false);
            expect(await readFile(join(testFolder,'keep.txt'),'utf8')).toBe('removing configuration must keep this file\n');
            expect(failures).toEqual([]);
            results.push({framework,result:'passed',checks:['settings save','nested device defaults save','unrelated folders preserved','folder removal cancel','confirmed configuration removal preserves files']});
        } finally {
            await api(page,'config','PUT',original);
            await rm(testFolder,{recursive:true,force:true});
            await page.close();
        }
    }
    await writeFile(join(root,'settings-results.json'),JSON.stringify(results,null,2));
    console.log(JSON.stringify(results));
} finally { await browser.close(); }
