const storageKey = 'syncshell-desktop';
export const desktopHelp = 'Local file actions are unavailable. Open this UI from Syncshell on the desktop running Syncthing, under the same user.';

// Only the plugin launch grants access; the address bar and HTTP requests retain no token.
export function desktopActions(browser = window) {
    let grant;
    try {
        const fragment = browser.location.hash.slice(1);
        if (fragment.startsWith('syncshell-desktop=')) {
            grant = fragment.slice('syncshell-desktop='.length);
            browser.history.replaceState(null, '', browser.location.pathname + browser.location.search);
            browser.sessionStorage.setItem(storageKey, grant);
        } else grant = browser.sessionStorage.getItem(storageKey);
    } catch { return null; }
    const match = /^127\.0\.0\.1:([0-9]{1,5})\/([a-f0-9]{64})$/.exec(grant || '');
    if (!match || Number(match[1]) < 1 || Number(match[1]) > 65535) return null;
    async function request(action, body) {
        let response;
        try {
            response = await browser.fetch(`http://127.0.0.1:${match[1]}/${action}`, {
                method: 'POST', credentials: 'omit', referrerPolicy: 'no-referrer',
                headers: {'Content-Type': 'application/json', 'X-Syncshell-Token': match[2]},
                body: JSON.stringify(body), signal: AbortSignal.timeout(30000),
            });
        } catch { throw new Error('Desktop connection is unavailable. Reopen the Web UI from the Syncshell plugin.'); }
        if (response.status === 403) throw new Error('Desktop authorization expired. Reopen the Web UI from the Syncshell plugin.');
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Desktop action failed');
        return result;
    }
    const body = (device, group, file = group.current || group.copies[0]) => ({device, folder: group.folder,
        root: group.root, path: group.path, file: file.path, size: file.bytes, modified: file.modified});
    return {
        status: device => request('status', {device}),
        check: (device, group, file) => request('check', body(device, group, file)),
        open: (group, file, device) => request('open', body(device, group, file)),
        rename: (group, file, device) => request('rename', body(device, group, file)),
    };
}
