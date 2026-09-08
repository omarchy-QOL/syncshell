import assert from 'node:assert/strict';
import {test} from 'node:test';
import {createApi, HttpError} from '../../webui/client/api.mjs';

function client(fetch, cookie = () => '') {
    return createApi({pageUrl: 'https://localhost/sync/index.html?lang=de',
        metadata: {deviceIDShort: 'DEVICE1'}, fetch, cookie});
}

test('relative REST base, encoded query, payload and fresh CSRF cookie', async () => {
    const calls = [];
    let cookie = 'unrelated=first; CSRF-Token-DEVICE1=a%2Bb';
    const api = client(async (url, init) => {
        calls.push({url, ...init});
        return new Response('{"ok":true}', {headers: {'Content-Type': 'application/json'}});
    }, () => cookie);
    await api.post('db/scan', undefined, {folder: 'a/b & ü', sub: 'nested/file.txt'});
    cookie = 'CSRF-Token-OTHER=wrong; CSRF-Token-DEVICE1=changed';
    await api.put('config', {folders: [], options: {unrelated: true}});
    assert.equal(calls[0].url.pathname, '/sync/rest/db/scan');
    assert.equal(calls[0].url.searchParams.get('folder'), 'a/b & ü');
    assert.equal(calls[0].url.searchParams.get('sub'), 'nested/file.txt');
    assert.equal(calls[0].headers.get('X-CSRF-Token-DEVICE1'), 'a+b');
    assert.equal(calls[0].credentials, 'same-origin');
    assert.equal(calls[0].body, undefined);
    assert.equal(calls[1].headers.get('X-CSRF-Token-DEVICE1'), 'changed');
    assert.deepEqual(JSON.parse(calls[1].body), {folders: [], options: {unrelated: true}});
});

test('HTTP failure preserves status and daemon error; empty success is valid', async () => {
    const api = client(async () => new Response('{"error":"folder missing"}',
        {status: 404, headers: {'Content-Type': 'application/json'}}));
    await assert.rejects(api.get('db/status'), error => error instanceof HttpError &&
        error.status === 404 && error.message === 'folder missing');
    const empty = client(async () => new Response(null, {status: 204}));
    assert.equal(await empty.post('system/restart'), '');
});

test('no metadata is required for password login, and credentials stay same-origin', async () => {
    let init;
    const api = createApi({pageUrl: 'https://localhost/', metadata: null,
        cookie: () => '', fetch: async (_, options) => {
            init = options;
            return new Response('{}');
        }});
    await api.post('noauth/auth/password', {username: 'test', password: 'test'});
    assert.equal(init.headers.has('X-CSRF-Token-undefined'), false);
    assert.equal(init.credentials, 'same-origin');
    await assert.rejects(api.get('https://elsewhere.invalid/'), TypeError);
    await assert.rejects(api.get('../outside'), TypeError);
});

test('abort signal reaches fetch and text diagnostics remain available', async () => {
    const controller = new AbortController();
    const api = client(async (_, init) => {
        assert.equal(init.signal, controller.signal);
        return new Response('unavailable', {status: 503});
    });
    await assert.rejects(api.get('system/status', {}, controller.signal),
        {status: 503, message: 'unavailable'});
});
