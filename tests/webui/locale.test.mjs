import assert from 'node:assert/strict';
import {test} from 'node:test';
import {loadEnglish, translator} from '../../webui/client/locale.mjs';

test('English text resolves nested keys and keeps substituted values literal', () => {
    const t = translator({Folders: 'Folders', theme: {name: {dark: 'Dark'}},
        'Remove {%name%}': 'Remove {{name}}'});
    assert.equal(t('Folders'), 'Folders');
    assert.equal(t('theme.name.dark'), 'Dark');
    assert.equal(t('theme'), 'theme');
    assert.equal(t('constructor'), 'constructor');
    assert.equal(t('Remove {%name%}', {name: '<script>&"'}), 'Remove <script>&"');
    assert.equal(t('Unknown field'), 'Unknown field');
    assert.equal(t('Remove {%name%}'), 'Remove ');
    assert.equal(translator({})('Remove {%name%}', {name: 'folder'}), 'Remove folder');
});

test('the interface loads only the English catalog', async () => {
    const requests = [];
    const locale = await loadEnglish({pageUrl: 'https://localhost/sync/?lang=de',
        fetch: async url => {
            requests.push(url.href);
            return new Response('{"Folders":"Folders"}');
        }});
    assert.equal(locale.language, 'en');
    assert.equal(locale.t('Folders'), 'Folders');
    assert.deepEqual(requests,
        ['https://localhost/sync/assets/lang/lang-en.json']);
});

test('a missing English catalog reports a clear loading error', async () => {
    await assert.rejects(loadEnglish({pageUrl: 'https://localhost/',
        fetch: async () => new Response('', {status: 404})}),
    /Could not load English interface text/);
});
