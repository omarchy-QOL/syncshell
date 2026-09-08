import {useContext} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {fieldHelp} from '../client/field-help.mjs';
import {unitPrefixed} from '../client/format.mjs';
import {Tooltip} from './Tooltip.jsx';

export function Field({label, rowClass = '', icon = '', help = '', totalBytes, children}) {
    const {t} = useContext(LocaleContext);
    const field = {icon: icon || fieldHelp[label]?.icon || 'fa fa-info-circle',
        help: help || fieldHelp[label]?.help || ''};
    return <tr class={rowClass}>
        <th><Tooltip icon={field.icon} label={label} text={field.help}>{totalBytes !== undefined && <>{t(field.help)}<br />{t('Total')}: ~{unitPrefixed(totalBytes, true)}B</>}</Tooltip>&nbsp;<span>{t(label)}</span></th>
        <td class="text-right">{children}</td>
    </tr>;
}
