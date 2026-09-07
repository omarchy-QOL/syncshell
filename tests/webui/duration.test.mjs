import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {duration, timestamp} from '../../webui/client/format.mjs';

test('localized durations retain the shipped formatter across units and locales', () => {
    let factory;
    let language;
    const context = vm.createContext({console,
        angular: {module: () => ({filter: (_, fn) => { factory = fn; }})}});
    for (const path of ['vendor/HumanizeDuration.js/humanize-duration.js',
        'syncthing/core/durationFilter.js']) {
        vm.runInContext(readFileSync(new URL('../../webui/modern/' + path,
            import.meta.url), 'utf8'), context);
    }
    const original = factory({use: () => language});
    for (language of [undefined, 'en', 'de', 'zh-HK']) {
        for (const seconds of [0, 1, 61, 3600, 90061, 1860050]) {
            for (const precision of ['d', 'h', 'm', 's']) {
                assert.equal(duration(seconds, precision, language, context.humanizeDuration),
                    original(seconds, precision));
            }
        }
    }
});

test('timestamps preserve local yyyy-MM-dd HH:mm:ss layout', () => {
    assert.equal(timestamp(new Date(2026, 8, 8, 1, 2, 3)), '2026-09-08 01:02:03');
    assert.equal(timestamp('invalid'), '');
});
