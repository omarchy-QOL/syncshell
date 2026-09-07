// Copyright (C) 2014 The Syncthing Authors.
// SPDX-License-Identifier: MPL-2.0

export function folderStatus(folder, info) {
    if (folder.paused) return 'paused';
    if (!info?.state) return 'unknown';
    const state = String(info.state);
    if (state === 'error') return 'stopped';
    if (state !== 'idle') return state;
    if (info.needTotalItems > 0) return 'outofsync';
    if (info.errors !== 0) return 'faileditems';
    if (['receiveonly', 'receiveencrypted'].includes(folder.type) &&
        info.receiveOnlyTotalItems > 0) {
        return folder.type === 'receiveonly' ? 'localadditions' : 'localunencrypted';
    }
    if (folder.devices.length <= 1) return 'unshared';
    return state;
}

export function folderClass(status) {
    if (['idle', 'localadditions'].includes(status)) return 'success';
    if (status === 'paused') return 'default';
    if (['syncing', 'sync-preparing', 'scanning', 'cleaning', 'starting']
        .includes(status)) return 'primary';
    if (['stopped', 'outofsync', 'error', 'faileditems', 'localunencrypted']
        .includes(status)) return 'danger';
    if (['unshared', 'scan-waiting', 'sync-waiting', 'clean-waiting']
        .includes(status)) return 'warning';
    return 'info';
}

export function folderStateClass(status) {
    const color = folderClass(status);
    return color === 'primary' || ['outofsync', 'localadditions'].includes(status)
        ? 'warning' : color;
}

export function folderStateDetails(folder, info) {
    return !!(info?.state && !folder.paused && (folderStatus(folder, info) !== 'idle' ||
        info.globalFiles !== info.localFiles ||
        info.globalDirectories !== info.localDirectories ||
        info.globalBytes !== info.localBytes));
}

export function progressPercentage(current, total) {
    return current === total ? 99 : Math.floor(100 * current / total);
}

export function syncPercentage(info) {
    if (!info || info.needTotalItems === 0) return 100;
    if (info.needBytes === 0 && info.needTotalItems > 0) return 95;
    return progressPercentage(info.inSyncBytes, info.globalBytes);
}

export function localStateTotal(models) {
    const total = {bytes: 0, directories: 0, files: 0};
    for (const model of Object.values(models)) {
        total.bytes += model.localBytes;
        total.directories += model.localDirectories;
        total.files += model.localFiles;
    }
    return total;
}
