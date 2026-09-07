// Copyright (C) 2014 The Syncthing Authors.
// SPDX-License-Identifier: MPL-2.0

export function preferredLocale(requested, available) {
    for (const browser of requested) {
        if (browser.length < 2) continue;
        const match = available.find(candidate => {
            const lower = candidate.toLowerCase();
            return lower.startsWith(browser) &&
                (lower.length === browser.length || lower[browser.length] === '-');
        });
        if (match) return match;
    }
    return 'en';
}

export function translator(messages, fallback = {}) {
    return (key, values = {}) => {
        const text = messages[key] ?? fallback[key] ?? key;
        return text.replace(/{{\s*(\w+)\s*}}/g, (_, name) => values[name] ?? '');
    };
}

export function createLocale(api, {available = window.validLangs,
    pageUrl = location.href, fetch: fetcher = globalThis.fetch,
    storage = () => window.localStorage} = {}) {
    async function dictionary(language) {
        const response = await fetcher(new URL(
            'assets/lang/lang-' + encodeURIComponent(language) + '.json', pageUrl));
        if (!response.ok) throw new Error('Could not load language ' + language);
        return response.json();
    }
    async function use(language, save = false) {
        const fallback = await dictionary('en');
        let messages = fallback;
        if (language !== 'en') {
            try { messages = await dictionary(language); } catch { language = 'en'; }
        }
        if (save) {
            try { storage().setItem('SYN_LANG', language); } catch {}
        }
        return {language, t: translator(messages, fallback)};
    }
    async function auto() {
        const param = new URL(pageUrl).searchParams.get('lang');
        if (param) return use(param, true);
        let saved;
        try { saved = storage().getItem('SYN_LANG'); } catch {}
        if (saved) return use(saved);
        let languages = [];
        try { languages = await api.get('svc/lang'); } catch {}
        return use(preferredLocale(languages, available));
    }
    return {auto, use};
}
