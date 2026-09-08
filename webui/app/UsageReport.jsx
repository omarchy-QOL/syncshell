import {useContext, useEffect, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {Dialog} from './Dialog.jsx';
import {usageReport, decideUsage} from '../client/reports.mjs';
export function UsageReport({api, session, state, consent = false, onClose}) {
    const {t} = useContext(LocaleContext), [maximum] = useState(state.system.urVersionMax || 2);
    const [version, setVersion] = useState(maximum), [diff, setDiff] = useState(false), [preview, setPreview] = useState(!consent);
    const [report, setReport] = useState(null), [error, setError] = useState(''), [busy, setBusy] = useState(false);
    useEffect(() => {
        if (!preview) return;
        const controller = new AbortController(); setReport(null);
        usageReport(api, version, diff, controller.signal).then(value => { setReport(value); setError(''); })
            .catch(value => { if (!controller.signal.aborted) setError(value.message); });
        return () => controller.abort();
    }, [api, version, diff, preview]);
    async function decide(accepted) {
        setBusy(true);
        try { await decideUsage(session, maximum, accepted); onClose(); }
        catch (value) { setError(value.message); }
        finally { setBusy(false); }
    }
    return <Dialog title={consent ? 'Allow Anonymous Usage Reporting?' : 'Anonymous Usage Reporting'} large status="info" icon="fas fa-chart-bar" onClose={onClose} onCancel={() => { if (!consent && !busy) onClose(); }} footer={consent ? <>
        <button class="btn btn-success" disabled={busy} onClick={() => decide(true)}>{t('Yes')}</button><button class="btn btn-danger" disabled={busy} onClick={() => decide(false)}>{t('No')}</button>
    </> : <button class="btn btn-default" onClick={onClose}>{t('Close')}</button>}>
        {consent && state.config.options.urAccepted > 0 ? <p>{t('Anonymous usage report format has changed. Would you like to move to the new format?')}</p> : <><p>{t('The encrypted usage report is sent daily. It is used to track common platforms, folder sizes, and app versions. If the reported data set is changed you will be prompted with this dialog again.')}</p><p>{t('The aggregated statistics are publicly available at the URL below.')} <a href="https://data.syncthing.net/" target="_blank" rel="noreferrer">data.syncthing.net</a></p></>}
        {!preview ? <button class="btn btn-default" onClick={() => setPreview(true)}>{t('Preview Usage Report')}</button> : <>
            {!consent && <><label for="report-version">{t('Version')}</label><select id="report-version" class="form-control" value={version} onChange={event => setVersion(Number(event.currentTarget.value))}>{Array.from({length:maximum-1},(_,i)=>maximum-i).map(value => <option key={value} value={value}>{t('Version')} {value}</option>)}</select>
                {version > 2 && <label><input type="checkbox" checked={diff} onChange={event => setDiff(event.currentTarget.checked)} /> {t('Show diff with previous version')}</label>}
            </>}
            {report ? <pre class="port-share-text">{JSON.stringify(report,null,2)}</pre> : !error && <p role="status">{t('Loading data...')}</p>}
        </>}
        {error && <p class="text-danger" role="alert">{error}</p>}
    </Dialog>;
}
