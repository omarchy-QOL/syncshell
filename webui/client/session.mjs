// Copyright (C) 2026 The Syncshell Authors.
// SPDX-License-Identifier: MPL-2.0

import {createEvents} from './events.mjs';
import {completionTotal, connectionRates} from './devices.mjs';

export function initialState() {
    return {online: false, ready: false, error: null, config: {folders: [], devices: [], options: {}, gui: {}},
        system: {}, version: {}, model: {}, scanProgress: {}, folderStats: {},
        deviceStats: {}, connections: {}, connectionsTotal: {}, completion: {},
        discoveryCache: {}, pendingDevices: {}, pendingFolders: {}, globalChanges: [],
        errors: [], seenError: '', configInSync: true};
}

export function folderEvent(state, event) {
    const data = event.data;
    switch (event.type) {
    case 'FolderSummary':
        return {...state, model: {...state.model, [data.folder]: data.summary}};
    case 'StateChanged': {
        if (!state.model[data.folder]) return state;
        const scanProgress = {...state.scanProgress};
        if (data.to === 'scanning') delete scanProgress[data.folder];
        return {...state, scanProgress, model: {...state.model,
            [data.folder]: {...state.model[data.folder], state: data.to,
                error: data.error}}};
    }
    case 'FolderErrors':
        if (!state.model[data.folder]) return state;
        return {...state, model: {...state.model,
            [data.folder]: {...state.model[data.folder], errors: data.errors.length}}};
    case 'FolderScanProgress':
        return {...state, scanProgress: {...state.scanProgress,
            [data.folder]: {current: data.current, total: data.total, rate: data.rate}}};
    default:
        return state;
    }
}

export function createSession(api, {publish, onAuthExpired,
    refreshMs = 10000, retryMs = 1000} = {}) {
    let state = initialState();
    let controller;
    let interval;
    let hydrating;
    let previousConnectionTime = 0;

    function update(next) {
        if (controller?.signal.aborted) return;
        state = next;
        publish(state);
    }

    function fail(error) {
        if (controller?.signal.aborted) return;
        if (error.status === 403) onAuthExpired?.();
        update({...state, error});
    }

    async function read(path, query) {
        return api.get(path, query, controller.signal);
    }

    async function folderStats() {
        const stats = await read('stats/folder');
        update({...state, folderStats: stats});
    }

    function rates(connections) {
        const now = Date.now();
        const result = connectionRates(connections, state, (now - previousConnectionTime) / 1000);
        previousConnectionTime = now;
        return result;
    }

    function cleanDiscovery(cache = {}) {
        return Object.fromEntries(Object.entries(cache).map(([id, entry]) =>
            [id, {...entry, addresses: (entry.addresses || []).map(address => address.replace(/\/\?.*/, ''))}]));
    }

    async function refreshPending() {
        const [pendingDevices, pendingFolders] = await Promise.all([
            read('cluster/pending/devices'), read('cluster/pending/folders')]);
        update({...state, pendingDevices: pendingDevices || {}, pendingFolders: pendingFolders || {}});
    }

    async function refreshGlobalChanges() {
        const changes = await read('events/disk', {limit: 25});
        if (changes) update({...state, globalChanges: changes.slice().reverse()});
    }

    async function refresh() {
        const [system, connections, errors, discovery] = await Promise.all([
            read('system/status'), read('system/connections'), read('system/error'), read('system/discovery')]);
        update({...state, system, ...rates(connections), discoveryCache: cleanDiscovery(discovery),
            errors: errors?.errors || []});
    }

    async function refreshModels(config) {
        await Promise.all(config.folders.filter(folder => !folder.paused).map(async folder => {
            const model = await read('db/status', {folder: folder.id});
            update({...state, model: {...state.model, [folder.id]: model}});
        }));
        await Promise.all(config.folders.flatMap(folder => folder.devices || [])
            .filter((device, index, devices) => device.deviceID !== state.system.myID &&
                devices.findIndex(item => item.deviceID === device.deviceID) === index)
            .flatMap(device => config.folders.filter(folder => folder.devices.some(item =>
                item.deviceID === device.deviceID)).map(async folder => {
                try {
                    const result = await read('db/completion', {device: device.deviceID, folder: folder.id});
                    update({...state, completion: {...state.completion,
                        [device.deviceID]: completionTotal({...state.completion[device.deviceID], [folder.id]: result})}});
                } catch (error) { if (error.status !== 404) fail(error); }
            })));
    }

    async function hydrate() {
        const [config, system, version, stats, deviceStats, connections, inSync,
            discovery, pendingDevices, pendingFolders, errors] = await Promise.all([
            'config', 'system/status', 'system/version', 'stats/folder', 'stats/device',
            'system/connections', 'config/insync', 'system/discovery',
            'cluster/pending/devices', 'cluster/pending/folders', 'system/error'].map(path => read(path)));
        if (state.version.version && state.version.version !== version.version) {
            onAuthExpired?.();
            return;
        }
        const completion = Object.fromEntries(config.devices.map(device => [device.deviceID,
            state.completion[device.deviceID] || {_total: 100, _needBytes: 0, _needItems: 0}]));
        update({...state, online: true, error: null, config, system, version,
            folderStats: stats, deviceStats, ...rates(connections), completion,
            configInSync: inSync.configInSync, discoveryCache: cleanDiscovery(discovery),
            pendingDevices: pendingDevices || {}, pendingFolders: pendingFolders || {}, errors: errors?.errors || []});
        await refreshModels(config);
        update({...state, ready: true});
        refreshGlobalChanges().catch(fail);
    }

    const events = createEvents(api, {retryMs, onAuthExpired,
        onOnline() {
            if (!state.online && !hydrating) {
                hydrating = hydrate().catch(fail).finally(() => { hydrating = undefined; });
            }
        },
        onOffline(error) { update({...state, online: false, error}); },
        onEvent(event) {
            update(folderEvent(state, event));
            const data = event.data;
            if (event.type === 'FolderCompletion') {
                update({...state, completion: {...state.completion,
                    [data.device]: completionTotal({...state.completion[data.device], [data.folder]: data})}});
            }
            if (event.type === 'DeviceDisconnected') {
                if (state.connections[data.id]) update({...state, connections: {...state.connections,
                    [data.id]: {...state.connections[data.id], connected: false}}});
                read('stats/device').then(deviceStats => update({...state, deviceStats})).catch(fail);
            }
            if (event.type === 'DeviceConnected') refresh().catch(fail);
            if (event.type === 'PendingDevicesChanged' || event.type === 'PendingFoldersChanged') {
                refreshPending().catch(fail);
            }

            if (event.type === 'ConfigSaved') {
                update({...state, config: event.data});
                refreshModels(event.data).catch(fail);
                read('config/insync').then(value => update({...state,
                    configInSync: value.configInSync})).catch(fail);
            }
            if (event.type === 'LocalIndexUpdated' || (event.type === 'StateChanged' &&
                event.data.from === 'scanning' && event.data.to === 'idle')) {
                folderStats().catch(fail);
                refreshGlobalChanges().catch(fail);
            }
        }});

    function start() {
        if (controller && !controller.signal.aborted) return;
        controller = new AbortController();
        interval = setInterval(() => refresh().catch(fail), refreshMs);
        events.start();
    }

    async function stop() {
        controller?.abort();
        clearInterval(interval);
        await events.stop();
    }

    async function rescan(folder, sub) {
        try {
            await api.post('db/scan', undefined, {folder, sub}, controller.signal);
        } catch (error) {
            fail(error);
            throw error;
        }
    }

    async function saveConfig(config) {
        try {
            await api.put('config', config, controller.signal);
            update({...state, config});
            const inSync = await read('config/insync');
            update({...state, configInSync: inSync.configInSync});
        } catch (error) { fail(error); throw error; }
    }

    function changeConfig(edit) {
        const config = JSON.parse(JSON.stringify(state.config));
        edit(config);
        return saveConfig(config);
    }

    function setPaused(kind, id, paused) {
        return changeConfig(config => {
            for (const item of config[kind]) {
                if (kind === 'devices' && item.deviceID === state.system.myID) continue;
                if (id === undefined || (kind === 'folders' ? item.id : item.deviceID) === id) item.paused = paused;
            }
        });
    }

    function dismissNotification(id) {
        return changeConfig(config => {
            config.options.unackedNotificationIDs = (config.options.unackedNotificationIDs || []).filter(value => value !== id);
        });
    }

    async function clearErrors() {
        const seenError = state.errors.at(-1)?.when || state.seenError;
        try {
            await api.post('system/error/clear', undefined, undefined, controller.signal);
            update({...state, errors: [], seenError});
        } catch (error) { fail(error); throw error; }
    }

    async function dismissPending(device, folder) {
        try {
            await api.delete(folder ? 'cluster/pending/folders' : 'cluster/pending/devices',
                {device, folder}, controller.signal);
            await refreshPending();
        } catch (error) { fail(error); throw error; }
    }

    async function ignorePending(device, folder, pending) {
        await changeConfig(config => {
            if (folder) {
                const target = config.devices.find(item => item.deviceID === device);
                target.ignoredFolders = [...(target.ignoredFolders || []).filter(item => item.id !== folder),
                    {id: folder, label: pending.label, time: new Date().toISOString()}];
            } else {
                config.ignoredDevices = [...(config.ignoredDevices || []).filter(item => item.deviceID !== device),
                    {deviceID: device, name: pending.name, address: pending.address}];
            }
        });
        await dismissPending(device, folder);
    }

    async function systemAction(action) {
        try { await api.post('system/' + action, undefined, undefined, controller.signal); }
        catch (error) { fail(error); throw error; }
    }

    return {start, stop, rescan, refresh, refreshGlobalChanges, reportError: fail, saveConfig, changeConfig, setPaused,
        dismissNotification, clearErrors, dismissPending, ignorePending, systemAction};
}
