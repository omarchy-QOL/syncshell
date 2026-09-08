import {ShareStatus} from './ShareStatus.jsx';
import {useContext, useEffect, useRef, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {deviceName, sharedFolders, deviceStatus, deviceLabels, deviceIcons, deviceColor,
    connectionType, connectionLabels, connectionIcons, lastSeenDays, addressError, remoteGui,
    serviceHealth} from '../client/devices.mjs';
import {localStateTotal} from '../client/folders.mjs';
import {unitPrefixed, compactNumber, duration, timestamp} from '../client/format.mjs';
import {stripeSections} from '../client/stripes.mjs';
import {Field} from './Field.jsx';
import {Counts} from './Counts.jsx';
import {Tooltip} from './Tooltip.jsx';
import {Identicon} from './Identicon.jsx';

export function Device({device, state, session, local = false, metric, toggleUnits, onAction}) {
    const {t, language} = useContext(LocaleContext);
    const [open, setOpen] = useState(local);
    const [foldersOpen, setFoldersOpen] = useState(false);
    const panel = useRef();
    useEffect(() => { if (open) return stripeSections(panel.current); }, [open]);
    const conn = local ? state.connectionsTotal : state.connections[device.deviceID] || {};
    const completion = state.completion[device.deviceID] || {};
    const folders = sharedFolders(state.config, device.deviceID);
    const status = deviceStatus(device, state);
    const type = connectionType(conn);
    const age = lastSeenDays(state.deviceStats[device.deviceID]?.lastSeen);
    const totals = localStateTotal(state.model);
    const listeners = serviceHealth(state.system.connectionServiceStatus);
    const discovery = serviceHealth(state.system.discoveryStatus);
    const gui = remoteGui(device, conn);
    const addresses = [...(device.addresses || []).map(address => ({address, source: 'Configured'})),
        ...(state.discoveryCache[device.deviceID]?.addresses || []).map(address => ({address, source: 'Discovered'}))];
    const perform = promise => promise.catch(() => {});
    const openAction = (type, extra = {}) => onAction({type, device, ...extra});
    const rate = bytes => unitPrefixed(metric ? bytes * 8 : bytes, !metric) + (metric ? 'bps' : 'B/s');
    const link = (event, action) => { event.preventDefault(); openAction(action); };
    return <div class="panel panel-default">
        <button class="btn panel-heading" aria-expanded={open} onClick={() => setOpen(!open)}>
            {!local && status === 'syncing' && <span class="panel-progress" style={{width: completion._total + '%'}} />}
            <span class="panel-title device-title">
                <Identicon id={device.deviceID} />
                {!local && <span class={`panel-status pull-right text-${deviceColor(device, state)}`}>
                    <span class="hidden-xs">{t(deviceLabels[status])}</span>
                    {status === 'syncing' && ` (${completion._total}%, ${unitPrefixed(completion._needBytes, true)}B)`}
                    <span class={`visible-xs fa fa-fw ${deviceIcons[status]}`} aria-label={t(deviceLabels[status])} />
                    <span class="inline-icon"><span class={`reception reception-theme ${connectionIcons[type] || ''}`} /></span>
                </span>}
                <span class="panel-title-text"><span class="device-name" title={deviceName(device)}>{deviceName(device)}</span>
                    <small class="device-role text-success">({t(local ? 'This Device' : 'Remote')})</small></span>
            </span>
        </button>
        {open && <div class="panel-collapse" ref={panel}><div class="panel-body less-padding">
            {!local && <table class="table table-condensed visible-xs remote-status"><tbody>
                <Field label="Device Status" icon={`fa fa-fw ${deviceIcons[status]}`}>{t(deviceLabels[status])}</Field>
            </tbody></table>}
            {(local || conn.connected || folders.length > 0 || completion._needItems > 0) &&
                <details class="device-details" open><summary>{t('Current activity')}</summary>
                    <table class="table table-condensed table-auto"><tbody>
                        {!local && !conn.connected && folders.length > 0 && <Field label="Sync Status">
                            {completion._total === 100 ? t('Up to Date') : completion._total < 100 ? t('Out of Sync') + ' (' + completion._total + '%)' : ''}</Field>}
                        {(local || conn.connected) && ['in', 'out'].map(direction =>
                            <Field key={direction} label={direction === 'in' ? 'Download Rate' : 'Upload Rate'}
                                icon={`fas fa-fw fa-cloud-${direction === 'in' ? 'download' : 'upload'}-alt`}
                                help={direction === 'in' ? (local ? 'Incoming traffic across all connected devices. Click the rate to switch between bytes and bits per second. A configured limit appears below.' : 'Data received by this machine from this remote device. Click the rate to switch between bytes and bits per second.') : (local ? 'Outgoing traffic across all connected devices. Click the rate to switch between bytes and bits per second. A configured limit appears below.' : 'Data sent by this machine to this remote device. Click the rate to switch between bytes and bits per second.')}
                                totalBytes={conn[direction + 'BytesTotal']}>
                                <a href="#units" onClick={event => { event.preventDefault(); toggleUnits(); }}>{rate(conn[direction + 'bps'] || 0)}
                                    {(local ? state.config.options : device)[direction === 'in' ? 'maxRecvKbps' : 'maxSendKbps'] > 0 &&
                                        <small><br /><i class="text-muted">{t('Limit')}: {rate((local ? state.config.options : device)[direction === 'in' ? 'maxRecvKbps' : 'maxSendKbps'] * 1024)}
                                            {local && state.config.options.limitBandwidthInLan && ` (${t('Applied to LAN')})`}</i></small>}
                                </a>
                            </Field>)}
                        {local && <Field label="Local State (Total)"><Counts prefix="local" info={{localFiles: totals.files, localDirectories: totals.directories, localBytes: totals.bytes}} /></Field>}
                        {!local && completion._needItems > 0 && <Field label="Out of Sync Items">
                            <a href="#remote-needed" onClick={event => link(event, 'remote-needed')}>
                                <Tooltip icon="fas fa-fw fa-exchange-alt" label="Out of Sync Items"
                                    text={`${completion._needItems.toLocaleString()} ${t('items')}, ~${unitPrefixed(completion._needBytes, true)}B`} />
                                {compactNumber(completion._needItems)} {t('items')}, ~{unitPrefixed(completion._needBytes, true)}B</a>
                        </Field>}
                    </tbody></table>
                </details>}
            <details class="device-details" open><summary>{t('Connectivity')}</summary>
                <table class="table table-condensed table-auto"><tbody>
                    {local ? <>
                        <Field label="Listeners"><a href="#listeners" class={`text-${listeners.color}`} onClick={event => link(event, 'listeners')}>{listeners.running}/{listeners.total}</a></Field>
                        {state.system.discoveryEnabled && <Field label="Discovery"><a href="#discovery" class={`text-${discovery.color}`} onClick={event => link(event, 'discovery')}>{discovery.running}/{discovery.total}</a></Field>}
                    </> : <>
                        <Field label="Address">{conn.connected ? conn.address : addresses.map((item, index) =>
                            <span class="remote-address" key={index}><span class="folder-text" title={t(item.source) + ': ' + item.address}>{item.address}</span>
                                {state.system.lastDialStatus?.[item.address]?.error && !device.paused && <small class="text-danger" title={state.system.lastDialStatus[item.address].error}>{addressError(state.system.lastDialStatus[item.address])}</small>}
                            </span>)}</Field>
                        {!conn.connected ? <Field label="Last seen">
                            {!age ? t('Never') : <>{timestamp(state.deviceStats[device.deviceID].lastSeen)}
                                {age >= 7 && <><br /><i class={age >= 365 ? 'text-danger' : age >= 30 ? 'text-warning' : ''}>{t(age >= 365 ? 'More than a year ago' : age >= 30 ? 'More than a month ago' : 'More than a week ago')}</i></>}</>}
                        </Field> : <>
                            <Field label="Connection Type" icon="reception reception-4 reception-theme" help="Transport and network used to reach this device. A relay forwards traffic when a direct connection is unavailable.">{t(connectionLabels[type] || 'Disconnected')}</Field>
                            <Field label="Number of Connections">1{conn.secondary?.length ? ' + ' + conn.secondary.length : ''}</Field>
                        </>}
                    </>}
                </tbody></table>
            </details>
            <details class="device-details"><summary>{t('Device information')}</summary>
                <table class="table table-condensed table-auto"><tbody>
                    {local ? <>
                        <Field label="Uptime">{duration(state.system.uptime, 'm', language)}</Field>
                        <Field label="Identification" help="The unique ID used to pair this device with other devices. Click the shortened ID to see the full ID and QR code."><a href="#identification" onClick={event => link(event, 'identification')}>{device.deviceID.slice(0, 7)}</a></Field>
                        <Field label="Version" help="Version and platform of the Syncthing service running on this device.">{state.version.version} ({state.version.os} {state.version.arch})</Field>
                    </> : <>
                        {conn.clientVersion && <Field label="Version">{conn.clientVersion}</Field>}
                        {device.introducedBy && <Field label="Introduced By">{deviceName(state.config.devices.find(item => item.deviceID === device.introducedBy)) || device.introducedBy.slice(0, 7)}</Field>}
                        <Field label="Compression">{t(({always: 'All Data', metadata: 'Metadata Only', never: 'Off'})[device.compression] || '')}</Field>
                        {device.allowedNetworks?.length > 0 && <Field label="Allowed Networks">{device.allowedNetworks.join(', ')}</Field>}
                        {[['introducer', 'Introducer'], ['autoAcceptFolders', 'Auto Accept'], ['untrusted', 'Untrusted']].map(([property, label]) =>
                            device[property] && <Field key={property} label={label}>{t('Yes')}</Field>)}
                    </>}
                </tbody></table>
            </details>
        </div>
        {!local && <div class="panel-footer folder-actions remote-actions">
            <button class="btn btn-sm btn-default" onClick={() => openAction('identification')}><span class="fas fa-qrcode" />&nbsp;{t('Identification')}</button>
            {folders.length > 0 && <div class={`dropup folder-sharing remote-folders ${foldersOpen ? 'open' : ''}`}>
                <button class="btn btn-sm btn-default dropdown-toggle" aria-expanded={foldersOpen} onClick={() => setFoldersOpen(!foldersOpen)}><span class="fas fa-folder" />&nbsp;{t('Folders')} <span class="caret" /></button>
                <ul class="dropdown-menu">{folders.map(folder => <li key={folder.id}><a href="#folder-sharing" onClick={event => { event.preventDefault(); setFoldersOpen(false); onAction({type: 'edit-folder', folder, tab: 'sharing'}); }}>{folder.label || folder.id} <ShareStatus encrypted={folder.type === 'receiveencrypted' || !!folder.devices.find(member => member.deviceID === device.deviceID)?.encryptionPassword} remoteState={state.completion[device.deviceID]?.[folder.id]?.remoteState} /></a></li>)}</ul>
            </div>}
            <span class="pull-right">
                {device.remoteGUIPort > 0 && <a class="btn btn-sm btn-default" href={gui || undefined} aria-disabled={!gui}><span class="fas fa-desktop" />&nbsp;{t('Remote GUI')}</a>}
                <button class="btn btn-sm btn-default" onClick={() => perform(session.setPaused('devices', device.deviceID, !device.paused))}><span class={`fas fa-${device.paused ? 'play' : 'pause'}`} />&nbsp;{t(device.paused ? 'Resume' : 'Pause')}</button>
                <button class="btn btn-sm btn-default" onClick={() => openAction('edit-device')}><span class="fas fa-pencil-alt" />&nbsp;{t('Edit')}</button>
            </span>
        </div>}
        </div>}
    </div>;
}
