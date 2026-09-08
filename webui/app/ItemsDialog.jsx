import {useContext, useEffect, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {Pagination} from './Pagination.jsx';
import {Dialog} from './Dialog.jsx';
import {Tooltip} from './Tooltip.jsx';
import {itemRoutes, itemTitles, pageItems} from '../client/items.mjs';
import {unitPrefixed} from '../client/format.mjs';

export function ItemsDialog({api, folder, kind, total, onClose}) {
    const {t} = useContext(LocaleContext);
    const [page, setPage] = useState(1);
    const [perpage, setPerpage] = useState(10);
    const [items, setItems] = useState([]);
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    useEffect(() => {
        const controller = new AbortController();
        setLoading(true);
        api.get(itemRoutes[kind], {folder: folder.id, page, perpage}, controller.signal)
            .then(data => { setItems(pageItems(kind, data)); setError(''); })
            .catch(failure => { if (!controller.signal.aborted) setError(failure.message); })
            .finally(() => { if (!controller.signal.aborted) setLoading(false); });
        return () => controller.abort();
    }, [api, folder.id, kind, page, perpage]);
    async function prioritize(file) {
        try {
            const data = await api.post('db/prio', undefined, {folder: folder.id, file, page, perpage});
            setItems(pageItems('need', data));
        } catch (failure) { setError(failure.message); }
    }
    return <Dialog title={itemTitles[kind]} large status={kind === 'failed' ? 'warning' : 'info'}
        icon={kind === 'need' ? 'fas fa-cloud-download-alt' : 'fas fa-exclamation-circle'} onClose={onClose}>
        {kind === 'failed' && <p>{t('The following items could not be synchronized.')} {t('They are retried automatically and will be synced when the error is resolved.')}</p>}
        {kind === 'local' && <p>{t(folder.type === 'receiveencrypted' ? 'The following unexpected items were found.' : 'The following items were changed locally.')}</p>}
        {error && <p role="alert" class="text-danger">{error}</p>}
        <table class="table table-striped table-condensed" aria-busy={loading}><tbody>
            {items.map((file, index) => <tr key={`${file.name || file.path}:${index}`}>
                {kind === 'need' && <td class="small-data">{file.action}</td>}
                <td class="word-break-all">{kind === 'need' ? <>
                    {file.type === 'queued' && <button class="btn btn-link btn-sm" aria-label={t('Move to top of queue')}
                        onClick={() => prioritize(file.name)}><span class="fas fa-eject" /></button>}
                    <Tooltip label={file.name} text={file.name} triggerText={file.name.split('/').at(-1)} />
                </> : file.path || file.name}</td>
                <td>{kind === 'failed' ? file.error : file.type === 'DIRECTORY' ? '' : unitPrefixed(file.size, true) + 'B'}</td>
            </tr>)}
        </tbody></table>
        <Pagination page={page} perpage={perpage} total={total} onPage={setPage} onSize={setPerpage} />
    </Dialog>;
}
