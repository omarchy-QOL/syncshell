import {useEffect, useRef} from 'preact/hooks';
import {bindTooltip} from '../client/tooltip.mjs';

export function Tooltip({icon, label, text = '', kind = 'help', children}) {
    const trigger = useRef();
    const tip = useRef();
    useEffect(() => bindTooltip(trigger.current, tip.current), []);
    return <>
        <span ref={trigger} class={`${icon} folder-${kind === 'count' ? 'count' : 'help'}-icon`}
            tabIndex="0" role="img" aria-label={label} />
        <div ref={tip} popover="manual" role="tooltip" class={`tooltip in port-tooltip folder-${kind}-tooltip`}>
            <div class="tooltip-arrow" /><div class="tooltip-inner">{children || text}</div>
        </div>
    </>;
}
