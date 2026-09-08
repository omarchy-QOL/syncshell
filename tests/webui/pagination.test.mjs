import assert from 'node:assert/strict';
import {test} from 'node:test';
import {referenceSource} from './reference.mjs';
import vm from 'node:vm';
import {paginationPages} from '../../webui/client/pagination.mjs';

test('page ranges retain first, last and ellipsis behavior from the existing UI', () => {
    const source = referenceSource('vendor/angular/angular-dirPagination.js');
    const start = source.indexOf('        function generatePagesArray(');
    const context = vm.createContext({});
    vm.runInContext(source.slice(start, source.indexOf('\n    }\n\n    /**', start)), context);
    for (const total of [0, 1, 10, 25, 90, 91, 1000]) {
        for (let page = 1; page <= Math.ceil(total / 10); page++) {
            assert.deepEqual(paginationPages(page, total, 10),
                Array.from(context.generatePagesArray(page, total, 10, 9)));
        }
    }
    assert.deepEqual(paginationPages(1, 0, 10), []);
});
