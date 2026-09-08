import {useContext, useEffect, useRef, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {listConflicts, recheckConflicts, replaceDirectory, parentPath, missingHelp, hostActionHelp} from '../client/conflicts.mjs';
import {conflictTranslator} from '../client/conflict-words.mjs';
import {unitPrefixed, timestamp} from '../client/format.mjs';
import {Tooltip} from './Tooltip.jsx';
import {Dialog} from './Dialog.jsx';
import '../client/conflicts.css';

export function Conflicts({api, folders, active, ready, hostActions = null}) {
    const locale = useContext(LocaleContext), t = conflictTranslator(locale);
    const [groups, setGroups] = useState([]), [search, setSearch] = useState('');
    const [selected, setSelected] = useState({}), [loading, setLoading] = useState(false);
    const [scanning, setScanning] = useState(null);
    const [errors, setErrors] = useState([]), [message, setMessage] = useState(''), [rename, setRename] = useState(null);
    const controller = useRef();
    const folderKey = folders.map(folder => folder.id).join('|');
    useEffect(() => {
        if (!active || !ready) return;
        const request = new AbortController(); controller.current = request;
        load(false, null, request);
        return () => request.abort();
    }, [active, ready, folderKey]);
    const visible = groups.filter(group => [group.folderName, group.path, ...group.copies.map(file => file.path)]
        .some(value => value.toLocaleLowerCase().includes(search.toLocaleLowerCase())));
    async function load(scan = false, group = null, request = controller.current) {
        setLoading(true); setScanning(scan ? group?.id || 'all' : null); setErrors([]); setMessage('');
        try {
            const result = scan ? await recheckConflicts(api, folders, group, request.signal)
                : await listConflicts(api, folders, request.signal);
            if (request.signal.aborted) return;
            setGroups(previous => group ? replaceDirectory(previous, group, result.groups) : result.groups);
            setErrors(result.errors);
            if (scan && !result.errors.length) setMessage('Syncthing scan finished; file list updated.');
        } catch (error) { if (!request.signal.aborted) setErrors([error.message]); }
        finally { if (!request.signal.aborted) { setLoading(false); setScanning(null); } }
    }
    async function open(group, file) {
        try { await hostActions.open(group, file); } catch (error) { setErrors([error.message]); }
    }
    async function restore() {
        setLoading(true); setErrors([]);
        try {
            await hostActions.rename(rename.group, rename.file);
            const group = rename.group; setRename(null);
            await load(true, group);
        } catch (error) { setErrors([error.message]); }
        finally { setLoading(false); }
    }
    function fileLink(group, file) {
        if (!file) return <span class="text-warning"><Tooltip icon="fas fa-exclamation-triangle" label="Missing current file" text={t(missingHelp)} /> {t('Missing current file')}</span>;
        if (!file.available) return <span class="text-warning" title={t('Waiting for Syncthing to download this file')}>{file.name} · {t('Not available locally')}</span>;
        const contents = <><span aria-hidden="true" class="fas fa-fw fa-file" /><span class="review-filename">{file.name}</span></>;
        return hostActions ? <a class="review-file" href="#open-file" title={group.root + '/' + file.path} onClick={event => { event.preventDefault(); open(group, file); }}>{contents}</a>
            : <span class="review-file" title={group.root + '/' + file.path}>{contents}</span>;
    }
    const metadata = file => <>{unitPrefixed(file.bytes, true)}B · {timestamp(file.modified)}</>;
    return <>
        <section class="conflict-review" aria-label={t('Conflict files')}>
            <h3>{t('Review in your file manager')}</h3>
            <div class="review-tools">
                <input type="search" class="form-control input-sm review-search" placeholder={t('Search filenames or paths')} aria-label={t('Search filenames or paths')} value={search} onInput={event => setSearch(event.currentTarget.value)} />
                <button class="btn btn-default review-recheck" disabled={loading} aria-busy={scanning === 'all'} onClick={() => load(true)}><span class={scanning === 'all' ? 'text-warning review-rechecking' : ''}><span aria-hidden="true" class={`fas fa-refresh${scanning === 'all' ? ' fa-spin' : ''}`} /> {t('Recheck all files')}</span></button>
            </div>
            {loading && <p role="status">{t('Loading data...')}</p>}
            {message && <p class="review-message" role="status">{t(message)}</p>}
            {errors.map(error => <p key={error} class="review-message text-danger" role="alert">{error}</p>)}
            <table class="table table-striped review-table review-design-03" aria-label={t('Conflict files')}>
                <thead><tr class="review-column-headings">{['Location', 'Current file', 'Conflict files', 'Actions'].map(heading => <th key={heading} scope="col">{t(heading)}</th>)}</tr></thead>
                <tbody>{visible.map(group => {
                    const file = group.copies.find(copy => copy.path === selected[group.id]) || group.copies[0];
                    return <tr key={group.id} class="review-row">
                        <td class="review-context"><span class="review-path" title={group.root + '/' + parentPath(group.path)}>{group.folderName}{parentPath(group.path) ? ' / ' + parentPath(group.path) : ''}</span></td>
                        <td class="review-current"><span class="review-cell-label">{t('Current file')}</span>{fileLink(group, group.current)}
                            {group.current ? <small class="review-file-meta">{metadata(group.current)}</small>
                                : <small class="review-file-meta review-missing-hint">{t('To keep a conflict file, rename it to:')} <span class="review-filename" title={group.root + '/' + group.path}>{group.name}</span></small>}
                        </td>
                        <td class="review-copies">
                            {group.copies.length > 1 ? <select class="form-control input-sm review-version" aria-label={t('Conflict files') + ': ' + group.name} value={file.path} title={file.name} onChange={event => setSelected({...selected, [group.id]: event.currentTarget.value})}>
                                {group.copies.map((copy, index) => <option key={copy.path} value={copy.path}>{index + 1}/{group.copies.length} · {copy.name}</option>)}
                            </select> : <span class="review-mobile-label">{t('Conflict files')}</span>}
                            {fileLink(group, file)}
                            <small class="review-file-meta review-conflict-meta">{metadata(file)}
                                {!group.current && file.available && <button class="btn btn-default review-autoresolve" disabled={!hostActions || loading} title={!hostActions ? t(hostActionHelp) : undefined} onClick={() => setRename({group, file})}><span class="text-warning">{t('Autoresolve')}</span></button>}
                            </small>
                        </td>
                        <td class="review-actions">
                            <button class="btn btn-default" disabled={!hostActions || loading} title={!hostActions ? t(hostActionHelp) : undefined} onClick={() => open(group)}><span aria-hidden="true" class="fas fa-folder-open" /> {t('Open folder')}</button>
                            <button class="btn btn-default" disabled={loading} aria-busy={scanning === group.id} onClick={() => load(true, group)}><span class={scanning === group.id ? 'text-warning review-rechecking' : ''}><span aria-hidden="true" class={`fas fa-refresh${scanning === group.id ? ' fa-spin' : ''}`} /> {t('Recheck files in folder')}</span></button>
                        </td>
                    </tr>;
                })}</tbody>
            </table>
            {!loading && !visible.length && !errors.length && <p class="text-success">{t(groups.length ? 'No matches' : 'No conflict files remain')}</p>}
        </section>
        {rename && <Dialog title={t('Restore original name')} onClose={() => setRename(null)} onCancel={() => { if (!loading) setRename(null); }} footer={<>
            <button class="btn btn-default" disabled={loading} onClick={() => setRename(null)}>{t('Cancel')}</button><button class="btn btn-default" disabled={loading} onClick={restore}><span class="text-warning">{t('Rename')}</span></button>
        </>}>
            <p>{t('Rename the selected conflict file to the original name. Other conflict files remain. An existing file will never be overwritten.')}</p>
            <strong>{t('From')}:</strong><p class="review-confirm-path">{rename.group.root}/{rename.file.path}</p>
            <strong>{t('To')}:</strong><p class="review-confirm-path">{rename.group.root}/{rename.group.path}</p>
            {errors.map(error => <p key={error} class="text-danger" role="alert">{error}</p>)}
        </Dialog>}
    </>;
}
