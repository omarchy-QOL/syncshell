import {useContext} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {fieldHelp} from '../client/field-help.mjs';
import {Tooltip} from './Tooltip.jsx';

export function Field({label, rowClass = '', children}) {
    const {t} = useContext(LocaleContext);
    const field = fieldHelp[label];
    return <tr class={rowClass}>
        <th><Tooltip icon={field.icon} label={label} text={field.help} />&nbsp;<span>{t(label)}</span></th>
        <td class="text-right">{children}</td>
    </tr>;
}
