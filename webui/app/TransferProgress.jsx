import {useContext} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {transferSegments} from '../client/transfer.mjs';
import {unitPrefixed} from '../client/format.mjs';
export function TransferProgress({progress, legend = false}) {
    const {t} = useContext(LocaleContext);
    return <div class="progress" role={legend ? undefined : 'progressbar'} aria-label={legend ? undefined : t('Downloading')} aria-valuemin={legend ? undefined : 0} aria-valuemax={legend ? undefined : progress.bytesTotal} aria-valuenow={legend ? undefined : progress.bytesDone}>
        {transferSegments.map(([key, label, color]) => <div key={key} class={`progress-bar ${color ? 'progress-bar-' + color : ''}`} style={{width:(legend ? 20 : Number.isFinite(progress[key]) ? progress[key] : 0) + '%'}} title={t(label)}>{legend && <span class="show">{t(label)}</span>}</div>)}
        {!legend && <span class="show frontal">{unitPrefixed(progress.bytesDone, true)}B / {unitPrefixed(progress.bytesTotal, true)}B</span>}
    </div>;
}
