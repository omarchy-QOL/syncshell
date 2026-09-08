import {render} from 'preact';
import {useEffect, useRef, useState} from 'preact/hooks';
import {createApi} from '../client/api.mjs';
import {createSession, initialState} from '../client/session.mjs';
import {Folder} from './Folder.jsx';
import {Login} from './Login.jsx';
import '../client/components.css';
import {LanguageMenu} from './LanguageMenu.jsx';
import {LocaleContext} from './locale-context.jsx';
import {createLocale, translator} from '../client/locale.mjs';

function App() {
    const [state, setState] = useState(initialState);
    const [api] = useState(() => createApi());
    const [languages] = useState(() => createLocale(api));
    const [locale, setLocale] = useState({language: 'en', t: translator({})});
    const languageVersion = useRef(0);
    async function selectLanguage(code) {
        const version = ++languageVersion.current;
        const selected = await (code ? languages.use(code, true) : languages.auto());
        if (version !== languageVersion.current) return;
        setLocale(selected);
        document.documentElement.lang = selected.language;
    }
    const [session] = useState(() => createSession(api, {publish: setState,
        onAuthExpired: () => location.reload()}));
    const authenticated = Boolean(window.metadata?.authenticated);
    useEffect(() => {
        selectLanguage().catch(error => setState(state => ({...state, error})));
        if (!authenticated) return;
        session.start();
        return () => { session.stop(); };
    }, [session, authenticated]);
    const name = state.config.devices.find(device => device.deviceID === state.system.myID)
        ?.name || state.system.myID || 'Syncthing';
    return <LocaleContext.Provider value={{...locale, select: selectLanguage}}>
        <nav class="navbar navbar-top navbar-default" aria-label="Main"><div class="container">
            <span class="navbar-brand"><img class="logo" src="assets/img/logo-horizontal.svg"
                height="32" width="117" alt="Syncthing" /></span>
            <p class="navbar-text">{name}</p>
            <ul class="nav navbar-nav navbar-right"><LanguageMenu /></ul>
        </div></nav>
        <main class="container content">
            {!authenticated ? <Login /> : <>
            {state.error && <div class="alert alert-danger" role="alert">{state.error.message}</div>}
            {!state.ready && <p role="status">Connecting to Syncthing…</p>}
            <div class="dashboard"><div class="dashboard-primary active">
                <section class="dashboard-folders" aria-labelledby="folder-list">
                    <h3 id="folder-list">{locale.t('Folders')}</h3>
                    <div class="panel-group">{state.config.folders.map(folder =>
                        <Folder api={api} progress={state.scanProgress[folder.id]} key={folder.id} folder={folder} info={state.model[folder.id]}
                            stats={state.folderStats[folder.id]}
                            rescan={() => session.rescan(folder.id)} />)}</div>
                </section>
            </div></div>
            </>}
        </main>
    </LocaleContext.Provider>;
}

render(<App />, document.getElementById('app'));
