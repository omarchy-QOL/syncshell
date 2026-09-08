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

export function Folder({folder, info, stats, progress, api, rescan}) {
    const {t, language} = useContext(LocaleContext);
    const [open, setOpen] = useState(false);
    const [scanning, setScanning] = useState(false);
    const [itemsKind, setItemsKind] = useState('');
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
                                label="Global/local State" prefix={label} text={fieldHelp['Global/local State'].help} />&nbsp;<span>{t('Global/local State')}</span></th>
                            <td class="text-right"><Counts info={info} /></td>
                        </tr>}
                        {summaries.map(prefix => <Field key={prefix} label={prefix === 'global' ? 'Global State' : 'Local State'} rowClass="folder-state-detail">
                            <Counts info={info} prefix={prefix} />
                        </Field>)}
                        {info?.needTotalItems > 0 && <Field label="Out of Sync Items"><a href="#needed" onClick={showItems('need')}>
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
                    <button class="btn btn-sm btn-default" disabled={scanning || !['idle', 'stopped', 'unshared', 'outofsync', 'faileditems', 'localadditions'].includes(status)} onClick={scan}>
                        <span class="fas fa-fw fa-refresh" aria-hidden="true" /> {t('Rescan')}
                    </button>
                </div>
            </div>}
        </div>
        {itemsKind && <ItemsDialog api={api} folder={folder} kind={itemsKind}
            total={itemsKind === 'need' ? info.needTotalItems : itemsKind === 'failed' ? info.pullErrors : info.receiveOnlyTotalItems}
            onClose={() => setItemsKind('')} />}
    </>;
}
