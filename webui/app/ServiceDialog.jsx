import {useContext, useEffect, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {Dialog} from './Dialog.jsx';
export function ServiceDialog({kind, state, session, onClose}) {
    const {t} = useContext(LocaleContext), [started] = useState(state.system.startTime);
    const [phase, setPhase] = useState('confirm'), [error, setError] = useState('');
    const title = error ? 'Error' : phase === 'confirm' ? 'Upgrade' : kind === 'shutdown' ? 'Shutdown Complete' : 'Restarting';
    useEffect(() => { if (kind !== 'upgrade') apply(); }, []);
    useEffect(() => {
        if (phase !== 'confirm' && started && state.online && state.system.startTime !== started) onClose();
    }, [phase, started, state.online, state.system.startTime]);
    async function apply() {
        setPhase('working'); setError('');
        try {
            await session.systemAction(kind); setPhase('waiting');
            if (kind !== 'shutdown' && state.config.gui.useTLS !== (location.protocol === 'https:')) location.protocol = state.config.gui.useTLS ? 'https:' : 'http:';
        } catch (value) { setError(value.message); }
    }
    return <Dialog title={title} status={error ? 'danger' : phase === 'confirm' ? 'warning' : kind === 'shutdown' ? 'success' : 'info'} icon={kind === 'shutdown' && phase === 'waiting' ? 'fas fa-power-off' : 'fas fa-hourglass-half'} onClose={onClose} onCancel={() => { if (phase === 'confirm' || error) onClose(); }} footer={<>
        {error ? <button class="btn btn-default" onClick={onClose}>{t('Close')}</button> : phase === 'confirm' && <><button class="btn btn-primary" onClick={apply}>{t('Upgrade')}</button><button class="btn btn-default" onClick={onClose}>{t('Close')}</button></>}
    </>}>
        {error ? <p role="alert">{error}</p> : phase === 'confirm' ? <><p>{t('Are you sure you want to upgrade?')}</p><p><a href={'https://github.com/syncthing/syncthing/releases/tag/' + encodeURIComponent(state.upgradeInfo?.latest || '')} target="_blank" rel="noreferrer">{t('Release Notes')}</a></p></>
            : kind === 'shutdown' ? <p role="status">{t(phase === 'working' ? 'Please wait' : 'Syncthing has been shut down.')}</p> : <p role="status">{t('Syncthing is restarting.')} {t('Please wait')}...</p>}
    </Dialog>;
}
