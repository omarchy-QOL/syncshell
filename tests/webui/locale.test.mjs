import assert from 'node:assert/strict';
import {test} from 'node:test';
import {createLocale, preferredLocale, translator} from '../../webui/client/locale.mjs';

test('browser language prefix matching preserves region boundaries', () => {
    const available = ['en', 'en-GB', 'zh-CN', 'zh-TW'];
    assert.equal(preferredLocale(['x', 'zh-tw', 'en'], available), 'zh-TW');
    assert.equal(preferredLocale(['zh', 'en'], available), 'zh-CN');
    assert.equal(preferredLocale(['e', 'en-us'], available), 'en');
});

test('translation falls back per key and keeps substituted values literal', () => {
    const t = translator({Folders: 'Ordner', theme: {name: {dark: 'Dark'}}}, {'Remove {%name%}': 'Remove {{name}}'});
    assert.equal(t('Folders'), 'Ordner');
    assert.equal(t('theme.name.dark'), 'Dark');
    assert.equal(t('theme'), 'theme');
    assert.equal(t('constructor'), 'constructor');
    assert.equal(t('Remove {%name%}', {name: '<script>&"'}), 'Remove <script>&"');
    assert.equal(t('Unknown field'), 'Unknown field');
    assert.equal(t('Remove {%name%}'), 'Remove ');
});

test('URL language wins over storage and browser negotiation, and is persisted', async () => {
    const writes = [];
    let browserCalls = 0;
    const locale = createLocale({async get() { browserCalls++; return ['fr']; }}, {
        available: ['en', 'de', 'fr'], pageUrl: 'https://localhost/sync/?lang=de',
        storage: () => ({getItem: () => 'fr', setItem: (...args) => writes.push(args)}),
        fetch: async url => new Response(JSON.stringify(url.pathname.endsWith('de.json')
            ? {Folders: 'Ordner'} : {Folders: 'Folders'}))});
    const selected = await locale.auto();
    assert.equal(selected.language, 'de');
    assert.equal(selected.t('Folders'), 'Ordner');
    assert.equal(browserCalls, 0);
    assert.deepEqual(writes, [['SYN_LANG', 'de']]);
});

test('blocked storage and missing translation files preserve a usable fallback', async () => {
    const locale = createLocale({async get() { return ['de']; }}, {
        available: ['en', 'de'], pageUrl: 'https://localhost/',
        storage: () => { throw new Error('disabled'); },
        fetch: async url => url.pathname.endsWith('en.json')
            ? new Response('{"Folders":"Folders"}') : new Response('', {status: 404})});
    assert.equal((await locale.auto()).t('Folders'), 'Folders');
});
