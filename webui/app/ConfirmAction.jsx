import {useContext, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {Dialog} from './Dialog.jsx';
import {managementActions, performManagement} from '../client/management.mjs';
export function ConfirmAction({action, api, session, onClose, onDone, devices = []}) {
    const {t} = useContext(LocaleContext), definition = managementActions[action.type];
    const name = action.folder?.label || action.folder?.id || action.device?.name || action.device?.deviceID;
    const introducer = devices.find(device => device.deviceID === action.device?.introducedBy && device.introducer);
    const [busy, setBusy] = useState(false), [error, setError] = useState('');
    async function apply() {
        setBusy(true); setError('');
        try { await performManagement(action, session, api); onDone(); }
        catch (value) { setError(value.message); }
        finally { setBusy(false); }
    }
    return <Dialog title={definition.title} status="warning" icon="fas fa-question-circle" onClose={onClose} onCancel={() => { if (!busy) onClose(); }} footer={<>
        <button class="btn btn-warning" disabled={busy} onClick={apply}>{t(definition.button)}</button><button class="btn btn-default" disabled={busy} onClick={onClose}>{t('Cancel')}</button>
    </>}>
        <p>{t(definition.description).replace('{%label%}', name).replace('{%name%}', name)}</p>
        {definition.detail && <p>{t(definition.detail)}</p>}
        {introducer && <p>{t('{%reintroducer%} might reintroduce this device.').replace('{%reintroducer%}', introducer.name || introducer.deviceID)}</p>}
        {error && <p class="text-danger" role="alert">{error}</p>}
    </Dialog>;
}
