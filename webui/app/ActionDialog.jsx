import {useContext, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {Dialog} from './Dialog.jsx';
import {Editor} from './Editor.jsx';
import {Settings} from './Settings.jsx';
import {RemoteFiles} from './RemoteFiles.jsx';
import {RestoreVersions} from './RestoreVersions.jsx';
import {deviceName, sharedFolders, serviceHealth} from '../client/devices.mjs';
import {timestamp} from '../client/format.mjs';
export function ActionDialog({action, state, api, session, onClose}) {
    const {t} = useContext(LocaleContext);
    const [copied, setCopied] = useState(false);
    const friendly = id => deviceName(state.config.devices.find(device => device.deviceID.startsWith(id || '\0'))) || id || t('Unknown');
    if (action.type === 'settings' || action.type === 'advanced') return <Settings state={state} api={api} session={session} onClose={onClose} advanced={action.type === 'advanced'} />;
    if (action.type.startsWith('edit-') || action.type.startsWith('add-'))
        return <Editor action={action} state={state} api={api} session={session} onClose={onClose} />;
    if (action.type === 'versions') return <RestoreVersions api={api} folder={action.folder} onClose={onClose} />;
    if (action.type === 'about') return <Dialog title="About" icon="fas fa-info-circle" onClose={onClose}>
        <h3>Syncshell Modern / Omarchy UI</h3>
        <p>Based on Syncthing, by the Syncthing authors and community.</p>
        <p>Syncthing {state.version.version}</p>
        <p><a href="https://github.com/omarchy-QOL/syncshell" target="_blank" rel="noreferrer">Syncshell</a> · <a href="https://syncthing.net" target="_blank" rel="noreferrer">Syncthing</a> · <a href="LICENSE.syncthing" target="_blank">Mozilla Public License 2.0</a></p>
    </Dialog>;
    if (action.type === 'identification') return <Dialog title={t('Device Identification') + ' - ' + deviceName(action.device)} large status="info" icon="fas fa-qrcode" onClose={onClose}>
        <div class="text-center"><div class="well well-sm text-monospace"><strong>{action.device.deviceID}</strong></div>
            <img class="img-thumbnail" src={'qr/?text=' + encodeURIComponent(action.device.deviceID)} height="328" width="328" alt={t('QR code')} />
            <div class="btn-group-vertical"><button class="btn btn-default" onClick={async () => { await navigator.clipboard.writeText(action.device.deviceID); setCopied(true); }}><span class="fa fa-clone" /> {t(copied ? 'Copied!' : 'Copy')}</button></div>
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
