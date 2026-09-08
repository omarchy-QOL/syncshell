import {useContext, useEffect, useRef} from 'preact/hooks';
import {bindTooltip} from '../client/tooltip.mjs';
import {LocaleContext} from './locale-context.jsx';

export function Tooltip({icon = '', label, text = '', prefix = '', kind = 'help',
    triggerText, tail = false, children}) {
    const {t} = useContext(LocaleContext);
    const trigger = useRef();
    const tip = useRef();
    useEffect(() => bindTooltip(trigger.current, tip.current), []);
    return <>
        <span ref={trigger} class={icon ? `${icon} folder-${kind === 'count' ? 'count' : 'help'}-icon`
            : tail ? 'folder-tail' : 'folder-text'} tabIndex="0" role={icon ? 'img' : undefined}
            aria-label={triggerText === undefined ? t(label) : label}>{triggerText !== undefined && <bdi dir="ltr">{triggerText}</bdi>}</span>
        <div ref={tip} popover="manual" role="tooltip" class={`tooltip in port-tooltip folder-${kind}-tooltip`}>
            <div class="tooltip-arrow" /><div class="tooltip-inner">{children || <>{prefix ? t(prefix) + '. ' : ''}{triggerText === undefined ? t(text) : text}</>}</div>
        </div>
    </>;
}
