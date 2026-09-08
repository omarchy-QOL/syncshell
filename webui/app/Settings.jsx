import {useContext, useEffect, useRef, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {Dialog} from './Dialog.jsx';
import {Editor} from './Editor.jsx';
import {FormFields} from './FormFields.jsx';
import {copy, setValue} from '../client/edit.mjs';
import {settingsTabs, settingsFields, settingsConfig, upgradeMode, ignoredFolders, unignore, loadSettings, advancedSections} from '../client/settings.mjs';
import {timestamp} from '../client/format.mjs';
export function Settings({state, api, session, onClose, advanced = false}) {
    const {t} = useContext(LocaleContext), form = useRef();
    const [initial] = useState(() => copy(state.config));
    const [draft, setDraft] = useState(() => copy(initial)), [mode, setMode] = useState(upgradeMode(initial));
    const [tab, setTab] = useState('General'), [options, setOptions] = useState({themes: [], upgrade: null});
    const [busy, setBusy] = useState(false), [error, setError] = useState('');
    const [nested, setNested] = useState(null), [report, setReport] = useState(null), [discard, setDiscard] = useState(false);
    const fields = settingsFields(tab, draft, state.system.myID, options.themes);
    const ignored = ignoredFolders(draft);
    useEffect(() => {
        const controller = new AbortController();
        loadSettings(api, controller.signal).then(value => { if (!controller.signal.aborted) setOptions(value); });
        return () => controller.abort();
    }, [api]);
    function update(path, value) { setDraft(previous => setValue(previous, path, value)); }
    async function save() {
        if (!form.current.reportValidity()) return;
        setBusy(true); setError('');
        try {
            const config = advanced ? copy(draft) : settingsConfig(draft, mode, state.system, state.version, !!options.upgrade);
            await session.saveConfig(config); onClose();
            if (initial.gui.theme !== config.gui.theme) location.reload();
        } catch (value) { setError(value.message); }
        finally { setBusy(false); }
    }
    function close() {
        if (busy) return;
        if (JSON.stringify(draft) !== JSON.stringify(initial) || mode !== upgradeMode(initial)) setDiscard(true);
        else onClose();
    }
    async function defaults(kind) {
        try { setNested({type: 'edit-' + kind, defaults: true, [kind]: await api.get('config/defaults/' + kind)}); }
        catch (value) { setError(value.message); }
    }
    async function generateKey() {
        try { update('gui.apiKey', (await api.get('svc/random/string', {length: 32})).random); }
        catch (value) { setError(value.message); }
    }
    async function preview() {
        try { setReport(await api.get('svc/report', {version: draft.options.urAccepted > 0 ? draft.options.urAccepted : state.system.urVersionMax})); }
        catch (value) { setError(value.message); }
    }
    return <>
        <Dialog title={advanced ? 'Advanced Configuration' : 'Settings'} status={advanced ? 'danger' : 'default'} icon="fas fa-cog" large onClose={onClose} onCancel={close} footer={<>
            <button class="btn btn-primary btn-sm" disabled={busy} onClick={save}>{t('Save')}</button><button class="btn btn-default btn-sm" disabled={busy} onClick={close}>{t('Close')}</button>
        </>}>
            <form ref={form} onSubmit={event => { event.preventDefault(); save(); }}>
                {error && <p class="text-danger" role="alert">{t(error)}</p>}
                <fieldset disabled={busy}>
                {advanced ? <>
                    <p class="text-danger"><strong>{t('Be careful!')}</strong> {t('Incorrect configuration may damage your folder contents and render Syncthing inoperable.')}</p>
                    {advancedSections(draft).map(section => <details key={section.path} class="panel panel-default"><summary class="panel-heading">{t(section.label)}</summary><div class="panel-body"><FormFields draft={draft} fields={section.fields} onChange={update} /></div></details>)}
                </> : <>
                    <ul class="nav nav-tabs">{settingsTabs.map(name => <li key={name} class={tab === name ? 'active' : ''}><a href={'#settings-' + name} onClick={event => { event.preventDefault(); setTab(name); }}>{t(name)}</a></li>)}</ul>
                    {tab === 'Ignored Devices' ? <>
                        {!draft.remoteIgnoredDevices?.length && <p>{t('You have no ignored devices.')}</p>}
                        <div class="table-responsive"><table class="table table-striped"><tbody>{(draft.remoteIgnoredDevices || []).map(device => <tr key={device.deviceID}><td>{timestamp(device.time)}</td><td class="word-break-all" title={device.deviceID}>{device.name || device.deviceID}</td><td class="word-break-all">{device.address}</td><td><button type="button" class="btn btn-default btn-sm" onClick={() => setDraft(unignore(draft, device.deviceID))}>{t('Unignore')}</button></td></tr>)}</tbody></table></div>
                    </> : tab === 'Ignored Folders' ? <>
                        {!ignored.length && <p>{t('You have no ignored folders.')}</p>}
                        <div class="table-responsive"><table class="table table-striped"><tbody>{ignored.map(({device, folder}) => <tr key={device.deviceID + folder.id}><td>{timestamp(folder.time)}</td><td>{folder.label || folder.id}</td><td class="word-break-all" title={device.deviceID}>{device.name || device.deviceID}</td><td><button type="button" class="btn btn-default btn-sm" onClick={() => setDraft(unignore(draft, device.deviceID, folder.id))}>{t('Unignore')}</button></td></tr>)}</tbody></table></div>
                    </> : <>
                        <FormFields draft={draft} fields={fields} onChange={update} />
                        {tab === 'GUI' && state.system.guiAddressOverridden && <p class="text-warning">{t('The GUI address is overridden by startup options. Changes here will not take effect while the override is in place.')}</p>}
                        {tab === 'General' && <>
                            <label for="settings-api-key">{t('API Key')}</label><div class="input-group"><input id="settings-api-key" class="form-control" type="password" readOnly value={draft.gui.apiKey} /><span class="input-group-btn"><button type="button" class="btn btn-default" onClick={generateKey}>{t('Generate')}</button></span></div>
                            <div class="form-group"><label for="settings-usage">{t('Anonymous Usage Reporting')}</label> <button type="button" class="btn btn-link btn-sm" onClick={preview}>{t('Preview')}</button>
                                {mode === 'candidate' || state.version.isCandidate ? <p>{t('Usage reporting is always enabled for candidate releases.')}</p> : <select id="settings-usage" class="form-control" value={draft.options.urAccepted} onChange={event => update('options.urAccepted', Number(event.currentTarget.value))}>
                                    {Array.from({length: Math.max(0, (state.system.urVersionMax || 1) - 1)}, (_, i) => state.system.urVersionMax - i).map(version => <option key={version} value={version}>{t('Version')} {version}</option>)}
                                    <option value={0}>{t('Undecided (will prompt)')}</option><option value={-1}>{t('Disabled')}</option>
                                </select>}
                            </div>
                            <div class="form-group"><label for="settings-upgrades">{t('Automatic upgrades')}</label>
                                {options.upgrade ? <select id="settings-upgrades" class="form-control" value={mode} onChange={event => setMode(event.currentTarget.value)}>{!state.version.isCandidate && <option value="none">{t('No upgrades')}</option>}<option value="stable">{t('Stable releases only')}</option><option value="candidate">{t('Stable releases and release candidates')}</option></select>
                                    : <p>{t('Unavailable/Disabled by administrator or maintainer')}</p>}
                            </div>
                            <p><strong>{t('Default Configuration')}</strong></p><div class="folder-actions"><button type="button" class="btn btn-default" onClick={() => defaults('folder')}>{t('Edit Folder Defaults')}</button><button type="button" class="btn btn-default" onClick={() => defaults('device')}>{t('Edit Device Defaults')}</button></div>
                        </>}
                    </>}
                </>}
                </fieldset>
            </form>
        </Dialog>
        {nested && <Editor action={nested} state={state} api={api} session={session} onSaved={(value, lines) => {
            setDraft(previous => { const next = setValue(previous, 'defaults.' + (nested.folder ? 'folder' : 'device'), value); if (nested.folder) next.defaults.ignores.lines = lines; return next; });
        }} onClose={() => setNested(null)} />}
        {report && <Dialog title="Anonymous Usage Reporting" large onClose={() => setReport(null)}><pre>{JSON.stringify(report, null, 2)}</pre></Dialog>}
        {discard && <Dialog title="Discard Changes" onClose={() => setDiscard(false)} footer={<><button class="btn btn-warning" onClick={onClose}>{t('Discard Changes')}</button><button class="btn btn-default" onClick={() => setDiscard(false)}>{t('Cancel')}</button></>}><p>{t('Discard unsaved changes?')}</p></Dialog>}
    </>;
}
