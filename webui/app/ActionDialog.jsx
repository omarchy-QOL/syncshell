import {useContext} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {Dialog} from './Dialog.jsx';
import {About} from './About.jsx';
import {IdentityControls} from './IdentityControls.jsx';
import {ServiceDialog} from './ServiceDialog.jsx';
import {Logs} from './Logs.jsx';
import {Editor} from './Editor.jsx';
import {Settings} from './Settings.jsx';
import {ConfirmAction} from './ConfirmAction.jsx';
import {RemoteFiles} from './RemoteFiles.jsx';
import {RestoreVersions} from './RestoreVersions.jsx';
import {deviceName, sharedFolders, serviceHealth} from '../client/devices.mjs';
import {timestamp} from '../client/format.mjs';
export function ActionDialog({action, state, api, session, onClose}) {
    const {t} = useContext(LocaleContext);
    const friendly = id => deviceName(state.config.devices.find(device => device.deviceID.startsWith(id || '\0'))) || id || t('Unknown');
    if (['restart', 'shutdown', 'upgrade'].includes(action.type)) return <ServiceDialog kind={action.type} state={state} session={session} onClose={onClose} />;
    if (action.type === 'logs') return <Logs api={api} onClose={onClose} />;
    if (action.type === 'settings' || action.type === 'advanced') return <Settings state={state} api={api} session={session} onClose={onClose} advanced={action.type === 'advanced'} />;
    if (action.type.startsWith('edit-') || action.type.startsWith('add-'))
        return <Editor action={action} state={state} api={api} session={session} onClose={onClose} />;
    if (['override', 'revert'].includes(action.type)) return <ConfirmAction action={action} api={api} session={session} onClose={onClose} onDone={onClose} />;
    if (action.type === 'versions') return <RestoreVersions api={api} folder={action.folder} onClose={onClose} />;
    if (action.type === 'about') return <About api={api} version={state.version} onClose={onClose} />;
    if (action.type === 'identification') return <Dialog title={t('Device Identification') + ' - ' + deviceName(action.device)} large status="info" icon="fas fa-qrcode" onClose={onClose}>
        <div class="text-center"><div class="well well-sm text-monospace"><strong>{action.device.deviceID}</strong></div>
            <img class="img-thumbnail" src={'qr/?text=' + encodeURIComponent(action.device.deviceID)} height="328" width="328" alt={t('QR code')} />
            <IdentityControls device={action.device} api={api} />
        </div>
    </Dialog>;
    if (action.type === 'listeners' || action.type === 'discovery') {
        const health = serviceHealth(action.type === 'listeners' ? state.system.connectionServiceStatus : state.system.discoveryStatus);
        return <Dialog title={action.type === 'listeners' ? health.failed.length ? 'Listener Failures' : 'Listener Status' : health.failed.length ? 'Discovery Failures' : 'Discovery Status'} status={health.failed.length ? 'danger' : 'default'} icon="fas fa-sitemap" onClose={onClose}>
            {health.entries.map(([name, value]) => <section key={name}><h5>{name}</h5><dl>{Object.entries(value || {}).map(([key, item]) =>
                <div key={key}><dt>{key}</dt><dd class={key === 'error' ? 'text-danger' : ''}>{Array.isArray(item) ? item.join(', ') : typeof item === 'object' ? JSON.stringify(item) : item}</dd></div>)}</dl></section>)}
        </Dialog>;
    }
    if (action.type === 'remote-needed') {
        const folders = sharedFolders(state.config, action.device.deviceID).filter(folder => {
            const completion = state.completion[action.device.deviceID]?.[folder.id];
            return !completion || completion.needItems + completion.needDeletes > 0;
        });
        return <Dialog title={t('Out of Sync Items') + ' - ' + deviceName(action.device)} large status="info" icon="fas fa-exchange-alt" onClose={onClose}>
            {folders.map(folder => <RemoteFiles key={folder.id} api={api} folder={folder} device={action.device} state={state} single={folders.length === 1} />)}
        </Dialog>;
    }
    if (action.type === 'changes') return <Dialog title="Recent Changes" large icon="fas fa-info-circle" onClose={onClose}>
        <div class="table-responsive"><table class="table table-condensed table-striped"><thead><tr>{['Device', 'Action', 'Type', 'Folder', 'Path', 'Time'].map(label => <th key={label}>{t(label)}</th>)}</tr></thead>
            <tbody>{state.globalChanges.map(event => <tr key={event.id}><td>{friendly(event.data.modifiedBy)}</td><td>{t(event.data.action)}</td><td>{t(event.data.type)}</td><td>{state.config.folders.find(folder => folder.id === event.data.folder)?.label || event.data.folder}</td><td class="word-break-all">{event.data.path}</td><td>{timestamp(event.time)}</td></tr>)}</tbody>
        </table></div>
    </Dialog>;
    return null;
}
