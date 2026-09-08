// Copyright (C) 2014 The Syncthing Authors.
// SPDX-License-Identifier: MPL-2.0

export function translator(messages) {
    return (key, values = {}) => {
        let text;
        if (Object.hasOwn(messages, key) && typeof messages[key] === 'string') {
            text = messages[key];
        } else {
            const value = String(key).split('.').reduce((current, part) =>
                current && Object.hasOwn(current, part) ? current[part] : undefined,
            messages);
            text = typeof value === 'string' ? value : key ?? '';
        }
        return text.replace(/{{\s*(\w+)\s*}}|{%\s*(\w+)\s*%}/g,
            (_, catalogName, sourceName) => values[catalogName || sourceName] ?? '');
    };
}

export async function loadEnglish({pageUrl = location.href,
    fetch: fetcher = globalThis.fetch} = {}) {
    const response = await fetcher(new URL('assets/lang/lang-en.json', pageUrl));
    if (!response.ok) throw new Error('Could not load English interface text');
    return {language: 'en', t: translator(await response.json())};
}
