import { ConflictRow } from './ConflictRow.jsx';
import { useContext, useEffect, useRef, useState } from 'preact/hooks';
import { LocaleContext } from './locale-context.jsx';
import { listConflicts, recheckConflicts, replaceDirectory } from '../client/conflicts.mjs';
import { Dialog } from './Dialog.jsx';
import '../client/conflicts.css';
import { desktopHelp } from '../client/desktop.mjs';

export function Conflicts({ api, folders, active, ready, hostActions = null, device }) {
    const { t } = useContext(LocaleContext);
    const [groups, setGroups] = useState([]),
        [search, setSearch] = useState('');
    const [selected, setSelected] = useState({}),
        [loading, setLoading] = useState(false);
    const [scanning, setScanning] = useState(null);
    const [errors, setErrors] = useState([]),
        [message, setMessage] = useState(''),
        [rename, setRename] = useState(null);
    const [access, setAccess] = useState({}),
        [desktopError, setDesktopError] = useState('');
    const controller = useRef();
    const folderKey = folders.map((folder) => folder.id).join('|');
    useEffect(() => {
        if (!active || !ready) return;
        const request = new AbortController();
        controller.current = request;
        load(false, null, request);
        return () => request.abort();
    }, [active, ready, folderKey]);
    const visible = groups.filter((group) =>
        [group.folderName, group.path, ...group.copies.map((file) => file.path)].some((value) =>
            value.toLocaleLowerCase().includes(search.toLocaleLowerCase())
        )
    );
    async function load(scan = false, group = null, request = controller.current) {
        setLoading(true);
        setScanning(scan ? group?.id || 'all' : null);
        setErrors([]);
        setMessage('');
        try {
            const result = scan
                ? await recheckConflicts(api, folders, group, request.signal)
                : await listConflicts(api, folders, request.signal);
            if (request.signal.aborted) return;
            setGroups((previous) =>
                group ? replaceDirectory(previous, group, result.groups) : result.groups
            );
            setErrors(result.errors);
            if (hostActions?.status) await refreshAccess(result.groups, request.signal);
            if (scan && !result.errors.length)
                setMessage('Syncthing scan finished; file list updated.');
        } catch (error) {
            if (!request.signal.aborted) setErrors([error.message]);
        } finally {
            if (!request.signal.aborted) {
                setLoading(false);
                setScanning(null);
            }
        }
    }
    async function checkFileAccess(group, file) {
        const key = JSON.stringify([group.id, file.path]);
        try {
            return [key, await hostActions.check(device, group, file)];
        } catch (error) {
            return [key, { reason: error.message }];
        }
    }
    async function refreshAccess(groups, signal) {
        try {
            await hostActions.status(device);
            setDesktopError('');
            const pending = groups.flatMap((group) =>
                [group.current, ...group.copies]
                    .filter(Boolean)
                    .map((file) => checkFileAccess(group, file))
            );
            const entries = await Promise.all(pending);
            if (!signal.aborted) {
                setAccess((previous) => ({ ...previous, ...Object.fromEntries(entries) }));
            }
        } catch (error) {
            setDesktopError(error.message);
            setAccess({});
        }
    }
    async function open(group, file) {
        try {
            await hostActions.open(group, file, device);
        } catch (error) {
            setErrors([error.message]);
        }
    }
    async function restore() {
        setLoading(true);
        setErrors([]);
        try {
            await hostActions.rename(rename.group, rename.file, device);
            const group = rename.group;
            setRename(null);
            await load(true, group);
        } catch (error) {
            setErrors([error.message]);
        } finally {
            setLoading(false);
        }
    }
    function permission(group, file) {
        if (!hostActions) return { reason: desktopHelp };
        if (desktopError) return { reason: desktopError };
        if (!hostActions.check) return { open: true, rename: true };
        return (
            access[JSON.stringify([group.id, file.path])] || {
                reason: 'Checking local file access...'
            }
        );
    }
    return (
        <>
            <section class="conflict-review" aria-label={t('Conflict files')}>
                <h3>{t('Review in your file manager')}</h3>
                {(!hostActions || desktopError) && (
                    <p role="status">{t(desktopError || desktopHelp)}</p>
                )}
                <div class="review-tools">
                    <input
                        type="search"
                        class="form-control input-sm review-search"
                        placeholder={t('Search filenames or paths')}
                        aria-label={t('Search filenames or paths')}
                        value={search}
                        onInput={(event) => setSearch(event.currentTarget.value)}
                    />
                    <button
                        class="btn btn-default review-recheck"
                        disabled={loading}
                        aria-busy={scanning === 'all'}
                        onClick={() => load(true)}
                    >
                        <span class={scanning === 'all' ? 'text-warning review-rechecking' : ''}>
                            <span
                                aria-hidden="true"
                                class={`fas fa-refresh${scanning === 'all' ? ' fa-spin' : ''}`}
                            />{' '}
                            {t('Recheck all files')}
                        </span>
                    </button>
                </div>
                {loading && <p role="status">{t('Loading data...')}</p>}
                {message && (
                    <p class="review-message" role="status">
                        {t(message)}
                    </p>
                )}
                {errors.map((error) => (
                    <p key={error} class="review-message text-danger" role="alert">
                        {error}
                    </p>
                ))}
                <table
                    class="table table-striped review-table review-design-03"
                    aria-label={t('Conflict files')}
                >
                    <thead>
                        <tr class="review-column-headings">
                            {['Location', 'Current file', 'Conflict files', 'Actions'].map(
                                (heading) => (
                                    <th key={heading} scope="col">
                                        {t(heading)}
                                    </th>
                                )
                            )}
                        </tr>
                    </thead>
                    <tbody>
                        {visible.map((group) => (
                            <ConflictRow
                                key={group.id}
                                group={group}
                                selected={selected[group.id]}
                                permission={permission}
                                showAccessReason={Boolean(hostActions && !desktopError)}
                                loading={loading}
                                scanning={scanning}
                                onSelect={(path) => setSelected({ ...selected, [group.id]: path })}
                                onOpen={open}
                                onRename={(file) => setRename({ group, file })}
                                onRecheck={() => load(true, group)}
                            />
                        ))}
                    </tbody>
                </table>
                {!loading && !visible.length && !errors.length && (
                    <p class="text-success">
                        {t(groups.length ? 'No matches' : 'No conflict files remain')}
                    </p>
                )}
            </section>
            {rename && (
                <Dialog
                    title={t('Restore original name')}
                    onClose={() => setRename(null)}
                    onCancel={() => {
                        if (!loading) setRename(null);
                    }}
                    footer={
                        <>
                            <button
                                class="btn btn-default"
                                disabled={loading}
                                onClick={() => setRename(null)}
                            >
                                {t('Cancel')}
                            </button>
                            <button class="btn btn-default" disabled={loading} onClick={restore}>
                                <span class="text-warning">{t('Rename')}</span>
                            </button>
                        </>
                    }
                >
                    <p>
                        {t(
                            'The selected file keeps its contents and takes the original name shown below. Its conflict filename disappears; other conflict files remain.'
                        )}
                    </p>
                    <p>
                        {t(
                            'If a file already exists at the destination, nothing is renamed or replaced.'
                        )}
                    </p>
                    <strong>{t('From')}:</strong>
                    <p class="review-confirm-path">
                        {rename.group.root}/{rename.file.path}
                    </p>
                    <strong>{t('To')}:</strong>
                    <p class="review-confirm-path">
                        {rename.group.root}/{rename.group.path}
                    </p>
                    {errors.map((error) => (
                        <p key={error} class="text-danger" role="alert">
                            {error}
                        </p>
                    ))}
                </Dialog>
            )}
        </>
    );
}
