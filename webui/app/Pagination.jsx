import {useContext} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {paginationPages} from '../client/pagination.mjs';

export function Pagination({page, perpage, total, onPage, onSize}) {
    const {t} = useContext(LocaleContext);
    const pages = paginationPages(page, total, perpage);
    const last = Math.ceil(total / perpage);
    function change(event, next) {
        event.preventDefault();
        if (typeof next === 'number' && next >= 1 && next <= last && next !== page) onPage(next);
    }
    return <>
        {pages.length > 1 && <ul class="pagination">
            <li class={page === 1 ? 'disabled' : ''}><a href="#previous" aria-label={t('Previous')} aria-disabled={page === 1}
                onClick={event => change(event, page - 1)}>&lsaquo;</a></li>
            {pages.map((number, index) => <li key={index} class={number === page ? 'active' : number === '...' ? 'disabled' : ''}>
                <a href={`#page-${index}`} aria-current={number === page ? 'page' : undefined}
                    aria-disabled={number === '...'} onClick={event => change(event, number)}>{number}</a></li>)}
            <li class={page === last ? 'disabled' : ''}><a href="#next" aria-label={t('Next')} aria-disabled={page === last}
                onClick={event => change(event, page + 1)}>&rsaquo;</a></li>
        </ul>}
        <ul class="pagination pull-right">{[10, 25, 50].map(size => <li key={size} class={size === perpage ? 'active' : ''}>
            <a href="#page-size" onClick={event => { event.preventDefault(); onPage(Math.min(page, Math.max(1, Math.ceil(total / size)))); onSize(size); }}>{size}</a></li>)}</ul>
        <div class="clearfix" />
    </>;
}
