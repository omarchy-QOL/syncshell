import {useContext, useEffect, useRef, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {Dialog} from './Dialog.jsx';
import {copy, getValue, setValue, editorFields, inputValue, changedValue, saveEditor, ignoreLines} from '../client/edit.mjs';
import {deviceName} from '../client/devices.mjs';

export function Editor({action, state, api, session, onClose, onSaved}) {
    const {t} = useContext(LocaleContext);
    const kind = action.type.includes('device') ? 'device' : 'folder';
    const defaults = !!action.defaults;
    const isNew = action.type.startsWith('add');
    const [draft, setDraft] = useState(() => copy(action[kind]));
    const [tab, setTab] = useState(action.tab === 'sharing' ? 'Sharing' : action.tab === 'ignores' ? 'Ignore Patterns' : 'General');
    const [error, setError] = useState('');
    const [busy, setBusy] = useState(false);
    const [addIgnores, setAddIgnores] = useState(true);
    const [stage, setStage] = useState('edit');
    const [ignores, setIgnores] = useState('');
    const originalIgnores = useRef([]);
    const [loadedIgnores, setLoadedIgnores] = useState(false);
    const saved = useRef(false);
    const form = useRef();
    const [shares, setShares] = useState(() => Object.fromEntries(state.config.folders.map(folder => {
        const member = folder.devices.find(device => device.deviceID === draft.deviceID);
        return [folder.id, {selected: !!member, password: member?.encryptionPassword || ''}];
    })));
    const tabs = (kind === 'folder' ? ['General', 'Sharing', 'File Versioning', 'Ignore Patterns', 'Advanced'] : ['General', 'Sharing', 'Advanced']).filter(name => !defaults || name !== 'Sharing');
    const fields = editorFields(kind, tab, state.config, state.system.myID).filter(field => !defaults || !['id', 'deviceID'].includes(field.path));
    const title = defaults ? 'Edit ' + (kind === 'folder' ? 'Folder' : 'Device') + ' Defaults' : (isNew ? 'Add ' : 'Edit ') + (kind === 'folder' ? 'Folder' : 'Device');
    useEffect(() => {
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
    function update(path, value) { setDraft(draft => setValue(draft, path, value)); }
    function shareDevice(id, selected) {
        setDraft(draft => ({...draft, devices: selected ? [...draft.devices, {deviceID: id, encryptionPassword: ''}]
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
                await api.post('db/ignores', {ignore: ignoreLines(ignores)}, {folder: draft.id});
                await session.setPaused('folders', draft.id, !!draft.paused);
            } else if (kind === 'folder' && isNew && addIgnores && draft.type !== 'receiveencrypted') {
                await saveEditor({session, api, state, kind, draft: {...copy(draft), paused: true}, isNew, shares});
                setStage('ignores'); setTab('Ignore Patterns');
                const data = await api.get('db/ignores', {folder: draft.id});
                originalIgnores.current = (data.ignore?.length || data.error) ? data.ignore || [] : state.config.defaults?.ignores?.lines || [];
                setIgnores(originalIgnores.current.join('\n')); setLoadedIgnores(true);
                if (data.error) setError(data.error);
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
        <button class="btn btn-primary btn-sm" disabled={busy || (stage === 'ignores' && !loadedIgnores)} onClick={save}><span class="fas fa-check" />&nbsp;{t('Save')}</button>
        <button class="btn btn-default btn-sm" disabled={busy} onClick={cancel}><span class="fas fa-times" />&nbsp;{t('Cancel')}</button>
    </>;
    return <Dialog title={title} large icon="fas fa-cog" footer={footer} onClose={cancel} onCancel={cancel}>
        <form ref={form} onSubmit={event => { event.preventDefault(); save(); }}>
            <ul class="nav nav-tabs">{tabs.map(name => <li key={name} class={tab === name ? 'active' : stage === 'ignores' && name !== 'Ignore Patterns' ? 'disabled' : ''}>
                <a href={`#editor-${name}`} onClick={event => { event.preventDefault(); if (stage !== 'ignores' || name === 'Ignore Patterns') setTab(name); }}>{t(name)}</a>
            </li>)}</ul>
            {error && <p class="text-danger" role="alert">{t(error)}</p>}
            <div class="tab-content">
                {tab === 'Sharing' ? <>
                    <p class="help-block">{t(kind === 'folder' ? 'Select additional devices to share this folder with.' : 'Select the folders to share with this device.')}</p>
                    {kind === 'folder' ? state.config.devices.filter(device => device.deviceID !== state.system.myID).map(device => {
                        const member = draft.devices.find(item => item.deviceID === device.deviceID);
                        return <div class="form-group" key={device.deviceID}><label><input type="checkbox" checked={!!member} onChange={event => shareDevice(device.deviceID, event.currentTarget.checked)} /> {deviceName(device)}</label>
                            {member && draft.type !== 'receiveencrypted' && <input class="form-control" type="password" aria-label={t('Encryption Password') + ': ' + deviceName(device)} placeholder={t('Encryption Password')} value={member.encryptionPassword || ''} required={device.untrusted}
                                onInput={event => update('devices.' + draft.devices.indexOf(member) + '.encryptionPassword', event.currentTarget.value)} />}</div>;
                    }) : state.config.folders.map(folder => <div class="form-group" key={folder.id}><label><input type="checkbox" checked={shares[folder.id].selected} onChange={event => shareFolder(folder.id, 'selected', event.currentTarget.checked)} /> {folder.label || folder.id}</label>
                        {shares[folder.id].selected && folder.type !== 'receiveencrypted' && <input class="form-control" type="password" aria-label={t('Encryption Password') + ': ' + (folder.label || folder.id)} placeholder={t('Encryption Password')} value={shares[folder.id].password} required={draft.untrusted}
                            onInput={event => shareFolder(folder.id, 'password', event.currentTarget.value)} />}</div>)}
                </> : tab === 'Ignore Patterns' ? <>
                    <p class="help-block">{t('Ignore Patterns')}</p>
                    {isNew && stage !== 'ignores' ? <><label><input type="checkbox" checked={addIgnores} onChange={event => setAddIgnores(event.currentTarget.checked)} /> {t('Add Ignore Patterns')}</label>
                        <p>{t('Patterns are applied before the folder starts synchronizing.')}</p></> :
                        <textarea class="form-control" rows="12" aria-label={t('Ignore Patterns')} value={ignores} disabled={draft.type === 'receiveencrypted' || !loadedIgnores} onInput={event => setIgnores(event.currentTarget.value)} />}
                </> : <>
                    {fields.map(field => <div class="form-group" key={field.path}>
                        {field.type === 'checkbox' ? <label><input type="checkbox" checked={!!getValue(draft, field.path)} onChange={event => update(field.path, changedValue(field, event.currentTarget))} /> {t(field.label)}</label> : <>
                            <label for={'editor-' + field.path}>{t(field.label)}</label>
                            {field.type === 'select' ? <select id={'editor-' + field.path} class="form-control" value={inputValue(draft, field)} onChange={event => update(field.path, event.currentTarget.value)}>
                                {field.options.map(([value, label]) => <option key={value} value={value}>{t(label)}</option>)}</select> :
                                <input id={'editor-' + field.path} class="form-control" type={field.type === 'list' ? 'text' : field.type} value={inputValue(draft, field)} readOnly={!isNew && !defaults && ['id', 'path', 'deviceID'].includes(field.path)}
                                    required={!defaults && ['id', 'path', 'deviceID'].includes(field.path)} step={field.path.endsWith('.value') ? '0.01' : undefined} min={field.type === 'number' ? 0 : undefined} onInput={event => update(field.path, changedValue(field, event.currentTarget))} />}
                        </>}
                    </div>)}
                    {tab === 'File Versioning' && draft.versioning.type && (draft.versioning.type === 'simple' ? [['keep', 'Keep Versions'], ['cleanoutDays', 'Clean out after']] : draft.versioning.type === 'trashcan' ? [['cleanoutDays', 'Clean out after']] : draft.versioning.type === 'staggered' ? [['maxAge', 'Maximum Age (s)']] : [['command', 'External Versioning Command']]).map(([key, label]) =>
                        <div class="form-group" key={key}><label for={'version-' + key}>{t(label)}</label><input id={'version-' + key} class="form-control" value={draft.versioning.params?.[key] || ''} onInput={event => update('versioning.params.' + key, event.currentTarget.value)} /></div>)}
                </>}
            </div>
        </form>
    </Dialog>;
}
