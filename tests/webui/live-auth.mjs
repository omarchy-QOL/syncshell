import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {randomUUID} from 'node:crypto';
import {connect, waitFor} from './browser.mjs';

const root = resolve(process.argv[2]);
const debug = 'http://127.0.0.1:19222';
for (const [index, framework] of ['svelte', 'preact'].entries()) {
    const base = resolve(root, framework);
    await readFile(resolve(base, '.syncshell-port-fixture'));
    const xml = await readFile(resolve(base, 'home/config.xml'), 'utf8');
    const key = xml.match(/<apikey>(.*?)<\/apikey>/)[1];
    const url = `http://127.0.0.1:${18401 + index}/`;
    const api = async (path, body) => {
        const response = await fetch(url + 'rest/' + path, {method: body ? 'PUT' : 'GET',
            headers: {'X-API-Key': key, 'Content-Type': 'application/json'},
            body: body ? JSON.stringify(body) : undefined});
        assert.equal(response.ok, true);
        const text = await response.text();
        return text ? JSON.parse(text) : null;
    };
    const original = await api('config/gui');
    // recover only our disposable credentials after an interrupted fixture run
    if (original.user === 'port-test') {
        original.user = '';
        original.password = '';
    }
    async function waitForGui() {
        for (let i = 0; i < 100; i++) {
            try { await api('config/gui'); return; } catch {
                await new Promise(resolve => setTimeout(resolve, 100));
            }
        }
        throw new Error('Test GUI did not restart');
    }
    const password = randomUUID();
    let page;
    try {
        await api('config/gui', {...original, user: 'port-test', password});
        await new Promise(resolve => setTimeout(resolve, 200));
        await waitForGui();
        const tabs = await fetch(debug + '/json/list').then(response => response.json());
        const tab = tabs.find(tab => tab.url === url);
        assert.ok(tab, framework + ' review tab');
        page = await connect(tab);
        await page.call('Runtime.enable');
        await page.call('Page.reload', {ignoreCache: true});
        await waitFor(page, `document.querySelector('#username') !== null`, framework + ' login');
        assert.equal(await page.evaluate(`document.querySelector('.dashboard') === null`), true);
        const fill = async (id, value) => page.evaluate(`(() => {
            const input = document.getElementById(${JSON.stringify(id)});
            input.value = ${JSON.stringify(value)};
            input.dispatchEvent(new Event('input', {bubbles: true}));
        })()`);
        await fill('username', 'port-test');
        await fill('password', 'incorrect');
        await page.evaluate(`document.querySelector('button[type="submit"]').click()`);
        await waitFor(page, `document.querySelector('[role="alert"]')?.textContent.includes('Incorrect')`,
            framework + ' bad password');
        await fill('password', password);
        await page.evaluate(`document.querySelector('button[type="submit"]').click()`);
        await waitFor(page, `document.querySelector('.panel-heading')?.textContent.includes('Port verification')`,
            framework + ' authenticated hydration');
        assert.deepEqual(page.errors, []);
        console.log(framework + ': unauthenticated entry, bad password and successful login passed');
    } finally {
        await waitForGui();
        await api('config/gui', original);
        await new Promise(resolve => setTimeout(resolve, 200));
        await waitForGui();
        if (page) {
            await page.call('Page.reload', {ignoreCache: true});
            page.close();
        }
    }
}
