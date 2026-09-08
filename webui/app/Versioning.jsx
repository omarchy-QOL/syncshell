import {useContext} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {duration} from '../client/format.mjs';
import {versioningTypes} from '../client/folder-view.mjs';
import {Tooltip} from './Tooltip.jsx';

export function Versioning({config}) {
    const {t, language} = useContext(LocaleContext);
    const path = config.fsPath || '.stversions';
    const time = value => duration(value, 's', language);
    return <>
        <span title={config.type === 'external' ? config.params.command : ''}>{t(versioningTypes[config.type] || '')}</span>
        {config.type !== 'external' && <>
            {['trashcan', 'simple'].includes(config.type) && <span title={t('Clean out after')}>&ensp;<span class="fa fa-calendar" />&nbsp;{Number(config.params.cleanoutDays) === 0 ? t('Disabled') : duration(config.params.cleanoutDays * 86400, 'd', language)}</span>}
            {config.type === 'simple' && <span title={t('Keep Versions')}>&ensp;<span class="fa fa-file-archive-o" />&nbsp;{config.params.keep}</span>}
            {config.type === 'staggered' && <span title={t('Maximum Age')}>&ensp;<span class="fa fa-calendar" />&nbsp;{Number(config.params.maxAge) === 0 ? t('Forever') : time(config.params.maxAge)}</span>}
            <span title={t('Cleanup Interval')}>&ensp;<span class="fa fa-recycle" />&nbsp;{config.cleanupIntervalS === 0 ? t('Disabled') : time(config.cleanupIntervalS)}</span>
            <span class="folder-change"><span class="fa fa-folder-open-o" /><Tooltip label={path} text={path} triggerText={path.split(/[\\/]/).at(-1)} tail /></span>
        </>}
    </>;
}
