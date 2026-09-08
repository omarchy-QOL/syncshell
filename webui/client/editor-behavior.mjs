import {setValue} from './edit.mjs';
export function folderPath(base, name, separator = '/') {
    return base ? base.replace(/[\\/]+$/, '') + separator + name : '';
}
export function updateEditor(draft, path, value, {kind, isNew, defaults, autoPath, config, system}) {
    const next = setValue(draft, path, value);
    if (kind === 'device' && path === 'untrusted' && value) {
        next.introducer = false; next.autoAcceptFolders = false;
    }
    if (kind === 'folder') {
        if (path === 'type') {
            next.fsWatcherEnabled = value !== 'receiveencrypted';
            if (value === 'receiveencrypted') { next.ignorePerms = true; next.versioning = {type: ''}; }
            if (isNew || defaults) next.blockIndexing = ['sendreceive', 'receiveonly'].includes(value);
        }
        if (['type', 'fsWatcherEnabled'].includes(path) && [60, 3600, 86400].includes(next.rescanIntervalS))
            next.rescanIntervalS = next.type === 'receiveencrypted' ? 86400 : next.fsWatcherEnabled ? 3600 : 60;
        if (isNew && autoPath && ['label', 'id'].includes(path) && config.defaults.folder.path)
            next.path = folderPath(config.defaults.folder.path, next.label || next.id, system.pathSeparator);
    }
    return next;
}
export function editorFieldState(field, draft, {kind, isNew, defaults, myID}) {
    const value = {...field};
    if (kind === 'device') {
        value.disabled = (['introducer', 'autoAcceptFolders'].includes(field.path) && draft.untrusted) ||
            (field.path === 'addresses' && draft.deviceID === myID);
        return value;
    }
    if (field.path.startsWith('versioning.') && field.path !== 'versioning.type' &&
        !['simple', 'trashcan', 'staggered'].includes(draft.versioning?.type)) value.hidden = true;
    if (field.path.startsWith('xattrFilter.') && !draft.syncXattrs && !draft.sendXattrs) value.hidden = true;
    if (field.path === 'type' && !isNew && !defaults) {
        value.disabled = draft.type === 'receiveencrypted';
        value.options = field.options.filter(([type]) => type !== 'receiveencrypted' || draft.type === type);
    }
    value.disabled ||= (['fsWatcherEnabled', 'ignorePerms', 'versioning.type'].includes(field.path) && draft.type === 'receiveencrypted') ||
        (field.path === 'order' && draft.type === 'sendonly') ||
        (['syncOwnership', 'syncXattrs'].includes(field.path) && ['sendonly', 'receiveencrypted'].includes(draft.type)) ||
        (field.path === 'sendOwnership' && (['receiveonly', 'receiveencrypted'].includes(draft.type) || draft.syncOwnership)) ||
        (field.path === 'sendXattrs' && (['receiveonly', 'receiveencrypted'].includes(draft.type) || draft.syncXattrs));
    if (field.path === 'sendOwnership') value.checked = draft.sendOwnership || draft.syncOwnership;
    if (field.path === 'sendXattrs') value.checked = draft.sendXattrs || draft.syncXattrs;
    return value;
}
export function newXattrEntry(entries = []) {
    if (entries.some(entry => entry.match === '')) return entries;
    const next = entries.slice(), entry = {match: '', permit: false};
    next.splice(next.at(-1)?.match === '*' ? next.length - 1 : next.length, 0, entry);
    return next;
}
export function xattrDefault(entries = []) {
    return !entries.length ? 'permit' : entries.at(-1).match !== '*' ? 'deny' : '';
}
export function xattrHint(entries = []) {
    return entries.length && !(entries.length === 1 && entries[0].match === '*') && entries.every(entry => !entry.permit)
        ? 'Hint: only deny-rules detected while the default is deny. Consider adding "permit any" as last rule.' : '';
}
export function overlappingPath(draft, config, system) {
    if (!draft.path) return null;
    const parts = path => path.replace(/^~(?=[\\/])/, system.tilde || '~')
        .split(system.pathSeparator || '/').filter((part, index, all) => part || index !== all.length - 1);
    const candidate = parts(draft.path);
    for (const folder of config.folders.filter(folder => folder.id !== draft.id)) {
        const existing = parts(folder.path);
        if (existing.length <= candidate.length && existing.every((part, index) => part === candidate[index])) return {folder, type: 'subdirectory'};
        if (candidate.length <= existing.length && candidate.every((part, index) => part === existing[index])) return {folder, type: 'parent directory'};
    }
    return null;
}
