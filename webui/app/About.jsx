import {useContext, useEffect, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {Dialog} from './Dialog.jsx';
import data from '../client/about-data.json';
import {aboutPaths} from '../client/about.mjs';
export function About({api, version, onClose}) {
    const {t} = useContext(LocaleContext);
    const [tab, setTab] = useState('Authors'), [paths, setPaths] = useState({}), [error, setError] = useState('');
    useEffect(() => {
        const controller = new AbortController();
        if (window.metadata?.authenticated) api.get('system/paths', undefined, controller.signal).then(setPaths)
            .catch(value => { if (!controller.signal.aborted) setError(value.message); });
        return () => controller.abort();
    }, [api]);
    return <Dialog title="About" large status="info" icon="far fa-heart" onClose={onClose}>
        <h2 class="text-center"><a href="https://github.com/omarchy-QOL/syncshell" target="_blank" rel="noreferrer">Syncshell</a></h2>
        <p class="text-center">Modern / Omarchy Web UI, based on Syncthing.</p>
        <p class="text-center">Syncthing {version.version || ''} {version.codename || ''}</p>
        {version.date && <p class="text-center">Build {version.date.slice(0, 10)} {Array.isArray(version.tags) ? version.tags.join(', ') : ''}</p>}
        {!version.version && <p class="text-center">{t('Log in to see version information.')}</p>}
        <p class="text-center">{t('Syncthing is Free and Open Source Software licensed as MPL v2.0.')} <a href="LICENSE.syncthing">MPL 2.0</a></p>
        <ul class="nav nav-tabs">{['Authors','Included Software','Paths'].map(name => <li key={name} class={tab === name ? 'active' : ''}><a href={'#about-' + name} onClick={event => { event.preventDefault(); setTab(name); }}>{t(name)}</a></li>)}</ul>
        {error && <p class="text-danger" role="alert">{error}</p>}
        {tab === 'Authors' ? <><h4>{t('The Syncthing Authors')}</h4><p>{data.authors}</p></> : tab === 'Included Software' ? <><p>Preact · <a href="licenses/preact.txt">MIT license</a></p><p>{t('Syncthing includes the following software or portions thereof:')}</p><ul class="list-unstyled">{data.software.map(software => <li key={software.url}><a href={software.url} target="_blank" rel="noreferrer">{software.name}</a> · {software.notice}</li>)}</ul></>
            : <table class="table table-condensed table-striped port-about-paths"><caption>{t('Internally used paths:')}</caption><tbody>{aboutPaths.map(([label,keys]) => <tr key={label}><th>{t(label)}</th><td>{keys.map(key => <div key={key}><code class="word-break-all">{paths[key] || ''}</code></div>)}</td></tr>)}</tbody></table>}
    </Dialog>;
}
