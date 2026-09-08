// Copyright (C) 2014 The Syncthing Authors.
// SPDX-License-Identifier: MPL-2.0

export function folderStatusIcon(status) {
    switch (status) {
        case 'clean-waiting':
        case 'scan-waiting':
        case 'sync-preparing':
        case 'sync-waiting':
        case 'starting':
            return 'fa-hourglass-half';
        case 'cleaning':
            return 'fa-recycle';
        case 'faileditems':
        case 'localunencrypted':
        case 'outofsync':
            return 'fa-exclamation-circle';
        case 'idle':
        case 'localadditions':
            return 'fa-check';
        case 'paused':
            return 'fa-pause';
        case 'scanning':
            return 'fa-search';
        case 'stopped':
            return 'fa-stop';
        case 'syncing':
            return 'fa-sync';
        case 'unknown':
            return 'fa-question-circle';
        case 'unshared':
            return 'fa-unlink';
    }
}

export function folderStatusText(status) {
    switch (status) {
        case 'clean-waiting':
            return 'Waiting to Clean';
        case 'cleaning':
            return 'Cleaning Versions';
        case 'faileditems':
            return 'Failed Items';
        case 'idle':
            return 'Up to Date';
        case 'starting':
            return 'Starting';
        case 'localadditions':
            return 'Local Additions';
        case 'localunencrypted':
            return 'Unexpected Items';
        case 'outofsync':
            return 'Out of Sync';
        case 'paused':
            return 'Paused';
        case 'scan-waiting':
            return 'Waiting to Scan';
        case 'scanning':
            return 'Scanning';
        case 'stopped':
            return 'Stopped';
        case 'sync-preparing':
            return 'Preparing to Sync';
        case 'sync-waiting':
            return 'Waiting to Sync';
        case 'syncing':
            return 'Syncing';
        case 'unknown':
            return 'Unknown';
        case 'unshared':
            return 'Unshared';
    }
}


export const folderTypes = {sendreceive: 'Send & Receive', sendonly: 'Send Only',
    receiveonly: 'Receive Only', receiveencrypted: 'Receive Encrypted'};
export const pullOrders = {random: 'Random', alphabetic: 'Alphabetic',
    smallestFirst: 'Smallest First', largestFirst: 'Largest First',
    oldestFirst: 'Oldest First', newestFirst: 'Newest First'};
export const versioningTypes = {trashcan: 'Trash Can', simple: 'Simple',
    staggered: 'Staggered', external: 'External'};

export function scanRemaining(progress) {
    if (!progress) return '';
    let seconds = Math.ceil((progress.total - progress.current) / progress.rate / 10) * 10;
    let days = 0;
    let hours = 0;
    const result = [];
    if (seconds >= 86400) {
        days = Math.floor(seconds / 86400);
        if (days > 31) return '> 1 month';
        result.push(days + 'd');
        seconds %= 86400;
    }
    if (seconds > 3600) {
        hours = Math.floor(seconds / 3600);
        result.push(hours + 'h');
        seconds %= 3600;
    }
    const date = new Date(new Date(1970, 0, 1).setSeconds(seconds));
    if (days === 0) result.push(date.getMinutes() + 'm');
    if (days === 0 && hours === 0) result.push(String(date.getSeconds()).padStart(2, '0') + 's');
    return result.join(' ');
}
