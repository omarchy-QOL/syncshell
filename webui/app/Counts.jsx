import {Tooltip} from './Tooltip.jsx';
import {compactNumber, unitPrefixed} from '../client/format.mjs';

export function Counts({info, prefix = 'global'}) {
    const files = info?.[prefix + 'Files'];
    const folders = info?.[prefix + 'Directories'];
    const bytes = info?.[prefix + 'Bytes'];
    const full = <>
        <div><span><span class="far fa-fw fa-copy" /> Files:</span><span>{(files || 0).toLocaleString()}</span></div>
        <div><span><span class="far fa-fw fa-folder" /> Folders:</span><span>{(folders || 0).toLocaleString()}</span></div>
        <div><span><span class="far fa-fw fa-hdd" /> Total:</span><span>~{unitPrefixed(bytes, true)}B</span></div>
    </>;
    return <>
        <Tooltip icon="far fa-copy" label="Files" kind="count">{full}</Tooltip>&nbsp;{compactNumber(files)}&ensp;
        <Tooltip icon="far fa-hdd" label="Total" kind="count">{full}</Tooltip>&nbsp;~{unitPrefixed(bytes, true)}B
    </>;
}
