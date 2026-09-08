import {ShareStatus} from './ShareStatus.jsx';
import {recoveryActions, managementActions} from '../client/management.mjs';
import {useContext, useEffect, useRef, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {folderStatus, folderClass, folderStateClass, folderStateDetails, syncPercentage, progressPercentage}
    from '../client/folders.mjs';
import {folderStatusText, folderStatusIcon, folderTypes, pullOrders, scanRemaining}
    from '../client/folder-view.mjs';
import {compactNumber, unitPrefixed, duration, timestamp} from '../client/format.mjs';
import {stripeSections} from '../client/stripes.mjs';
import {fieldHelp} from '../client/field-help.mjs';
import {Tooltip} from './Tooltip.jsx';
import {Counts} from './Counts.jsx';
import {Field} from './Field.jsx';
import {Versioning} from './Versioning.jsx';
import {ItemsDialog} from './ItemsDialog.jsx';

export function Folder({folder, info, stats, progress, api, rescan, state, session, onAction}) {
    const {t, language} = useContext(LocaleContext);
    const [open, setOpen] = useState(false);
    const [scanning, setScanning] = useState(false);
    const [itemsKind, setItemsKind] = useState('');
    const [sharingOpen, setSharingOpen] = useState(false);
    const panel = useRef();
    useEffect(() => { if (open) return stripeSections(panel.current); }, [open]);
    const status = folderStatus(folder, info);
    const label = folderStatusText(status);
    const summaries = folderStateDetails(folder, info) ? ['global', 'local'] : [];
    const percent = status === 'syncing' ? syncPercentage(info) : progress
        ? progressPercentage(progress.current, progress.total) : undefined;
    const watcherFailed = folder.fsWatcherEnabled && !folder.paused && status !== 'stopped' && info?.watchError;
    const localChanges = ['receiveonly', 'receiveencrypted'].includes(folder.type) && info?.receiveOnlyTotalItems > 0;
    const basename = value => (value || '').split(/[\\/]/).at(-1);
    async function scan() {
        setScanning(true);
        try { await rescan(); } catch {} finally { setScanning(false); }
    }
    const showItems = kind => event => { event.preventDefault(); setItemsKind(kind); };
    return <>
        <div class="panel panel-default">
            <button class="btn panel-heading" aria-expanded={open} onClick={() => setOpen(!open)}>
                {['scanning', 'syncing'].includes(status) && percent !== undefined &&
                    <span class="panel-progress" style={{width: percent + '%'}} />}
                <span class="panel-title">
                    <span class="panel-icon hidden-xs"><span class={`fas fa-fw fa-${({sendonly: 'upload', receiveonly: 'download', receiveencrypted: 'lock'})[folder.type] || 'folder'}`} aria-hidden="true" /></span>
                    <span class={`panel-status pull-right text-${folderClass(status)}`}>
                        <span class="hidden-xs">{t(label)}</span>
                        {status === 'scanning' && percent !== undefined && ` (${percent}%)`}
                        {status === 'syncing' && ` (${percent}%, ${unitPrefixed(info.needBytes, true)}B)`}
                        <span class={`visible-xs fa fa-fw ${folderStatusIcon(status)}`} aria-label={t(label)} />
                    </span>
                    <span class="panel-title-text" title={folder.label || folder.id}>{folder.label || folder.id}</span>
                </span>
            </button>
            {open && <div class="panel-collapse" ref={panel}><div class="panel-body less-padding">
                <details class="folder-details" open>
                    <summary>{t('Current activity')}</summary>
                    <table class="table table-condensed table-auto"><tbody>
                        {!folder.paused && info?.state && <tr class="folder-state-summary">
                            <th><Tooltip icon={`fa fa-fw fa-circle text-${folderStateClass(status)}`}
                                label="Global/local State" prefix={label} text={fieldHelp['Global/local State'].help} />&nbsp;<span>{t('Global/local State')}</span>
                                {info.ignorePatterns && <a href="#ignores" title={t('Reduced by ignore patterns')} onClick={event => { event.preventDefault(); onAction({type: 'edit-folder', folder, tab: 'ignores'}); }}><span class="fas fa-info-circle" /></a>}
                            </th>
                            <td class="text-right"><Counts info={info} /></td>
                        </tr>}
                        {summaries.map(prefix => <Field key={prefix} label={prefix === 'global' ? 'Global State' : 'Local State'} rowClass="folder-state-detail">
                            <Counts info={info} prefix={prefix} />
                        </Field>)}
                        {info?.needTotalItems > 0 && <Field label="Out of Sync Items" icon="fas fa-fw fa-cloud-download-alt" help="Items this device still needs to synchronize with other devices. The size counts whole files; reusing existing data can reduce the amount actually downloaded. Click the value to see the items."><a href="#needed" onClick={showItems('need')}>
                            {compactNumber(info.needTotalItems)} {t('items')}, ~{unitPrefixed(info.needBytes, true)}B</a></Field>}
                        {!folder.paused && info?.state && folder.ignoreDelete &&
                            <tr><td colSpan="2" class="text-right"><i class="small">{t('Altered by ignoring deletes.')} <a href="https://docs.syncthing.net/advanced/folder-ignoredelete.html" target="_blank" rel="noreferrer">{t('Help')}</a></i></td></tr>}
                        {stats?.lastScan && <Field label="Last Scan">{(Date.now() - new Date(stats.lastScan)) / 86400000 >= 365 ? t('Never') : timestamp(stats.lastScan)}</Field>}
                        {!folder.paused && (info?.invalid || info?.error) && <Field label="Error">
                            <Tooltip label={info.invalid || info.error} text={info.invalid || info.error} triggerText={info.invalid || info.error} /></Field>}
                        {info && info.errors !== 0 && <Field label="Failed Items"><a href="#failed" onClick={showItems('failed')}>
                            {compactNumber(info.pullErrors || 0)} {t('items')}</a></Field>}
                        {localChanges && <Field label="Locally Changed Items"><a href="#local-changed" onClick={showItems('local')}>
                            {compactNumber(info.receiveOnlyTotalItems)} {t('items')}, ~{unitPrefixed(info.receiveOnlyChangedBytes, true)}B</a></Field>}
                        {status === 'scanning' && progress?.rate > 0 && <Field label="Scan Time Remaining">
                            <span title={unitPrefixed(progress.rate, true) + 'B/s'}>~ {scanRemaining(progress)}</span></Field>}
                        {!['sendonly', 'receiveencrypted'].includes(folder.type) && stats?.lastFile?.filename &&
                            <Field label="Latest Change"><Tooltip label={stats.lastFile.filename}
                                triggerText={basename(stats.lastFile.filename)} tail kind="change">
                                {folder.path}/{stats.lastFile.filename}<br />
                                <span class="text-nowrap"><span class={stats.lastFile.deleted ? 'text-danger' : 'text-success'}>{t(stats.lastFile.deleted ? 'Deleted' : 'Updated')}</span>
                                    {' @ '}<span class="text-warning folder-change-time">{timestamp(stats.lastFile.at)}</span></span>
                            </Tooltip></Field>}
                    </tbody></table>
                </details>
                <details class="folder-details">
                    <summary>{t('Configuration')}</summary>
                    <table class="table table-condensed table-auto"><tbody>
                        <Field label="Rescans"><span title={watcherFailed || ''}>
                            <span class="far fa-clock" />&nbsp;{folder.rescanIntervalS > 0 ? duration(folder.rescanIntervalS, 's', language) : t('Disabled')}&ensp;
                            <span class={`fas fa-${folder.fsWatcherEnabled && !watcherFailed ? 'eye' : 'eye-slash'}`} />&nbsp;{t(watcherFailed ? 'Failed to set up, retrying' : folder.fsWatcherEnabled ? 'Enabled' : 'Disabled')}
                        </span></Field>
                        {folder.versioning?.type && <Field label="File Versioning"><Versioning config={folder.versioning} /></Field>}
                        {folder.ignorePerms && <Field label="Ignore Permissions">{t('Yes')}</Field>}
                    </tbody></table>
                </details>
                <details class="folder-details">
                    <summary>{t('Folder information')}</summary>
                    <table class="table table-condensed table-auto"><tbody>
                        <Field label="Folder Path"><Tooltip label={folder.path} text={folder.path} triggerText={folder.path} tail /></Field>
                        <Field label="Folder Type">{t(folderTypes[folder.type] || '')}</Field>
                        {folder.label && <Field label="Folder ID"><Tooltip label={folder.id} text={folder.id} triggerText={folder.id} /></Field>}
                        <Field label="Block Indexing">{t(folder.blockIndexing ? 'Yes' : 'No')}</Field>
                        {folder.type !== 'sendonly' && <Field label="File Pull Order">{t(pullOrders[folder.order] || '')}</Field>}
                    </tbody></table>
                </details>
            </div>
                <div class="panel-footer folder-actions">
                    {recoveryActions(folder, info, status).map(type => <button key={type} class="btn btn-danger btn-sm" onClick={() => onAction({type, folder})}>{t(managementActions[type].title)}</button>)}
                    <div class={`dropdown folder-sharing pull-left ${sharingOpen ? 'open' : ''}`}>
                        <button class="btn btn-sm btn-default dropdown-toggle" aria-expanded={sharingOpen} disabled={!folder.devices.some(device => device.deviceID !== state.system.myID)} onClick={() => setSharingOpen(!sharingOpen)}><span class="fas fa-share-alt" /> {t('Shared')} <span class="caret" /></button>
                        <ul class="dropdown-menu">{folder.devices.filter(device => device.deviceID !== state.system.myID).map(member => {
                            const device = state.config.devices.find(item => item.deviceID === member.deviceID);
                            return <li key={member.deviceID}><a href="#edit-device" onClick={event => { event.preventDefault(); setSharingOpen(false); if (device) onAction({type: 'edit-device', device}); }}>{device?.name || member.deviceID.slice(0, 7)} <ShareStatus encrypted={folder.type === 'receiveencrypted' || !!member.encryptionPassword} remoteState={state.completion[member.deviceID]?.[folder.id]?.remoteState} /></a></li>;
                        })}</ul>
                    </div>
                    <button class="btn btn-sm btn-default" onClick={() => session.setPaused('folders', folder.id, !folder.paused).catch(() => {})}><span class={`fas fa-${folder.paused ? 'play' : 'pause'}`} /> {t(folder.paused ? 'Resume' : 'Pause')}</button>
                    <button class="btn btn-sm btn-default" disabled={scanning || !['idle', 'stopped', 'unshared', 'outofsync', 'faileditems', 'localadditions'].includes(status)} onClick={scan}>
                        <span class="fas fa-fw fa-refresh" aria-hidden="true" /> {t('Rescan')}
                    </button>
                    {folder.versioning?.type && folder.versioning.type !== 'external' && <button class="btn btn-sm btn-default" disabled={folder.paused} onClick={() => onAction({type: 'versions', folder})}><span aria-hidden="true" class="fas fa-undo" /> {t('Versions')}</button>}
                    <button class="btn btn-sm btn-default" onClick={() => onAction({type: 'edit-folder', folder})}><span class="fas fa-pencil-alt" /> {t('Edit')}</button>
                </div>
            </div>}
        </div>
        {itemsKind && <ItemsDialog api={api} folder={folder} kind={itemsKind} revision={state.itemsRevision[folder.id] || 0} progress={state.downloadProgress[folder.id] || {}} progressEnabled={state.config.options.progressUpdateIntervalS > 0 && folder.type !== 'receiveencrypted'}
            total={itemsKind === 'need' ? info.needTotalItems : itemsKind === 'failed' ? info.pullErrors : info.receiveOnlyTotalItems}
            onClose={() => setItemsKind('')} />}
    </>;
}
