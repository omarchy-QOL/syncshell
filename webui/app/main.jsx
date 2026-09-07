import {render} from 'preact';
import {useEffect, useState} from 'preact/hooks';
import {createApi} from '../client/api.mjs';
import {createSession, initialState} from '../client/session.mjs';
import {Folder} from './Folder.jsx';

function App() {
    const [state, setState] = useState(initialState);
    const [session] = useState(() => createSession(createApi(), {publish: setState,
        onAuthExpired: () => location.reload()}));
    useEffect(() => { session.start(); return () => { session.stop(); }; }, [session]);
    const name = state.config.devices.find(device => device.deviceID === state.system.myID)
        ?.name || state.system.myID || 'Syncthing';
    return <>
        <nav class="navbar navbar-top navbar-default" aria-label="Main"><div class="container">
            <span class="navbar-brand"><img class="logo" src="assets/img/logo-horizontal.svg"
                height="32" width="117" alt="Syncthing" /></span>
            <p class="navbar-text">{name}</p>
        </div></nav>
        <main class="container content">
            {state.error && <div class="alert alert-danger" role="alert">{state.error.message}</div>}
            {!state.ready && <p role="status">Connecting to Syncthing…</p>}
            <div class="dashboard"><div class="dashboard-primary active">
                <section class="dashboard-folders" aria-labelledby="folder-list">
                    <h3 id="folder-list">Folders</h3>
                    <div class="panel-group">{state.config.folders.map(folder =>
                        <Folder key={folder.id} folder={folder} info={state.model[folder.id]}
                            stats={state.folderStats[folder.id]}
                            rescan={() => session.rescan(folder.id)} />)}</div>
                </section>
            </div></div>
        </main>
    </>;
}

render(<App />, document.getElementById('app'));
