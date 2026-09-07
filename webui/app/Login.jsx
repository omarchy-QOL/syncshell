import {useState} from 'preact/hooks';
import {createApi} from '../client/api.mjs';

export function Login() {
    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');
    const [stayLoggedIn, setStayLoggedIn] = useState(false);
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState('');
    async function login(event) {
        event.preventDefault();
        setBusy(true);
        setError('');
        try {
            await createApi().post('noauth/auth/password', {username: username.trim(), password, stayLoggedIn});
            location.reload();
        } catch (failure) {
            setError(failure.status === 403 ? 'Incorrect user name or password.' : 'Login failed, see Syncthing logs for details.');
        } finally { setBusy(false); }
    }
    return <form class="panel panel-default" onSubmit={login}>
        <div class="panel-heading"><h3 class="panel-title">Log In</h3></div>
        <div class="panel-body">
            {error && <p class="text-danger" role="alert">{error}</p>}
            <div class="form-group"><label for="username">Username</label>
                <input id="username" class="form-control" autoComplete="username" value={username}
                    onInput={event => setUsername(event.currentTarget.value)} /></div>
            <div class="form-group"><label for="password">Password</label>
                <input id="password" class="form-control" type="password" autoComplete="current-password"
                    value={password} onInput={event => setPassword(event.currentTarget.value)} /></div>
            <label><input type="checkbox" checked={stayLoggedIn}
                onChange={event => setStayLoggedIn(event.currentTarget.checked)} /> Stay logged in</label>
        </div>
        <div class="panel-footer"><button class="btn btn-primary" type="submit" disabled={busy}>Log In</button></div>
    </form>;
}
