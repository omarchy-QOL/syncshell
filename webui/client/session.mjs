// Copyright (C) 2026 The Syncshell Authors.
// SPDX-License-Identifier: MPL-2.0

import {createEvents} from './events.mjs';

export function initialState() {
    return {online: false, ready: false, error: null, config: {folders: [], devices: []},
        system: {}, version: {}, model: {}, scanProgress: {}, folderStats: {},
        deviceStats: {}, connections: {}, errors: [], configInSync: true};
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

    function update(next) {
        if (controller.signal.aborted) return;
        state = next;
        publish(state);
    }

    function fail(error) {
        if (controller.signal.aborted) return;
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

    async function refresh() {
        const [system, connections, errors] = await Promise.all([
            read('system/status'), read('system/connections'), read('system/error')]);
        update({...state, system, connections: connections.connections,
            errors: errors.errors || []});
    }

    async function hydrate() {
        const [config, system, version, stats, deviceStats, connections, inSync] =
            await Promise.all(['config', 'system/status', 'system/version',
                'stats/folder', 'stats/device', 'system/connections', 'config/insync']
                .map(path => read(path)));
        const models = await Promise.all(config.folders.filter(folder => !folder.paused)
            .map(async folder => [folder.id, await read('db/status', {folder: folder.id})]));
        update({...state, ready: true, online: true, error: null, config, system,
            version, folderStats: stats, deviceStats, connections: connections.connections,
            configInSync: inSync.configInSync, model: {...state.model, ...Object.fromEntries(models)}});
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
            if (event.type === 'ConfigSaved') {
                update({...state, config: event.data});
                read('config/insync').then(value => update({...state,
                    configInSync: value.configInSync})).catch(fail);
            }
            if (event.type === 'LocalIndexUpdated' || (event.type === 'StateChanged' &&
                event.data.from === 'scanning' && event.data.to === 'idle')) {
                folderStats().catch(fail);
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

    return {start, stop, rescan, refresh};
}
