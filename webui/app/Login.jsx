import {LocaleContext} from './locale-context.jsx';
import {useContext, useEffect, useRef, useState} from 'preact/hooks';
import {createApi} from '../client/api.mjs';

export function Login() {
    const {t} = useContext(LocaleContext);
    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');
    const [stayLoggedIn, setStayLoggedIn] = useState(false);
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState('');
    const userInput = useRef();
    useEffect(() => { userInput.current.focus(); }, []);
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
    return <div class="center-block">
        <h3>{t('Authentication Required')}</h3>
        <form onSubmit={login}>
            <div class="form-group"><label for="user">{t('User')}</label>
                <input id="user" name="user" class="form-control" autoComplete="username"
                    ref={userInput} value={username} required
                    onInput={event => setUsername(event.currentTarget.value)} /></div>
            <div class="form-group"><label for="password">{t('Password')}</label>
                <input id="password" name="password" class="form-control" type="password"
                    autoComplete="current-password" value={password}
                    onInput={event => setPassword(event.currentTarget.value)} /></div>
            <div class="form-group"><label><input id="stayLoggedIn" type="checkbox"
                checked={stayLoggedIn} onChange={event => setStayLoggedIn(event.currentTarget.checked)} /> {t('Stay logged in')}</label></div>
            <div class="row">
                <div class="col-md-9 login-form-messages">
                    {error && <p class="text-danger" role="alert">{t(error)}</p>}
                </div>
                <div class="col-md-3 text-right"><button id="submit" class="btn btn-default"
                    type="submit" disabled={busy}>{t('Log In')}</button></div>
            </div>
        </form>
    </div>;
}
