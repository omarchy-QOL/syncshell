import {useContext} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {noticeAction} from '../client/notices.mjs';
import {timestamp} from '../client/format.mjs';
import {Identicon} from './Identicon.jsx';

const color = action => ['Ignore', 'Disable Crash Reporting'].includes(action) ? 'danger'
    : action === 'Yes' ? 'primary' : ['Add Device', 'Add', 'Share', 'Enable Crash Reporting'].includes(action) ? 'success' : 'default';
const icon = action => ({Settings: 'fa-cog', Restart: 'fa-refresh', 'Add Device': 'fa-plus',
    Ignore: 'fa-times', Dismiss: 'fa-clock', No: 'fa-times', 'Disable Crash Reporting': 'fa-times'})[action] || 'fa-check';

export function Notifications({cards, session, onAction}) {
    const {t} = useContext(LocaleContext);
    return <>
        <h3>{t('Notifications')}</h3>
        {!cards.length && <p class="notifications-empty">{t('No pending notifications.')}</p>}
        {cards.map(card => <div class="row" key={card.id}><div class="col-md-12"><div class={`panel panel-${card.severity}`}>
            <div class="panel-heading"><h3 class="panel-title">
                {card.kind === 'device' ? <Identicon id={card.device} /> :
                    <span class="panel-icon"><span class={`fas ${card.kind === 'folder' ? 'fa-folder' : card.severity === 'success' ? 'fa-bolt' : 'fa-exclamation-circle'}`} /></span>}
                {t(card.title)}{card.time && <span class="pull-right">{timestamp(card.time)}</span>}
            </h3></div>
            <div class="panel-body">
                {(card.paragraphs || []).map((paragraph, index) => <p key={index}>{t(paragraph, card.params)}</p>)}
                {(card.errors || []).map((error, index) => <p key={index}><small>{timestamp(error.when)}:</small> {error.message}</p>)}
                {card.watchers && <table><tbody>{card.watchers.map(watcher => <tr key={watcher.name}><td>{watcher.name}: </td><td>{watcher.error}</td></tr>)}</tbody></table>}
                {card.link && <p><a href={card.link} target="_blank" rel="noreferrer"><span class="fas fa-info-circle" />&nbsp;{t(card.id === 'watchers' ? 'Support' : 'Learn more')}</a></p>}
            </div>
            {card.actions?.length > 0 && <div class="panel-footer clearfix">{card.actions.map(action =>
                <button key={action} class={`btn btn-sm btn-${color(action)}`}
                    onClick={() => noticeAction(session, card, action, onAction).catch(() => {})}>
                    <span class={`fas ${icon(action)}`} />&nbsp;{t(action)}
                </button>)}</div>}
        </div></div></div>)}
    </>;
}
