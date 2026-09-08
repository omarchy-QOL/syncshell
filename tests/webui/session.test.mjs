import assert from 'node:assert/strict';
import {test} from 'node:test';
import {createSession, initialState, folderEvent} from '../../webui/client/session.mjs';

test('folder event updates preserve unrelated folders and clear obsolete scan data', () => {
    const original = {...initialState(), model: {a: {state: 'idle'}, b: {state: 'idle'}},
        scanProgress: {a: {current: 50}, b: {current: 20}}};
    const scanning = folderEvent(original,
        {type: 'StateChanged', data: {folder: 'a', from: 'idle', to: 'scanning'}});
    assert.equal(scanning.model.a.state, 'scanning');
    assert.equal(scanning.model.b, original.model.b);
    assert.equal(scanning.scanProgress.a, undefined);
    assert.equal(original.model.a.state, 'idle');
    const summary = {state: 'idle', localFiles: 3};
    assert.equal(folderEvent(scanning, {type: 'FolderSummary',
        data: {folder: 'a', summary}}).model.a, summary);
    assert.equal(folderEvent(scanning, {type: 'FolderErrors',
        data: {folder: 'unknown', errors: ['bad']}}), scanning);
});

test('session hydrates, scans only the selected directory and cancels on disposal', async () => {
    const calls = [];
    let ready;
    const loaded = new Promise(resolve => { ready = resolve; });
    let events = 0;
    const data = {'config': {folders: [{id: 'a'}, {id: 'paused', paused: true}], devices: []},
        'system/status': {myID: 'local'}, 'system/version': {version: 'v2.1.3'},
        'stats/folder': {}, 'stats/device': {}, 'system/connections': {connections: {}},
        'config/insync': {configInSync: true}, 'db/status': {state: 'idle'}};
    const api = {async get(path, query, signal) {
        calls.push({path, query});
        if (path !== 'events') return data[path];
        if (events++ === 0) return [{id: 1, type: 'Starting'}];
        return new Promise((_, reject) => signal.addEventListener('abort',
            () => reject(new DOMException('Aborted', 'AbortError')), {once: true}));
    }, async post(path, body, query) { calls.push({path, body, query, method: 'POST'}); },
        async put(path, body) { data[path] = body; },
        async delete(path, query) { calls.push({path, query, method: 'DELETE'}); }};
    const session = createSession(api, {publish: state => { if (state.ready) ready(state); }});
    session.start();
    const state = await loaded;
    assert.equal(state.model.a.state, 'idle');
    assert.equal(state.model.paused, undefined);
    await session.rescan('a', 'nested');
    assert.deepEqual(calls.at(-1), {path: 'db/scan', body: undefined,
        query: {folder: 'a', sub: 'nested'}, method: 'POST'});
    await session.ignorePending('ignored-peer', undefined, {name: 'Ignored peer', address: '127.0.0.1:1'});
    assert.equal(data.config.remoteIgnoredDevices[0].deviceID, 'ignored-peer');
    assert.ok(data.config.remoteIgnoredDevices[0].time);
    assert.equal(data.config.ignoredDevices, undefined);
    await session.stop();
});
