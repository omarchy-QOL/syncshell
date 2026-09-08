import {render} from 'preact';
import {useEffect, useRef, useState} from 'preact/hooks';
import {createApi} from '../client/api.mjs';
import {createSession, initialState} from '../client/session.mjs';
import {createLocale, translator} from '../client/locale.mjs';
import {grouped, deviceName} from '../client/devices.mjs';
import {notices} from '../client/notices.mjs';
import {Folder} from './Folder.jsx';
import {Device} from './Device.jsx';
import {Login} from './Login.jsx';
import {LanguageMenu} from './LanguageMenu.jsx';
import {Notifications} from './Notifications.jsx';
import {ActionDialog} from './ActionDialog.jsx';
import {LocaleContext} from './locale-context.jsx';
import '../client/components.css';

const tabs = [['overview', 'Overview'], ['conflicts', 'Resolve sync conflicts'], ['notifications', 'Notifications']];
const helpLinks = [['Introduction','https://github.com/omarchy-QOL/syncshell#readme'], ['Home page','https://github.com/omarchy-QOL/syncshell'], ['Documentation','https://docs.syncthing.net/'], ['Support','https://github.com/omarchy-QOL/syncshell/issues'], ['Changelog','https://github.com/omarchy-QOL/syncshell/blob/main/CHANGELOG.md'], ['Statistics','https://data.syncthing.net/'], ['Bugs','https://github.com/omarchy-QOL/syncshell/issues'], ['Source Code','https://github.com/omarchy-QOL/syncshell']];
function App() {
    const [state, setState] = useState(initialState);
    const [api] = useState(() => createApi());
    const [languages] = useState(() => createLocale(api));
    const [locale, setLocale] = useState({language: 'en', t: translator({})});
    const [session] = useState(() => createSession(api, {publish: setState, onAuthExpired: () => location.reload()}));
    const [activeTab, setActiveTab] = useState('overview'), [menu, setMenu] = useState('');
    const [action, setAction] = useState(null), [metric, setMetric] = useState(false);
    const languageVersion = useRef(0);
    const authenticated = Boolean(window.metadata?.authenticated);
    const self = state.config.devices.find(device => device.deviceID === state.system.myID);
    const others = state.config.devices.filter(device => device.deviceID !== state.system.myID);
    const folderGroups = grouped(state.config.folders, 'label', 'id');
    const deviceGroups = grouped(others, 'name', 'deviceID');
    const cards = notices(state);
    const name = deviceName(self) || 'Syncthing';
    const {t} = locale;
    const perform = promise => promise.catch(() => {});
    async function selectLanguage(code) {
        const version = ++languageVersion.current;
        const selected = await (code ? languages.use(code, true) : languages.auto());
        if (version !== languageVersion.current) return;
        setLocale(selected); document.documentElement.lang = selected.language;
    }
    function toggleUnits() {
        setMetric(value => { try { localStorage.setItem('metricRates', String(!value)); } catch {} return !value; });
    }
    async function openAction(next) {
        setMenu('');
        try {
            if (next.type === 'add-device') {
                const device = await api.get('config/defaults/device');
                device.deviceID = typeof next.device === 'string' ? next.device : '';
                device.name = next.pending?.name || '';
                next = {...next, device};
            }
            if (next.type === 'add-folder') {
                const folder = await api.get('config/defaults/folder');
                folder.id = typeof next.folder === 'string' ? next.folder : Math.random().toString(36).slice(2, 7) + '-' + Math.random().toString(36).slice(2, 7);
                folder.label = next.pending?.label || '';
                folder.devices = [{deviceID: state.system.myID}, ...(next.device ? [{deviceID: next.device}] : [])];
                if (next.pending?.receiveEncrypted) folder.type = 'receiveencrypted';
                next = {...next, folder};
            }
            if (next.type === 'changes') await session.refreshGlobalChanges();
            setAction(next);
        } catch (error) { session.reportError(error); }
    }
    function tabKey(event) {
        let index = tabs.findIndex(([id]) => id === activeTab);
        if (event.key === 'ArrowRight') index = (index + 1) % tabs.length;
        else if (event.key === 'ArrowLeft') index = (index + tabs.length - 1) % tabs.length;
        else if (event.key === 'Home') index = 0;
        else if (event.key === 'End') index = tabs.length - 1;
        else return;
        event.preventDefault(); setActiveTab(tabs[index][0]);
        event.currentTarget.querySelectorAll('[role="tab"]')[index].focus();
    }
    useEffect(() => {
        selectLanguage().catch(error => session.reportError(error));
        try { setMetric(localStorage.getItem('metricRates') === 'true'); } catch {}
        function outside(event) { if (!event.target.closest('.action-menu')) setMenu(''); }
        document.addEventListener('pointerdown', outside);
        if (authenticated) session.start();
        return () => { session.stop(); document.removeEventListener('pointerdown', outside); };
    }, [session, authenticated]);
    useEffect(() => { document.title = name + ' | Syncshell (Preact)'; }, [name]);
    return <LocaleContext.Provider value={{...locale, select: selectLanguage}}>
        <nav class="navbar navbar-top navbar-default" aria-label="Main"><div class="container">
            <span class="navbar-brand"><img class="logo" src="assets/img/logo-horizontal.svg" height="32" width="117" alt="Syncthing" /></span>
            {authenticated && <p class="navbar-text hidden-xs">{name}</p>}
            <ul class="nav navbar-nav navbar-right"><LanguageMenu />
                <li class={`dropdown action-menu ${menu === 'help' ? 'open' : ''}`}><a href="#help" class="dropdown-toggle" aria-expanded={menu === 'help'} onClick={event => { event.preventDefault(); setMenu(menu === 'help' ? '' : 'help'); }}><span class="fa fa-question-circle" /> {t('Help')} <span class="caret" /></a>
                    <ul class="dropdown-menu">{helpLinks.map(([label, url]) => <li key={label}><a href={url} target="_blank" rel="noreferrer">{t(label)}</a></li>)}
                        <li><a href="#about" onClick={event => { event.preventDefault(); openAction({type: 'about'}); }}>{t('About')}</a></li>
                    </ul>
                </li>
                {authenticated && <li class={`dropdown action-menu ${menu === 'actions' ? 'open' : ''}`}><a href="#actions" class="dropdown-toggle" aria-expanded={menu === 'actions'} onClick={event => { event.preventDefault(); setMenu(menu === 'actions' ? '' : 'actions'); }}><span class="fas fa-cog" /> {t('Actions')} <span class="caret" /></a>
                    <ul class="dropdown-menu">
                        <li><a href="#settings" onClick={event => { event.preventDefault(); openAction({type: 'settings'}); }}>{t('Settings')}</a></li>
                        <li><a href="#identification" onClick={event => { event.preventDefault(); openAction({type: 'identification', device: self}); }}>{t('Show ID')}</a></li>
                        <li><a href="rest/debug/support" target="_blank">{t('Support Bundle')}</a></li>
                        {(state.config.gui?.user || state.config.gui?.authMode === 'ldap') && <li><a href="#logout" onClick={async event => { event.preventDefault(); await api.post('noauth/auth/logout', {}); location.reload(); }}>{t('Log Out')}</a></li>}
                        <li><a href="#restart" onClick={event => { event.preventDefault(); setMenu(''); perform(session.systemAction('restart')); }}>{t('Restart')}</a></li>
                        <li><a href="#shutdown" onClick={event => { event.preventDefault(); setMenu(''); perform(session.systemAction('shutdown')); }}>{t('Shut Down')}</a></li>
                    </ul>
                </li>}
            </ul>
        </div></nav>
        <main class="container content">
            {!authenticated ? <Login /> : <>
                {state.error && <div class="alert alert-danger" role="alert">{state.error.message}</div>}
                {!state.ready && <p role="status">{t('Loading data...')}</p>}
                <div class="dashboard">
                    <ul class="nav nav-tabs dashboard-tabs" role="tablist" onKeyDown={tabKey}>{tabs.map(([id, label]) =>
                        <li key={id} class={id === activeTab ? 'active' : ''} role="presentation"><a id={id + '-tab'} href={'#dashboard-' + id} role="tab" aria-controls={'dashboard-' + id} aria-selected={id === activeTab} tabIndex={id === activeTab ? 0 : -1} onClick={event => { event.preventDefault(); setActiveTab(id); }}>{t(label)}
                            {id === 'notifications' && <span class="notification-indicator"><span class="fas fa-circle text-success" role="img" aria-label={t('Pending notifications')} /><span class="fas fa-circle text-warning" role="img" aria-label={t('Pending warnings')} /><span class="fas fa-circle text-danger" role="img" aria-label={t('Pending errors')} /></span>}
                        </a></li>)}</ul>
                    <div class="tab-content">
                        <div id="dashboard-overview" class={`tab-pane dashboard-primary ${activeTab === 'overview' ? 'active' : ''}`} role="tabpanel" aria-labelledby="overview-tab">
                            <section class="dashboard-folders" aria-labelledby="folder-list"><h3 id="folder-list">{t('Folders')}{state.config.folders.length > 1 ? ' (' + state.config.folders.length + ')' : ''}</h3>
                                {folderGroups.map(([group, folders]) => <div key={group}>{group && <h4 class="folder-text" title={group}>{group}{folders.length > 1 ? ' (' + folders.length + ')' : ''}</h4>}
                                    <div class="panel-group">{folders.map(folder => <Folder key={folder.id} api={api} session={session} state={state} folder={folder} progress={state.scanProgress[folder.id]} info={state.model[folder.id]} stats={state.folderStats[folder.id]} rescan={() => session.rescan(folder.id)} onAction={openAction} />)}</div>
                                </div>)}
                                <div class="folder-actions">
                                    {state.config.folders.some(folder => !folder.paused) && <button class="btn btn-sm btn-default" onClick={() => perform(session.setPaused('folders', undefined, true))}><span class="fas fa-pause" /> {t('Pause All')}</button>}
                                    {state.config.folders.some(folder => folder.paused) && <button class="btn btn-sm btn-default" onClick={() => perform(session.setPaused('folders', undefined, false))}><span class="fas fa-play" /> {t('Resume All')}</button>}
                                    {state.config.folders.length > 0 && <button class="btn btn-sm btn-default" onClick={() => perform(session.rescan())}><span class="fas fa-refresh" /> {t('Rescan All')}</button>}
                                    <button class="btn btn-sm btn-default" onClick={() => openAction({type: 'add-folder'})}><span class="fas fa-plus" /> {t('Add Folder')}</button>
                                </div>
                            </section>
                            <section class="dashboard-devices" aria-label={t('Devices')}><h3>{t('Devices')}</h3>
                                {self && <Device device={self} state={state} session={session} local metric={metric} toggleUnits={toggleUnits} onAction={openAction} />}
                                <div class="dashboard-remotes">{deviceGroups.map(([group, devices]) => <div key={group}>{group && <h4>{group}{devices.length > 1 ? ' (' + devices.length + ')' : ''}</h4>}
                                    <div class="panel-group">{devices.map(device => <Device key={device.deviceID} device={device} state={state} session={session} metric={metric} toggleUnits={toggleUnits} onAction={openAction} />)}</div></div>)}
                                    <div class="folder-actions">
                                        {others.some(device => !device.paused) && <button class="btn btn-sm btn-default" onClick={() => perform(session.setPaused('devices', undefined, true))}>{t('Pause All')}</button>}
                                        {others.some(device => device.paused) && <button class="btn btn-sm btn-default" onClick={() => perform(session.setPaused('devices', undefined, false))}>{t('Resume All')}</button>}
                                        <button class="btn btn-sm btn-default" onClick={() => openAction({type: 'changes'})}>{t('Recent Changes')}</button>
                                        <button class="btn btn-sm btn-default" onClick={() => openAction({type: 'add-device'})}>{t('Add Remote Device')}</button>
                                    </div>
                                </div>
                            </section>
                        </div>
                        <section id="dashboard-conflicts" class={`tab-pane ${activeTab === 'conflicts' ? 'active' : ''}`} role="tabpanel" aria-labelledby="conflicts-tab"><h3>{t('Resolve sync conflicts')}</h3><p>{t('Sync conflict resolution is not available yet.')}</p></section>
                        <section id="dashboard-notifications" class={`tab-pane notifications ${activeTab === 'notifications' ? 'active' : ''}`} role="tabpanel" aria-labelledby="notifications-tab"><Notifications cards={cards} session={session} onAction={openAction} /></section>
                    </div>
                </div>
            </>}
        </main>
        {action && <ActionDialog key={action.type + (action.device?.deviceID || action.folder?.id || '')} action={action} state={state} api={api} session={session} onClose={() => setAction(null)} />}
    </LocaleContext.Provider>;
}
render(<App />, document.getElementById('app'));
