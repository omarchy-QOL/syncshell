// Copyright (C) 2026 The Syncshell Authors.
// SPDX-License-Identifier: MPL-2.0

export class HttpError extends Error {
    constructor(response, data) {
        super(typeof data === 'string' && data ? data :
            data?.error || `HTTP ${response.status}`);
        this.name = 'HttpError';
        this.status = response.status;
        this.data = data;
        this.url = response.url;
    }
}

export function createApi({pageUrl = location.href,
    metadata = window.metadata, fetch: fetcher = globalThis.fetch,
    cookie = () => document.cookie} = {}) {
    const base = new URL('rest/', pageUrl);
    const suffix = metadata?.deviceIDShort;

    async function request(method, path, {query, body, signal} = {}) {
        const url = new URL(path, base);
        if (url.origin !== base.origin || !url.pathname.startsWith(base.pathname)) {
            throw new TypeError('Syncthing requests must stay within the REST base');
        }
        for (const [key, value] of Object.entries(query || {})) {
            if (value !== undefined && value !== null) url.searchParams.set(key, value);
        }
        const headers = new Headers({Accept: 'application/json, text/plain, */*'});
        if (suffix) {
            const prefix = `CSRF-Token-${suffix}=`;
            const token = cookie().split(';').map(part => part.trim())
                .find(part => part.startsWith(prefix));
            if (token) headers.set(`X-CSRF-Token-${suffix}`,
                decodeURIComponent(token.slice(prefix.length)));
        }
        if (body !== undefined) headers.set('Content-Type', 'application/json');
        const response = await fetcher(url, {method, headers, signal,
            credentials: 'same-origin',
            body: body === undefined ? undefined : JSON.stringify(body)});
        const text = await response.text();
        let data = text;
        if (text && (response.headers.get('Content-Type')?.includes('json') ||
            /^[\s]*[\[{]/.test(text))) {
            try { data = JSON.parse(text); } catch (error) {
                if (response.ok) throw error;
            }
        }
        if (!response.ok) throw new HttpError(response, data);
        return data;
    }

    return {
        request,
        get: (path, query, signal) => request('GET', path, {query, signal}),
        post: (path, body, query, signal) =>
            request('POST', path, {body, query, signal}),
        put: (path, body, signal) => request('PUT', path, {body, signal}),
        patch: (path, body, signal) => request('PATCH', path, {body, signal}),
        delete: (path, query, signal) => request('DELETE', path, {query, signal})
    };
}
