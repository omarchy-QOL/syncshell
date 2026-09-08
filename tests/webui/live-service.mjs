import {chromium, expect} from '@playwright/test';
import {access, writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {join} from 'node:path';
const root = '/home/iz/Work/syncshell-framework-ports';
const runtime = join(root,'runtime');
const browser = await chromium.launch({headless:true,executablePath:'/usr/bin/chromium'});
const results = [];
const unitState = unit => {
    try { return execFileSync('systemctl',['--user','is-active',unit],{encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim(); }
    catch(error) { return error.stdout?.trim() || 'missing'; }
};
try {
    for(const [index, framework] of ['svelte','preact'].entries()) {
        await access(join(runtime,framework,'.syncshell-port-fixture'));
        const unit='syncshell-port-'+framework;
        const page=await browser.newPage({viewport:{width:1500,height:954},colorScheme:'dark'});
        await page.goto(`http://127.0.0.1:${18401+index}/`);
        await expect(page.locator('.dashboard-folders .panel-heading')).toBeVisible();
        const before=execFileSync('systemctl',['--user','show',unit,'-p','ExecMainStartTimestampMonotonic','--value'],{encoding:'utf8'}).trim();
        try {
            await page.getByRole('link',{name:/Actions/}).click();
            await page.getByRole('link',{name:'Restart',exact:true}).click();
            await expect(page.getByRole('dialog',{name:'Restarting',exact:true})).toBeVisible();
            await expect.poll(() => execFileSync('systemctl',['--user','show',unit,'-p','ExecMainStartTimestampMonotonic','--value'],{encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim(),{timeout:20000}).not.toBe(before);
            await expect(page.getByRole('dialog')).toHaveCount(0,{timeout:20000});
            expect(unitState(unit)).toBe('active');
            await page.getByRole('link',{name:/Actions/}).click();
            await page.getByRole('link',{name:'Shut Down',exact:true}).click();
            const shutdown=page.getByRole('dialog',{name:'Shutdown Complete',exact:true});
            await expect(shutdown).toContainText('Syncthing has been shut down.');
            await expect(page.locator('main > [role="alert"]')).toHaveCount(0);
            await expect.poll(() => unitState(unit),{timeout:15000}).not.toBe('active');
            await page.screenshot({path:join(root,framework+'-shutdown-browser.png')});
            execFileSync('node',[join(import.meta.dirname,'setup-live.mjs'),runtime],{stdio:'ignore'});
            await expect(page.getByRole('dialog')).toHaveCount(0,{timeout:20000});
            expect(unitState(unit)).toBe('active');
            results.push({framework,result:'passed',checks:['real process restart','restart dialog closes on new daemon start time','real shutdown','shutdown status','recovery after test supervisor restarts service']});
        } finally {
            if(unitState(unit)!=='active') execFileSync('node',[join(import.meta.dirname,'setup-live.mjs'),runtime],{stdio:'ignore'});
            await page.close();
        }
    }
    await writeFile(join(root,'service-results.json'),JSON.stringify(results,null,2));
    console.log(JSON.stringify(results));
} finally {await browser.close();}
