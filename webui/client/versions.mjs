// Copyright (C) 2026 The Syncshell Authors.
// SPDX-License-Identifier: MPL-2.0

export function versionGroups(versions, search = '', start = '', end = '') {
    const groups = new Map(), query = search.toLowerCase().replaceAll('\\', '/');
    const minimum = start ? new Date(start).getTime() : -Infinity;
    const maximum = end ? new Date(end).getTime() : Infinity;
    for (const [path, entries] of Object.entries(versions || {}).sort(([a], [b]) => a.localeCompare(b))) {
        if (!path.toLowerCase().includes(query)) continue;
        const visible = entries.filter(entry => {
            const time = new Date(entry.versionTime).getTime();
            return time >= minimum && time <= maximum;
        }).sort((a, b) => new Date(b.versionTime) - new Date(a.versionTime));
        if (!visible.length) continue;
        const parent = path.includes('/') ? path.slice(0, path.lastIndexOf('/')) : '';
        if (!groups.has(parent)) groups.set(parent, []);
        groups.get(parent).push({path, versions: visible});
    }
    return [...groups.entries()];
}
export const selectedVersions = selections => Object.fromEntries(Object.entries(selections).filter(([, time]) => time));
export function selectVersions(selections, files, action) {
    const next = {...selections};
    for (const file of files) {
        if (action === 'unset') delete next[file.path];
        else next[file.path] = file.versions[action === 'oldest' ? file.versions.length - 1 : 0].versionTime;
    }
    return next;
}
export const versionActions = [['latest', 'Select latest version'], ['oldest', 'Select oldest version'], ['unset', 'Do not restore all']];
