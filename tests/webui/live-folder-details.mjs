import assert from 'node:assert/strict';
import {connect, waitFor} from './browser.mjs';

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const debug = 'http://127.0.0.1:19222';
for (const [index, framework] of ['svelte', 'preact'].entries()) {
    const tabs = await fetch(debug + '/json/list').then(response => response.json());
    const page = await connect(tabs.find(tab => tab.url === `http://127.0.0.1:${18401 + index}/`));
    try {
        await page.call('Runtime.enable');
        await page.call('Page.reload', {ignoreCache: true});
        await waitFor(page, `document.querySelector('.panel-heading')?.textContent.includes('Port verification')`,
            framework + ' folder');
        await page.evaluate(`document.querySelector('.panel-heading').click()`);
        await waitFor(page, `document.querySelector('.folder-state-summary .folder-count-icon') !== null`,
            framework + ' new count icons');
        await page.call('Page.bringToFront');
        for (const section of [0, 1, 2, 0, 1, 2]) {
            await page.evaluate(`document.querySelectorAll('details > summary')[${section}].click()`);
            await sleep(100);
            assert.equal(await page.evaluate(`(() => {
                const rows = [...document.querySelectorAll('details > summary, details > table > tbody > tr')]
                    .filter(row => row.tagName === 'SUMMARY' || row.closest('details').open);
                return rows.every((row, i) => row.classList.contains('section-stripe') === (i % 2 === 1));
            })()`), true, framework + ' continuous stripe order');
        }
        const point = await page.evaluate(`(() => {
            const rect = document.querySelector('.folder-state-summary .folder-count-icon').getBoundingClientRect();
            return {x: rect.x + rect.width / 2, y: rect.y + rect.height / 2};
        })()`);
        await page.call('Input.dispatchMouseEvent', {type: 'mouseMoved', ...point});
        await waitFor(page, `document.querySelector('.folder-count-tooltip:popover-open') !== null`, framework + ' count tooltip');
        const values = await page.evaluate(`(() => {
            const tip = document.querySelector('.folder-count-tooltip:popover-open');
            const rows = [...tip.querySelectorAll('.tooltip-inner > div')];
            return {labels: rows.map(row => row.firstElementChild.textContent.trim()),
                rights: rows.map(row => row.lastElementChild.getBoundingClientRect().right),
                cursor: getComputedStyle(document.querySelector('.folder-count-icon')).cursor};
        })()`);
        assert.deepEqual(values.labels, ['Files:', 'Folders:', 'Total:']);
        assert.ok(values.rights.every(right => Math.abs(right - values.rights[0]) < 1));
        assert.equal(values.cursor, 'default');
        await page.call('Input.dispatchMouseEvent', {type: 'mouseMoved', x: point.x + 20, y: point.y});
        await sleep(500);
        assert.equal(await page.evaluate(`document.querySelectorAll('.port-tooltip:popover-open').length`), 0,
            framework + ' number text must not trigger hover');
        await page.evaluate(`document.querySelector('.folder-count-icon').focus()`);
        await waitFor(page, `document.querySelector('.folder-count-tooltip:popover-open') !== null`, framework + ' keyboard tooltip');
        await page.evaluate(`document.querySelector('.folder-count-icon').dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape'}))`);
        assert.equal(await page.evaluate(`document.querySelectorAll('.port-tooltip:popover-open').length`), 0);
        assert.deepEqual(page.errors, []);
        console.log(framework + ': continuous stripes, icon-only hover, aligned values and keyboard dismissal passed');
    } finally { page.close(); }
}
