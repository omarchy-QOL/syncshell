import {useContext, useEffect, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {Dialog} from './Dialog.jsx';
import {versionGroups, selectVersions, selectedVersions, versionActions} from '../client/versions.mjs';
import {timestamp, unitPrefixed} from '../client/format.mjs';

export function RestoreVersions({api, folder, onClose}) {
    const {t} = useContext(LocaleContext);
    const [versions, setVersions] = useState(null), [selections, setSelections] = useState({});
    const [errors, setErrors] = useState({}), [error, setError] = useState('');
    const [busy, setBusy] = useState(false), [confirm, setConfirm] = useState(false);
    const [search, setSearch] = useState(''), [start, setStart] = useState(''), [end, setEnd] = useState('');
    const groups = versionGroups(versions, search, start, end), chosen = selectedVersions(selections);
    const count = Object.keys(chosen).length;
    useEffect(() => {
        const controller = new AbortController();
        api.get('folder/versions', {folder: folder.id}, controller.signal).then(setVersions)
            .catch(value => { if (!controller.signal.aborted) setError(value.message); });
        return () => controller.abort();
    }, [api, folder.id]);
    async function restore() {
        setBusy(true); setError('');
        try {
            const failures = await api.post('folder/versions', chosen, {folder: folder.id});
            setErrors(failures); setConfirm(false);
            if (!Object.keys(failures).length) onClose();
            else {
                setSelections(Object.fromEntries(Object.entries(chosen).filter(([path]) => failures[path])));
                setVersions(await api.get('folder/versions', {folder: folder.id}));
            }
        } catch (value) { setError(value.message); }
        finally { setBusy(false); }
    }
    const massActions = files => versionActions.map(([action, label]) => <button key={action} class="btn btn-default btn-sm" onClick={() => setSelections(previous => selectVersions(previous, files, action))}>{t(label)}</button>);
    return <Dialog title={t('Restore Versions') + ' - ' + (folder.label || folder.id)} icon="fas fa-undo" large onClose={onClose} onCancel={() => { if (!busy) onClose(); }} footer={confirm ? <>
        <button class="btn btn-warning btn-sm" disabled={busy} onClick={restore}>{t('Yes')}</button><button class="btn btn-default btn-sm" disabled={busy} onClick={() => setConfirm(false)}>{t('No')}</button>
    </> : <>
        <button class="btn btn-primary btn-sm" disabled={busy || !count} onClick={() => setConfirm(true)}>{t('Restore')} ({count})</button><button class="btn btn-default btn-sm" disabled={busy} onClick={onClose}>{t('Close')}</button>
    </>}>
        {error && <p class="text-danger" role="alert">{error}</p>}
        {Object.keys(errors).length > 0 && <><p>{t('Some items could not be restored:')}</p><table class="table table-striped"><tbody>{Object.entries(errors).map(([path, message]) => <tr key={path}><td class="word-break-all">{path}</td><td class="word-break-all text-danger">{message}</td></tr>)}</tbody></table></>}
        {versions === null && !error ? <p role="status">{t('Loading data...')}</p> : versions && !Object.keys(versions).length ? <p>{t('There are no file versions to restore.')}</p> : versions && <fieldset disabled={busy || confirm}>
            <div class="port-version-filters">
                <label>{t('Filter by name')}<input class="form-control" type="search" value={search} onInput={event => setSearch(event.currentTarget.value)} /></label>
                <label>{t('Filter by date')} · {t('From')}<input class="form-control" type="datetime-local" step="1" value={start} onInput={event => setStart(event.currentTarget.value)} /></label>
                <label>{t('Filter by date')} · {t('To')}<input class="form-control" type="datetime-local" step="1" value={end} onInput={event => setEnd(event.currentTarget.value)} /></label>
            </div>
            <div class="folder-actions">{massActions(groups.flatMap(([, files]) => files))}</div>
            {groups.map(([parent, files]) => <details key={parent} class="port-version-group" open><summary><span aria-hidden="true" class="fas fa-folder" /> {parent || folder.label || folder.id}</summary>
                <div class="folder-actions">{massActions(files)}</div>
                {files.map((file, index) => <div key={file.path} class={`port-version-row ${index % 2 === 0 ? "section-stripe" : ""}`}><span class="folder-text" title={file.path}>{file.path.slice(file.path.lastIndexOf('/') + 1)}</span>
                    <select class="form-control input-sm" aria-label={file.path} value={selections[file.path] || ''} onChange={event => setSelections({...selections, [file.path]: event.currentTarget.value})}>
                        <option value="">{t('Do not restore')}</option>
                        {selections[file.path] && !file.versions.some(version => version.versionTime === selections[file.path]) && <option value={selections[file.path]}>{timestamp(selections[file.path])}</option>}
                        {file.versions.map(version => <option key={version.versionTime} value={version.versionTime}>{timestamp(version.versionTime)} · {unitPrefixed(version.size, true)}B</option>)}
                    </select>
                </div>)}
            </details>)}
        </fieldset>}
        {confirm && <div class="alert alert-warning" role="alert">{t('Are you sure you want to restore {%count%} files?', {count}).replace('{%count%}', count)}</div>}
    </Dialog>;
}
