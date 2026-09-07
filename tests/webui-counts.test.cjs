const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
let compact;
vm.runInNewContext(fs.readFileSync(path.join(__dirname,
    '../webui/modern/syncthing/core/compactNumberFilter.js'), 'utf8'), {
    angular: {module: () => ({filter: (_, factory) => { compact = factory(); }})}
});
for (const [input, expected] of [
    [0, '0'], [999, '999'], [1000, '1.0k'], [1099, '1.0k'],
    [1100, '1.1k'], [12921, '12.9k'], [109274, '109.2k'],
    [999999, '999.9k'], [1000000, '1.0M'], [12999999, '12.9M'],
    [999999999, '999.9M'], [1000000000, '1.0B'],
    [109699999999, '109.6B'], [undefined, '-'], [NaN, '-'],
    [Infinity, '-'], [-1, '-']
]) {
    assert.equal(compact(input), expected, String(input));
}
console.log('compact count boundaries passed');
