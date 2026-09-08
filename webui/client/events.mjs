// Copyright (C) 2014 The Syncthing Authors.
// SPDX-License-Identifier: MPL-2.0

// preserve the cursor and recovery behavior of core/eventService.js
export function createEvents(api, {onEvent, onOnline = () => {},
    onOffline = () => {}, onAuthExpired = () => location.reload(),
    retryMs = 1000} = {}) {
    let running;
    let controller;
    let timer;
    let wake;
    let lastID = 0;

    function start() {
        if (running) return running;
        controller = new AbortController();
        const signal = controller.signal;
        running = poll(signal).finally(() => { running = undefined; });
        return running;
    }

    async function poll(signal) {
        let query = {limit: 1};
        while (!signal.aborted) {
            try {
                const data = await api.get('events', query, signal);
                if (signal.aborted) return;
                // a daemon restart can leave an already-started 200 response empty
                if (!data) throw new Error('Empty event response');
                onOnline();
                if (lastID > 0) data.forEach(onEvent);
                if (data.length) lastID = data[data.length - 1].id;
                query = {since: lastID};
            } catch (error) {
                if (signal.aborted) return;
                if (error.status === 403) {
                    onAuthExpired();
                    return;
                }
                onOffline(error);
                await new Promise(resolve => {
                    wake = resolve;
                    timer = setTimeout(resolve, retryMs);
                });
                timer = undefined;
                wake = undefined;
                query = {limit: 1};
            }
        }
    }

    function stop() {
        controller?.abort();
        clearTimeout(timer);
        wake?.();
        return running;
    }

    return {start, stop};
}
