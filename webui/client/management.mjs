export function recoveryActions(folder, info = {}, status) {
    const actions = [];
    if (folder.type === 'sendonly' && status === 'outofsync') actions.push('override');
    if (['receiveonly', 'receiveencrypted'].includes(folder.type) && info.receiveOnlyTotalItems > 0 &&
        ['outofsync', 'faileditems', 'localadditions'].includes(status)) actions.push('revert');
    return actions;
}
export const managementActions = {
    'remove-folder': {title: 'Remove Folder', button: 'Yes', description: 'Are you sure you want to remove folder {%label%}?', detail: 'No files will be deleted as a result of this operation.'},
    'remove-device': {title: 'Remove Device', button: 'Yes', description: 'Are you sure you want to remove device {%name%}?'},
    override: {title: 'Override Changes', button: 'Override', description: 'The folder content on other devices will be overwritten to become identical with this device. Files not present here will be deleted on other devices.', detail: 'Are you sure you want to override all remote changes?'},
    revert: {title: 'Revert Local Changes', button: 'Revert', description: 'The folder content on this device will be overwritten to become identical with other devices. Files newly added here will be deleted.', detail: 'Are you sure you want to revert all local changes?'},
};
export async function performManagement(action, session, api) {
    if (action.type === 'remove-folder') return session.changeConfig(config => {
        config.folders = config.folders.filter(folder => folder.id !== action.folder.id);
    });
    if (action.type === 'remove-device') return session.changeConfig(config => {
        config.devices = config.devices.filter(device => device.deviceID !== action.device.deviceID);
        for (const folder of config.folders) folder.devices = folder.devices.filter(device => device.deviceID !== action.device.deviceID);
    });
    if (action.type === 'override' || action.type === 'revert')
        return api.post('db/' + action.type, undefined, {folder: action.folder.id});
    throw new Error('Unknown folder action');
}
