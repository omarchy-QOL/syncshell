export const itemRoutes = {need: 'db/need', failed: 'folder/errors', local: 'db/localchanged'};
export const itemTitles = {need: 'Out of Sync Items', failed: 'Failed Items', local: 'Locally Changed Items'};

export function neededItems(data) {
    return ['progress', 'queued', 'rest'].flatMap(type => (data[type] || []).map(file => {
        const flags = file.flags;
        const action = (flags & 20480) === 20480 ? 'Del (dir)' :
            flags & 4096 ? 'Del' : flags & 16384 ? 'Update' : 'Sync';
        return {...file, type, action};
    }));
}

export function pageItems(kind, data) {
    return kind === 'need' ? neededItems(data) : kind === 'failed' ? data.errors || [] : data.files || [];
}
