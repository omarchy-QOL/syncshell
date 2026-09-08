import {useContext, useEffect, useRef, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {Dialog} from './Dialog.jsx';
import {ConfirmAction} from './ConfirmAction.jsx';
import {copy, getValue, setValue, editorFields, inputValue, changedValue, saveEditor, ignoreLines} from '../client/edit.mjs';
import {folderPath, updateEditor, editorFieldState, newXattrEntry, xattrDefault, xattrHint, overlappingPath} from '../client/editor-behavior.mjs';
import {fieldHelp} from '../client/field-help.mjs';
import {Tooltip} from './Tooltip.jsx';
import {IdentityControls} from './IdentityControls.jsx';
import {SharingEntry} from './SharingEntry.jsx';
import {deviceName} from '../client/devices.mjs';

export function Editor({action, state, api, session, onClose, onSaved}) {
    const {t} = useContext(LocaleContext);
    const kind = action.type.includes('device') ? 'device' : 'folder';
    const defaults = !!action.defaults;
    const isNew = action.type.startsWith('add');
    const [draft, setDraft] = useState(() => copy(action[kind]));
    const [tab, setTab] = useState(action.tab === 'sharing' ? 'Sharing' : action.tab === 'ignores' ? 'Ignore Patterns' : 'General');
    const [removing, setRemoving] = useState(false);
    const [error, setError] = useState('');
    const [busy, setBusy] = useState(false);
    const [addIgnores, setAddIgnores] = useState(false);
    const autoPath = useRef(true);
    const [directories, setDirectories] = useState([]);
    const [stage, setStage] = useState('edit');
    const [ignores, setIgnores] = useState('');
    const originalIgnores = useRef([]);
    const [loadedIgnores, setLoadedIgnores] = useState(false);
    const saved = useRef(false);
    const form = useRef();
    const [passwords, setPasswords] = useState(() => Object.fromEntries((draft.devices || []).map(member => [member.deviceID, member.encryptionPassword || ''])));
    const [shares, setShares] = useState(() => Object.fromEntries(state.config.folders.map(folder => {
        const member = folder.devices.find(device => device.deviceID === draft.deviceID);
        return [folder.id, {selected: !!member, password: member?.encryptionPassword || ''}];
    })));
    const tabs = (kind === 'folder' ? ['General', 'Sharing', 'File Versioning', 'Ignore Patterns', 'Advanced'] : ['General', 'Sharing', 'Advanced']).filter(name => !defaults || name !== 'Sharing');
    const fields = editorFields(kind, tab, state.config, state.system.myID).map(field => editorFieldState(field, draft, {kind, isNew, defaults, myID: state.system.myID})).filter(field => !field.hidden && (!defaults || !['id', 'deviceID'].includes(field.path)));
    const title = defaults ? 'Edit ' + (kind === 'folder' ? 'Folder' : 'Device') + ' Defaults' : (isNew ? 'Add ' : 'Edit ') + (kind === 'folder' ? 'Folder' : 'Device');
    const overlap = kind === 'folder' ? overlappingPath(draft, state.config, state.system) : null;
    useEffect(() => {
        if (kind !== 'folder' || (!isNew && !defaults) || !draft.path) return;
        const controller = new AbortController();
        api.get('system/browse', {current: draft.path}, controller.signal).then(setDirectories)
            .catch(value => { if (!controller.signal.aborted) setError(value.message); });
        return () => controller.abort();
    }, [api, kind, isNew, defaults, draft.path]);
    useEffect(() => {
        if (kind === 'folder' && isNew && state.config.defaults.folder.path) setDraft(previous => ({...previous, path: folderPath(state.config.defaults.folder.path, previous.label || previous.id, state.system.pathSeparator)}));
        if (defaults && kind === 'folder') {
            originalIgnores.current = state.config.defaults.ignores.lines; setIgnores(originalIgnores.current.join('\n')); setLoadedIgnores(true); return;
        }
        if (kind === 'folder' && !isNew && draft.type !== 'receiveencrypted') {
            api.get('db/ignores', {folder: draft.id}).then(data => {
                originalIgnores.current = data.ignore || [];
                setIgnores(originalIgnores.current.join('\n'));
                setLoadedIgnores(true);
                if (data.error) setError(data.error);
            }).catch(failure => setError(failure.message));
        }
    }, []);
    function tabDisabled(name) {
        return (stage === 'ignores' && name !== 'Ignore Patterns') || (kind === 'folder' && draft.type === 'receiveencrypted' && name === 'Ignore Patterns');
    }
    function update(path, value) {
        if (path === 'path') autoPath.current = false;
        setDraft(previous => updateEditor(previous, path, value, {kind, isNew, defaults, autoPath: autoPath.current, config: state.config, system: state.system}));
    }
    async function loadAddedIgnores() {
        setLoadedIgnores(false); setBusy(true); setError('');
        try {
            const data = await api.get('db/ignores', {folder: draft.id});
            originalIgnores.current = (data.ignore?.length || data.error) ? data.ignore || [] : state.config.defaults?.ignores?.lines || [];
            setIgnores(originalIgnores.current.join('\n')); setLoadedIgnores(true);
            if (data.error) setError(data.error);
        } catch (failure) { setError(failure.message); }
        finally { setBusy(false); }
    }
    function sharePassword(id, value) {
        setPasswords(previous => ({...previous, [id]: value}));
        setDraft(previous => ({...previous, devices: previous.devices.map(member => member.deviceID === id ? {...member,encryptionPassword:value} : member)}));
    }
    function shareDevice(id, selected) {
        setDraft(draft => ({...draft, devices: selected ? [...draft.devices, {deviceID: id, encryptionPassword: passwords[id] || ''}]
            : draft.devices.filter(device => device.deviceID !== id)}));
    }
    function shareFolder(id, property, value) { setShares(shares => ({...shares, [id]: {...shares[id], [property]: value}})); }
    async function save() {
        if (!form.current.reportValidity()) return;
        setBusy(true); setError('');
        try {
            if (defaults) {
                await saveEditor({session, api, state, kind, draft, isNew, shares, defaults, ignores: ignoreLines(ignores)});
            } else if (stage === 'ignores') {
                if (!loadedIgnores) return;
                await api.post('db/ignores', {ignore: ignoreLines(ignores)}, {folder: draft.id});
                await session.setPaused('folders', draft.id, !!draft.paused);
            } else if (kind === 'folder' && isNew && addIgnores && draft.type !== 'receiveencrypted') {
                await saveEditor({session, api, state, kind, draft: {...copy(draft), paused: true}, isNew, shares});
                setStage('ignores'); setTab('Ignore Patterns');
                await loadAddedIgnores();
                return;
            } else {
                if (kind === 'folder' && loadedIgnores && ignores !== originalIgnores.current.join('\n'))
                    await api.post('db/ignores', {ignore: ignoreLines(ignores)}, {folder: draft.id});
                await saveEditor({session, api, state, kind, draft, isNew, shares});
            }
            saved.current = true; onSaved?.(copy(draft), ignoreLines(ignores)); onClose();
        } catch (failure) { setError(failure.message); }
        finally { setBusy(false); }
    }
    async function cancel() {
        if (busy) return;
        if (!saved.current && stage === 'ignores' && loadedIgnores) {
            saved.current = true;
            try {
                await api.post('db/ignores', {ignore: originalIgnores.current}, {folder: draft.id});
                await session.setPaused('folders', draft.id, !!draft.paused);
            } catch (failure) { session.reportError(failure); }
        }
        onClose();
    }
    const footer = <>
        {!defaults && !isNew && stage === 'edit' && draft.deviceID !== state.system.myID && <button class="btn btn-warning btn-sm pull-left" disabled={busy} onClick={() => setRemoving(true)}>{t('Remove')}</button>}
        <button class="btn btn-primary btn-sm" disabled={busy || (stage === 'ignores' && !loadedIgnores)} onClick={save}><span class="fas fa-check" />&nbsp;{t('Save')}</button>
        <button class="btn btn-default btn-sm" disabled={busy} onClick={cancel}><span class="fas fa-times" />&nbsp;{t('Cancel')}</button>
    </>;
    return <><Dialog title={title} large icon="fas fa-cog" footer={footer} onClose={cancel} onCancel={cancel}>
        <form ref={form} onSubmit={event => { event.preventDefault(); save(); }}>
            <ul class="nav nav-tabs">{tabs.map(name => <li key={name} class={tab === name ? 'active' : tabDisabled(name) ? 'disabled' : ''}>
                <a href={`#editor-${name}`} aria-disabled={tabDisabled(name)} onClick={event => { event.preventDefault(); if (!tabDisabled(name)) setTab(name); }}>{t(name)}</a>
            </li>)}</ul>
            {error && <p class="text-danger" role="alert">{t(error)}</p>}
            <datalist id="directory-list">{directories.map(directory => <option key={directory} value={directory} />)}</datalist>
            <datalist id="editor-groups">{[...new Set(state.config[kind === 'folder' ? 'folders' : 'devices'].map(item => item.group).filter(Boolean))].map(group => <option key={group} value={group} />)}</datalist>
            <div class="tab-content">
                {tab === 'Sharing' ? <>
                    <div class="folder-actions">{[true,false].map(select => <button key={String(select)} type="button" class="btn btn-link btn-sm" onClick={() => { if (kind === 'folder') setDraft(previous => ({...previous, devices: select ? state.config.devices.map(device => previous.devices.find(member => member.deviceID === device.deviceID) || {deviceID:device.deviceID,encryptionPassword:passwords[device.deviceID] || ''}) : previous.devices.filter(member => member.deviceID === state.system.myID)})); else setShares(previous => Object.fromEntries(Object.entries(previous).map(([id, share]) => [id, {...share, selected:select}]))); }}>{t(select ? 'Select All' : 'Deselect All')}</button>)}</div>
                    <p class="help-block">{t(kind === 'folder' ? 'Select additional devices to share this folder with.' : 'Select the folders to share with this device.')}</p>
                    {kind === 'folder' ? state.config.devices.filter(device => device.deviceID !== state.system.myID).map(device => {
                        const member = draft.devices.find(item => item.deviceID === device.deviceID);
                        return <SharingEntry key={device.deviceID} label={deviceName(device)} id={device.deviceID} selected={!!member} password={passwords[device.deviceID] || ''} encrypted={draft.type === 'receiveencrypted'} required={device.untrusted || state.pendingFolders[draft.id]?.offeredBy?.[device.deviceID]?.remoteEncrypted} remoteState={state.completion[device.deviceID]?.[draft.id]?.remoteState} onSelected={value=>shareDevice(device.deviceID,value)} onPassword={value=>sharePassword(device.deviceID,value)} />;
                    }) : state.config.folders.map(folder => <SharingEntry key={folder.id} label={folder.label || folder.id} id={folder.id} selected={shares[folder.id].selected} password={shares[folder.id].password} encrypted={folder.type === 'receiveencrypted'} required={draft.untrusted || state.pendingFolders[folder.id]?.offeredBy?.[draft.deviceID]?.remoteEncrypted} remoteState={state.completion[draft.deviceID]?.[folder.id]?.remoteState} onSelected={value=>shareFolder(folder.id,'selected',value)} onPassword={value=>shareFolder(folder.id,'password',value)} />)}
                </> : tab === 'Ignore Patterns' ? <>
                    <p class="help-block">{t('Enter ignore patterns, one per line.')} <a href="https://docs.syncthing.net/users/ignoring.html" target="_blank" rel="noreferrer">{t('full documentation')}</a></p>
                    {stage === 'ignores' && <><p>{t('Set Ignores on Added Folder')} · {draft.label || draft.id}</p>{!loadedIgnores && <button type="button" class="btn btn-default" disabled={busy} onClick={loadAddedIgnores}>{t('Retry')}</button>}</>}
                    {isNew && stage !== 'ignores' ? <><label><input type="checkbox" checked={addIgnores} onChange={event => setAddIgnores(event.currentTarget.checked)} /> {t('Add Ignore Patterns')}</label>
                        <p>{t('Patterns are applied before the folder starts synchronizing.')}</p></> :
                        <textarea class="form-control" rows="12" aria-label={t('Ignore Patterns')} value={ignores} disabled={draft.type === 'receiveencrypted' || !loadedIgnores} onInput={event => setIgnores(event.currentTarget.value)} />}
                </> : <>
                    {kind === 'device' && tab === 'General' && !defaults && <IdentityControls device={draft} api={api} />}
                    {fields.map(field => <div class="form-group" key={field.path}>
                        {field.type === 'checkbox' ? <label><input type="checkbox" checked={field.checked ?? !!getValue(draft, field.path)} disabled={field.disabled} onChange={event => update(field.path, changedValue(field, event.currentTarget))} /> {t(field.label)}</label> : <>
                            <label for={'editor-' + field.path}>{t(field.label)}</label>
                            {fieldHelp[field.label] && <Tooltip icon="fas fa-info-circle" label={field.label} text={fieldHelp[field.label].help} />}
                            {field.type === 'select' ? <select id={'editor-' + field.path} class="form-control" value={inputValue(draft, field)} disabled={field.disabled} onChange={event => update(field.path, event.currentTarget.value)}>
                                {field.options.map(([value, label]) => <option key={value} value={value}>{t(label)}</option>)}</select> :
                                <input id={'editor-' + field.path} class="form-control" type={field.type === 'list' ? 'text' : field.type} value={inputValue(draft, field)} disabled={field.disabled} list={field.path === 'path' ? 'directory-list' : field.path === 'group' ? 'editor-groups' : undefined} readOnly={!isNew && !defaults && ['id', 'path', 'deviceID'].includes(field.path)}
                                    required={!defaults && ['id', 'path', 'deviceID'].includes(field.path)} step={field.path.endsWith('.value') ? '0.01' : undefined} min={field.type === 'number' ? 0 : undefined} onInput={event => update(field.path, changedValue(field, event.currentTarget))} />}
                        </>}
                        {field.type === 'checkbox' && fieldHelp[field.label] && <Tooltip icon="fas fa-info-circle" label={field.label} text={fieldHelp[field.label].help} />}
                        {field.path === 'path' && overlap && <p class="text-warning">{t(overlap.type === 'subdirectory' ? 'Warning, this path is a subdirectory of an existing folder "{%otherFolder%}".' : 'Warning, this path is a parent directory of an existing folder "{%otherFolder%}".').replace('{%otherFolder%}', overlap.folder.label || overlap.folder.id)}</p>}
                    </div>)}
                    {tab === 'File Versioning' && draft.versioning.type && (draft.versioning.type === 'simple' ? [['keep', 'Keep Versions'], ['cleanoutDays', 'Clean out after']] : draft.versioning.type === 'trashcan' ? [['cleanoutDays', 'Clean out after']] : draft.versioning.type === 'staggered' ? [['maxAge', 'Maximum Age']] : [['command', 'External Versioning Command']]).map(([key, label]) =>
                        <div class="form-group" key={key}><label for={'version-' + key}>{t(label)}{key === 'maxAge' ? ' (' + t('days') + ')' : ''}</label><input id={'version-' + key} class="form-control" type={key === 'command' ? 'text' : 'number'} min={key === 'keep' ? 1 : 0} required value={key === 'maxAge' ? Math.floor(Number(draft.versioning.params?.[key] || 0) / 86400) : draft.versioning.params?.[key] || ''} onInput={event => update('versioning.params.' + key, key === 'maxAge' ? String(Number(event.currentTarget.value) * 86400) : event.currentTarget.value)} /></div>)}
                    {kind === 'folder' && tab === 'Advanced' && (draft.syncXattrs || draft.sendXattrs) && <>
                        <p>{t('Extended Attributes Filter')} · <a href="https://docs.syncthing.net/advanced/folder-xattr-filter.html" target="_blank" rel="noreferrer">{t('Help')}</a></p>
                        <p>{t('To permit a rule, have the checkbox checked. To deny a rule, leave it unchecked.')}</p>
                        {(draft.xattrFilter?.entries || []).map((entry,index) => <div class="port-xattr-rule" key={index}><input type="checkbox" aria-label={t('permit') + ' ' + (index + 1)} checked={entry.permit} onChange={event => update('xattrFilter.entries.' + index + '.permit', event.currentTarget.checked)} /><input class="form-control" aria-label={t('Active filter rules') + ' ' + (index + 1)} value={entry.match} onInput={event => update('xattrFilter.entries.' + index + '.match', event.currentTarget.value)} /><button type="button" class="btn btn-default" onClick={() => update('xattrFilter.entries', draft.xattrFilter.entries.filter((_,i) => i !== index))}>{t('Remove')}</button></div>)}
                        <button type="button" class="btn btn-default" onClick={() => update('xattrFilter.entries', newXattrEntry(draft.xattrFilter?.entries))}>{t('Add filter entry')}</button>
                        <p>{t('Default')}: {t(xattrDefault(draft.xattrFilter?.entries))}</p><p>{t(xattrHint(draft.xattrFilter?.entries))}</p>
                    </>}
                </>}
            </div>
        </form>
    </Dialog>{removing && <ConfirmAction action={{type: 'remove-' + kind, [kind]: draft}} api={api} session={session} devices={state.config.devices} onClose={() => setRemoving(false)} onDone={onClose} />}</>;
}
