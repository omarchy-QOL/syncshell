import {useContext} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {getValue, inputValue, changedValue} from '../client/edit.mjs';
export function FormFields({draft, fields, onChange}) {
    const {t} = useContext(LocaleContext);
    return fields.map(field => <div class="form-group" key={field.path}>
        {field.type === 'checkbox' ? <label><input type="checkbox" checked={!!getValue(draft, field.path)} onChange={event => onChange(field.path, event.currentTarget.checked)} /> {t(field.label)}</label> : <>
            <label for={'config-' + field.path}>{t(field.label)}</label>
            {field.type === 'select' ? <select id={'config-' + field.path} class="form-control" value={inputValue(draft, field)} onChange={event => onChange(field.path, event.currentTarget.value)}>
                {field.options.map(([value, label]) => <option key={value} value={value}>{t(label)}</option>)}
            </select> : field.type === 'lines' ? <textarea id={'config-' + field.path} class="form-control" rows="6" value={(getValue(draft, field.path) || []).join('\n')} onInput={event => onChange(field.path, event.currentTarget.value.split('\n'))} />
                : <input id={'config-' + field.path} class="form-control" type={field.type === 'list' ? 'text' : field.type} step="any" min={field.min} required={field.required} value={inputValue(draft, field)} onInput={event => onChange(field.path, changedValue(field, event.currentTarget))} />}
        </>}
    </div>);
}
