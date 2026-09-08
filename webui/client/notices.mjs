// Copyright (C) 2014 The Syncthing Authors.
// SPDX-License-Identifier: MPL-2.0

import {notificationCards} from './notification-cards.mjs';
import {deviceName} from './devices.mjs';
import {folderStatus} from './folders.mjs';

export function notices(state) {
    const cards = [];
    const config = state.config;
    const gui = config.gui || {};
    const address = state.system.guiAddressUsed;
    const authenticated = gui.authMode === 'ldap' || (gui.user && gui.password);
    if (address && !address.startsWith('127.') && !address.startsWith('[::1]:') &&
        !address.startsWith('/') && !authenticated && !gui.insecureAdminAccess) {
        cards.push({id: 'openNoAuth', severity: 'danger', title: 'Danger!',
            paragraphs: ['The Syncthing admin interface is configured to allow remote access without a password.',
                'This can easily give hackers access to read and change any files on your computer.',
                'Please set a GUI Authentication User and Password in the Settings dialog.'], actions: ['Settings']});
    }
    if (!state.configInSync) cards.push({id: 'restart', severity: 'warning', title: 'Restart Needed',
        paragraphs: ['The configuration has been saved but not activated. Syncthing must restart to activate the new configuration.'], actions: ['Restart']});
    for (const id of config.options?.unackedNotificationIDs || []) {
        if (id === 'authenticationUserAndPassword' && authenticated) continue;
        if (notificationCards[id]) cards.push({id, ...notificationCards[id],
            params: {syncthingInotify: 'syncthing-inotify'}});
    }
    for (const [id, pending] of Object.entries(state.pendingDevices)) {
        cards.push({id: 'device-' + id, kind: 'device', device: id, pending, severity: 'warning',
            title: 'New Device', time: pending.time,
            paragraphs: ['Device "{%name%}" ({%device%} at {%address%}) wants to connect. Add new device?'],
            params: {name: pending.name, device: id, address: pending.address}, actions: ['Add Device', 'Ignore', 'Dismiss']});
    }
    for (const [folder, pending] of Object.entries(state.pendingFolders)) {
        for (const [device, offered] of Object.entries(pending.offeredBy || {})) {
            const existing = config.folders.find(item => item.id === folder);
            cards.push({id: 'folder-' + folder + '-' + device, kind: 'folder', folder, device, pending: offered,
                folderConfig: existing, severity: 'warning', title: existing ? 'Share Folder' : 'New Folder', time: offered.time,
                paragraphs: [offered.label ? '{%device%} wants to share folder "{%folderlabel%}" ({%folder%}).'
                    : '{%device%} wants to share folder "{%folder%}".', existing ? 'Share this folder?' : 'Add new folder?'],
                params: {device: deviceName(config.devices.find(item => item.deviceID === device)),
                    folder, folderlabel: offered.label}, actions: [existing ? 'Share' : 'Add', 'Ignore', 'Dismiss']});
        }
    }
    const errors = state.errors.filter(error => !state.seenError || error.when > state.seenError);
    if (errors.length) cards.push({id: 'errors', severity: 'warning', title: 'Notice',
        errors: errors.map(error => ({...error, message: config.devices.reduce((text, device) =>
            text.replace(device.deviceID, deviceName(device)), error.message)})), actions: ['OK']});
    const watchers = config.folders.filter(folder => folder.fsWatcherEnabled && !folder.paused &&
        state.model[folder.id]?.watchError && folderStatus(folder, state.model[folder.id]) !== 'stopped')
        .map(folder => ({name: folder.label || folder.id, error: state.model[folder.id].watchError}));
    if (watchers.length) cards.push({id: 'watchers', severity: 'warning', title: 'Filesystem Watcher Errors', watchers,
        paragraphs: ["For the following folders an error occurred while starting to watch for changes. It will be retried every minute, so the errors might go away soon. If they persist, try to fix the underlying issue and ask for help if you can't."],
        link: 'https://forum.syncthing.net', actions: []});
    return cards;
}

export async function noticeAction(session, card, action, open) {
    if (action === 'Settings') { open({type: 'settings'}); if (card.id === 'channelNotification') await session.dismissNotification(card.id); return; }
    if (action === 'Restart') return open({type: 'restart'});
    if (action === 'Ignore') return session.ignorePending(card.device, card.folder, card.pending);
    if (action === 'Dismiss') return session.dismissPending(card.device, card.folder);
    if (action === 'Share' && card.folderConfig?.type !== 'receiveencrypted' && card.pending.remoteEncrypted) {
        const folder = JSON.parse(JSON.stringify(card.folderConfig));
        if (!folder.devices.some(member => member.deviceID === card.device)) folder.devices.push({deviceID: card.device, encryptionPassword: ''});
        return open({type: 'edit-folder', folder, tab: 'sharing'});
    }
    if (action === 'Share') return session.changeConfig(config => {
        const folder = config.folders.find(item => item.id === card.folder);
        if (!folder.devices.some(item => item.deviceID === card.device)) folder.devices.push({deviceID: card.device});
    });
    if (action === 'Add' || action === 'Add Device') {
        open({type: card.kind === 'folder' ? 'add-folder' : 'add-device', ...card});
        return;
    }
    if (card.id === 'errors') return session.clearErrors();
    if (action === 'Yes' && card.id === 'fsWatcherNotification') {
        await session.changeConfig(config => {
            for (const folder of config.folders) if (!folder.fsWatcherEnabled) {
                folder.fsWatcherEnabled = true;
                if (folder.rescanIntervalS) folder.rescanIntervalS = Math.min(86400, folder.rescanIntervalS * 60);
            }
        });
    }
    if (action === 'Enable Crash Reporting' || action === 'Disable Crash Reporting') {
        await session.changeConfig(config => { config.options.crashReportingEnabled = action.startsWith('Enable'); });
    }
    return session.dismissNotification(card.id);
}
