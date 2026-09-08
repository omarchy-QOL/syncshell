import test from 'node:test';
import assert from 'node:assert/strict';
import { desktopActions } from '../../webui/client/desktop.mjs';

function browser(grant) {
    const values = new Map();
    return {
        location: { hash: '#syncshell-desktop=' + grant, pathname: '/', search: '' },
        history: {
            replaceState(...args) {
                this.args = args;
            }
        },
        sessionStorage: { setItem: (k, v) => values.set(k, v), getItem: (k) => values.get(k) },
        async fetch(url, options) {
            this.request = { url, options };
            return { ok: true, json: async () => ({ available: true }) };
        }
    };
}
test('desktop grant stays off requests to Syncthing and survives tab reload', async () => {
    const page = browser('127.0.0.1:12345/' + 'a'.repeat(64));
    const actions = desktopActions(page);
    assert.equal(page.history.args[2], '/');
    await actions.status('my-device');
    assert.equal(page.request.url, 'http://127.0.0.1:12345/status');
    assert.equal(page.request.options.credentials, 'omit');
    assert.equal(page.request.options.referrerPolicy, 'no-referrer');
    page.location.hash = '';
    assert.ok(desktopActions(page));
});
test('desktop grants cannot redirect secrets or requests to a remote host', () => {
    for (const grant of [
        'evil.example:1234/' + 'a'.repeat(64),
        '127.0.0.1:65536/' + 'a'.repeat(64),
        '127.0.0.1:1234/not-a-token'
    ]) {
        assert.equal(desktopActions(browser(grant)), null);
    }
});
test('lost connection reports how to restore access', async () => {
    const page = browser('127.0.0.1:12345/' + 'a'.repeat(64));
    page.fetch = async () => {
        throw new TypeError('connection refused');
    };
    await assert.rejects(desktopActions(page).status('id'), /Reopen the Web UI/);
});
