import {useContext, useEffect, useRef, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';

const entries = window.validLangs.map(code => [code, window.langPrettyprint[code] || `[${code}]`])
    .sort((a, b) => a[1].localeCompare(b[1]));

export function LanguageMenu() {
    const locale = useContext(LocaleContext);
    const [open, setOpen] = useState(false);
    const root = useRef();
    useEffect(() => {
        function outside(event) { if (!root.current.contains(event.target)) setOpen(false); }
        document.addEventListener('pointerdown', outside);
        return () => document.removeEventListener('pointerdown', outside);
    }, []);
    function key(event) {
        if (event.key === 'Escape') { setOpen(false); root.current.querySelector('a').focus(); }
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
            event.preventDefault();
            setOpen(true);
            const items = [...root.current.querySelectorAll('.dropdown-menu a')];
            const step = event.key === 'ArrowDown' ? 1 : -1;
            const index = items.indexOf(document.activeElement);
            requestAnimationFrame(() => items[Math.max(0, Math.min(items.length - 1, index + step))]?.focus());
        }
    }
    return <li ref={root} class={`dropdown ${open ? 'open' : ''}`} >
        <a href="#language" class="dropdown-toggle" aria-label="Language" onKeyDown={key} aria-expanded={open} aria-haspopup="true"
            onClick={event => { event.preventDefault(); setOpen(!open); }}>
            <span class="fas fa-globe" /><span class="hidden-xs">&nbsp;{window.langPrettyprint[locale.language] || 'English'}</span> <span class="caret" />
        </a>
        <ul class="dropdown-menu">{entries.map(([code, name]) =>
            <li key={code} class={code === locale.language ? 'active' : ''}><a href="#language" onKeyDown={key}
                onClick={event => { event.preventDefault(); locale.select(code); setOpen(false); }}>{name}</a></li>)}</ul>
    </li>;
}
