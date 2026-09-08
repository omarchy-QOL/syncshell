// Only the local review runner injects this file; it is not a release asset.
(() => {
    const token = document.querySelector('meta[name="review-token"]').content;
    const record = file => file && [file.path, file.name, file.bytes, file.modified, file.available, file.digest ?? null];
    const signature = group => JSON.stringify([record(group.current),
        group.copies.slice().sort((a,b) => a.path.localeCompare(b.path)).map(record)]);
    async function request(path, body) {
        const response = await fetch('/review/' + path, body ? {method: 'POST',
            headers: {'Content-Type': 'application/json', 'X-Review-Token': token}, body: JSON.stringify(body)} : {});
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Review action failed');
        return result;
    }
    async function current(group) {
        const list = await request('list');
        const found = list.root === group.root && list.groups.find(item => item.path === group.path);
        if (!found || signature(found) !== signature(group))
            throw new Error('These files changed after the list was loaded; recheck before resolving');
        return {id: found.id, path: found.path, revision: found.revision};
    }
    window.syncshellHostActions = {
        async open(group, file) {
            return request('open', {...await current(group), file: file?.path, all: !file});
        },
        async rename(group, file) {
            const result = await request('restore-name', {...await current(group), file: file.path});
            if (result.warning) throw new Error(result.warning);
            return result;
        },
    };
})();
