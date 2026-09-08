import {chromium, expect} from '@playwright/test';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {randomUUID} from 'node:crypto';

const runtime = process.env.SYNCSHELL_TEST_RUNTIME;
if (!runtime) throw new Error('Set SYNCSHELL_TEST_RUNTIME to a disposable fixture');
await readFile(join(runtime, '.syncshell-port-fixture'));
const xml = await readFile(join(runtime, 'home/config.xml'), 'utf8');
const key = xml.match(/<apikey>(.*?)<\/apikey>/)[1];
const address = xml.match(/<gui\b[\s\S]*?<address>(.*?)<\/address>/)[1];
if (!/^127\.0\.0\.1:\d+$/.test(address)) throw new Error('Authentication fixture must use loopback');
const url = 'http://' + address + '/';
async function api(body) {
    const response = await fetch(url + 'rest/config/gui', {method:body ? 'PUT' : 'GET',
        headers:{'X-API-Key':key,'Content-Type':'application/json','Connection':'close'}, body:body ? JSON.stringify(body) : undefined});
    if (!response.ok) throw new Error('Authentication fixture API failed');
    const text = await response.text();
    return body ? null : JSON.parse(text);
}
const original = await api();
if (original.user) throw new Error('Authentication fixture must start without a login user');
const browser = await chromium.launch({headless:true,
    ...(process.env.SYNCSHELL_CHROMIUM ? {executablePath:process.env.SYNCSHELL_CHROMIUM} : {})});
try {
    const password = randomUUID();
    await api({...original,user:'fixture-user',password});
    await expect.poll(() => api().then(()=>true,()=>false)).toBe(true);
    const page = await browser.newPage();
    await page.goto(url);
    await page.locator('#user:visible').fill('fixture-user');
    await page.locator('#password:visible').fill('incorrect');
    await page.locator('button[type="submit"]:visible').click();
    await expect(page.locator('.login-form-messages')).toContainText('Incorrect');
    await page.locator('#password:visible').fill(password);
    await page.locator('button[type="submit"]:visible').click();
    await expect(page.locator('.dashboard-folders .panel-heading').first()).toBeVisible();
    const output = process.env.SYNCSHELL_TEST_OUTPUT || 'test-results';
    await mkdir(output,{recursive:true});
    await writeFile(join(output,'authentication.json'),JSON.stringify({result:'passed',
        checks:['fresh login required','incorrect password refused','correct password hydrates the frontend']},null,2)+'\n');
    console.log('real frontend authentication passed');
} finally {
    await expect.poll(() => api().then(()=>true,()=>false)).toBe(true);
    await api(original);
    await expect.poll(() => api().then(()=>true,()=>false)).toBe(true);
    await browser.close();
}
