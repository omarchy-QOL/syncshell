// Copyright (C) 2014 The Syncthing Authors.
// SPDX-License-Identifier: MPL-2.0

import {timestamp} from './format.mjs';

export const deviceName = device => device?.name || device?.deviceID?.slice(0, 7) || '';
export const sharedFolders = (config, id) => config.folders.filter(folder =>
    folder.devices.some(device => device.deviceID === id));

export function grouped(items, name, id) {
    const groups = {};
    for (const item of items) (groups[item.group || ''] ||= []).push(item);
    return Object.keys(groups).sort().map(group => [group,
        groups[group].sort((a, b) => (a[name] || a[id]).localeCompare(b[name] || b[id]))]);
}

export function completionTotal(folders = {}) {
    let bytes = 0, needed = 0, items = 0, deletes = 0;
    for (const [key, folder] of Object.entries(folders)) {
        if (key.startsWith('_')) continue;
        bytes += folder.globalBytes;
        needed += folder.needBytes;
        items += folder.needItems;
        deletes += folder.needDeletes;
    }
    return {...folders, _total: needed === 0 && items + deletes > 0 ? 95 :
        bytes === 0 ? 100 : Math.floor(100 * (1 - needed / bytes)),
        _needBytes: bytes === 0 ? 0 : needed, _needItems: bytes === 0 ? 0 : items + deletes};
}

export function connectionRates(current, previous, elapsed) {
    const rate = (value = {}, old) => ({...value,
        inbps: old && elapsed > 0 ? Math.max(0, (value.inBytesTotal - old.inBytesTotal) / elapsed) : 0,
        outbps: old && elapsed > 0 ? Math.max(0, (value.outBytesTotal - old.outBytesTotal) / elapsed) : 0});
    return {connectionsTotal: rate(current.total, previous.connectionsTotal),
        connections: Object.fromEntries(Object.entries(current.connections || {}).map(([id, conn]) =>
            [id, rate(conn, previous.connections?.[id])]))};
}

export function deviceStatus(device, state) {
    const unused = sharedFolders(state.config, device.deviceID).length === 0 ? 'unused-' : '';
    const conn = state.connections[device.deviceID];
    if (!conn) return 'unknown';
    if (device.paused) return unused + 'paused';
    if (conn.connected) return state.completion[device.deviceID]?._total === 100
        ? unused + 'insync' : 'syncing';
    const age = lastSeenDays(state.deviceStats[device.deviceID]?.lastSeen);
    return unused + (!unused && (!age || age >= 7) ? 'disconnected-inactive' : 'disconnected');
}

export const deviceLabels = {unknown: 'Unknown', disconnected: 'Disconnected',
    'disconnected-inactive': 'Disconnected (Inactive)', insync: 'Up to Date', paused: 'Paused',
    syncing: 'Syncing', 'unused-disconnected': 'Disconnected (Unused)',
    'unused-insync': 'Connected (Unused)', 'unused-paused': 'Paused (Unused)'};
export const deviceIcons = {disconnected: 'fa-power-off', 'disconnected-inactive': 'fa-power-off',
    insync: 'fa-check', paused: 'fa-pause', syncing: 'fa-sync', unknown: 'fa-question-circle',
    'unused-disconnected': 'fa-unlink', 'unused-insync': 'fa-unlink', 'unused-paused': 'fa-unlink'};
export function deviceColor(device, state) {
    const conn = state.connections[device.deviceID];
    return !conn ? 'info' : device.paused ? 'default' : !conn.connected ? 'info' :
        state.completion[device.deviceID]?._total === 100 ? 'success' : 'primary';
}
export function lastSeenDays(value) {
    const date = new Date(value);
    return !value || date.getTime() === 0 ? undefined : (Date.now() - date) / 86400000;
}
export function connectionType(conn) {
    if (!conn) return '-1';
    for (const type of ['relay', 'quic', 'tcp']) {
        if (conn.type?.startsWith(type)) return type + (conn.isLocal ? 'lan' : 'wan');
    }
    return 'disconnected';
}
export const connectionLabels = {relaywan: 'Relay WAN', relaylan: 'Relay LAN',
    quicwan: 'QUIC WAN', quiclan: 'QUIC LAN', tcpwan: 'TCP WAN', tcplan: 'TCP LAN'};
export const connectionIcons = {tcplan: 'reception-4', quiclan: 'reception-4', tcpwan: 'reception-3',
    quicwan: 'reception-3', relaylan: 'reception-2', relaywan: 'reception-1', disconnected: 'reception-0'};
export function remoteGui(device, conn) {
    if (!device.remoteGUIPort || !conn?.connected || !conn.address || conn.type?.includes('Relay')) return '';
    const index = conn.address.lastIndexOf(':');
    const address = index < 0 ? conn.address : conn.address.slice(0, index) + ':' + device.remoteGUIPort;
    return 'http://' + address.replace(/%.*?\]:/, ']:').replace('%', '%25');
}
export function addressError(status) {
    return status?.error ? status.error.replace(/.+: /, '') + ' (' + timestamp(status.when).slice(-8) + ')' : '';
}
export function serviceHealth(services = {}) {
    const entries = Object.entries(services);
    const failed = entries.filter(([, value]) => value?.error);
    return {entries, failed, total: entries.length, running: entries.length - failed.length,
        color: entries.length && !failed.length ? 'success' : entries.length === failed.length ? 'danger' : ''};
}
export function identiconRects(id = '') {
    const value = id.replace(/[\W_]/g, '');
    const rects = [];
    if (!value) return rects;
    for (let row = 0; row < 5; row++) for (let col = 2; col >= 0; col--) {
        if (!(value.charCodeAt(row + col * 5) % 2)) {
            rects.push([col, row]);
            if (col !== 2) rects.push([4 - col, row]);
        }
    }
    return rects;
}
