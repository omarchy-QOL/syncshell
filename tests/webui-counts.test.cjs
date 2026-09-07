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

const app = fs.readFileSync(path.join(__dirname,
    '../webui/modern/syncthing/app.js'), 'utf8');
const units = {};
vm.runInNewContext(app.slice(app.indexOf('function unitPrefixed(')), units);
for (const [input, expected] of [
    [0, '0 '], [1023, '1,023 '], [1024, '1,024 '], [1025, '1 Ki'],
    [1048576, '1,024 Ki'], [1073741824, '1,024 Mi'],
    [1073741825, '1 Gi'], [7351042089, '6.85 Gi'],
    [1099511627776, '1,024 Gi'], [1099511627777, '1 Ti']
]) {
    assert.equal(units.unitPrefixed(input, true), expected, String(input));
}
console.log('binary size boundaries and significant digits passed');
