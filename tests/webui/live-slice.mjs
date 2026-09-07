import assert from 'node:assert/strict';
import {writeFile, readFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {resolve} from 'node:path';

const root = resolve(process.argv[2]);
const debug = 'http://127.0.0.1:19222';
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

async function connect(tab) {
    const socket = new WebSocket(tab.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
        socket.onopen = resolve;
        socket.onerror = reject;
    });
    let id = 0;
    const pending = new Map();
    const errors = [];
    socket.onmessage = ({data}) => {
        const message = JSON.parse(data);
        if (message.id) {
            const callbacks = pending.get(message.id);
            pending.delete(message.id);
            if (message.error) callbacks.reject(new Error(message.error.message));
            else callbacks.resolve(message.result);
        } else if (message.method === 'Runtime.exceptionThrown') {
            errors.push(message.params.exceptionDetails.text);
        }
    };
    const call = (method, params = {}) => new Promise((resolve, reject) => {
        pending.set(++id, {resolve, reject});
        socket.send(JSON.stringify({id, method, params}));
    });
    const evaluate = async expression => {
        const result = await call('Runtime.evaluate', {expression,
            returnByValue: true, awaitPromise: true});
        if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
        return result.result.value;
    };
    return {call, evaluate, errors, close: () => socket.close()};
}

async function waitFor(page, expression, label) {
    for (let i = 0; i < 200; i++) {
        if (await page.evaluate(expression)) return;
        await sleep(100);
    }
    throw new Error('Timed out: ' + label);
}

const pages = [];
try {
    for (const [index, framework] of ['svelte', 'preact'].entries()) {
        const url = `http://127.0.0.1:${18401 + index}/`;
        const targets = await fetch(debug + '/json/list').then(response => response.json());
        let tab = targets.find(tab => tab.type === 'page' && tab.url === url);
        if (!tab) tab = await fetch(debug + '/json/new?' + encodeURIComponent(url),
            {method: 'PUT'}).then(response => response.json());
        const page = await connect(tab);
        pages.push(page);
        await page.call('Runtime.enable');
        await waitFor(page, `document.querySelector('.panel-heading')?.textContent.includes('Port verification')`,
            framework + ' hydration');
        if (await page.evaluate(`document.querySelector('.panel-heading').getAttribute('aria-expanded') !== 'true'`)) {
            await page.evaluate(`document.querySelector('.panel-heading').click()`);
        }
        await waitFor(page, `document.querySelector('.folder-state-summary') !== null`, framework + ' folder');
        assert.equal(await page.evaluate(`typeof window.angular`), 'undefined');
        console.log(framework + ': hydrated and expanded without Angular');
    }

    const filename = 'browser-rescan-verification.txt';
    const content = Buffer.alloc(16 * 1024, 'x');
    content.write('small browser scan verification ' + Date.now());
    await writeFile(resolve(root, 'svelte/files', filename), content);
    const scan = `([...document.querySelectorAll('button')].find(button => button.textContent.trim() === 'Rescan')).click()`;
    await pages[0].evaluate(scan);
    for (const [index, framework] of ['svelte', 'preact'].entries()) {
        await waitFor(pages[index], `(async () => {
            const name = 'CSRF-Token-' + window.metadata.deviceIDShort;
            const token = document.cookie.split(';').map(x => x.trim())
                .find(x => x.startsWith(name + '=')).slice(name.length + 1);
            const response = await fetch('rest/db/status?folder=port-verification',
                {headers: {['X-' + name]: decodeURIComponent(token)}});
            const model = await response.json();
            return model.localFiles === 1 && model.needTotalItems === 0;
        })()`, framework + ' actual synchronization');
        await waitFor(pages[index], `document.querySelector('.folder-state-summary td').textContent.includes('16 KiB')`,
            framework + ' visible event update');
    }
    assert.deepEqual(await readFile(resolve(root, 'preact/files', filename)), content);
    console.log('Svelte rescan: actual file indexed, transferred and shown in both UIs');

    const reverse = Buffer.from(content);
    reverse.write('reverse browser scan verification ' + Date.now());
    await writeFile(resolve(root, 'preact/files', filename), reverse);
    await pages[1].evaluate(scan);
    let received = false;
    for (let attempt = 0; attempt < 200; attempt++) {
        received = (await readFile(resolve(root, 'svelte/files', filename))).equals(reverse);
        if (received) break;
        await sleep(100);
    }
    assert.equal(received, true, 'Preact rescan must index and transfer the changed file');
    console.log('Preact rescan: changed file indexed and transferred back to Svelte peer');
    for (const [index, framework] of ['svelte', 'preact'].entries()) {
        const unit = 'syncshell-port-' + framework;
        try {
            execFileSync('systemctl', ['--user', 'stop', unit]);
            await waitFor(pages[index], `document.querySelector('[role="alert"]') !== null`, framework + ' offline');
        } finally {
            execFileSync('node', [resolve(import.meta.dirname, 'setup-live.mjs'), root], {stdio: 'ignore'});
        }
        await waitFor(pages[index], `document.querySelector('[role="alert"]') === null`, framework + ' recovery');
        assert.deepEqual(pages[index].errors, []);
        console.log(framework + ': service outage recovered without page reload');
    }
    await pages[0].call('Page.bringToFront');
} finally {
    pages.forEach(page => page.close());
}
