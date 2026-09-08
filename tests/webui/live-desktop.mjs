// Exercise the shipped core and browser connection against a disposable daemon.
import { chromium } from 'playwright';
import { spawn } from 'node:child_process';
import { readFile, writeFile, mkdir, mkdtemp, rm, stat, chmod } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const runtime = process.env.SYNCSHELL_TEST_RUNTIME;
if (!runtime || !process.env.SYNCSHELL_CORE)
    throw new Error('Set SYNCSHELL_TEST_RUNTIME and SYNCSHELL_CORE');
await stat(join(runtime, '.syncshell-port-fixture'));
const configPath = join(runtime, 'home/config.xml'),
    xml = await readFile(configPath, 'utf8');
const gui = xml.match(/<gui\b[^>]*>([\s\S]*?)<\/gui>/)[1];
const base = 'http://' + gui.match(/<address>(.*?)<\/address>/)[1];
const key = gui.match(/<apikey>(.*?)<\/apikey>/)[1];
async function api(route, method = 'GET', body) {
    const response = await fetch(base + '/rest/' + route, {
        method,
        headers: { 'X-API-Key': key, ...(body ? { 'Content-Type': 'application/json' } : {}) },
        body: body && JSON.stringify(body)
    });
    assert.ok(response.ok, `${route}: ${response.status}`);
    const text = await response.text();
    return text ? JSON.parse(text) : null;
}
const evidence = process.env.SYNCSHELL_EVIDENCE || join(runtime, 'evidence');
await mkdir(evidence, { recursive: true });
const temporary = await mkdtemp(join(runtime, 'desktop-'));
const launchFile = join(temporary, 'launch');
const opener = `#!/usr/bin/env node
const fs = require('node:fs');
const {spawnSync} = require('node:child_process');
if (process.argv[2].startsWith('file:')) {
    fs.writeFileSync(${JSON.stringify(launchFile)}, process.argv[2], {mode: 0o600});
} else {
    const result = spawnSync('/usr/bin/xdg-open', process.argv.slice(2));
    process.exit(result.status ?? 1);
}
`;
await writeFile(join(temporary, 'xdg-open'), opener, { mode: 0o700 });
const core = spawn(
    resolve(process.env.SYNCSHELL_CORE),
    ['stream', '--host-id', 'omarchy', '--config', configPath],
    {
        env: { ...process.env, PATH: temporary + ':' + process.env.PATH },
        stdio: ['pipe', 'pipe', 'pipe']
    }
);
let frames = '';
core.stdout.on('data', (data) => {
    frames += data;
});
core.stderr.resume();
async function waitUntil(check) {
    for (let i = 0; i < 200; i++) {
        if (await check()) return;
        await new Promise((r) => setTimeout(r, 100));
    }
    throw new Error('Timed out');
}
const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.SYNCSHELL_CHROMIUM || '/usr/bin/chromium'
});
const page = await browser.newPage({ viewport: { width: 1908, height: 954 } });
let folder, directory;
try {
    await waitUntil(() => frames.includes('"online":true'));
    core.stdin.write(
        JSON.stringify({
            v: 1,
            type: 'action',
            id: 'desktop-open',
            action: 'webui.open',
            args: {}
        }) + '\n'
    );
    await waitUntil(async () => {
        try {
            return Boolean(await readFile(launchFile, 'utf8'));
        } catch {
            return false;
        }
    });
    const launch = await readFile(launchFile, 'utf8');
    assert.equal((await stat(fileURLToPath(launch))).mode & 0o777, 0o600);
    assert.equal((await stat(dirname(fileURLToPath(launch)))).mode & 0o777, 0o700);
    folder = (await api('config/folders')).find((item) => item.id === 'port-verification');
    assert.ok(folder);
    directory = await mkdtemp(join(folder.path, 'desktop-actions-'));
    const filename = 'notes.sync-conflict-20260908-123456-ABCDEFG.txt';
    const source = join(directory, filename),
        target = join(directory, 'notes.txt');
    await writeFile(source, 'Keep this tiny conflict version.\n');
    await api('db/scan?folder=' + folder.id, 'POST');
    await page.goto(launch);
    await page.getByRole('tab', { name: /Resolve sync conflicts/ }).click();
    const row = page.locator('tr.review-row').filter({ hasText: filename });
    const auto = row.getByRole('button', { name: 'Autoresolve', exact: true });
    await auto.waitFor();
    await waitUntil(() => auto.isEnabled());
    assert.equal(new URL(page.url()).hash, '');
    await chmod(directory, 0o500);
    await row.getByRole('button', { name: 'Recheck files in folder', exact: true }).click();
    await waitUntil(async () => !(await auto.isEnabled()));
    await row.getByText('This desktop user cannot rename files in this folder.').waitFor();
    assert.ok(await row.getByRole('button', { name: 'Open folder', exact: true }).isEnabled());
    await chmod(directory, 0o700);
    await row.getByRole('button', { name: 'Recheck files in folder', exact: true }).click();
    await waitUntil(() => auto.isEnabled());
    for (const control of [
        row.getByRole('button', { name: 'Open folder', exact: true }),
        row.locator('a.review-file')
    ]) {
        const response = page.waitForResponse(
            (response) => new URL(response.url()).pathname === '/open'
        );
        await control.click();
        const result = await response;
        const payload = await result.json();
        assert.ok(result.ok(), payload.error);
        assert.equal(payload.opened, true);
    }
    await auto.click();
    await page.getByRole('dialog').screenshot({ path: join(evidence, 'rename-before.png') });
    await writeFile(target, 'An original appeared while the dialog was open.\n');
    await page.getByRole('button', { name: 'Rename', exact: true }).click();
    await page
        .getByRole('dialog')
        .getByText('the original name already exists; no file was replaced')
        .waitFor();
    assert.match(await readFile(target, 'utf8'), /^An original/);
    assert.match(await readFile(source, 'utf8'), /^Keep/);
    await rm(target);
    await page.getByRole('button', { name: 'Rename', exact: true }).click();
    await waitUntil(() => row.count().then((n) => n === 0));
    assert.equal(await readFile(target, 'utf8'), 'Keep this tiny conflict version.\n');
    await page.reload();
    await page.getByRole('tab', { name: /Resolve sync conflicts/ }).click();
    await page.getByText('No conflict files remain', { exact: true }).waitFor();
    await writeFile(
        join(evidence, 'desktop-results.json'),
        JSON.stringify(
            {
                result: 'passed',
                checks: [
                    'production core launch through private bootstrap',
                    'direct Syncthing serving without review injection',
                    'default containing-folder opening from both controls',
                    'destination appearing during dialog is preserved',
                    'permission denial disables rename early without preventing folder opening',
                    'confirmed rename retains bytes and clears conflict row',
                    'tab reload retains local connection'
                ]
            },
            null,
            2
        ) + '\n'
    );
    console.log('Production desktop workflow passed');
} finally {
    await browser.close();
    await new Promise((resolve) => {
        const timer = setTimeout(() => core.kill('SIGTERM'), 2000);
        core.once('exit', () => {
            clearTimeout(timer);
            resolve();
        });
        core.stdin.end();
    });
    if (directory) {
        await chmod(directory, 0o700).catch(() => {});
        await rm(directory, { recursive: true, force: true });
        await api('db/scan?folder=' + folder.id, 'POST').catch(() => {});
    }
    await rm(temporary, { recursive: true, force: true });
}
