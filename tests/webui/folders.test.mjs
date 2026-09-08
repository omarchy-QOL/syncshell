import assert from 'node:assert/strict';
import {test} from 'node:test';
import {referenceSource} from './reference.mjs';
import vm from 'node:vm';
import {folderStatus, folderClass, folderStateClass, folderStateDetails,
    syncPercentage} from '../../webui/client/folders.mjs';
import {compactNumber, unitPrefixed} from '../../webui/client/format.mjs';

const source = referenceSource('syncthing/core/syncthingController.js');
const scope = {model: {}, hasFailedFiles: id => scope.model[id]?.errors !== 0,
    hasReceiveOnlyChanged: folder => ['receiveonly', 'receiveencrypted']
        .includes(folder.type) && scope.model[folder.id]?.receiveOnlyTotalItems > 0};
const context = vm.createContext({$scope: scope});
vm.runInContext(source.slice(source.indexOf('        $scope.folderStatus ='),
    source.indexOf('        $scope.scanPercentage =')) +
    source.slice(source.indexOf('        function progressIntegerPercentage'),
        source.indexOf('        $scope.scanRate =')), context);

test('status, semantic colors, details and progress agree with shipped rules', () => {
    const base = {state: 'idle', errors: 0, needTotalItems: 0, needBytes: 0,
        globalFiles: 2, localFiles: 2, globalDirectories: 1, localDirectories: 1,
        globalBytes: 100, localBytes: 100, inSyncBytes: 100};
    const infos = [undefined, {}, base, {...base, localFiles: 1},
        {...base, errors: 1}, {...base, receiveOnlyTotalItems: 1},
        {...base, needTotalItems: 1},
        {...base, needTotalItems: 1, needBytes: 50, inSyncBytes: 50},
        ...['error', 'scanning', 'syncing', 'scan-waiting', 'starting', 'cleaning',
            'sync-preparing', 'sync-waiting', 'clean-waiting', 'unknown']
            .map(state => ({...base, state}))];
    for (const paused of [false, true]) for (const devices of [[], [{}, {}]]) {
        for (const type of ['sendreceive', 'receiveonly', 'receiveencrypted']) {
            const folder = {id: 'folder', devices, paused, type};
            for (const info of infos) {
                scope.model.folder = info;
                const status = folderStatus(folder, info);
                assert.equal(status, scope.folderStatus(folder));
                assert.equal(folderClass(status), scope.folderClass(folder));
                assert.equal(folderStateClass(status), scope.folderStateClass(folder));
                assert.equal(folderStateDetails(folder, info), !!scope.folderStateDetails(folder));
                assert.equal(syncPercentage(info), scope.syncPercentage('folder'));
            }
        }
    }
});

test('compact counts retain truncation at k, M and B boundaries', () => {
    for (const [input, output] of [[999, '999'], [1000, '1.0k'],
        [109274, '109.2k'], [999999, '999.9k'], [1000000, '1.0M'],
        [999999999, '999.9M'], [1000000000, '1.0B'],
        [109699999999, '109.6B'], [NaN, '-'], [Infinity, '-'], [-1, '-']]) {
        assert.equal(compactNumber(input), output);
    }
    assert.equal(unitPrefixed(7351042089, true), '6.85 Gi');
    assert.equal(unitPrefixed(1073741824, true), '1,024 Mi');
    assert.equal(unitPrefixed(1073741825, true), '1 Gi');
});
