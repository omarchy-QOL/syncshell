import {chromium, expect} from '@playwright/test';
import {spawn} from 'node:child_process';
import {createInterface} from 'node:readline';
import {mkdir, writeFile} from 'node:fs/promises';
import {join} from 'node:path';

const [binary, source, runtime, qml, output] = process.argv.slice(2);
if (!output) throw new Error('Usage: plugin-acceptance.mjs <go-tool> <export> <runtime> <qml> <evidence>');
await mkdir(output, {recursive:true});
const child = spawn('sudo', [binary, '-plugin-source', source, '-runtime', runtime,
    '-plugin-qml', qml, '-fixture-port', '18801'], {stdio:['pipe','pipe','pipe']});
const phases = [], waiting = [];
let stderr = '', finished = false;
child.stderr.on('data', data => { stderr += data; });
createInterface({input:child.stdout}).on('line', line => {
    let value;
    try { value = JSON.parse(line); } catch { return; }
    const resolve = waiting.shift(); if (resolve) resolve(value); else phases.push(value);
});
const exited = new Promise(resolve => child.on('exit', code => {
    finished = true; resolve(code);
    while(waiting.length) waiting.shift()({phase:'failed',error:stderr});
}));
const next = () => phases.length ? Promise.resolve(phases.shift()) : finished
    ? Promise.resolve({phase:'failed',error:stderr}) : new Promise(resolve => waiting.push(resolve));
const rgb = hex => 'rgb(' + [1,3,5].map(i => parseInt(hex.slice(i,i+2),16)).join(', ') + ')';
const browser = await chromium.launch({headless:true,
    ...(process.env.SYNCSHELL_CHROMIUM ? {executablePath:process.env.SYNCSHELL_CHROMIUM} : {})});
try {
    const ready = await next();
    if (ready.phase !== 'ready') throw new Error(ready.error || JSON.stringify(ready));
    const page = await browser.newPage({viewport:{width:1908,height:954}});
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    await page.goto(ready.url);
    await expect(page.locator('.dashboard-folders .panel-heading').first()).toBeVisible();
    await expect.poll(() => page.locator('body').evaluate(e => getComputedStyle(e).backgroundColor)).toBe(rgb(ready.background));
    await page.locator('.dashboard-folders .panel-heading').first().click();
    await page.evaluate(() => { window.themeAcceptance = 'retained'; });
    await page.screenshot({path:join(output,'qml-theme-before.png')});
    child.stdin.write('theme\n');
    const theme = await next();
    if (theme.phase !== 'theme') throw new Error(theme.error || JSON.stringify(theme));
    await expect.poll(() => page.locator('body').evaluate(e => getComputedStyle(e).backgroundColor), {timeout:10000}).toBe(rgb(theme.background));
    expect(await page.evaluate(() => window.themeAcceptance)).toBe('retained');
    await page.screenshot({path:join(output,'qml-theme-after.png')});
    expect(errors).toEqual([]);
    child.stdin.write('scan\n');
    const complete = await next();
    if (complete.phase !== 'complete') throw new Error(complete.error || JSON.stringify(complete));
    expect(await exited, stderr).toBe(0);
    await writeFile(join(output,'results.json'), JSON.stringify({result:'passed',url:ready.url,
        checks:[...complete.checks,'browser follows the QML palette change without navigation']},null,2)+'\n');
    console.log('plugin theme and asset-independent QML rescan passed');
} finally {
    child.stdin.end();
    if (!finished) child.kill('SIGTERM');
    await exited;
    await browser.close();
}
