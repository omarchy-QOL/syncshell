export const transferSegments = [
    ['reused', 'Reused', 'success'], ['copiedFromOrigin', 'Copied from original', ''],
    ['copiedFromElsewhere', 'Copied from elsewhere', 'info'], ['pulled', 'Downloaded', 'warning'],
    ['pulling', 'Downloading', 'danger'],
];
export function transferProgress(stats) {
    return Object.fromEntries(Object.entries(stats).map(([folder, files]) => [folder,
        Object.fromEntries(Object.entries(files).map(([file, value]) => {
            const parts = Object.fromEntries(transferSegments.map(([key]) => [key, 100 * value[key] / value.total]));
            if (parts.pulling < 1 && parts.pulled + parts.copiedFromElsewhere + parts.copiedFromOrigin + parts.reused <= 99) parts.pulling = 1;
            return [file, {...parts, bytesTotal: value.bytesTotal, bytesDone: value.bytesDone}];
        }))]));
}
export function endedTransfers(previous, next) {
    return Object.keys(previous).filter(folder => Object.keys(previous[folder]).some(file => !next[folder]?.[file]));
}
export const needIcons = {'Del': 'far fa-trash-alt', 'Del (dir)': 'far fa-trash-alt', 'Sync': 'far fa-arrow-alt-circle-down', 'Update': 'fas fa-asterisk'};
