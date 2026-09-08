import {useContext,useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {ShareStatus} from './ShareStatus.jsx';
export function SharingEntry({label,id,selected,password = '',encrypted = false,required = false,remoteState = '',onSelected,onPassword}) {
    const {t} = useContext(LocaleContext), [plain,setPlain] = useState(false);
    return <div class="form-group">
        <label title={id}><input type="checkbox" checked={selected} onChange={event=>onSelected(event.currentTarget.checked)} /> {label}</label>
        <ShareStatus remoteState={remoteState} />
        <div class="input-group">
            <span class="input-group-addon"><span aria-hidden="true" class={`fas fa-${encrypted || password ? 'lock' : 'unlock'}`} /></span>
            <input class="form-control" type={plain?'text':'password'} aria-label={t('Encryption Password')+': '+label} autoComplete="off" value={password} disabled={encrypted || !selected} required={selected && !encrypted && required} placeholder={t(encrypted ? 'Received data is already encrypted' : !selected ? 'Not shared' : required ? 'Device is untrusted, enter encryption password' : 'If untrusted, enter encryption password')} onInput={event=>onPassword(event.currentTarget.value)} />
            <span class="input-group-btn"><button type="button" class="btn btn-default" disabled={encrypted || !selected} aria-label={t(plain?'Hide password':'Show password')} onClick={()=>setPlain(!plain)}><span aria-hidden="true" class={`fas fa-${plain?'eye-slash':'eye'}`} /></button></span>
        </div>
    </div>;
}
