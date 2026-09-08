import {identiconRects} from '../client/devices.mjs';
export function Identicon({id}) {
    return <span class="panel-icon"><svg class="identicon" viewBox="0 0 5 5" aria-hidden="true">
        {identiconRects(id).map(([x, y], index) => <rect key={index} x={x} y={y} width="1" height="1" />)}
    </svg></span>;
}
