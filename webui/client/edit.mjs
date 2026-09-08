export const copy = value => JSON.parse(JSON.stringify(value));
export const getValue = (object, path) => path.split('.').reduce((value, key) => value?.[key], object);
export function setValue(object, path, value) {
    const result = copy(object), keys = path.split('.');
    let target = result;
    for (const key of keys.slice(0, -1)) target = target[key] ||= {};
    target[keys.at(-1)] = value;
    if (path === 'versioning.type' && value) {
        const defaults = value === 'simple' ? {keep: '5', cleanoutDays: '0'}
            : value === 'trashcan' ? {cleanoutDays: '0'}
            : value === 'staggered' ? {maxAge: String(365 * 86400)} : {command: ''};
        result.versioning.params = {...defaults, ...result.versioning.params};
        result.versioning.cleanupIntervalS ??= 3600;
        result.versioning.fsPath ??= '';
    }
    return result;
}
const field = (path, label, type = 'text', options) => ({path, label, type, options});
export function editorFields(kind, tab, config, myID) {
    if (kind === 'device') return tab === 'General' ? [
        field('deviceID', 'Device ID'), field('name', 'Device Name'), field('group', 'Device Group')
    ] : [field('addresses', 'Addresses', 'list'),
        field('compression', 'Compression', 'select', [['metadata', 'Metadata Only'], ['always', 'All Data'], ['never', 'Off']]),
        field('introducer', 'Introducer', 'checkbox'), field('autoAcceptFolders', 'Auto Accept', 'checkbox'),
        field('untrusted', 'Untrusted', 'checkbox'), field('maxRecvKbps', 'Incoming Rate Limit (KiB/s)', 'number'),
        field('maxSendKbps', 'Outgoing Rate Limit (KiB/s)', 'number'), field('numConnections', 'Number of Connections', 'number')];
    if (kind === 'folder') {
        if (tab === 'General') return [field('label', 'Folder Label'), field('group', 'Folder Group'), field('id', 'Folder ID'), field('path', 'Folder Path')];
        if (tab === 'File Versioning') return [
            field('versioning.type', 'File Versioning', 'select', [['', 'No File Versioning'], ['trashcan', 'Trash Can'], ['simple', 'Simple'], ['staggered', 'Staggered'], ['external', 'External']]),
            field('versioning.fsPath', 'Versions Path'), field('versioning.cleanupIntervalS', 'Cleanup Interval', 'number')];
        return [field('type', 'Folder Type', 'select', [['sendreceive', 'Send & Receive'], ['sendonly', 'Send Only'], ['receiveonly', 'Receive Only'], ['receiveencrypted', 'Receive Encrypted']]),
            field('fsWatcherEnabled', 'Watch for Changes', 'checkbox'), field('rescanIntervalS', 'Full Rescan Interval (s)', 'number'),
            field('ignorePerms', 'Ignore Permissions', 'checkbox'), field('blockIndexing', 'Block Indexing', 'checkbox'),
            field('order', 'File Pull Order', 'select', [['random', 'Random'], ['alphabetic', 'Alphabetic'], ['smallestFirst', 'Smallest First'], ['largestFirst', 'Largest First'], ['oldestFirst', 'Oldest First'], ['newestFirst', 'Newest First']]),
            field('minDiskFree.value', 'Minimum Free Disk Space', 'number'), field('minDiskFree.unit', 'Unit', 'select', [['%', '%'], ['kB', 'kB'], ['MB', 'MB'], ['GB', 'GB'], ['TB', 'TB']]),
            field('syncOwnership', 'Sync Ownership', 'checkbox'), field('sendOwnership', 'Send Ownership', 'checkbox'),
            field('syncXattrs', 'Sync Extended Attributes', 'checkbox'), field('sendXattrs', 'Send Extended Attributes', 'checkbox'),
            field('xattrFilter.maxSingleEntrySize', 'Maximum Single Entry Size', 'number'), field('xattrFilter.maxTotalSize', 'Maximum Total Size', 'number')];
    }
    if (tab === 'GUI') return [field('gui.user', 'GUI Authentication User'), field('gui.password', 'GUI Authentication Password', 'password'),
        field('gui.address', 'GUI Listen Address'), field('gui.useTLS', 'Use HTTPS for GUI', 'checkbox'),
        field('gui.unixSocketPermissions', 'Unix Socket Permissions')];
    if (tab === 'Connections') return [field('options.listenAddresses', 'Sync Protocol Listen Addresses', 'list'),
        field('options.globalAnnounceEnabled', 'Global Discovery', 'checkbox'), field('options.globalAnnounceServers', 'Global Discovery Servers', 'list'),
        field('options.localAnnounceEnabled', 'Local Discovery', 'checkbox'), field('options.natEnabled', 'Enable NAT traversal', 'checkbox'),
        field('options.relaysEnabled', 'Enable Relaying', 'checkbox'), field('options.maxRecvKbps', 'Incoming Rate Limit (KiB/s)', 'number'),
        field('options.maxSendKbps', 'Outgoing Rate Limit (KiB/s)', 'number'), field('options.limitBandwidthInLan', 'Limit Bandwidth in LAN', 'checkbox')];
    const self = config.devices.findIndex(device => device.deviceID === myID);
    return [field('devices.' + self + '.name', 'Device Name'), field('options.startBrowser', 'Start Browser', 'checkbox'),
        field('options.minHomeDiskFree.value', 'Minimum Free Disk Space', 'number'),
        field('options.minHomeDiskFree.unit', 'Unit', 'select', [['%', '%'], ['kB', 'kB'], ['MB', 'MB'], ['GB', 'GB'], ['TB', 'TB']])];
}

export function inputValue(draft, field) {
    const value = getValue(draft, field.path);
    return field.type === 'list' ? (value || []).join(', ') : value ?? '';
}
export function changedValue(field, input) {
    if (field.type === 'checkbox') return input.checked;
    if (field.type === 'number') return input.value === '' ? 0 : Number(input.value);
    if (field.type === 'list') return input.value.split(/[,\s]+/).map(value => value.trim()).filter(Boolean);
    return input.value;
}
export function ignoreLines(text) { return text === '' ? [] : text.split('\n'); }

export async function saveEditor({session, api, state, kind, draft, isNew, shares, defaults = false, ignores = []}) {
    const value = normalizeEditor(draft, kind);
    if (defaults) return session.changeConfig(config => {
        config.defaults[kind] = value;
        if (kind === 'folder') config.defaults.ignores.lines = ignores;
    });
    if (kind === 'device') {
        const checked = await api.get('svc/deviceid', {id: value.deviceID});
        if (checked.error) throw new Error(checked.error);
        value.deviceID = checked.id || value.deviceID;
        if (value.untrusted && state.config.folders.some(folder => folder.type !== 'receiveencrypted' &&
            shares[folder.id]?.selected && !shares[folder.id]?.password))
            throw new Error('Encryption Password is required for an untrusted device.');
        if (isNew && state.config.devices.some(item => item.deviceID === value.deviceID)) throw new Error('A device with that ID is already added.');
    } else {
        if (!value.id.trim()) throw new Error('The folder ID cannot be blank.');
        if (!value.path.trim()) throw new Error('The folder path cannot be blank.');
        if (isNew && state.config.folders.some(item => item.id === value.id)) throw new Error('The folder ID must be unique.');
        if (!value.devices.some(item => item.deviceID === state.system.myID)) value.devices.push({deviceID: state.system.myID});
        if (!value.versioning?.type) value.versioning = {type: ''};
        if (value.versioning.type === 'external' && !value.versioning.params?.command?.trim())
            throw new Error('External Versioning Command cannot be blank.');
        if (value.type !== 'receiveencrypted' && value.devices.some(member =>
            state.config.devices.find(device => device.deviceID === member.deviceID)?.untrusted && !member.encryptionPassword))
            throw new Error('Encryption Password is required for an untrusted device.');
    }
    return session.changeConfig(config => {
        const list = kind === 'device' ? 'devices' : 'folders';
        const key = kind === 'device' ? 'deviceID' : 'id';
        config[list] = [...config[list].filter(item => item[key] !== value[key]), value];
        if (kind === 'device') for (const folder of config.folders) {
            const present = folder.devices.some(item => item.deviceID === value.deviceID);
            if (shares[folder.id]?.selected && !present) folder.devices.push({deviceID: value.deviceID, encryptionPassword: shares[folder.id].password || ''});
            if (shares[folder.id]?.selected && present) folder.devices.find(item => item.deviceID === value.deviceID).encryptionPassword = shares[folder.id].password || '';
            if (!shares[folder.id]?.selected && present) folder.devices = folder.devices.filter(item => item.deviceID !== value.deviceID);
        }
    });
}

export function normalizeEditor(draft, kind) {
    const value = JSON.parse(JSON.stringify(draft));
    if (kind === 'folder') {
        if (value.xattrFilter) value.xattrFilter.entries = (value.xattrFilter.entries || []).filter(entry => entry.match !== '');
        const versioning = value.versioning || {};
        for (const key of versioning.type === 'simple' ? ['keep', 'cleanoutDays'] : versioning.type === 'trashcan' ? ['cleanoutDays'] : versioning.type === 'staggered' ? ['maxAge'] : []) {
            const number = Number(versioning.params?.[key]);
            if (!Number.isFinite(number) || number < (key === 'keep' ? 1 : 0) || versioning.params[key] === '')
                throw new Error(key === 'keep' ? 'You must keep at least one version.' : 'A negative number of days does not make sense.');
        }
    }
    return value;
}
