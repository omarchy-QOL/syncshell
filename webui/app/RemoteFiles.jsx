import {useContext, useEffect, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {deviceName} from '../client/devices.mjs';
import {unitPrefixed, timestamp} from '../client/format.mjs';
import {Pagination} from './Pagination.jsx';
export function RemoteFiles({api, folder, device, state, single}) {
    const {t} = useContext(LocaleContext);
    const [page, setPage] = useState(1), [perpage, setPerpage] = useState(10);
    const [files, setFiles] = useState([]), [error, setError] = useState('');
    const revision = state.completion[device.deviceID]?.[folder.id]?.needItems + ':' + state.completion[device.deviceID]?.[folder.id]?.needBytes;
    useEffect(() => {
        const controller = new AbortController();
        api.get('db/remoteneed', {folder: folder.id, device: device.deviceID, page, perpage}, controller.signal)
            .then(data => setFiles(data.files || [])).catch(failure => { if (!controller.signal.aborted) setError(failure.message); });
        return () => controller.abort();
    }, [api, folder.id, device.deviceID, page, perpage, revision]);
    const friendly = id => deviceName(state.config.devices.find(item => item.deviceID.startsWith(id || '\0'))) || id || t('Unknown');
    return <details class="panel panel-default" open={single}>
        <summary class="panel-heading">{folder.label || folder.id}</summary>
        <div class="panel-body less-padding">
            {error && <p class="text-danger" role="alert">{error}</p>}
            <table class="table table-striped"><thead><tr>{['Path', 'Size', 'Mod. Time', 'Mod. Device'].map(label => <th key={label}>{t(label)}</th>)}</tr></thead>
                <tbody>{files.map(file => <tr key={file.name}><td class="word-break-all">{file.name}</td><td>{file.type === 'DIRECTORY' ? '' : unitPrefixed(file.size, true) + 'B'}</td><td>{timestamp(file.modified)}</td><td>{friendly(file.modifiedBy)}</td></tr>)}</tbody>
            </table>
            <Pagination page={page} perpage={perpage} total={state.completion[device.deviceID]?.[folder.id]?.needItems || files.length} onPage={setPage} onSize={setPerpage} />
        </div>
    </details>;
}
